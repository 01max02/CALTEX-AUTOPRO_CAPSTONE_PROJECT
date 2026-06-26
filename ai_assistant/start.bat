@echo off
cd /d "%~dp0"
echo Starting Caltex AutoPro AI Backend...
echo.
echo Port  : 8001
echo Local : http://localhost:8001
echo LAN   : http://0.0.0.0:8001  (accessible from mobile devices on same network)
echo Docs  : http://localhost:8001/docs
echo.
echo NOTE: Mobile app default is http://10.0.2.2:8001 (Android emulator)
echo       For a physical device, run Flutter with:
echo         flutter run --dart-define=AI_BACKEND_URL=http://YOUR_LAN_IP:8001
echo.
venv\Scripts\uvicorn.exe main:app --host 0.0.0.0 --port 8001 --reload
pause
