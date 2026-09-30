# Roda a integração app + Emulator Suite (dev). Pré-requisito: emuladores de pé
# (firebase emulators:start --only auth,firestore,functions --project planly-dev-d8533)
# e um emulador/dispositivo Android ligado. Ver docs/testing/integracao-emulador.md
param(
  [string]$Device = 'emulator-5554',
  [string]$Test = 'integration_test/emulator_e2e_test.dart',
  [string[]]$ExtraArgs = @()
)
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$env:Path = "$env:Path;C:\dev\flutter\bin"
if (-not $env:ANDROID_HOME) { $env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk" }

# Seed (zera Auth/Firestore do emulador e recria o cenário com as Functions reais).
$env:NODE_NO_WARNINGS = '1'  # o Admin SDK tenta o metadata server do GCP e avisa (inofensivo)
$line = (node integration_test/seed/seed.mjs | Select-Object -Last 1)
$seed = $line | ConvertFrom-Json

flutter test $Test --flavor dev -d $Device $ExtraArgs `
  "--dart-define=SEED_FAMILY=$($seed.familyId)" `
  "--dart-define=SEED_H1=$($seed.h1)" `
  "--dart-define=SEED_H2=$($seed.h2)" `
  "--dart-define=SEED_ANA=$($seed.ana)" `
  "--dart-define=SEED_BETO=$($seed.beto)" `
  "--dart-define=SEED_FROZEN=$($seed.frozenFamily)" `
  "--dart-define=SEED_DELETING=$($seed.deletingFamily)"
exit $LASTEXITCODE
