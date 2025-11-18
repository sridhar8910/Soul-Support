from django.conf import settings
from django.db import migrations, models


def seed_guidance_resources(apps, schema_editor):
    GuidanceResource = apps.get_model("api", "GuidanceResource")
    default_items = [
        {
            "resource_type": "article",
            "title": "Understanding Anxiety Triggers and How to Manage Them",
            "subtitle": "Dr. Sarah Chen",
            "summary": "Learn about common anxiety triggers and evidence-based techniques to manage them effectively in daily life.",
            "category": "Anxiety & Depression",
            "duration": "7 min read",
            "is_featured": True,
        },
        {
            "resource_type": "article",
            "title": "Mindfulness Techniques from Clinical Experts",
            "subtitle": "Dr. James Miller",
            "summary": "Discover practical mindfulness exercises used by clinical psychologists to reduce stress and improve mental clarity.",
            "category": "Stress Management",
            "duration": "5 min read",
        },
        {
            "resource_type": "talk",
            "title": "Breaking the Stigma: Mental Health at Work",
            "subtitle": "Dr. Michael Ross",
            "summary": "How organisations can build psychologically safe workplaces and support employees.",
            "category": "Workplace Wellness",
            "duration": "24:15",
            "is_featured": True,
        },
        {
            "resource_type": "talk",
            "title": "Building Better Relationships",
            "subtitle": "Dr. Emma Carter",
            "summary": "A compassionate look at communication tools for nurturing relationships.",
            "category": "Relationship Growth",
            "duration": "21:30",
        },
        {
            "resource_type": "podcast",
            "title": "Self-Compassion in Daily Life",
            "subtitle": "Hosted by Dr. Rachel Green",
            "summary": "Short reflections and guided prompts to help you practice self-kindness every day.",
            "category": "Self-Esteem",
            "duration": "35 min",
            "is_featured": True,
        },
        {
            "resource_type": "podcast",
            "title": "Building Emotional Resilience",
            "subtitle": "Hosted by Dr. Sofia Martinez",
            "summary": "Evidence-based strategies to strengthen your resilience against daily stress.",
            "category": "Stress Management",
            "duration": "38 min",
        },
    ]
    GuidanceResource.objects.bulk_create(GuidanceResource(**item) for item in default_items)


def drop_guidance_resources(apps, schema_editor):
    GuidanceResource = apps.get_model("api", "GuidanceResource")
    GuidanceResource.objects.all().delete()


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0008_merge_20251113_1617"),
    ]

    operations = [
        migrations.AddField(
            model_name="userprofile",
            name="language",
            field=models.CharField(default="English", max_length=32),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="notifications_enabled",
            field=models.BooleanField(default=True),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="prefers_dark_mode",
            field=models.BooleanField(default=False),
        ),
        migrations.CreateModel(
            name="GuidanceResource",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("resource_type", models.CharField(choices=[("article", "Article"), ("talk", "Expert Talk"), ("podcast", "Podcast")], max_length=16)),
                ("title", models.CharField(max_length=200)),
                ("subtitle", models.CharField(blank=True, max_length=160)),
                ("summary", models.TextField(blank=True)),
                ("category", models.CharField(blank=True, max_length=120)),
                ("duration", models.CharField(blank=True, max_length=40)),
                ("media_url", models.URLField(blank=True)),
                ("thumbnail", models.CharField(blank=True, max_length=255)),
                ("is_featured", models.BooleanField(default=False)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
            ],
            options={
                "ordering": ("resource_type", "title"),
            },
        ),
        migrations.CreateModel(
            name="MoodLog",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("value", models.PositiveSmallIntegerField()),
                ("recorded_at", models.DateTimeField(auto_now_add=True)),
                (
                    "user",
                    models.ForeignKey(on_delete=models.deletion.CASCADE, related_name="mood_logs", to=settings.AUTH_USER_MODEL),
                ),
            ],
            options={
                "ordering": ("-recorded_at",),
            },
        ),
        migrations.RunPython(seed_guidance_resources, drop_guidance_resources),
    ]

