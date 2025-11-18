from django.db import migrations


def create_admin_user(apps, schema_editor):
    User = apps.get_model("auth", "User")
    if not User.objects.filter(username="admin").exists():
        User.objects.create_superuser(
            username="admin",
            email="admin@gmail.com",
            password="admin@123",
        )


def remove_admin_user(apps, schema_editor):
    User = apps.get_model("auth", "User")
    User.objects.filter(username="admin", email="admin@gmail.com").delete()


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0006_emailotp"),
    ]

    operations = [
        migrations.RunPython(create_admin_user, reverse_code=remove_admin_user),
    ]

