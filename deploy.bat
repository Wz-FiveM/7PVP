@echo off
rem Met a jour la resource 7PVP sur le VPS depuis GitHub. Options : -Redemarrer -Apercu -Restaurer -Force (voir tools\deploy-vps.ps1)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\deploy-vps.ps1" %*
set code=%errorlevel%
rem Sans option (double-clic) : garde la fenetre ouverte pour lire le resultat
if "%~1"=="" pause
exit /b %code%
