# Smart Med API

Run locally:

```bash
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Environment variables for the personalized AI explainer:

```powershell
$env:OPENAI_API_KEY="your-openai-key"
$env:OPENAI_MODEL="gpt-5.4-mini"
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\service-account.json"
```

The `/personalized-explanation` endpoint verifies a Firebase ID token from the
`Authorization: Bearer <token>` header, then reads these Firestore paths:

- `users/{uid}`
- `users/{uid}/medications`
- `users/{uid}/allergies`
- `users/{uid}/medical_conditions`
- `drug_catalog/{drugId}`
- `drug_interactions/{sortedDrugIdA}__{sortedDrugIdB}` for curated pair facts

Recommended `drug_interactions/{pairKey}` shape:

```json
{
  "drugIds": ["warfarin", "ibuprofen"],
  "drugNames": ["Warfarin", "Ibuprofen"],
  "severity": "High",
  "title": "Bleeding risk",
  "summary": "This combination can increase bleeding risk.",
  "warnings": ["Watch for bruising or black stools."],
  "recommendations": ["Review the combination with a clinician."],
  "source": "curated_firestore"
}
```

The AI layer is grounded: it only turns Firestore facts into patient-friendly
language. If OpenAI is unavailable or the output is invalid, the API falls back
to a deterministic Firestore-only explanation instead of guessing.

Keep it running on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install_api_startup_task.ps1
```

This installs a `SmartMedApiServer` scheduled task that starts at Windows logon,
runs the API on port `8000`, and restarts it if it exits. Logs are written to
`logs\api-server.log`, with uvicorn output in `logs\api-server.stderr.log`.

Remove the startup task:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\remove_api_startup_task.ps1
```

Test examples:

```bash
curl "http://127.0.0.1:8000/drug-details?name=paracetamol"
curl "http://127.0.0.1:8000/drug-alternatives?name=ibuprofen"
curl "http://127.0.0.1:8000/drug-interaction?drug1=warfarin&drug2=ibuprofen"
```
