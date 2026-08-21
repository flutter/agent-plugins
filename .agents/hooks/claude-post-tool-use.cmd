@echo off
rem flutter-app-runtime: PostToolUse handler for Windows (Claude Code).
rem
rem Fires after Edit or Write tool calls.
rem Checks stdin for .dart file edits and outputs hookSpecificOutput with additionalContext.

setlocal EnableExtensions EnableDelayedExpansion

findstr /I /C:".dart" >nul 2>&1
if %errorlevel% equ 0 (
    echo {"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"Dart source changed. Use the flutter-app-runtime skill to push this to the running app: hot_reload for widget/UI or simple logic changes. If no app is running, say so and continue."}}
)
exit /b 0
