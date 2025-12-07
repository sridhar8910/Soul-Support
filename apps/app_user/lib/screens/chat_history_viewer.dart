import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:common/api/api_client.dart';

class ChatHistoryViewer extends StatefulWidget {
  final int chatId;
  final String counsellorName;

  const ChatHistoryViewer({
    super.key,
    required this.chatId,
    required this.counsellorName,
  });

  @override
  State<ChatHistoryViewer> createState() => _ChatHistoryViewerState();
}

class _ChatHistoryViewerState extends State<ChatHistoryViewer> {
  final ApiClient _api = ApiClient();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final messages = await _api.getChatMessages(widget.chatId);
      if (!mounted) return;
      
      setState(() {
        _messages = messages;
        _loading = false;
      });
      
      // Scroll to bottom after loading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } on ApiClientException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load chat messages. Please try again.';
        _loading = false;
      });
    }
  }

  String _formatTimestamp(String? timestampStr) {
    if (timestampStr == null || timestampStr.isEmpty) return '';
    try {
      final date = DateTime.parse(timestampStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(date.year, date.month, date.day);
      
      if (messageDate == today) {
        return DateFormat('h:mm a').format(date);
      } else {
        return DateFormat('MMM d, h:mm a').format(date);
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.counsellorName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (_messages.isNotEmpty)
              Text(
                '${_messages.length} message${_messages.length != 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF8B5FBF),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadMessages,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _messages.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No messages in this chat',
                            style: TextStyle(color: Colors.grey),
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
                        final text = message['text']?.toString() ?? '';
                        final isUser = message['is_user'] == true;
                        final timestamp = message['created_at']?.toString() ?? 
                                         message['timestamp']?.toString() ?? '';
                        final timestampFormatted = _formatTimestamp(timestamp);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            mainAxisAlignment:
                                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isUser) ...[
                                const CircleAvatar(
                                  backgroundColor: Color(0xFF8B5FBF),
                                  radius: 18,
                                  child: Icon(Icons.person, color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Column(
                                  crossAxisAlignment:
                                      isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isUser
                                            ? const Color(0xFF8B5FBF)
                                            : Colors.grey[200],
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(20),
                                          topRight: const Radius.circular(20),
                                          bottomLeft: Radius.circular(isUser ? 20 : 0),
                                          bottomRight: Radius.circular(isUser ? 0 : 20),
                                        ),
                                      ),
                                      child: Text(
                                        text,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: isUser ? Colors.white : Colors.grey[800],
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                    if (timestampFormatted.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        timestampFormatted,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (isUser) ...[
                                const SizedBox(width: 8),
                                const CircleAvatar(
                                  backgroundColor: Color(0xFF8B5FBF),
                                  radius: 18,
                                  child: Icon(Icons.person, color: Colors.white, size: 20),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

