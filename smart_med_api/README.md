# Smart Med API

Run locally:

```bash
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

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
