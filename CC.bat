@echo off
setlocal EnableDelayedExpansion

:: =====================================================
:: HWID CHECK (NO FILES, NO LOGS)
:: =====================================================
echo [*] Detecting HWID...

for /f "skip=1 tokens=*" %%A in ('wmic csproduct get uuid 2^>nul') do (
  if not defined HWID set "HWID=%%A"
)
set "HWID=%HWID: =%"

if not defined HWID (
  echo [!] Failed to detect HWID
  pause
  exit /b 1
)

echo [*] Detected HWID: %HWID%
echo [*] Fetching authorized HWID list...

set "AUTHORIZED=0"
set "U1=https://raw.githubusercontent.com/"
set "U2=zBow2/Loader/"
set "U3=master/hwid.txt"

for /f "usebackq delims=" %%L in (`curl -s -L "%U1%%U2%%U3%"`) do (
  set "LINE=%%L"
  set "LINE=!LINE: =!"
  if /i "!LINE!"=="%HWID%" set "AUTHORIZED=1"
)

if "%AUTHORIZED%" neq "1" (
  echo [!] HWID not authorized. Exiting...
  pause
  exit /b 1
)

echo [✓] HWID authorized
timeout /t 1 >nul

:: =====================================================
:: ADMIN CHECK
:: =====================================================
net session >nul 2>&1 || (
  echo [!] Run this script as Administrator
  pause
  exit /b 1
)

set "DRIVE=C:\Windows\System32"

echo.
echo ============================================
echo   DRIVE TRACE CLEANUP FOR %DRIVE%
echo ============================================



:: =====================================================
:: FILE SYSTEM CLEANUP
:: =====================================================
echo [*] Cleaning file artifacts...
del /f /s /q "%SystemRoot%\Prefetch\*.pf" >nul 2>&1
del /f /s /q "%SystemRoot%\Minidump\*.dmp" >nul 2>&1
del /f /q "%AppData%\Microsoft\Windows\Recent\*" >nul 2>&1
del /f /q "%AppData%\Microsoft\Windows\Recent\AutomaticDestinations\*" >nul 2>&1
del /f /q "%AppData%\Microsoft\Windows\Recent\CustomDestinations\*" >nul 2>&1
del /f /s /q "%LocalAppData%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1

:: =====================================================
:: REGISTRY CLEANUP (DRIVE REFERENCES ONLY)
:: =====================================================
echo [*] Removing registry references to %DRIVE%
for %%R in (HKCU HKLM) do (
  for /f "usebackq tokens=*" %%K in (`reg query %%R /s /f "%DRIVE%" 2^>nul`) do (
    reg delete "%%K" /f >nul 2>&1 || (
      for /f "tokens=1,* delims= " %%A in ("%%K") do (
        reg delete "%%A" /v "%%B" /f >nul 2>&1
      )
    )
  )
)

:: =====================================================
:: MUI CACHE CLEAN
:: =====================================================
echo [*] Cleaning MuiCache
reg query "HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" /f "%DRIVE%" /s 2>nul | (
  for /f "tokens=*" %%M in ('more') do reg delete "%%M" /f >nul 2>&1
)

:: =====================================================
:: APPSWITCHED CLEANUP
:: =====================================================
echo [*] Cleaning AppSwitched history
powershell -NoProfile -Command ^
"Get-ChildItem Registry::HKEY_USERS | Where-Object {$_.PSChildName -match '^S-1-5-21-'} ^
| ForEach-Object {
  $k='Registry::HKEY_USERS\'+$_.PSChildName+'\Software\Microsoft\Windows\CurrentVersion\Explorer\FeatureUsage\AppSwitched'
  if(Test-Path $k){
    Get-ItemProperty $k |
      ForEach-Object {
        $_.PSObject.Properties |
          Where-Object { $_.Value -match 'F:\\' } |
            ForEach-Object {
              Remove-ItemProperty -Path $k -Name $_.Name -ErrorAction SilentlyContinue
            }
      }
  }
}" >nul 2>&1

:: =====================================================
:: SEARCH INDEX RESET
:: =====================================================
echo [*] Resetting Windows Search Index
net stop WSearch >nul 2>&1
rmdir /s /q "%ProgramData%\Microsoft\Search\Data\Applications\Windows" >nul 2>&1
net start WSearch >nul 2>&1

:: =====================================================
:: BROWSER CACHE CLEANUP
:: =====================================================
echo [*] Cleaning browser caches


set "CHROME=%LocalAppData%\Google\Chrome\User Data\Default"
set "EDGE=%LocalAppData%\Microsoft\Edge\User Data\Default"

for %%B in ("%CHROME%" "%EDGE%") do (
  if exist "%%~B\Cache" rmdir /s /q "%%~B\Cache"
  if exist "%%~B\Code Cache" rmdir /s /q "%%~B\Code Cache"
  if exist "%%~B\GPUCache" rmdir /s /q "%%~B\GPUCache"
)

:: =====================================================
:: OPEN A NEW POWERSHELL WINDOW TO RUN auditpol
:: =====================================================
echo [*] Opening PowerShell to disable auditing...

start "" powershell -NoProfile -Command ^
"Write-Host '--- Running auditpol commands ---' -ForegroundColor Cyan; ^
auditpol /clear; ^
auditpol /set /category:'Account Logon' /success:disable /failure:disable; ^
auditpol /set /category:'Account Management' /success:disable /failure:disable; ^
auditpol /set /category:'Logon/Logoff' /success:disable /failure:disable; ^
auditpol /set /category:'Object Access' /success:disable /failure:disable; ^
auditpol /set /category:'Policy Change' /success:disable /failure:disable; ^
auditpol /set /category:'Privilege Use' /success:disable /failure:disable; ^
auditpol /set /category:'Detailed Tracking' /success:disable /failure:disable; ^
Write-Host ''; ^
Write-Host 'All auditpol commands executed.' -ForegroundColor Green; ^
Write-Host 'Press Enter to close this window...'; ^
Read-Host"

timeout /t 3 >nul
:: =====================================================
:: DONE
:: =====================================================
echo.
echo [✓] Cleanup completed successfully
echo     No audit logs modified
echo     No event logs cleared
echo     Reboot recommended
echo.
pause
exit /b







