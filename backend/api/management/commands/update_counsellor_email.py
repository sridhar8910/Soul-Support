from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from api.models import CounsellorProfile


class Command(BaseCommand):
    help = 'Updates counsellor user email'

    def add_arguments(self, parser):
        parser.add_argument(
            '--username',
            type=str,
            required=True,
            help='Username of the counsellor to update',
        )
        parser.add_argument(
            '--email',
            type=str,
            required=True,
            help='New email address',
        )

    def handle(self, *args, **options):
        username = options['username']
        new_email = options['email']
        
        try:
            user = User.objects.get(username=username)
            
            # Check if email is already taken
            if User.objects.filter(email__iexact=new_email).exclude(username=username).exists():
                self.stdout.write(
                    self.style.ERROR(f'Email "{new_email}" is already in use by another user.')
                )
                return
            
            old_email = user.email
            user.email = new_email
            user.is_active = True  # Ensure user is active
            user.save()
            
            self.stdout.write(
                self.style.SUCCESS(
                    f'Successfully updated email for "{username}": {old_email} -> {new_email}'
                )
            )
            self.stdout.write(f'Username: {username}')
            self.stdout.write(f'Email: {user.email}')
            self.stdout.write(f'is_active: {user.is_active}')
            
        except User.DoesNotExist:
            self.stdout.write(
                self.style.ERROR(f'User "{username}" not found.')
            )

