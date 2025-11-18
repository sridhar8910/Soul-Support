from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0014_alter_userprofile_wallet_minutes"),
    ]

    operations = [
        migrations.AddField(
            model_name="userprofile",
            name="nickname",
            field=models.CharField(blank=True, max_length=80),
        ),
    ]

