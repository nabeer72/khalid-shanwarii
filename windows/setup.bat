@echo off
set "TARGET_DIR=%LocalAppData%\MobilePOS"
echo Installing Mobile POS...

if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"

:: Extract the package.zip using PowerShell
echo Extracting files...
powershell -Command "Expand-Archive -Path 'package.zip' -DestinationPath '%TARGET_DIR%' -Force"

:: Create Shortcut
echo Creating Desktop Shortcut...
powershell -Command "$DesktopPath=[Environment]::GetFolderPath('Desktop'); $s=(New-Object -COM WScript.Shell).CreateShortcut($DesktopPath + '\Mobile POS.lnk'); $s.TargetPath='%TARGET_DIR%\mobile_app.exe'; $s.WorkingDirectory='%TARGET_DIR%'; $s.Save()"

echo.
echo Installation Complete! 
echo You can find "Mobile POS" on your Desktop.
pause
