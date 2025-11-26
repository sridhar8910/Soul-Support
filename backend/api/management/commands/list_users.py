"""
Django management command to list all users.
Usage: python manage.py list_users
"""

from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from api.models import CounsellorProfile, DoctorProfile


class Command(BaseCommand):
    help = 'List all users in the database'

    def add_arguments(self, parser):
        parser.add_argument(
            '--type',
            type=str,
            choices=['all', 'regular', 'counselor', 'doctor'],
            default='all',
            help='Type of users to list (default: all)'
        )

    def handle(self, *args, **options):
        user_type = options['type']
        
        # Check if tables exist
        from django.db import connection
        with connection.cursor() as cursor:
            if connection.vendor == 'sqlite':
                cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name IN ('api_counsellorprofile', 'api_doctorprofile');")
            else:  # PostgreSQL
                cursor.execute("""
                    SELECT table_name FROM information_schema.tables 
                    WHERE table_schema = 'public' 
                    AND table_name IN ('api_counsellorprofile', 'api_doctorprofile');
                """)
            existing_tables = [row[0] for row in cursor.fetchall()]
        
        has_counsellor_table = 'api_counsellorprofile' in existing_tables
        has_doctor_table = 'api_doctorprofile' in existing_tables
        
        if user_type == 'all':
            users = User.objects.all().order_by('id')
        elif user_type == 'regular':
            # Users who are not counselors or doctors
            if has_counsellor_table and has_doctor_table:
                try:
                    counselor_ids = CounsellorProfile.objects.values_list('user_id', flat=True)
                    doctor_ids = DoctorProfile.objects.values_list('user_id', flat=True)
                    users = User.objects.exclude(
                        id__in=list(counselor_ids) + list(doctor_ids)
                    ).order_by('id')
                except Exception:
                    users = User.objects.all().order_by('id')
            else:
                users = User.objects.all().order_by('id')
        elif user_type == 'counselor':
            if has_counsellor_table:
                try:
                    counselor_ids = CounsellorProfile.objects.values_list('user_id', flat=True)
                    users = User.objects.filter(id__in=counselor_ids).order_by('id')
                except Exception:
                    users = User.objects.none()
            else:
                self.stdout.write(self.style.WARNING("CounsellorProfile table does not exist. Run migrations first."))
                users = User.objects.none()
        elif user_type == 'doctor':
            if has_doctor_table:
                try:
                    doctor_ids = DoctorProfile.objects.values_list('user_id', flat=True)
                    users = User.objects.filter(id__in=doctor_ids).order_by('id')
                except Exception:
                    users = User.objects.none()
            else:
                self.stdout.write(self.style.WARNING("DoctorProfile table does not exist. Run migrations first."))
                users = User.objects.none()
        
        self.stdout.write(self.style.WARNING(f"\n{'='*80}"))
        self.stdout.write(self.style.WARNING(f"Users ({user_type}): {users.count()}"))
        self.stdout.write(self.style.WARNING(f"{'='*80}\n"))
        
        for user in users:
            # Check if tables exist before accessing related objects
            is_counselor = False
            is_doctor = False
            try:
                is_counselor = hasattr(user, 'counsellorprofile') and user.counsellorprofile is not None
            except Exception:
                pass  # Table doesn't exist or no profile
            try:
                is_doctor = hasattr(user, 'doctorprofile') and user.doctorprofile is not None
            except Exception:
                pass  # Table doesn't exist or no profile
            user_type_str = []
            if is_counselor:
                user_type_str.append('Counselor')
            if is_doctor:
                user_type_str.append('Doctor')
            if not user_type_str:
                user_type_str.append('Regular User')
            
            self.stdout.write(
                f"ID: {user.id:3d} | "
                f"Username: {user.username:20s} | "
                f"Email: {user.email:30s} | "
                f"Type: {', '.join(user_type_str)}"
            )
        
        self.stdout.write(f"\n{'='*80}\n")

