from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from api.models import CounsellorProfile


class Command(BaseCommand):
    help = 'Creates a test counsellor user for login'

    def add_arguments(self, parser):
        parser.add_argument(
            '--username',
            type=str,
            default='counsellor',
            help='Username for the counsellor (default: counsellor)',
        )
        parser.add_argument(
            '--email',
            type=str,
            default='counsellor@example.com',
            help='Email for the counsellor (default: counsellor@example.com)',
        )
        parser.add_argument(
            '--password',
            type=str,
            default='counsellor123',
            help='Password for the counsellor (default: counsellor123)',
        )

    def handle(self, *args, **options):
        username = options['username']
        email = options['email']
        password = options['password']

        # Check if user already exists
        if User.objects.filter(username=username).exists():
            self.stdout.write(
                self.style.WARNING(f'User "{username}" already exists.')
            )
            user = User.objects.get(username=username)
            
            # Ensure user is active
            if not user.is_active:
                user.is_active = True
                user.save()
                self.stdout.write(
                    self.style.SUCCESS(f'Activated user "{username}".')
                )
            
            # Check if counsellor profile exists
            if hasattr(user, 'counsellorprofile'):
                self.stdout.write(
                    self.style.SUCCESS(
                        f'Counsellor user "{username}" already exists with profile.'
                    )
                )
                self.stdout.write(f'Username: {username}')
                self.stdout.write(f'Email: {user.email}')
                self.stdout.write(f'is_active: {user.is_active}')
                self.stdout.write(f'Password: (use existing password or reset it)')
            else:
                # Create counsellor profile for existing user
                CounsellorProfile.objects.create(
                    user=user,
                    specialization='Mental Health',
                    is_available=True
                )
                self.stdout.write(
                    self.style.SUCCESS(
                        f'Created counsellor profile for existing user "{username}".'
                    )
                )
                self.stdout.write(f'Username: {username}')
                self.stdout.write(f'Email: {user.email}')
                self.stdout.write(f'is_active: {user.is_active}')
                self.stdout.write(f'Password: (use existing password)')
        else:
            # Create new user with is_active=True
            user = User.objects.create_user(
                username=username,
                email=email,
                password=password,
                is_active=True  # Explicitly set to active
            )
            
            # Create counsellor profile
            CounsellorProfile.objects.create(
                user=user,
                specialization='Mental Health',
                is_available=True
            )
            
            self.stdout.write(
                self.style.SUCCESS(
                    f'Successfully created counsellor user "{username}".'
                )
            )
            self.stdout.write(f'Username: {username}')
            self.stdout.write(f'Email: {email}')
            self.stdout.write(f'is_active: {user.is_active}')
            self.stdout.write(f'Password: {password}')

