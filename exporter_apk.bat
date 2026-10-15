@echo off
setlocal
rem Exporte Port Horizon pour Android (arm64). Fermer l'editeur Godot avant.
rem   exporter_apk.bat            : APK de DEBUG (par defaut, cle de debug de Godot) -> build\PortHorizonV2.apk
rem   exporter_apk.bat release    : APK de RELEASE signe avec VOTRE keystore -> build\android\PortHorizon.apk
rem   ... install                 : installe ensuite l'APK sur le telephone branche en USB (debogage active)
rem Paquet com.nadir.porthorizon.v2 : s'installe a cote de la V1 (com.nadir.porthorizon) sans l'ecraser.
rem Debug et release ne sont pas signes par la meme cle : desinstaller l'un avant d'installer l'autre (la partie est perdue).
rem
rem Keystore de release (jamais dans le depot, voir docs\RELEASE.md) : le definir AVANT de lancer ce script
rem   set GODOT_ANDROID_KEYSTORE_RELEASE_PATH=C:\Nadir\cles\porthorizon.keystore
rem   set GODOT_ANDROID_KEYSTORE_RELEASE_USER=porthorizon
rem   set GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=...
rem (ou le renseigner une fois dans l'editeur : Projet > Exporter > Android Release > Keystore ; il est alors range dans
rem  godot\.godot\export_credentials.cfg, hors du depot).
set MODE=debug
set INSTALL=0
for %%A in (%*) do (
  if /i "%%A"=="release" set MODE=release
  if /i "%%A"=="install" set INSTALL=1
)
if "%MODE%"=="release" (
  set "PRESET=Android Release"
  set "APK=%~dp0build\android\PortHorizon.apk"
) else (
  set "PRESET=Android"
  set "APK=%~dp0build\PortHorizonV2.apk"
)
if not exist "%~dp0build\android" mkdir "%~dp0build\android"
rem L'ancien APK est supprime d'abord : un export rate ne laisse pas un vieil APK passer pour le nouveau.
if exist "%APK%" del /q "%APK%"
if "%MODE%"=="release" (
  "C:\Nadir\Godot\Godot.exe" --headless --path "%~dp0godot" --export-release "%PRESET%" "%APK%"
) else (
  "C:\Nadir\Godot\Godot.exe" --headless --path "%~dp0godot" --export-debug "%PRESET%" "%APK%"
)
if errorlevel 1 ( echo Echec de l'export. & pause & exit /b 1 )
if not exist "%APK%" ( echo Echec de l'export : APK absent. & pause & exit /b 1 )
echo APK %MODE% pret : %APK%
if "%INSTALL%"=="1" "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" install -r "%APK%"
pause
