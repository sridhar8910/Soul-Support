from django.db import migrations, models


def seed_content(apps, schema_editor):
    MusicTrack = apps.get_model("api", "MusicTrack")
    MindCareBooster = apps.get_model("api", "MindCareBooster")
    MeditationSession = apps.get_model("api", "MeditationSession")

    music_tracks = [
        {
            "title": "Calm Ocean Waves",
            "description": "Gentle shoreline ambience to help you unwind.",
            "duration_seconds": 220,
            "mood": "calm",
            "order": 1,
        },
        {
            "title": "Midnight Reflections",
            "description": "Slow piano layered with soft rain for late-night focus.",
            "duration_seconds": 245,
            "mood": "focus",
            "order": 2,
        },
        {
            "title": "Deep Sleep Drift",
            "description": "Low-frequency drones engineered for restful sleep.",
            "duration_seconds": 300,
            "mood": "sleep",
            "order": 3,
        },
    ]
    MusicTrack.objects.bulk_create([MusicTrack(**item) for item in music_tracks])

    boosters = [
        {
            "title": "Box Breathing",
            "subtitle": "Reset in 90 seconds",
            "description": "Inhale, hold, exhale, hold — four calming counts each.",
            "category": "breathing",
            "icon": "self_improvement",
            "action_label": "Start Breathing",
            "estimated_seconds": 90,
            "order": 1,
        },
        {
            "title": "Micro Gratitude",
            "subtitle": "Shift perspective fast",
            "description": "List three small wins from today to lift your mood.",
            "category": "reflection",
            "icon": "favorite",
            "action_label": "Start Reflection",
            "estimated_seconds": 120,
            "order": 2,
        },
        {
            "title": "Mini Stretch",
            "subtitle": "Release tension",
            "description": "Neck, shoulders, wrists — quick release guided prompts.",
            "category": "movement",
            "icon": "accessibility_new",
            "action_label": "Start Stretch",
            "estimated_seconds": 150,
            "order": 3,
        },
    ]
    MindCareBooster.objects.bulk_create([MindCareBooster(**item) for item in boosters])

    sessions = [
        {
            "title": "Morning Reset",
            "subtitle": "Begin with clarity",
            "description": "Ground yourself with mindful breath and intention setting.",
            "category": "Focus",
            "duration_minutes": 6,
            "difficulty": "beginner",
            "order": 1,
            "is_featured": True,
        },
        {
            "title": "Compassion Break",
            "subtitle": "Softening the inner critic",
            "description": "Guided visualization to cultivate self-kindness.",
            "category": "Emotional",
            "duration_minutes": 8,
            "difficulty": "intermediate",
            "order": 2,
        },
        {
            "title": "Deep Sleep Gateway",
            "subtitle": "Release the day",
            "description": "Body scan and slow breath to prepare for restful sleep.",
            "category": "Sleep",
            "duration_minutes": 10,
            "difficulty": "beginner",
            "order": 3,
        },
    ]
    MeditationSession.objects.bulk_create([MeditationSession(**item) for item in sessions])


def remove_content(apps, schema_editor):
    MusicTrack = apps.get_model("api", "MusicTrack")
    MindCareBooster = apps.get_model("api", "MindCareBooster")
    MeditationSession = apps.get_model("api", "MeditationSession")

    MusicTrack.objects.all().delete()
    MindCareBooster.objects.all().delete()
    MeditationSession.objects.all().delete()


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0009_user_settings_and_guidance"),
    ]

    operations = [
        migrations.AddField(
            model_name="guidanceresource",
            name="is_featured",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="guidanceresource",
            name="thumbnail",
            field=models.URLField(blank=True),
        ),
        migrations.CreateModel(
            name="MeditationSession",
            fields=[
                ("id", models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("title", models.CharField(max_length=160, unique=True)),
                ("subtitle", models.CharField(blank=True, max_length=160)),
                ("description", models.TextField(blank=True)),
                ("category", models.CharField(max_length=60)),
                ("duration_minutes", models.PositiveIntegerField(default=5)),
                ("difficulty", models.CharField(choices=[("beginner", "Beginner"), ("intermediate", "Intermediate"), ("advanced", "Advanced")], default="beginner", max_length=20)),
                ("audio_url", models.URLField(blank=True)),
                ("video_url", models.URLField(blank=True)),
                ("is_featured", models.BooleanField(default=False)),
                ("thumbnail", models.URLField(blank=True)),
                ("order", models.PositiveIntegerField(default=0)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
            options={"ordering": ["order", "title"]},
        ),
        migrations.CreateModel(
            name="MindCareBooster",
            fields=[
                ("id", models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("title", models.CharField(max_length=160, unique=True)),
                ("subtitle", models.CharField(blank=True, max_length=160)),
                ("description", models.TextField(blank=True)),
                ("category", models.CharField(choices=[("breathing", "Breathing"), ("audio", "Audio"), ("movement", "Movement"), ("reflection", "Reflection")], default="breathing", max_length=32)),
                ("icon", models.CharField(blank=True, max_length=40)),
                ("action_label", models.CharField(default="Start", max_length=60)),
                ("prompt", models.TextField(blank=True)),
                ("order", models.PositiveIntegerField(default=0)),
                ("estimated_seconds", models.PositiveIntegerField(default=120)),
                ("resource_url", models.URLField(blank=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
            options={"ordering": ["order", "title"]},
        ),
        migrations.CreateModel(
            name="MusicTrack",
            fields=[
                ("id", models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("title", models.CharField(max_length=160, unique=True)),
                ("description", models.TextField(blank=True)),
                ("duration_seconds", models.PositiveIntegerField(default=180)),
                ("audio_url", models.URLField(blank=True)),
                ("mood", models.CharField(choices=[("calm", "Calm"), ("focus", "Focus"), ("sleep", "Sleep"), ("uplift", "Uplift")], default="calm", max_length=20)),
                ("thumbnail", models.URLField(blank=True)),
                ("order", models.PositiveIntegerField(default=0)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
            options={"ordering": ["order", "title"]},
        ),
        migrations.RunPython(seed_content, remove_content),
    ]

