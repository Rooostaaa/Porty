@echo off
rem Exporte Port Horizon pour Windows (release, x86_64, PCK embarque) dans build\windows\PortHorizon.exe.
rem Fermer l'editeur Godot avant. Modeles d'export Godot 4.7.1 requis (Editeur > Gerer les modeles d'export).
rem L'exe est autonome : le copier seul suffit. La sauvegarde du joueur va dans %APPDATA%\PortHorizonV2\.
if not exist "%~dp0build\windows" mkdir "%~dp0build\windows"
rem L'ancien exe est supprime d'abord : un export rate ne laisse pas un vieil exe passer pour le nouveau.
if exist "%~dp0build\windows\PortHorizon.exe" del /q "%~dp0build\windows\PortHorizon.exe"
"C:\Nadir\Godot\Godot.exe" --headless --path "%~dp0godot" --export-release "Windows Desktop" "%~dp0build\windows\PortHorizon.exe"
if errorlevel 1 ( echo Echec de l'export. & pause & exit /b 1 )
if not exist "%~dp0build\windows\PortHorizon.exe" ( echo Echec de l'export : exe absent. & pause & exit /b 1 )
echo Pret : %~dp0build\windows\PortHorizon.exe
pause
