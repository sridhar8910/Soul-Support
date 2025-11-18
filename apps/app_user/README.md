# Flutter Client

Flutter desktop/web client for the SoulSupport platform.

## Requirements

- Flutter SDK (3.3.0 or later as configured in `pubspec.yaml`)
- Windows desktop target (default), or Chrome/Edge/web-server for web debugging

Install dependencies after cloning:

```powershell
flutter pub get
```

## Running

```powershell
flutter run -d windows        # desktop
flutter run -d chrome         # web
flutter run -d <device-id>    # any connected device
```

You can also launch the backend and Flutter client together from the repository root with `.\run_all.ps1`.

### Backend Integration

- The app expects the REST API at `http://127.0.0.1:8000/api` by default (see `services/api_client.dart`).
- Update the base URL or inject a custom client before building for other environments.
- Ensure the Django server is running before logging in or registering within the app.

## Testing

```powershell
flutter test
```

## Useful Links

- [Flutter documentation](https://docs.flutter.dev/)
- [Desktop support overview](https://docs.flutter.dev/platform-integration/desktop)
- [Flutter testing](https://docs.flutter.dev/cookbook/testing)
