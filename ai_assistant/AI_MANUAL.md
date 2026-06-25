# Caltex AutoPro — AI Assistant Setup & Run Guide

## Requirements
- Python 3.13 (already installed)
- Virtual environment at `ai_assistant/venv/` (already created)

---

## First-Time Setup (already done — skip if venv exists)

```bat
cd ai_assistant
python -m venv venv
venv\Scripts\pip install -r requirements.txt
```

---

## Running the System (2 terminals)

### Terminal 1 — AI Backend (FastAPI)

**Option A — double-click the batch file:**
```
ai_assistant\start.bat
```

**Option B — run manually:**
```bat
cd ai_assistant
venv\Scripts\uvicorn main:app --host 127.0.0.1 --port 8001 --reload
```

Health check: http://localhost:8001/health  
Interactive docs: http://localhost:8001/docs

---

### Terminal 2 — Flask Web Server

```bat
cd automotive_website
python caltexautopro.py
```

Web app: http://localhost:5001

---

## Port 8001 already in use?

```powershell
# Find what's using it
netstat -ano | findstr ":8001"

# Kill it (replace XXXX with the PID shown)
taskkill /F /PID XXXX
```

Then try starting again.

---

## Environment Variables (ai_assistant/.env)

```
FIREBASE_CREDENTIALS_PATH=./caltex-autopro-1e664-firebase-adminsdk-fbsvc-07b4fc625e.json
GROQ_API_KEY=gsk_...
GROQ_MODEL=llama-3.1-8b-instant
```

---

## How It Works

```
Flutter/Web  →  POST /api/ai-chat (Flask proxy)
                    ↓
            POST http://localhost:8000/admin/chat
                    ↓
         Groq LLM + Firestore tool calls
                    ↓
              JSON reply back to UI
```
