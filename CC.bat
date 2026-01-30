@echo off
setlocal EnableDelayedExpansion

:: ===============================
:: GET HWID
:: ===============================
for /f "skip=1 tokens=*" %%A in ('wmic csproduct get uuid') do if not defined HWID set "HWID=%%A"
set "HWID=%HWID: =%"
echo [*] Detected HWID: %HWID%

:: ===============================
:: ADMIN CHECK
:: ===============================
net session >nul 2>&1 || (
  echo [!] Run this script as Administrator
  pause
  goto SELF_DELETE
)

:: ===============================
:: ASK TARGET PATH
:: ===============================
:ASK_TARGET
echo.
set /p "TARGET=Enter path to clean: "
if not exist "%TARGET%" (
  echo [!] Path not found.
  goto ASK_TARGET
)

echo [*] Target: %TARGET%

:: ===============================
:: FILE CLEANUP
:: ===============================
del /f /s /q "%TARGET%\*.tmp" "%TARGET%\*.log" "%TARGET%\*.cache*" >nul 2>&1
for %%D in ("Cache" "Code Cache" "GPUCache") do (
  if exist "%TARGET%\%%~D" rmdir /s /q "%TARGET%\%%~D"
)

:: ===============================
:: SYSTEM CLEANUP
:: ===============================
del /f /s /q "%SystemRoot%\Prefetch\*.pf" >nul 2>&1
del /f /s /q "%SystemRoot%\Minidump\*.dmp" >nul 2>&1
del /f /q "%AppData%\Microsoft\Windows\Recent\*" >nul 2>&1

:: ===============================
:: BROWSER CACHE
:: ===============================
taskkill /IM chrome.exe /F >nul 2>&1
taskkill /IM msedge.exe /F >nul 2>&1

for %%B in (
  "%LocalAppData%\Google\Chrome\User Data\Default"
  "%LocalAppData%\Microsoft\Edge\User Data\Default"
) do (
  for %%C in ("Cache" "Code Cache" "GPUCache") do (
    if exist "%%~B\%%~C" rmdir /s /q "%%~B\%%~C"
  )
)

:: ===============================
:: AUDITPOL (INLINE, WAITING)
:: ===============================
echo [*] Disabling auditing...
powershell -NoProfile -Command ^
"auditpol /clear; ^
 auditpol /set /category:'Logon/Logoff' /success:disable /failure:disable"

echo.
echo [✓] Cleanup completed.

pause

:SELF_DELETE
(goto) 2>nul & del "%~f0"
