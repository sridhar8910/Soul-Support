"""
Django management command to fix all missing columns in all tables.
"""
from django.core.management.base import BaseCommand
from django.db import connection


class Command(BaseCommand):
    help = 'Fix all missing columns in all database tables'

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS("\n" + "=" * 100))
        self.stdout.write(self.style.SUCCESS("FIXING ALL MISSING COLUMNS"))
        self.stdout.write(self.style.SUCCESS("=" * 100))
        
        fixes = {
            'api_wellnessjournalentry': {
                'updated_at': 'ALTER TABLE "api_wellnessjournalentry" ADD COLUMN IF NOT EXISTS "updated_at" timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP;',
            },
            'api_moodlog': {
                'created_at': 'ALTER TABLE "api_moodlog" ADD COLUMN IF NOT EXISTS "created_at" timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP;',
            },
        }
        
        total_fixed = 0
        
        for table_name, columns in fixes.items():
            self.stdout.write(f"\nFixing table: {table_name}")
            self.stdout.write("-" * 100)
            
            with connection.cursor() as cursor:
                # Check existing columns
                cursor.execute("""
                    SELECT column_name 
                    FROM information_schema.columns 
                    WHERE table_name = %s;
                """, (table_name,))
                existing_columns = {row[0] for row in cursor.fetchall()}
                
                for column_name, sql in columns.items():
                    if column_name not in existing_columns:
                        try:
                            self.stdout.write(f"  Adding column: {column_name}")
                            cursor.execute(sql)
                            total_fixed += 1
                            self.stdout.write(self.style.SUCCESS(f"    [OK] Added {column_name}"))
                        except Exception as e:
                            self.stdout.write(self.style.ERROR(f"    [ERROR] Failed: {str(e)[:100]}"))
                    else:
                        self.stdout.write(self.style.SUCCESS(f"  [OK] Column {column_name} already exists"))
        
        self.stdout.write("\n" + "=" * 100)
        if total_fixed > 0:
            self.stdout.write(self.style.SUCCESS(f"COMPLETED: Fixed {total_fixed} column(s)"))
            self.stdout.write("\n" + self.style.WARNING("IMPORTANT: Restart your Django server to apply changes!"))
            self.stdout.write("  Stop server: Ctrl+C")
            self.stdout.write("  Start server: python manage.py runserver")
        else:
            self.stdout.write(self.style.SUCCESS("All columns already exist"))
        self.stdout.write("=" * 100)

