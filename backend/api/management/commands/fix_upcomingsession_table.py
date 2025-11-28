"""
Django management command to fix UpcomingSession table by adding missing columns.
"""
from django.core.management.base import BaseCommand
from django.db import connection


class Command(BaseCommand):
    help = 'Add missing columns to UpcomingSession table'

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS("\n" + "=" * 100))
        self.stdout.write(self.style.SUCCESS("FIXING UPCOMINGSESSION TABLE"))
        self.stdout.write(self.style.SUCCESS("=" * 100))
        
        with connection.cursor() as cursor:
            # Check existing columns
            cursor.execute("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'api_upcomingsession' 
                ORDER BY ordinal_position;
            """)
            existing_columns = {row[0] for row in cursor.fetchall()}
            
            self.stdout.write(f"\nExisting columns: {sorted(existing_columns)}")
            
            # Columns that should exist based on the model
            required_columns = {
                'counsellor_id': 'ALTER TABLE "api_upcomingsession" ADD COLUMN IF NOT EXISTS "counsellor_id" integer NULL;',
                'actual_start_time': 'ALTER TABLE "api_upcomingsession" ADD COLUMN IF NOT EXISTS "actual_start_time" timestamp with time zone NULL;',
                'actual_end_time': 'ALTER TABLE "api_upcomingsession" ADD COLUMN IF NOT EXISTS "actual_end_time" timestamp with time zone NULL;',
                'session_status': 'ALTER TABLE "api_upcomingsession" ADD COLUMN IF NOT EXISTS "session_status" varchar(20) NOT NULL DEFAULT \'scheduled\';',
                'risk_level': 'ALTER TABLE "api_upcomingsession" ADD COLUMN IF NOT EXISTS "risk_level" varchar(20) NOT NULL DEFAULT \'none\';',
                'manual_flag': 'ALTER TABLE "api_upcomingsession" ADD COLUMN IF NOT EXISTS "manual_flag" varchar(10) NOT NULL DEFAULT \'green\';',
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
                        
                        # Add foreign key constraint if column was just created
                        if column_name == 'counsellor_id':
                            try:
                                cursor.execute("""
                                    ALTER TABLE "api_upcomingsession" 
                                    ADD CONSTRAINT "api_upcomingsession_counsellor_id_38d7a791_fk_auth_user_id" 
                                    FOREIGN KEY ("counsellor_id") 
                                    REFERENCES "auth_user" ("id") 
                                    DEFERRABLE INITIALLY DEFERRED;
                                """)
                                self.stdout.write(self.style.SUCCESS(f"  [OK] Added foreign key constraint for {column_name}"))
                            except Exception as e:
                                if 'already exists' in str(e).lower():
                                    self.stdout.write(self.style.SUCCESS(f"  [OK] Foreign key constraint already exists"))
                                else:
                                    self.stdout.write(self.style.WARNING(f"  [WARNING] Could not add foreign key: {str(e)[:50]}"))
                    except Exception as e:
                        error_msg = str(e)
                        if 'already exists' in error_msg.lower():
                            self.stdout.write(self.style.SUCCESS(f"  [OK] Column {column_name} already exists"))
                        else:
                            self.stdout.write(self.style.ERROR(f"  [ERROR] Failed to add {column_name}: {error_msg[:100]}"))
                else:
                    self.stdout.write(self.style.SUCCESS(f"  [OK] Column {column_name} already exists"))
            
            # Create indexes for the new columns
            self.stdout.write("\nCreating indexes...")
            indexes = [
                ('api_upcomin_actual_start_time_754b4525', 'CREATE INDEX IF NOT EXISTS "api_upcomin_actual_start_time_754b4525" ON "api_upcomingsession" ("actual_start_time");'),
                ('api_upcomin_actual_end_time_f944b80b', 'CREATE INDEX IF NOT EXISTS "api_upcomin_actual_end_time_f944b80b" ON "api_upcomingsession" ("actual_end_time");'),
                ('api_upcomin_session_status_46219986', 'CREATE INDEX IF NOT EXISTS "api_upcomin_session_status_46219986" ON "api_upcomingsession" ("session_status");'),
                ('api_upcomin_counsellor_id_38d7a791', 'CREATE INDEX IF NOT EXISTS "api_upcomin_counsellor_id_38d7a791" ON "api_upcomingsession" ("counsellor_id");'),
            ]
            
            for index_name, sql in indexes:
                try:
                    cursor.execute(sql)
                    self.stdout.write(self.style.SUCCESS(f"  [OK] Created index {index_name}"))
                except Exception as e:
                    if 'already exists' in str(e).lower():
                        self.stdout.write(self.style.SUCCESS(f"  [OK] Index {index_name} already exists"))
                    else:
                        self.stdout.write(self.style.WARNING(f"  [WARNING] Could not create index {index_name}: {str(e)[:50]}"))
            
            self.stdout.write("\n" + "=" * 100)
            if added_count > 0:
                self.stdout.write(self.style.SUCCESS(f"COMPLETED: Added {added_count} column(s) and indexes"))
            else:
                self.stdout.write(self.style.SUCCESS("All columns already exist"))
            self.stdout.write("=" * 100)

