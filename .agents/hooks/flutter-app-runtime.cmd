@echo off
rem flutter-app-runtime: PreInvocation handler for Windows (Antigravity).
rem
rem Native Windows batch script checking for pending Dart edit flag.
rem Zero runtime dependencies; executes in < 5ms.

setlocal EnableExtensions EnableDelayedExpansion

set "FLAG_FOUND=0"
if exist "%TEMP%\flutter-app-runtime.*.pending" set "FLAG_FOUND=1"
if exist "%TEMP%\flutter-app-runtime.pending" set "FLAG_FOUND=1"

if "!FLAG_FOUND!"=="1" (
    del /f /q "%TEMP%\flutter-app-runtime.*.pending" 2>nul
    del /f /q "%TEMP%\flutter-app-runtime.pending" 2>nul
    echo {"injectSteps":[{"ephemeralMessage":"Dart source changed. Use the flutter-app-runtime skill to push this to the running app: hot_reload for widget/UI or simple logic changes. If no app is running, say so and continue."}]}
) else (
    echo {"injectSteps":[]}
)
exit /b 0
