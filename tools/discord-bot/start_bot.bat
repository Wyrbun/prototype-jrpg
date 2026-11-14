@echo off
rem Starts the Prototype JRPG Discord bot. First run sets everything up.
cd /d "%~dp0"
if not exist .env (
  echo No .env file yet: copy .env.example to .env and fill in your keys.
  pause
  exit /b 1
)
if not exist .venv (
  echo Setting up for the first time...
  py -3 -m venv .venv || python -m venv .venv
  .venv\Scripts\python -m pip install --upgrade pip
  .venv\Scripts\python -m pip install -r requirements.txt
)
.venv\Scripts\python bot.py
pause
