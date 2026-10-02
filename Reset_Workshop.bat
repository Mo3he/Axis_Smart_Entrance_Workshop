@echo off
REM Deletes all participant flows and restarts Node-RED with the clean starter flow.
cd /d "%~dp0"
docker compose down -v
docker compose up -d --build
echo.
echo Node-RED reset. Open http://localhost:1880
pause
