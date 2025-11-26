"""
Django management command to check if messages are being saved
"""
from django.core.management.base import BaseCommand
from django.db.models import Count
from api.models import Chat, ChatMessage
from django.contrib.auth.models import User


class Command(BaseCommand):
    help = 'Check if chat messages are being saved to database'

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS("\n" + "=" * 80))
        self.stdout.write(self.style.SUCCESS("CHECKING CHAT MESSAGES IN DATABASE"))
        self.stdout.write(self.style.SUCCESS("=" * 80))
        
        # Check if tables exist first
        from django.db import connection
        with connection.cursor() as cursor:
            if connection.vendor == 'sqlite':
                cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name IN ('api_chat', 'api_chatmessage');")
            else:  # PostgreSQL
                cursor.execute("""
                    SELECT table_name FROM information_schema.tables 
                    WHERE table_schema = 'public' 
                    AND table_name IN ('api_chat', 'api_chatmessage');
                """)
            existing_tables = [row[0] for row in cursor.fetchall()]
        
        if 'api_chat' not in existing_tables or 'api_chatmessage' not in existing_tables:
            self.stdout.write(self.style.ERROR("\n[ERROR] Required tables do not exist!"))
            self.stdout.write("Missing tables:")
            if 'api_chat' not in existing_tables:
                self.stdout.write("  - api_chat")
            if 'api_chatmessage' not in existing_tables:
                self.stdout.write("  - api_chatmessage")
            self.stdout.write("\nPlease run migrations: python manage.py migrate")
            return
        
        # Count total messages
        try:
            total_messages = ChatMessage.objects.count()
            total_chats = Chat.objects.count()
        except Exception as e:
            self.stdout.write(self.style.ERROR(f"\n[ERROR] Failed to query database: {e}"))
            return
        
        self.stdout.write(f"\n📊 Database Statistics:")
        self.stdout.write(f"   Total Chats: {total_chats}")
        self.stdout.write(f"   Total Messages: {total_messages}")
        
        if total_messages == 0:
            self.stdout.write(self.style.WARNING("\n⚠️  NO MESSAGES FOUND IN DATABASE!"))
            self.stdout.write("   This means messages are NOT being saved.")
        else:
            self.stdout.write(self.style.SUCCESS(f"\n✅ Found {total_messages} messages in database"))
        
        # Show recent messages
        recent_messages = ChatMessage.objects.select_related('chat', 'sender').order_by('-created_at')[:10]
        
        if recent_messages:
            self.stdout.write(f"\n📝 Recent Messages (last {len(recent_messages)}):")
            self.stdout.write("-" * 80)
            for msg in recent_messages:
                self.stdout.write(f"   ID: {msg.id} | Chat: {msg.chat_id} | Sender: {msg.sender.username} | Time: {msg.created_at}")
                self.stdout.write(f"   Text: {msg.text[:60]}..." if len(msg.text) > 60 else f"   Text: {msg.text}")
                self.stdout.write("")
        
        # Check messages by chat
        chats_with_messages = Chat.objects.annotate(
            msg_count=Count('messages')
        ).filter(msg_count__gt=0)
        
        if chats_with_messages.exists():
            self.stdout.write(f"\n💬 Chats with Messages:")
            self.stdout.write("-" * 80)
            for chat in chats_with_messages[:5]:
                msg_count = ChatMessage.objects.filter(chat=chat).count()
                self.stdout.write(f"   Chat ID: {chat.id} | Status: {chat.status} | Messages: {msg_count}")
        else:
            self.stdout.write(self.style.WARNING("\n⚠️  NO CHATS HAVE MESSAGES!"))
        
        self.stdout.write("\n" + "=" * 80)

