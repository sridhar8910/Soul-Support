from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0013_userprofile_timezone"),
    ]

    operations = [
        migrations.AlterField(
            model_name="userprofile",
            name="wallet_minutes",
            field=models.PositiveIntegerField(default=100),
        ),
    ]

