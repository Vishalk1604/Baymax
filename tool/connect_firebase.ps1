# Connects this app to the real Firebase project and publishes the Firestore
# security rules. Run from anywhere: powershell -ExecutionPolicy Bypass -File tool\connect_firebase.ps1
param([string]$ProjectId = 'baymax-1c21f')
$ErrorActionPreference = 'Stop'

$env:Path = "C:\flutter\src\flutter\bin;$env:LOCALAPPDATA\Pub\Cache\bin;$env:APPDATA\npm;" + $env:Path
Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "== Installing FlutterFire CLI" -ForegroundColor Cyan
dart pub global activate flutterfire_cli
if ($LASTEXITCODE -ne 0) { throw 'flutterfire_cli install failed' }

Write-Host "== Registering the Android app in $ProjectId and writing lib/firebase_options.dart" -ForegroundColor Cyan
flutterfire configure --project=$ProjectId --platforms=android --yes
if ($LASTEXITCODE -ne 0) { throw 'flutterfire configure failed' }

Write-Host "== Publishing firestore.rules" -ForegroundColor Cyan
firebase deploy --only firestore:rules --project $ProjectId
if ($LASTEXITCODE -ne 0) { throw 'rules deploy failed (is Firestore created in the console?)' }

Write-Host "== Done: Firebase connected to $ProjectId" -ForegroundColor Green
