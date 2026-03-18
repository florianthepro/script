@echo off
setlocal enabledelayedexpansion
net session >nul 2>&1
if errorlevel 1 (
echo [FEHLER] Dieses Script muss als Administrator ausgefuehrt werden.
pause
exit /b 1
)
where wsl >nul 2>&1
if errorlevel 1 (
echo [FEHLER] WSL wurde nicht gefunden. Bitte zuerst WSL installieren, z.B.: wsl --install
pause
exit /b 1
)
where powershell >nul 2>&1
if errorlevel 1 (
echo [FEHLER] PowerShell wurde nicht gefunden. Dieses Script benoetigt PowerShell fuer den optionalen Download.
pause
exit /b 1
)
set DISTRO_NAME=UbuntuLive
set BASE_DIR=%ProgramData%\WSL_Live
if "%BASE_DIR%"=="" set BASE_DIR=%SystemDrive%\WSL_Live
if not exist "%BASE_DIR%" mkdir "%BASE_DIR%" >nul 2>&1
set INSTALL_DIR=%BASE_DIR%\%DISTRO_NAME%
set SCRIPT_DIR=%~dp0
set ROOTFS_FILE=%SCRIPT_DIR%ubuntu-rootfs.tar
if not exist "%ROOTFS_FILE%" (
echo [INFO] Kein lokales Ubuntu-Rootfs (ubuntu-rootfs.tar) im Script-Ordner gefunden.
if "%WSLLIVE_ROOTFS_URL%"=="" (
echo [FEHLER] Keine Download-URL fuer das Rootfs konfiguriert.
echo Lege ein Ubuntu-Rootfs als "ubuntu-rootfs.tar" in den Script-Ordner:
echo %SCRIPT_DIR%
echo Oder setze die Umgebungsvariable WSLLIVE_ROOTFS_URL mit einer gueltigen Rootfs-URL.
pause
exit /b 1
)
echo [INFO] Versuche Rootfs-Download von:
echo %WSLLIVE_ROOTFS_URL%
powershell -NoLogo -NoProfile -Command "try{Invoke-WebRequest -Uri '%WSLLIVE_ROOTFS_URL%' -OutFile '%ROOTFS_FILE%' -UseBasicParsing -ErrorAction Stop}catch{[Console]::Error.WriteLine('DOWNLOAD_FAILED');exit 1}"
if errorlevel 1 (
echo [FEHLER] Download des Rootfs ist fehlgeschlagen.
echo Pruefe die URL in WSLLIVE_ROOTFS_URL oder lade das Rootfs manuell herunter und speichere es als:
echo %ROOTFS_FILE%
pause
exit /b 1
)
)
if not exist "%ROOTFS_FILE%" (
echo [FEHLER] Rootfs-Datei wurde nicht gefunden, obwohl ein Download versucht wurde.
pause
exit /b 1
)
echo [INFO] Verwende Rootfs-Datei:
echo %ROOTFS_FILE%
echo [INFO] Beende ggf. laufende Instanz "%DISTRO_NAME%"...
wsl --terminate "%DISTRO_NAME%" >nul 2>&1
echo [INFO] Entferne ggf. vorhandene Distro "%DISTRO_NAME%"...
wsl --unregister "%DISTRO_NAME%" >nul 2>&1
echo [INFO] Entferne alten Installationsordner:
echo %INSTALL_DIR%
if exist "%INSTALL_DIR%" rmdir /s /q "%INSTALL_DIR%" 2>nul
mkdir "%INSTALL_DIR%" >nul 2>&1
if not exist "%INSTALL_DIR%" (
echo [FEHLER] Installationsordner konnte nicht angelegt werden:
echo %INSTALL_DIR%
pause
exit /b 1
)
echo [INFO] Importiere neue Live-Ubuntu-Instanz nach:
echo %INSTALL_DIR%
wsl --import "%DISTRO_NAME%" "%INSTALL_DIR%" "%ROOTFS_FILE%" --version 2
if errorlevel 1 (
echo [FEHLER] Import der Distro ist fehlgeschlagen.
echo Pruefe, ob "%ROOTFS_FILE%" ein gueltiges Ubuntu-Rootfs ist.
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
echo [INFO] Entferne Installationsordner:
echo %INSTALL_DIR%
if exist "%INSTALL_DIR%" rmdir /s /q "%INSTALL_DIR%" 2>nul
echo [INFO] Live-Umgebung wurde vollstaendig entfernt. Es wurden keine dauerhaften Daten behalten.
pause
endlocal
exit /b 0
