:: =====================================================
:: HWID CHECK
:: =====================================================
for /f "skip=1 tokens=*" %%A in ('wmic csproduct get uuid') do if not defined HWID set "HWID=%%A"
set "HWID=%HWID: =%"

set "U1=https://raw.githubusercontent.com/"
set "U2=zBow2/Loader/"
set "U3=master/hwid.txt"

curl -L "%U1%%U2%%U3%" -o "%TEMP%\_hwids.txt" || (
  echo [!] Failed to download HWID list
  pause
  exit /b 1
)

if not exist "%TEMP%\_hwids.txt" (
  echo [!] HWID list file not found
  pause
  exit /b 1
)

set AUTHORIZED=0
for /f "usebackq tokens=*" %%L in ("%TEMP%\_hwids.txt") do (
  set "LINE=%%L"
  set "LINE=!LINE: =!"
  if /i "!LINE!"=="%HWID%" set AUTHORIZED=1
)

del "%TEMP%\_hwids.txt"

if "%AUTHORIZED%" neq "1" (
  echo [!] HWID not authorized. Exiting...
  pause
  exit /b 1
)

echo [✓] HWID authorized
