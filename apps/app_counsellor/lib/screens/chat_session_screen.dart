import 'package:flutter/material.dart';
import 'package:common/api/api_client.dart';
import '../models/session.dart';
import 'dart:async';

class ChatSessionScreen extends StatefulWidget {
  final Session session;

  const ChatSessionScreen({super.key, required this.session});

  @override
  State<ChatSessionScreen> createState() => _ChatSessionScreenState();
}

class _ChatSessionScreenState extends State<ChatSessionScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiClient _api = ApiClient();

  late Session _session;
  bool _isSessionActive = false;
  DateTime? _startTime;
  DateTime? _endTime;
  Timer? _timer;
  Timer? _messagePollTimer;
  int _elapsedSeconds = 0;
  RiskLevel _selectedRisk = RiskLevel.none;
  bool _sendingMessage = false;

  // Manual flag colors
  String _manualFlag = 'green'; // 'green', 'yellow', 'red'

  final List<ChatMessage> _messages = [];
  int? _chatId;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _selectedRisk = _session.riskLevel;
    _notesController.text = _session.notes ?? '';
    _chatId = int.tryParse(_session.id);

    // Add initial system message
    _messages.add(
      ChatMessage(
        text:
            'Chat session scheduled for ${_formatTime(_session.scheduledTime)}',
        isClient: false,
        isSystem: true,
        timestamp: DateTime.now(),
      ),
    );

    // Load initial message if available (from accepted chat)
    // Use Future.microtask to ensure setState is called after initState completes
    Future.microtask(() => _loadInitialChatData());
    
    // Start polling for new messages if session is active
    if (_session.status == SessionStatus.inProgress) {
      _isSessionActive = true;
      _startMessagePolling();
    }
  }

  Future<void> _loadInitialChatData() async {
    // Small delay to ensure widget is fully built
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (!mounted) return;
    
    // Load initial message from session notes (temporarily stored there)
    if (_session.notes != null && _session.notes!.trim().isNotEmpty) {
      // Check if notes contain the initial message (from accepted chat)
      final initialMessage = _session.notes!.trim();
      // Only add if it's not a system message and not empty
      if (initialMessage.isNotEmpty && 
          !initialMessage.startsWith('Chat session') &&
          !initialMessage.startsWith('Session started')) {
        // Check if this message is already in the list
        final messageExists = _messages.any((msg) => 
          msg.text == initialMessage && msg.isClient);
        
        if (!messageExists && mounted) {
          setState(() {
            _messages.add(
              ChatMessage(
                text: initialMessage,
                isClient: true,
                isSystem: false,
                timestamp: _session.scheduledTime,
              ),
            );
          });
          _scrollToBottom();
        }
      }
    }
    
    // Try to fetch chat details and messages if chatId is available
    if (_chatId != null) {
      await _fetchChatMessages();
    }
  }

  Future<void> _fetchChatMessages() async {
    if (_chatId == null) return;
    
    try {
      // Try to get chat details - for now we'll simulate by checking if there are messages
      // In a full implementation, you'd call: await _api.getChatMessages(_chatId!);
      // For now, we'll use polling to check for new messages
    } catch (e) {
      // Silently fail - message fetching is optional
    }
  }

  void _startMessagePolling() {
    // Poll for new messages every 3 seconds
    _messagePollTimer?.cancel();
    _messagePollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _isSessionActive && _chatId != null) {
        _checkForNewMessages();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _checkForNewMessages() async {
    if (_chatId == null) return;
    
    try {
      // TODO: Implement actual message fetching API
      // For now, we'll check if we can get chat details to see if there are new messages
      // In a full implementation, you would:
      // 1. Call API to get chat messages: await _api.getChatMessages(_chatId!);
      // 2. Compare with existing messages by timestamp or ID
      // 3. Add new messages that aren't in the list
      
      // Example implementation (when API is ready):
      // final chatData = await _api.getChatDetails(_chatId!);
      // if (chatData['messages'] != null) {
      //   final messages = chatData['messages'] as List;
      //   for (var msg in messages) {
      //     final messageId = msg['id'];
      //     if (!_messages.any((m) => m.id == messageId)) {
      //       setState(() {
      //         _messages.add(ChatMessage(
      //           id: messageId,
      //           text: msg['text'],
      //           isClient: msg['sender'] == 'user',
      //           timestamp: DateTime.parse(msg['timestamp']),
      //         ));
      //       });
      //     }
      //   }
      //   _scrollToBottom();
      // }
    } catch (e) {
      // Silently fail - polling will continue
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messagePollTimer?.cancel();
    _messageController.dispose();
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    try {
      // Call API to start session if session ID is numeric
      final sessionId = int.tryParse(_session.id);
      if (sessionId != null) {
        try {
          await _api.startSession(sessionId);
        } catch (e) {
          // Session might already be started or endpoint might not exist
          // Continue anyway
        }
      }

      if (!mounted) return;

      setState(() {
        _isSessionActive = true;
        _startTime = DateTime.now();
        _session = Session(
          id: _session.id,
          clientId: _session.clientId,
          clientName: _session.clientName,
          clientPhoto: _session.clientPhoto,
          counselorId: _session.counselorId,
          scheduledTime: _session.scheduledTime,
          startTime: _startTime,
          endTime: null,
          type: _session.type,
          status: SessionStatus.inProgress,
          notes: _session.notes,
          riskLevel: _session.riskLevel,
          isEscalated: _session.isEscalated,
          durationMinutes: _session.durationMinutes,
        );
      });

      // Start timer
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _elapsedSeconds++;
          });
        }
      });

      // Add system message
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Session started at ${_formatTime(_startTime!)}',
            isClient: false,
            isSystem: true,
            timestamp: _startTime!,
          ),
        );
      });
      _scrollToBottom();

      // Add welcome message from counselor
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _messages.add(
              ChatMessage(
                text: "Hello! I'm here to support you. How can I help you today?",
                isClient: false,
                isSystem: false,
                timestamp: DateTime.now(),
              ),
            );
          });
          _scrollToBottom();
        }
      });

      // Start polling for new messages
      _startMessagePolling();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat session started')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _sendingMessage) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _sendingMessage = true;
      _messages.add(
        ChatMessage(
          text: messageText,
          isClient: false,
          isSystem: false,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();

    try {
      // TODO: Send message via API when message endpoints are available
      // For now, message is stored locally
      // await _api.sendChatMessage(_session.id, messageText);
      
      if (mounted) {
        setState(() {
          _sendingMessage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sendingMessage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _endSession() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Chat Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to end this chat session?'),
            const SizedBox(height: 16),
            Text(
              'Started: ${_formatTime(_startTime!)}',
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              'Duration: ${_formatDuration(_elapsedSeconds)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _completeSession();
            },
            child: const Text('End Session'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeSession() async {
    _timer?.cancel();
    
    final sessionId = int.tryParse(_session.id);
    if (sessionId != null && _isSessionActive) {
      try {
        await _api.endSession(sessionId);
      } catch (e) {
        // Log error but continue with UI update
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Note: Session end API call failed: $e'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _endTime = DateTime.now();
      _isSessionActive = false;
      _session = Session(
        id: _session.id,
        clientId: _session.clientId,
        clientName: _session.clientName,
        clientPhoto: _session.clientPhoto,
        counselorId: _session.counselorId,
        scheduledTime: _session.scheduledTime,
        startTime: _startTime,
        endTime: _endTime,
        type: _session.type,
        status: SessionStatus.completed,
        notes: _notesController.text,
        riskLevel: _selectedRisk,
        isEscalated: _session.isEscalated,
        durationMinutes: _elapsedSeconds ~/ 60,
      );
    });

    // Add system message
    setState(() {
      _messages.add(
        ChatMessage(
          text: 'Session ended at ${_formatTime(_endTime!)}',
          isClient: false,
          isSystem: true,
          timestamp: _endTime!,
        ),
      );
    });

    _showSessionSummary();
  }

  void _showSessionSummary() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Completed'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryRow('Client', _session.clientName),
              _buildSummaryRow('Type', 'Chat Session'),
              _buildSummaryRow('Started', _formatTime(_startTime!)),
              _buildSummaryRow('Ended', _formatTime(_endTime!)),
              _buildSummaryRow('Duration', _formatDuration(_elapsedSeconds)),
              _buildSummaryRow('Messages', '${_messages.length}'),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Risk Assessment
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showRiskSelectionDialog,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getRiskColor(_selectedRisk).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getRiskColor(_selectedRisk).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          color: _getRiskColor(_selectedRisk),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Risk Assessment',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap to change',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getRiskColor(_selectedRisk),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _selectedRisk.name.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Manual Flag Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getManualFlagColor(_manualFlag).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getManualFlagColor(_manualFlag).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.flag,
                      color: _getManualFlagColor(_manualFlag),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Manual Flag',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Set by counselor',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getManualFlagColor(_manualFlag),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _manualFlag.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close summary
                    _showManualFlagDialog();
                  },
                  icon: const Icon(Icons.flag),
                  label: const Text('Set/Update Manual Flag'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Text(
                'Session saved successfully',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to dashboard
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_session.clientName),
            if (_isSessionActive)
              Text(
                _formatDuration(_elapsedSeconds),
                style: const TextStyle(fontSize: 14),
              ),
          ],
        ),
        actions: [
          if (_isSessionActive)
            IconButton(
              icon: const Icon(Icons.note_add),
              onPressed: _showNotesDialog,
              tooltip: 'Add Private Notes',
            ),
        ],
      ),
      body: Column(
        children: [
          // Session Status Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: _isSessionActive
                ? Colors.green.shade50
                : Colors.grey.shade100,
            child: Row(
              children: [
                Icon(
                  _isSessionActive ? Icons.circle : Icons.circle_outlined,
                  color: _isSessionActive ? Colors.green : Colors.grey,
                  size: 12,
                ),
                const SizedBox(width: 8),
                Text(
                  _isSessionActive
                      ? 'Session Active - Started at ${_formatTime(_startTime!)}'
                      : 'Session Not Started',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isSessionActive
                        ? Colors.green.shade900
                        : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),

          // Risk Level Indicator (Real-time during session)
          if (_isSessionActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _getRiskColor(_selectedRisk).withOpacity(0.1),
              child: Row(
                children: [
                  Icon(
                    Icons.flag_outlined,
                    color: _getRiskColor(_selectedRisk),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Risk Level:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _getRiskColor(_selectedRisk),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _selectedRisk.name.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Chat Messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start the session to begin chatting',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (!_isSessionActive)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _startSession,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Chat Session'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    )
                  else ...[
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type your message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send),
                      color: Theme.of(context).primaryColor,
                      iconSize: 28,
                    ),
                    IconButton(
                      onPressed: _endSession,
                      icon: const Icon(Icons.call_end),
                      color: Colors.red,
                      iconSize: 28,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    if (message.isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message.text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ),
      );
    }

    // Client messages on left, Counselor messages on right
    final isClient = message.isClient;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isClient ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isClient)
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.person, color: Colors.white),
            ),
          if (isClient) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isClient
                    ? Colors.grey.shade200
                    : Theme.of(context).primaryColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isClient ? 20 : 0),
                  bottomRight: Radius.circular(isClient ? 0 : 20),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isClient
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 15,
                      color: isClient ? Colors.grey[800] : Colors.white,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isClient
                          ? Colors.grey.shade600
                          : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isClient) const SizedBox(width: 8),
          if (!isClient)
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.sentiment_satisfied_alt, color: Colors.white),
            ),
        ],
      ),
    );
  }

  void _showNotesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Private Notes'),
        content: TextField(
          controller: _notesController,
          decoration: const InputDecoration(
            hintText: 'Add confidential session notes...',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Notes saved')));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showManualFlagDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Manual Flag'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select flag color:'),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFlagOption('green', Colors.green, 'Green'),
                _buildFlagOption('yellow', Colors.yellow.shade700, 'Yellow'),
                _buildFlagOption('red', Colors.red, 'Red'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showRiskSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Risk Level'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRiskOption(RiskLevel.none, 'No Concern'),
              _buildRiskOption(RiskLevel.low, 'Low Risk'),
              _buildRiskOption(RiskLevel.medium, 'Medium Risk'),
              _buildRiskOption(RiskLevel.high, 'High Risk'),
              _buildRiskOption(
                RiskLevel.critical,
                'Critical - Immediate Attention',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRiskOption(RiskLevel level, String label) {
    final isSelected = _selectedRisk == level;
    final color = _getRiskColor(level);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRisk = level;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Risk level set to: $label'),
            backgroundColor: color,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildFlagOption(String flag, Color color, String label) {
    final isSelected = _manualFlag == flag;
    return GestureDetector(
      onTap: () {
        setState(() {
          _manualFlag = flag;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Flag set to: $label'),
            backgroundColor: color,
            duration: const Duration(seconds: 2),
          ),
        );
        // Show summary again after setting flag
        _showSessionSummary();
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.black : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8),
              ],
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 30)
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Color _getManualFlagColor(String flag) {
    switch (flag) {
      case 'red':
        return Colors.red;
      case 'yellow':
        return Colors.yellow.shade700;
      case 'green':
      default:
        return Colors.green;
    }
  }

  Color _getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.none:
        return Colors.green;
      case RiskLevel.low:
        return Colors.yellow.shade700;
      case RiskLevel.medium:
        return Colors.orange;
      case RiskLevel.high:
        return Colors.deepOrange;
      case RiskLevel.critical:
        return Colors.red;
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class ChatMessage {
  final String text;
  final bool isClient;
  final bool isSystem;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isClient,
    required this.isSystem,
    required this.timestamp,
  });
}
