"""
Django management command to fix UserProfile table by adding missing columns.
"""
from django.core.management.base import BaseCommand
from django.db import connection


class Command(BaseCommand):
    help = 'Add missing columns to UserProfile table'

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS("\n" + "=" * 100))
        self.stdout.write(self.style.SUCCESS("FIXING USERPROFILE TABLE"))
        self.stdout.write(self.style.SUCCESS("=" * 100))
        
        with connection.cursor() as cursor:
            # Check existing columns
            cursor.execute("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'api_userprofile' 
                ORDER BY ordinal_position;
            """)
            existing_columns = {row[0] for row in cursor.fetchall()}
            
            self.stdout.write(f"\nExisting columns: {sorted(existing_columns)}")
            
            # Columns that should exist based on the model
            required_columns = {
                'nickname': 'ALTER TABLE "api_userprofile" ADD COLUMN IF NOT EXISTS "nickname" varchar(80) NOT NULL DEFAULT \'\';',
                'mood_updates_count': 'ALTER TABLE "api_userprofile" ADD COLUMN IF NOT EXISTS "mood_updates_count" smallint NOT NULL DEFAULT 0 CHECK ("mood_updates_count" >= 0);',
                'mood_updates_date': 'ALTER TABLE "api_userprofile" ADD COLUMN IF NOT EXISTS "mood_updates_date" date NULL;',
                'timezone': 'ALTER TABLE "api_userprofile" ADD COLUMN IF NOT EXISTS "timezone" varchar(64) NOT NULL DEFAULT \'\';',
                'updated_at': 'ALTER TABLE "api_userprofile" ADD COLUMN IF NOT EXISTS "updated_at" timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP;',
            }
            
            # Add missing columns
            added_count = 0
            for column_name, sql in required_columns.items():
                if column_name not in existing_columns:
                    try:
                        self.stdout.write(f"\nAdding column: {column_name}")
                        cursor.execute(sql)
                        added_count += 1
                        self.stdout.write(self.style.SUCCESS(f"  [OK] Added {column_name}"))
                    except Exception as e:
                        self.stdout.write(self.style.ERROR(f"  [ERROR] Failed to add {column_name}: {e}"))
                else:
                    self.stdout.write(self.style.SUCCESS(f"  [OK] Column {column_name} already exists"))
            
            self.stdout.write("\n" + "=" * 100)
            if added_count > 0:
                self.stdout.write(self.style.SUCCESS(f"COMPLETED: Added {added_count} column(s)"))
            else:
                self.stdout.write(self.style.SUCCESS("All columns already exist"))
            self.stdout.write("=" * 100)

