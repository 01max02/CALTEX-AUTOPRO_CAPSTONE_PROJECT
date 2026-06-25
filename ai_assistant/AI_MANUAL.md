# Caltex AutoPro — AI Assistant Setup & Run Guide

---

## 🆕 Fresh Setup — For New Developers (After Pulling from Git)

Follow these steps **in order** if you just cloned or pulled the project for the first time.

---

### Step 1 — Install Python 3.13

Download and install Python 3.13 from https://www.python.org/downloads/  
During installation, **check "Add Python to PATH"**.

Verify it works:
```bat
python --version
```

---

### Step 2 — Create the Firebase Credentials File

The Firebase service account key is **not included in the repository** for security reasons.  
You need to create it manually.

1. Inside the `ai_assistant/` folder, create a new file named exactly:
   ```
   caltex-autopro-1e664-firebase-adminsdk-fbsvc-07b4fc625e.json
   ```
2. Paste the credentials content into that file (ask the project precious for the content).
3. Save the file.

> ⚠️ Never commit this file to Git. It is already listed in `.gitignore`.

---

### Step 3 — Create the `.env` File

Inside the `ai_assistant/` folder, create a file named `.env` with the following content (or just ask precious for the content):

```
FIREBASE_CREDENTIALS_PATH=./caltex-autopro-1e664-firebase-adminsdk-fbsvc-07b4fc625e.json
GROQ_API_KEY=gsk_...
GROQ_MODEL=llama-3.1-8b-instant
```

Replace `gsk_...` with the actual Groq API key (ask the project owner).

---

### Step 4 — Create the Virtual Environment and Install Dependencies

```bat
cd ai_assistant (copy the path of the folder)
python -m venv venv
venv\Scripts\pip install -r requirements.txt
```

> This only needs to be done once. If the `venv/` folder already exists, skip to Step 5.

---

### Step 5 — Run the System

See the **Running the System** section below.

---

---

## Requirements
- Python 3.13 (already installed)
- Virtual environment at `ai_assistant/venv/` (already created)

---

## First-Time Setup (already done — skip if venv exists)

```bat
cd ai_assistant (copy the path of the folder)
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
