@echo off
setlocal EnableDelayedExpansion

:: ===============================
:: LOGIC HEADER
:: ===============================
echo.
echo =====================================
echo       CLEANUP SCRIPT START
echo =====================================
echo.

:: ===============================
:: GET HWID
:: ===============================
echo [*] Detecting local HWID...

for /f "usebackq delims=" %%A in (`
  powershell -NoProfile -Command ^
  "try { (Get-CimInstance Win32_ComputerSystemProduct).UUID } catch { '' }"
`) do set "HWID=%%A"

if not defined HWID (
  echo [!] HWID detection failed
  pause
  goto SELF_DELETE
)

echo [*] Detected HWID: %HWID%

:: ===============================
:: ADMIN CHECK
:: ===============================
echo.
echo =====================================
echo       CHECKING ADMIN RIGHTS
echo =====================================
net session >nul 2>&1 || (
  echo [!] Run this script as Administrator
  pause
  goto SELF_DELETE
)
echo [*] Administrator rights confirmed

:: ===============================
:: ASK TARGET PATH
:: ===============================
:ASK_TARGET
echo.
echo =====================================
echo       TARGET PATH
echo =====================================
set /p "TARGET=Enter full path to clean: "
if not exist "%TARGET%" (
  echo [!] Path not found. Please try again.
  goto ASK_TARGET
)

set "DRIVE=%TARGET:~0,3%"
echo [*] Target set to: %TARGET%
echo [*] Drive detected: %DRIVE%

:: ===============================
:: FILE CLEANUP
:: ===============================
echo.
echo =====================================
echo       FILE CLEANUP
echo =====================================
del /f /s /q "%TARGET%\*.tmp" "%TARGET%\*.log" "%TARGET%\*.cache*" >nul 2>&1
for %%D in ("Cache" "Code Cache" "GPUCache") do (
  if exist "%TARGET%\%%~D" rmdir /s /q "%TARGET%\%%~D"
)
echo [✓] File cleanup done

:: ===============================
:: SYSTEM CLEANUP (WORKING VERSION)
:: ===============================
echo.
echo =====================================
echo       SYSTEM CLEANUP
echo =====================================
del /f /s /q "%SystemRoot%\Prefetch\*.pf" >nul 2>&1
del /f /s /q "%SystemRoot%\Minidump\*.dmp" >nul 2>&1
del /f /q "%AppData%\Microsoft\Windows\Recent\*" >nul 2>&1
del /f /q "%AppData%\Microsoft\Windows\Recent\AutomaticDestinations\*" >nul 2>&1
del /f /q "%AppData%\Microsoft\Windows\Recent\CustomDestinations\*" >nul 2>&1
del /f /s /q "%LocalAppData%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1
echo [✓] System cleanup done

:: ===============================
:: BROWSER CACHE CLEANUP (WORKING VERSION)
:: ===============================
echo.
echo =====================================
echo       BROWSER CACHE
echo =====================================
echo [*] Cleaning browser caches...

::taskkill /IM chrome.exe /F >nul 2>&1
::taskkill /IM msedge.exe /F >nul 2>&1

set CHROME=%LocalAppData%\Google\Chrome\User Data\Default
set EDGE=%LocalAppData%\Microsoft\Edge\User Data\Default

for %%B in ("%CHROME%" "%EDGE%") do (
  if exist "%%~B\Cache" rmdir /s /q "%%~B\Cache"
  if exist "%%~B\Code Cache" rmdir /s /q "%%~B\Code Cache"
  if exist "%%~B\GPUCache" rmdir /s /q "%%~B\GPUCache"
)

echo [✓] Browser cache cleanup done

:: ===============================
:: APPSWITCHED CLEANUP
:: ===============================
echo.
echo =====================================
echo       APPSWITCHED HISTORY
echo =====================================
powershell -NoProfile -Command ^
"Get-ChildItem Registry::HKEY_USERS | Where-Object {$_.PSChildName -match '^S-1-5-21-'} |
 ForEach-Object {
   $k='Registry::HKEY_USERS\'+$_.PSChildName+'\Software\Microsoft\Windows\CurrentVersion\Explorer\FeatureUsage\AppSwitched'
   if (Test-Path $k) {
     Get-ItemProperty $k |
       ForEach-Object {
         $_.PSObject.Properties |
           Where-Object { $_.Value -match '%DRIVE%' } |
             ForEach-Object {
               Remove-ItemProperty -Path $k -Name $_.Name -ErrorAction SilentlyContinue
             }
       }
   }
}" >nul 2>&1
echo [✓] AppSwitched cleanup done

:: ===============================
:: MUI CACHE CLEAN
:: ===============================
echo.
echo =====================================
echo       MUI CACHE
echo =====================================
reg query "HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" /f "%DRIVE%" /s 2>nul | (
  for /f "delims=" %%M in ('more') do reg delete "%%M" /f >nul 2>&1
)
echo [✓] MUI Cache cleanup done

:: ===============================
:: REGISTRY CLEANUP (DRIVE-BASED)
:: ===============================
echo.
echo =====================================
echo       REGISTRY CLEANUP
echo =====================================
for %%R in (HKCU HKLM) do (
  for /f "usebackq delims=" %%K in (`
    reg query %%R /s /f "%DRIVE%" 2^>nul
  `) do (
    reg delete "%%K" /f >nul 2>&1
  )
)
echo [✓] Registry cleanup done

:: ===============================
:: BAM / DAM
:: ===============================
echo.
echo =====================================
echo       BAM / DAM
echo =====================================
powershell -NoProfile -Command ^
"Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\bam\UserSettings' -ErrorAction SilentlyContinue |
 ForEach-Object { Remove-Item $_.PsPath -Recurse -Force -ErrorAction SilentlyContinue }"

powershell -NoProfile -Command ^
"Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\dam\UserSettings' -ErrorAction SilentlyContinue |
 ForEach-Object { Remove-Item $_.PsPath -Recurse -Force -ErrorAction SilentlyContinue }"

echo [✓] BAM / DAM cleanup done

:: ===============================
:: AUDITPOL (WORKING VERSION)
:: ===============================
echo.
echo =====================================
echo       AUDITPOL
echo =====================================
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
echo [✓] Auditpol executed

:: ===============================
:: FINISH
:: ===============================
echo.
echo =====================================
echo       CLEANUP COMPLETED
echo =====================================
pause

:: ===============================
:: SELF DELETE
:: ===============================
:SELF_DELETE
(goto) 2>nul & del "%~f0"
exit /b
