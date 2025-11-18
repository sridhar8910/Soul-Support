from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0005_supportgroup_upcomingsession_supportgroupmembership"),
    ]

    operations = [
        migrations.CreateModel(
            name="EmailOTP",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("email", models.EmailField(max_length=254)),
                ("code", models.CharField(max_length=6)),
                (
                    "purpose",
                    models.CharField(
                        choices=[("registration", "Registration"), ("password_reset", "Password reset")],
                        max_length=32,
                    ),
                ),
                ("token", models.CharField(max_length=64, unique=True)),
                ("is_verified", models.BooleanField(default=False)),
                ("attempts", models.PositiveSmallIntegerField(default=0)),
                ("expires_at", models.DateTimeField()),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("verified_at", models.DateTimeField(blank=True, null=True)),
            ],
            options={
                "ordering": ("-created_at",),
            },
        ),
        migrations.AddIndex(
            model_name="emailotp",
            index=models.Index(fields=["email", "purpose", "is_verified"], name="api_emailot_email_f7068d_idx"),
        ),
        migrations.AddIndex(
            model_name="emailotp",
            index=models.Index(fields=["token"], name="api_emailot_token_02bc1e_idx"),
        ),
    ]

