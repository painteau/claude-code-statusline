@echo off
:: Claude Code status line — Windows wrapper
:: Forces UTF-8 code page before running the bash script
:: Place this file alongside statusline.sh in ~/.claude/
chcp 65001 >nul 2>&1
"C:\Program Files\Git\bin\bash.exe" "%~dp0statusline.sh"
