@echo off
cd /d "%~dp0.."
if not exist "env.dev.json" (
  echo Missing env.dev.json - copy env.dev.json.example and add your Supabase URL and anon key.
  exit /b 1
)
flutter run -d chrome --dart-define-from-file=env.dev.json
