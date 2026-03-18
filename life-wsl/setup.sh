@echo off
setlocal enabledelayedexpansion
net session >nul 2>&1
if errorlevel 1 (
echo [FEHLER] Dieses Script muss als Administrator ausgefuehrt werden.
pause
exit /b 1
)
set DISTRO_NAME=UbuntuLive
set INSTALL_DIR=%USERPROFILE%\wsl-live\%DISTRO_NAME%
set ROOTFS_FILE=%~dp0ubuntu-rootfs.tar
set ROOTFS_URL=https://partner-images.canonical.com/core/jammy/current/ubuntu-jammy-core-cloudimg-amd64-root.tar.xz
set ROOTFS_COMPRESSED=%~dp0ubuntu-rootfs.tar.xz
set DELETE_ROOTFS=0
where wsl >nul 2>&1
if errorlevel 1 (
echo [FEHLER] WSL ist nicht installiert oder 'wsl.exe' ist nicht im Pfad.
echo Bitte zuerst WSL installieren: wsl --install
pause
exit /b 1
)
where powershell >nul 2>&1
if errorlevel 1 (
echo [FEHLER] PowerShell wurde nicht gefunden. Dieses Script benoetigt PowerShell fuer den Download.
pause
exit /b 1
)
where tar >nul 2>&1
if errorlevel 1 (
echo [FEHLER] 'tar' wurde nicht gefunden. Unter aktuellen Windows Versionen ist tar normalerweise enthalten.
pause
exit /b 1
)
if not exist "%ROOTFS_FILE%" (
echo [INFO] Ubuntu-Rootfs wurde nicht gefunden. Starte automatischen Download...
echo [INFO] Lade Ubuntu LTS Rootfs von:
echo %ROOTFS_URL%
powershell -Command "Try {Invoke-WebRequest -Uri '%ROOTFS_URL%' -OutFile '%ROOTFS_COMPRESSED%' -UseBasicParsing -ErrorAction Stop} Catch {Write-Error $_; Exit 1}"
if errorlevel 1 (
echo [FEHLER] Download des Ubuntu-Rootfs ist fehlgeschlagen.
pause
exit /b 1
)
echo [INFO] Entpacke Rootfs-Archiv...
tar -xf "%ROOTFS_COMPRESSED%" -C "%~dp0"
if errorlevel 1 (
echo [FEHLER] Entpacken des Rootfs ist fehlgeschlagen.
pause
exit /b 1
)
del /f /q "%ROOTFS_COMPRESSED%" >nul 2>&1
for %%F in ("%~dp0*.tar") do (
set ROOTFS_FILE=%%F
goto :rootfsFound
)
:rootfsFound
if not exist "%ROOTFS_FILE%" (
echo [FEHLER] Konnte entpacktes Rootfs nicht finden.
pause
exit /b 1
)
)
echo [INFO] Verwende Rootfs-Datei: %ROOTFS_FILE%
echo [INFO] Beende ggf. laufende Instanz "%DISTRO_NAME%"...
wsl --terminate "%DISTRO_NAME%" >nul 2>&1
echo [INFO] Entferne ggf. vorhandene Distro "%DISTRO_NAME%"...
wsl --unregister "%DISTRO_NAME%" >nul 2>&1
echo [INFO] Entferne alten Installationsordner "%INSTALL_DIR%"...
if exist "%INSTALL_DIR%" (
rmdir /s /q "%INSTALL_DIR%" 2>nul
)
mkdir "%INSTALL_DIR%" >nul 2>&1
echo [INFO] Importiere neue Live-Ubuntu-Instanz nach "%INSTALL_DIR%"...
wsl --import "%DISTRO_NAME%" "%INSTALL_DIR%" "%ROOTFS_FILE%" --version 2
if errorlevel 1 (
echo [FEHLER] Import der Distro ist fehlgeschlagen.
echo Pruefe, ob das Rootfs ein gueltiges Ubuntu-LTS-Image ist.
pause
exit /b 1
)
echo [INFO] Starte Live-Ubuntu-Session (Distro: %DISTRO_NAME%)...
echo [HINWEIS] Alle Aenderungen in dieser Session gehen nach dem Schliessen verloren.
echo.
wsl -d "%DISTRO_NAME%"
echo.
echo [INFO] Live-Session wurde beendet.
echo [INFO] Beende Distro "%DISTRO_NAME%"...
wsl --terminate "%DISTRO_NAME%" >nul 2>&1
echo [INFO] Deregistriere Distro "%DISTRO_NAME%"...
wsl --unregister "%DISTRO_NAME%" >nul 2>&1
echo [INFO] Entferne Installationsordner "%INSTALL_DIR%"...
if exist "%INSTALL_DIR%" (
rmdir /s /q "%INSTALL_DIR%" 2>nul
)
if "%DELETE_ROOTFS%"=="1" (
if exist "%ROOTFS_FILE%" (
echo [INFO] Entferne Rootfs-Datei "%ROOTFS_FILE%"...
del /f /q "%ROOTFS_FILE%" >nul 2>&1
)
)
echo [INFO] Live-Umgebung wurde vollstaendig entfernt. Keine Daten wurden behalten.
pause
endlocal
exit /b 0
