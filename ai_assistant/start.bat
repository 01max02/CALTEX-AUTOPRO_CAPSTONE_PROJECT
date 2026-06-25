@echo off
cd /d "%~dp0"
echo Starting Caltex AutoPro AI Backend...
echo.
echo Port : 8002
echo URL  : http://localhost:8002
echo Docs : http://localhost:8002/docs
echo.
venv\Scripts\uvicorn.exe main:app --host 127.0.0.1 --port 8002 --reload
pause
