# Smart Med API

Run locally:

```bash
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Environment variables for the Grok-powered AI features:

```powershell
$env:XAI_API_KEY="xai-your-api-key-here"
$env:XAI_MODEL="grok-4.20-reasoning"
$env:XAI_BASE_URL="https://api.x.ai/v1"
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\service-account.json"
```

You can also put the same values in `smart_med_api/.env`. This is the easiest
option if the API is started by the Windows scheduled task, because the task
does not inherit variables from your current PowerShell session.

Example `smart_med_api/.env`:

```powershell
XAI_API_KEY=xai-your-api-key-here
XAI_MODEL=grok-4.20-reasoning
XAI_BASE_URL=https://api.x.ai/v1
GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\service-account.json
```

The `/medicine-information/image` and `/personalized-explanation` endpoints use
the OpenAI Python SDK against xAI's OpenAI-compatible API at
`https://api.x.ai/v1`, with the default model `grok-4.20-reasoning`.

If `XAI_API_KEY` is missing, those endpoints return HTTP `500` with a helpful
setup message. If Grok is unavailable, they return a safe server error instead
of exposing provider details or secret values.

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
language. The backend now sends those grounded prompts to Grok through the
OpenAI Python SDK. If model output is invalid, the API falls back to a
deterministic Firestore-only explanation instead of guessing.

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

PowerShell test for the personalized explanation endpoint:

```powershell
$token = "<firebase-id-token>"
$body = @{
  view = "detail"
  medication_ids = @()
  include_inactive = $false
  simple_language = $true
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri "http://127.0.0.1:8000/personalized-explanation" `
  -Headers @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
  } `
  -Body $body
```
