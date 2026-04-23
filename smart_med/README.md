# smart_med

Smart Med is a Flutter app backed by Firebase Auth, Cloud Firestore, and a
small FastAPI service for grounded medication explanations.

## AI medication guide

The app now includes an `AI Medication Guide` entry on the home screen. The
client sends the user's Firebase ID token to the FastAPI backend, which:

- verifies the Firebase user
- reads the user's Firestore profile, medications, allergies, and conditions
- reads `drug_catalog` and optional `drug_interactions` facts from Firestore
- generates a grounded explanation with OpenAI, or falls back to deterministic
  Firestore-only wording if the model output is unavailable or unsafe

## Backend URL

By default the Flutter app uses:

- Android emulator: `http://10.0.2.2:8000`
- Other platforms: `http://127.0.0.1:8000`

Override it when needed:

```bash
flutter run --dart-define=SMART_MED_API_BASE_URL=http://192.168.1.50:8000
```

Use your machine's LAN IP when running the app on a physical phone.
