from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0012_userprofile_mood_updates_count_and_more"),
    ]

    operations = [
        migrations.AddField(
            model_name="userprofile",
            name="timezone",
            field=models.CharField(blank=True, max_length=64),
        ),
    ]

