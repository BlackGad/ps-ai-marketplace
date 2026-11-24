@echo off
rem Hand-built fixture: only command processor tools can serve an offline token for this probe.
echo %* | findstr /C:"get-access-token" >nul
if not errorlevel 1 (
  echo {"accessToken":"fixture-token","expires_on":4102444800}
  exit /b 0
)
echo %* | findstr /C:"-o tsv" >nul
if not errorlevel 1 exit /b 0
echo []
