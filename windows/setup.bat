@echo off
set "SOURCE_DIR=%~dp0"
set "TARGET_DIR=%LocalAppData%\MobilePOS"
echo Installing Mobile POS...

echo Installing Microsoft Visual C++ Runtime...
start /wait "" "%SOURCE_DIR%vc_redist.x64.exe" /install /quiet /norestart
set "VC_EXIT=%ERRORLEVEL%"
if "%VC_EXIT%"=="0" goto runtime_ready
if "%VC_EXIT%"=="1638" goto runtime_ready
if "%VC_EXIT%"=="3010" goto runtime_ready
echo Visual C++ Runtime installation failed with code %VC_EXIT%.
echo Approve the Windows administrator prompt and run this installer again.
pause
exit /b %VC_EXIT%

:runtime_ready
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"

echo Extracting files...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '%SOURCE_DIR%package.zip' -DestinationPath '%TARGET_DIR%' -Force"
if errorlevel 1 goto extraction_failed

echo Creating Desktop Shortcut...
powershell -NoProfile -Command "$DesktopPath=[Environment]::GetFolderPath('Desktop'); $s=(New-Object -COM WScript.Shell).CreateShortcut($DesktopPath + '\Mobile POS.lnk'); $s.TargetPath='%TARGET_DIR%\mobile_app.exe'; $s.WorkingDirectory='%TARGET_DIR%'; $s.Save()"
if errorlevel 1 goto shortcut_failed

echo.
echo Installation Complete! 
echo You can find "Mobile POS" on your Desktop.
pause
exit /b 0

:extraction_failed
echo Failed to extract the Mobile POS application files.
pause
exit /b 1

:shortcut_failed
echo The application installed, but the Desktop shortcut could not be created.
pause
exit /b 1
