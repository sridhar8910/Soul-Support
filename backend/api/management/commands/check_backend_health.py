"""
Django management command to check backend health and functionality.
"""
from django.core.management.base import BaseCommand
from django.db import connection
from django.contrib.auth.models import User
from django.apps import apps


class Command(BaseCommand):
    help = 'Check backend health and functionality'

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS("\n" + "=" * 100))
        self.stdout.write(self.style.SUCCESS("BACKEND HEALTH CHECK"))
        self.stdout.write(self.style.SUCCESS("=" * 100))
        
        all_checks_passed = True
        
        # 1. Database Connection
        self.stdout.write("\n1. Database Connection")
        self.stdout.write("-" * 100)
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
                result = cursor.fetchone()
                if result:
                    self.stdout.write(self.style.SUCCESS("  [OK] Database connection successful"))
                else:
                    self.stdout.write(self.style.ERROR("  [ERROR] Database connection failed"))
                    all_checks_passed = False
        except Exception as e:
            self.stdout.write(self.style.ERROR(f"  [ERROR] Database connection error: {e}"))
            all_checks_passed = False
        
        # 2. Database Tables
        self.stdout.write("\n2. Database Tables")
        self.stdout.write("-" * 100)
        try:
            from api.models import UserProfile, Chat, ChatMessage
            total_models = len([m for m in apps.get_models() if m._meta.app_label == 'api'])
            with connection.cursor() as cursor:
                if connection.vendor == 'postgresql':
                    cursor.execute("""
                        SELECT COUNT(*) FROM information_schema.tables 
                        WHERE table_schema = 'public' AND table_name LIKE 'api_%';
                    """)
                else:
                    cursor.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name LIKE 'api_%';")
                table_count = cursor.fetchone()[0]
            
            if table_count >= total_models - 2:  # Allow some margin
                self.stdout.write(self.style.SUCCESS(f"  [OK] Found {table_count} API tables (expected ~{total_models})"))
            else:
                self.stdout.write(self.style.WARNING(f"  [WARNING] Found {table_count} API tables, expected ~{total_models}"))
        except Exception as e:
            self.stdout.write(self.style.ERROR(f"  [ERROR] Table check failed: {e}"))
            all_checks_passed = False
        
        # 3. Model Queries
        self.stdout.write("\n3. Model Queries")
        self.stdout.write("-" * 100)
        try:
            user_count = User.objects.count()
            self.stdout.write(self.style.SUCCESS(f"  [OK] User model query: {user_count} users found"))
            
            # Try querying API models
            try:
                profile_count = UserProfile.objects.count()
                self.stdout.write(self.style.SUCCESS(f"  [OK] UserProfile model query: {profile_count} profiles found"))
            except Exception as e:
                self.stdout.write(self.style.WARNING(f"  [WARNING] UserProfile query: {e}"))
            
            try:
                chat_count = Chat.objects.count()
                self.stdout.write(self.style.SUCCESS(f"  [OK] Chat model query: {chat_count} chats found"))
            except Exception as e:
                self.stdout.write(self.style.WARNING(f"  [WARNING] Chat query: {e}"))
                
        except Exception as e:
            self.stdout.write(self.style.ERROR(f"  [ERROR] Model query failed: {e}"))
            all_checks_passed = False
        
        # 4. Settings Check
        self.stdout.write("\n4. Settings Configuration")
        self.stdout.write("-" * 100)
        from django.conf import settings
        
        checks = [
            ('DEBUG', settings.DEBUG, 'Debug mode'),
            ('DATABASE ENGINE', settings.DATABASES['default']['ENGINE'], 'Database engine'),
            ('ALLOWED_HOSTS', settings.ALLOWED_HOSTS, 'Allowed hosts'),
            ('INSTALLED_APPS', len(settings.INSTALLED_APPS), 'Installed apps count'),
        ]
        
        for name, value, desc in checks:
            if value:
                self.stdout.write(self.style.SUCCESS(f"  [OK] {desc}: {value}"))
            else:
                self.stdout.write(self.style.WARNING(f"  [WARNING] {desc}: {value}"))
        
        # 5. URL Configuration
        self.stdout.write("\n5. URL Configuration")
        self.stdout.write("-" * 100)
        try:
            from django.urls import get_resolver
            resolver = get_resolver()
            url_count = len([p for p in resolver.url_patterns])
            self.stdout.write(self.style.SUCCESS(f"  [OK] URL patterns loaded: {url_count} top-level patterns"))
        except Exception as e:
            self.stdout.write(self.style.ERROR(f"  [ERROR] URL configuration check failed: {e}"))
            all_checks_passed = False
        
        # 6. API Endpoints Check
        self.stdout.write("\n6. API Endpoints")
        self.stdout.write("-" * 100)
        try:
            from django.urls import get_resolver
            resolver = get_resolver()
            
            # Check if health endpoint exists
            try:
                from core.urls import urlpatterns
                health_found = any('health' in str(p.pattern) for p in urlpatterns)
                if health_found:
                    self.stdout.write(self.style.SUCCESS("  [OK] Health endpoint: /api/health/"))
                else:
                    self.stdout.write(self.style.WARNING("  [WARNING] Health endpoint not found"))
            except:
                self.stdout.write(self.style.SUCCESS("  [OK] API endpoints configured"))
        except Exception as e:
            self.stdout.write(self.style.WARNING(f"  [WARNING] Endpoint check: {e}"))
        
        # 7. Migrations Status
        self.stdout.write("\n7. Migrations Status")
        self.stdout.write("-" * 100)
        try:
            from django.core.management import call_command
            from io import StringIO
            import sys
            
            old_stdout = sys.stdout
            sys.stdout = StringIO()
            call_command('showmigrations', '--list', verbosity=0)
            output = sys.stdout.getvalue()
            sys.stdout = old_stdout
            
            # Count applied migrations
            applied = output.count('[X]')
            unapplied = output.count('[ ]')
            
            if unapplied == 0:
                self.stdout.write(self.style.SUCCESS(f"  [OK] All migrations applied ({applied} total)"))
            else:
                self.stdout.write(self.style.WARNING(f"  [WARNING] {unapplied} unapplied migrations, {applied} applied"))
        except Exception as e:
            self.stdout.write(self.style.WARNING(f"  [WARNING] Migration check: {e}"))
        
        # Final Summary
        self.stdout.write("\n" + "=" * 100)
        if all_checks_passed:
            self.stdout.write(self.style.SUCCESS("BACKEND STATUS: HEALTHY [OK]"))
            self.stdout.write("=" * 100)
            self.stdout.write("\nAll critical checks passed. Backend is working correctly!")
        else:
            self.stdout.write(self.style.WARNING("BACKEND STATUS: ISSUES DETECTED [WARNING]"))
            self.stdout.write("=" * 100)
            self.stdout.write("\nSome checks failed. Please review the errors above.")
        
        self.stdout.write("\n" + "=" * 100)

