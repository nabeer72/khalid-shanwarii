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

echo Resetting the previous installation database...
set "DB_DIR=%TARGET_DIR%\database"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$backupRoot=Join-Path $env:LOCALAPPDATA 'MobilePOS_Database_Backups'; $databasePaths=@($env:DB_DIR,(Join-Path $env:TARGET_DIR '.dart_tool\sqflite_common_ffi\databases'),(Join-Path $env:LOCALAPPDATA 'sqflite_common_ffi\databases')); $databaseFiles=@('khalid_shinwari.db','khalid_shinwari.db-wal','khalid_shinwari.db-shm'); foreach ($databasePath in $databasePaths) { foreach ($file in $databaseFiles) { $source=Join-Path $databasePath $file; if (Test-Path -LiteralPath $source) { New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null; $backup=Join-Path $backupRoot ('database-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff')); New-Item -ItemType Directory -Path $backup -Force | Out-Null; Move-Item -LiteralPath $source -Destination $backup -ErrorAction Stop } } }"
if errorlevel 1 goto database_reset_failed

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

:database_reset_failed
echo Failed to reset the previous application database.
echo The old database has not been removed. Installation was stopped.
pause
exit /b 1

:shortcut_failed
echo The application installed, but the Desktop shortcut could not be created.
pause
exit /b 1
