"""
Django management command to verify table columns match model fields.
"""
from django.core.management.base import BaseCommand
from django.db import connection
from django.apps import apps


class Command(BaseCommand):
    help = 'Verify that database table columns match model fields'

    def add_arguments(self, parser):
        parser.add_argument(
            '--table',
            type=str,
            help='Specific table to check (e.g., api_userprofile)',
        )

    def handle(self, *args, **options):
        table_name = options.get('table')
        
        self.stdout.write(self.style.SUCCESS("\n" + "=" * 100))
        self.stdout.write(self.style.SUCCESS("VERIFYING TABLE COLUMNS"))
        self.stdout.write(self.style.SUCCESS("=" * 100))
        
        if table_name:
            # Check specific table
            self.check_table(table_name)
        else:
            # Check all API model tables
            for app_config in apps.get_app_configs():
                if app_config.label == 'api':
                    for model in app_config.get_models():
                        table_name = model._meta.db_table
                        self.check_table(table_name)
                        self.stdout.write("")
    
    def check_table(self, table_name):
        """Check a specific table."""
        with connection.cursor() as cursor:
            # Get existing columns
            if connection.vendor == 'postgresql':
                cursor.execute("""
                    SELECT column_name, data_type, is_nullable
                    FROM information_schema.columns 
                    WHERE table_name = %s 
                    ORDER BY ordinal_position;
                """, (table_name,))
            else:
                cursor.execute("PRAGMA table_info(%s);" % table_name)
            
            existing_columns = {row[0]: row for row in cursor.fetchall()}
            
            self.stdout.write(f"\nTable: {table_name}")
            self.stdout.write(f"Columns found: {len(existing_columns)}")
            self.stdout.write("-" * 100)
            
            for col_name in sorted(existing_columns.keys()):
                col_info = existing_columns[col_name]
                if connection.vendor == 'postgresql':
                    data_type = col_info[1]
                    nullable = col_info[2]
                    self.stdout.write(f"  - {col_name:<30} {data_type:<20} nullable={nullable}")
                else:
                    self.stdout.write(f"  - {col_name}")

