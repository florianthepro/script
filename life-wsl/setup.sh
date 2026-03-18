@echo off
setlocal enabledelayedexpansion

set DISTRO_NAME=UbuntuLive
set ROOTFS_FILE=ubuntu-rootfs.tar
set INSTALL_DIR=%USERPROFILE%\wsl-live\%DISTRO_NAME%

where wsl >nul 2>&1
if errorlevel 1 (
 echo [FEHLER] WSL ist nicht installiert oder 'wsl.exe' ist nicht im Pfad.
 echo Bitte zuerst WSL installieren: wsl --install
 pause
 exit /b 1
)

if not exist "%ROOTFS_FILE%" (
 echo [FEHLER] Rootfs-Datei "%ROOTFS_FILE%" wurde nicht gefunden.
 echo Lege das Ubuntu-LTS-Rootfs (tar) in diesen Ordner und benenne es "%ROOTFS_FILE%".
 pause
 exit /b 1
)

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
 echo Pruefe, ob das Rootfs ein gueltiges Ubuntu-LTS-Image (tar) ist.
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

echo [INFO] Live-Umgebung wurde vollstaendig entfernt. Keine Daten wurden behalten.
pause
endlocal
exit /b 0
