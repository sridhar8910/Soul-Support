from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from api.models import CounsellorProfile


class Command(BaseCommand):
    help = 'Activates all counsellor users (sets is_active=True)'

    def handle(self, *args, **options):
        # Get all users with counsellor profiles
        counsellors = User.objects.filter(counsellorprofile__isnull=False)
        
        activated_count = 0
        already_active_count = 0
        
        for user in counsellors:
            if not user.is_active:
                user.is_active = True
                user.save()
                activated_count += 1
                self.stdout.write(
                    self.style.SUCCESS(f'✓ Activated: {user.username} ({user.email})')
                )
            else:
                already_active_count += 1
                self.stdout.write(
                    f'  Already active: {user.username} ({user.email})'
                )
        
        self.stdout.write('')
        self.stdout.write(
            self.style.SUCCESS(
                f'Summary: {activated_count} activated, {already_active_count} already active'
            )
        )

