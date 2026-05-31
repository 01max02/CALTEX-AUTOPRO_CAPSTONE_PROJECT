Automotive Firebase AI Assistant

Run steps:
1) Activate virtual environment
   .\.venv\Scripts\Activate.ps1

2) Install dependencies (from workspace root)
   pip install -r requirements.txt

3) Start API (from RHU_RAG_AI_PROTOTYPE-main)
   uvicorn api:app --reload --host 0.0.0.0 --port 8000

4) Open frontend
   http://127.0.0.1:8000

Notes:
- The system now retrieves live data from Firebase (Firestore or Realtime Database).
- The assistant can generate on-demand inventory, issuance, and transaction reports in Excel or PDF.