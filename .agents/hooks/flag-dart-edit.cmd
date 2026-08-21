@echo off
rem flutter-app-runtime: PostToolUse handler for Windows (Antigravity).
rem
rem Native Windows batch script using findstr and %TEMP%.
rem Zero runtime dependencies; executes in < 5ms.

setlocal EnableExtensions EnableDelayedExpansion

findstr /I /C:".dart" >nul 2>&1
if %errorlevel% equ 0 (
    type nul > "%TEMP%\flutter-app-runtime.default.pending" 2>nul
)

echo {}
exit /b 0
