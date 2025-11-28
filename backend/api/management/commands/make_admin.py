"""
Django management command to make a user a superuser/admin.
"""
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User


class Command(BaseCommand):
    help = 'Make a user a superuser/admin'

    def add_arguments(self, parser):
        parser.add_argument(
            '--username',
            type=str,
            required=True,
            help='Username of the user to make admin',
        )

    def handle(self, *args, **options):
        username = options['username']
        
        try:
            user = User.objects.get(username=username)
            
            user.is_staff = True
            user.is_superuser = True
            user.save()
            
            self.stdout.write(
                self.style.SUCCESS(
                    f'Successfully made "{username}" a superuser/admin.'
                )
            )
            self.stdout.write(f'Username: {username}')
            self.stdout.write(f'Email: {user.email}')
            self.stdout.write(f'is_staff: {user.is_staff}')
            self.stdout.write(f'is_superuser: {user.is_superuser}')
            self.stdout.write(f'is_active: {user.is_active}')
        except User.DoesNotExist:
            self.stdout.write(
                self.style.ERROR(f'User "{username}" does not exist.')
            )

