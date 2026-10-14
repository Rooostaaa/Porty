@echo off
rem Exporte Port Horizon V2 en APK debug (arm64) dans build\PortHorizonV2.apk. Fermer l'editeur Godot avant.
rem Paquet com.nadir.porthorizon.v2 : s'installe a cote de la V1 (com.nadir.porthorizon) sans l'ecraser.
rem Si un telephone est branche en USB (debogage active), ajouter "install" en argument pour l'installer directement.
if not exist "%~dp0build" mkdir "%~dp0build"
rem L'ancien APK est supprime d'abord : un export rate ne laisse pas un vieil APK passer pour le nouveau.
if exist "%~dp0build\PortHorizonV2.apk" del /q "%~dp0build\PortHorizonV2.apk"
"C:\Nadir\Godot\Godot.exe" --headless --path "%~dp0godot" --export-debug "Android" "%~dp0build\PortHorizonV2.apk"
if errorlevel 1 ( echo Echec de l'export. & pause & exit /b 1 )
if not exist "%~dp0build\PortHorizonV2.apk" ( echo Echec de l'export : APK absent. & pause & exit /b 1 )
echo APK pret : %~dp0build\PortHorizonV2.apk
if /i "%1"=="install" "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" install -r "%~dp0build\PortHorizonV2.apk"
pause
