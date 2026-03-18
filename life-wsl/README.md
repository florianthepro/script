# WSL Reset und Live‑WSL minimal

## 1. WSL Reset

    wsl --list --verbose
    wsl --unregister Ubuntu
    wsl --unregister Ubuntu-20.04
    wsl --unregister Debian
    wsl --unregister kali-linux
    wsl --unregister Alpine
    wsl --list --verbose
    dism.exe /online /disable-feature /featurename:Microsoft-Windows-Subsystem-Linux /norestart
    dism.exe /online /disable-feature /featurename:VirtualMachinePlatform /norestart
    shutdown /r /t 0

Nach Neustart:

    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    shutdown /r /t 0

Nach Neustart:

    wsl --update

***

## 2. Basis‑Ubuntu installieren und exportieren

    wsl --install -d Ubuntu
    wsl -d Ubuntu
    exit
    mkdir C:\WSL
    mkdir C:\WSL\Base
    wsl --export Ubuntu C:\WSL\Base\ubuntu-base.tar
    wsl --unregister Ubuntu

***

## 3. Live‑WSL Batch

Dateiname: `UbuntuLive.bat`

    @echo off
    set "LIVE_NAME=UbuntuLive"
    set "LIVE_ROOT=C:\WSL\Live\UbuntuLive"
    set "BASE_IMAGE=C:\WSL\Base\ubuntu-base.tar"
    if not exist "%BASE_IMAGE%" goto :end
    wsl --list --quiet | findstr /b /r /c:"%LIVE_NAME%" >nul 2>&1
    if %errorlevel%==0 wsl --terminate "%LIVE_NAME%"
    wsl --list --quiet | findstr /b /r /c:"%LIVE_NAME%" >nul 2>&1
    if %errorlevel%==0 wsl --unregister "%LIVE_NAME%"
    if exist "%LIVE_ROOT%" rmdir /S /Q "%LIVE_ROOT%"
    mkdir "%LIVE_ROOT%"
    wsl --import "%LIVE_NAME%" "%LIVE_ROOT%" "%BASE_IMAGE%" --version 2
    wsl -d "%LIVE_NAME%"
    wsl --terminate "%LIVE_NAME%" 2>nul
    wsl --unregister "%LIVE_NAME%" 2>nul
    if exist "%LIVE_ROOT%" rmdir /S /Q "%LIVE_ROOT%"
    :end

***

## 4. Live‑WSL manuell (atomar)

    wsl --terminate UbuntuLive
    wsl --unregister UbuntuLive
    rmdir /S /Q C:\WSL\Live\UbuntuLive
    mkdir C:\WSL\Live\UbuntuLive
    wsl --import UbuntuLive C:\WSL\Live\UbuntuLive C:\WSL\Base\ubuntu-base.tar --version 2
    wsl -d UbuntuLive
    wsl --terminate UbuntuLive
    wsl --unregister UbuntuLive
    rmdir /S /Q C:\WSL\Live\UbuntuLive
