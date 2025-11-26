"""
Django management command to show all models and their corresponding database tables.
Shows which models have tables in the database and which are missing.
"""
from django.core.management.base import BaseCommand
from django.db import connection
from django.apps import apps


class Command(BaseCommand):
    help = 'Show all Django models and their corresponding database tables'

    def add_arguments(self, parser):
        parser.add_argument(
            '--missing-only',
            action='store_true',
            help='Show only models that are missing tables',
        )
        parser.add_argument(
            '--app',
            type=str,
            help='Filter by app name (e.g., api, auth)',
        )

    def handle(self, *args, **options):
        missing_only = options['missing_only']
        app_filter = options.get('app')
        
        self.stdout.write(self.style.SUCCESS("\n" + "=" * 100))
        self.stdout.write(self.style.SUCCESS("DJANGO MODELS AND DATABASE TABLES"))
        self.stdout.write(self.style.SUCCESS("=" * 100))
        
        # Get all models from all apps
        all_models = []
        for app_config in apps.get_app_configs():
            if app_filter and app_config.label != app_filter:
                continue
            for model in app_config.get_models():
                all_models.append((app_config.label, model))
        
        # Get all existing tables in database
        existing_tables = self.get_existing_tables()
        
        # Group models by app
        models_by_app = {}
        for app_label, model in all_models:
            if app_label not in models_by_app:
                models_by_app[app_label] = []
            models_by_app[app_label].append(model)
        
        total_models = 0
        models_with_tables = 0
        models_missing_tables = 0
        
        # Display models grouped by app
        for app_label in sorted(models_by_app.keys()):
            models = models_by_app[app_label]
            self.stdout.write(f"\n{self.style.SUCCESS('App:')} {app_label} ({len(models)} models)")
            self.stdout.write("-" * 100)
            
            for model in sorted(models, key=lambda m: m._meta.db_table):
                total_models += 1
                table_name = model._meta.db_table
                model_name = model.__name__
                
                # Check if table exists
                table_exists = table_name in existing_tables
                
                if table_exists:
                    models_with_tables += 1
                    # Get row count
                    try:
                        with connection.cursor() as cursor:
                            if connection.vendor == 'sqlite':
                                cursor.execute(f'SELECT COUNT(*) FROM "{table_name}";')
                            else:  # PostgreSQL
                                cursor.execute(f'SELECT COUNT(*) FROM "{table_name}";')
                            row_count = cursor.fetchone()[0]
                            status = self.style.SUCCESS(f'[OK] {row_count} rows')
                    except Exception as e:
                        status = self.style.ERROR(f'[ERROR] {str(e)[:30]}')
                else:
                    models_missing_tables += 1
                    status = self.style.WARNING('[MISSING]')
                
                if not missing_only or not table_exists:
                    self.stdout.write(f"  {status} {model_name:<40} -> {table_name}")
        
        # Summary
        self.stdout.write("\n" + "=" * 100)
        self.stdout.write(self.style.SUCCESS("SUMMARY"))
        self.stdout.write("=" * 100)
        self.stdout.write(f"\nTotal models found: {total_models}")
        self.stdout.write(self.style.SUCCESS(f"Models with tables: {models_with_tables}"))
        self.stdout.write(self.style.WARNING(f"Models missing tables: {models_missing_tables}"))
        
        if models_missing_tables > 0:
            self.stdout.write(f"\n{self.style.WARNING('To create missing tables, run:')}")
            self.stdout.write("  python manage.py migrate")
        
        # List missing tables
        if models_missing_tables > 0:
            self.stdout.write(f"\n{self.style.WARNING('Missing tables:')}")
            for app_label in sorted(models_by_app.keys()):
                for model in sorted(models_by_app[app_label], key=lambda m: m._meta.db_table):
                    table_name = model._meta.db_table
                    if table_name not in existing_tables:
                        self.stdout.write(f"  - {model.__name__:<40} ({table_name})")
        
        self.stdout.write("\n" + "=" * 100)
    
    def get_existing_tables(self):
        """Get all existing tables in the database."""
        tables = []
        
        with connection.cursor() as cursor:
            if connection.vendor == 'sqlite':
                cursor.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;")
            elif connection.vendor == 'postgresql':
                cursor.execute("""
                    SELECT table_name 
                    FROM information_schema.tables 
                    WHERE table_schema = 'public' 
                    AND table_type = 'BASE TABLE'
                    ORDER BY table_name;
                """)
            else:  # MySQL, etc.
                cursor.execute("""
                    SELECT table_name 
                    FROM information_schema.tables 
                    WHERE table_schema = DATABASE()
                    AND table_type = 'BASE TABLE'
                    ORDER BY table_name;
                """)
            
            rows = cursor.fetchall()
            for row in rows:
                tables.append(row[0])
        
        return set(tables)

