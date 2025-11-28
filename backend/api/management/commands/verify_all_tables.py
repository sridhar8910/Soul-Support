"""
Django management command to verify all tables have required columns.
"""
from django.core.management.base import BaseCommand
from django.db import connection
from django.apps import apps


class Command(BaseCommand):
    help = 'Verify all database tables have required columns from models'

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS("\n" + "=" * 100))
        self.stdout.write(self.style.SUCCESS("VERIFYING ALL TABLES HAVE REQUIRED COLUMNS"))
        self.stdout.write(self.style.SUCCESS("=" * 100))
        
        issues_found = []
        
        # Check all API models
        for app_config in apps.get_app_configs():
            if app_config.label == 'api':
                for model in app_config.get_models():
                    table_name = model._meta.db_table
                    model_fields = {f.name: f for f in model._meta.get_fields() if hasattr(f, 'column')}
                    
                    with connection.cursor() as cursor:
                        if connection.vendor == 'postgresql':
                            cursor.execute("""
                                SELECT column_name 
                                FROM information_schema.columns 
                                WHERE table_name = %s;
                            """, (table_name,))
                        else:
                            cursor.execute("PRAGMA table_info(%s);" % table_name)
                        
                        db_columns = {row[0] for row in cursor.fetchall()}
                    
                    # Check required fields
                    missing = []
                    for field_name, field in model_fields.items():
                        # Get the actual database column name
                        db_column = field.column if hasattr(field, 'column') else field_name
                        if db_column not in db_columns:
                            missing.append(f"{field_name} (db: {db_column})")
                    
                    if missing:
                        issues_found.append((table_name, missing))
                        self.stdout.write(f"\n{self.style.ERROR('[ISSUES]')} {table_name}")
                        for col in missing:
                            self.stdout.write(f"  - Missing: {col}")
                    else:
                        self.stdout.write(f"\n{self.style.SUCCESS('[OK]')} {table_name} - All columns present")
        
        self.stdout.write("\n" + "=" * 100)
        if issues_found:
            self.stdout.write(self.style.ERROR(f"Found issues in {len(issues_found)} table(s)"))
            self.stdout.write("\nTo fix missing columns, run:")
            for table_name, _ in issues_found:
                if table_name == 'api_userprofile':
                    self.stdout.write(f"  python manage.py fix_userprofile_table")
                elif table_name == 'api_upcomingsession':
                    self.stdout.write(f"  python manage.py fix_upcomingsession_table")
        else:
            self.stdout.write(self.style.SUCCESS("All tables have required columns!"))
            self.stdout.write("\nIf you're still seeing errors, restart the Django server:")
            self.stdout.write("  - Stop the current server (Ctrl+C)")
            self.stdout.write("  - Start it again: python manage.py runserver")
        self.stdout.write("=" * 100)

