# Smart Med API

Run locally:

```bash
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Test examples:

```bash
curl "http://127.0.0.1:8000/drug-details?name=paracetamol"
curl "http://127.0.0.1:8000/drug-interaction?drug1=warfarin&drug2=ibuprofen"
```
