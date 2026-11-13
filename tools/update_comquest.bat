@echo off
rem ============================================================================
rem  update_comquest.bat
rem  Installs the newest ComQuest.Altis*.zip from your Downloads folder into
rem  Arma's mission folder, replacing the old ComQuest.Altis folder.
rem  The previous folder is kept as ComQuest.Altis_old (overwritten each time).
rem ============================================================================
setlocal
set "DL=%USERPROFILE%\Downloads"
set "MISSIONS=%USERPROFILE%\Documents\Arma 3 - Other Profiles\Django\mpmissions"

rem newest zip whose name starts with ComQuest.Altis (handles "ComQuest.Altis-guide (1).zip")
set "ZIP="
for /f "delims=" %%F in ('dir /b /o-d "%DL%\ComQuest.Altis*.zip" 2^>nul') do if not defined ZIP set "ZIP=%DL%\%%F"
if not defined ZIP (
    echo No ComQuest.Altis*.zip found in %DL%
    pause
    exit /b 1
)
echo Zip:     %ZIP%
echo Target:  %MISSIONS%\ComQuest.Altis
echo.

if not exist "%MISSIONS%" (
    echo Mission folder not found: %MISSIONS%
    pause
    exit /b 1
)

rem keep the previous version, just in case
if exist "%MISSIONS%\ComQuest.Altis_old" rmdir /s /q "%MISSIONS%\ComQuest.Altis_old"
if exist "%MISSIONS%\ComQuest.Altis" move "%MISSIONS%\ComQuest.Altis" "%MISSIONS%\ComQuest.Altis_old" >nul

rem extract (the zip holds the ComQuest.Altis folder itself)
powershell -NoProfile -Command "Expand-Archive -LiteralPath '%ZIP%' -DestinationPath '%MISSIONS%' -Force"
if errorlevel 1 (
    echo Extraction failed. Restoring the previous version.
    if exist "%MISSIONS%\ComQuest.Altis" rmdir /s /q "%MISSIONS%\ComQuest.Altis"
    move "%MISSIONS%\ComQuest.Altis_old" "%MISSIONS%\ComQuest.Altis" >nul
    pause
    exit /b 1
)

echo Done. Installed version:
findstr /b "CQ_branch CQ_build" "%MISSIONS%\ComQuest.Altis\cfg\version.sqf"
echo.
pause
