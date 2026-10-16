param([Parameter(Mandatory=$true)][string] $SourceRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Source=(Resolve-Path $SourceRoot).Path
$Support=$PSScriptRoot
$Dist=Join-Path (Split-Path $Support -Parent) 'dist'
$Release=Join-Path $Dist 'Claude-Desktop-Windows-x64'
New-Item -ItemType Directory -Force -Path $Dist,$Release | Out-Null
$env:CSC_IDENTITY_AUTO_DISCOVERY='false'
$env:CI='true'
Push-Location $Source
try {
    & python "$Support/integrity.py" --source $Source --output "$Release/source-integrity.json" --stage before
    if($LASTEXITCODE -ne 0){throw 'Original source does not match the pinned commit.'}
    & npm ci --no-audit --no-fund
    if($LASTEXITCODE -ne 0){throw 'Locked dependency installation failed.'}
    & npm run type-check 2>&1 | Tee-Object -FilePath "$Release/type-check.txt"
    $TypeCheckExit=$LASTEXITCODE
    & npm run build-only
    if($LASTEXITCODE -ne 0){throw 'Original Vite build failed.'}
    $Generated=@(git diff --name-only)
    $Allowed=@('src/auto-imports.d.ts','src/components.d.ts')
    $Unexpected=@($Generated | Where-Object {$_ -notin $Allowed})
    if($Unexpected.Count -gt 0){throw "Unexpected generated source changes: $Unexpected"}
    foreach($File in $Generated){& git restore --source=HEAD -- $File;if($LASTEXITCODE -ne 0){throw 'Failed to restore generated type declarations.'}}
    & python "$Support/integrity.py" --source $Source --output "$Release/source-integrity.json" --stage before-packaging
    if($LASTEXITCODE -ne 0){throw 'Application source changed before packaging.'}
    & node "$Support/pack-config.cjs" $Source "$Support/electron-builder.runtime.json" "$Release/packaging-config-report.json"
    if($LASTEXITCODE -ne 0){throw 'External packaging configuration generation failed.'}
    & "$Source/node_modules/.bin/electron-builder.cmd" --win nsis zip --x64 --publish never --config "$Support/electron-builder.runtime.json"
    if($LASTEXITCODE -ne 0){throw 'Windows packaging failed.'}
    $Bundle=Join-Path $Source 'dist-client/win-unpacked'
    & node "$Support/verify-package.cjs" $Source $Bundle "$Release/source-integrity.json"
    if($LASTEXITCODE -ne 0){throw 'Packaged application sources differ or assets are missing.'}
    & npm install --prefix "$Support/tooling" --no-package-lock --no-audit --no-fund 'playwright@1.55.0'
    if($LASTEXITCODE -ne 0){throw 'Runtime verification tool installation failed.'}
    $env:NODE_PATH=Join-Path $Support 'tooling/node_modules'
    & node "$Support/verify-windows.cjs" "$Bundle/Claude-Desktop.exe" "$Release/windows-runtime-check.json" "$Dist/qa"
    if($LASTEXITCODE -ne 0){throw 'Actual Windows application runtime verification failed.'}
    & python "$Support/integrity.py" --source $Source --output "$Release/source-integrity-final.json" --stage after-build
    if($LASTEXITCODE -ne 0){throw 'Original source bytes changed during the build.'}
    Copy-Item "$Source/dist-client/Claude-Desktop-setup-1.0.0.exe" "$Release/Claude-Desktop-setup-1.0.0.exe"
    Copy-Item "$Source/dist-client/Claude-Desktop-setup-1.0.0.zip" "$Release/Claude-Desktop-1.0.0-Windows-x64.zip"
    Copy-Item "$Source/LICENSE" "$Release/LICENSE.txt"
    & git archive --format=zip --prefix=Claude-Desktop-original-source/ --output="$Release/Claude-Desktop-original-source-85cb591e.zip" HEAD
    if($LASTEXITCODE -ne 0){throw 'Original source archive failed.'}
    $Result=@{source_commit='85cb591eae2d4330198957ada16545621973581b';application_source_changed=$false;lockfile_changed=$false;electron='25.3.1';node=(node --version);type_check_exit_code=$TypeCheckExit;vite_build_succeeded=$true;windows_packaging_succeeded=$true;generated_type_declarations_restored=$Generated;publishing='disabled'}
    $Result | ConvertTo-Json -Depth 5 | Set-Content "$Release/build-result.json" -Encoding utf8
    $Readme=@'
Claude-Desktop 1.0.0 - Windows x64

Forras: https://github.com/diablomike20/Claude-Desktop
Eredeti commit: 85cb591eae2d4330198957ada16545621973581b

Telepites: Claude-Desktop-setup-1.0.0.exe
Telepites nelkul: a Claude-Desktop-1.0.0-Windows-x64.zip TELJES tartalmat
csomagold ki egy uj mappaba, majd inditsd a Claude-Desktop.exe fajlt.
Az EXE melletti eroforrasok es DLL-ek is szuksegesek.
Kulon Node.js nem kell a futtatashoz.

A repo eredeti Electron-alkalmazasa a claude.ai weboldalat nyitja meg.
A sajat Claude-fiokoddal torteno bejelentkezes a programban vegezheto el.
Bejelentkezett chatelest a build ellenorzese nem vegzett.
Control Center: Preferences > Control Center, vagy Ctrl+Shift+P.
Teljes kilepes: Claude > Quit, vagy a talcaikon Quit parancsa.

Az alkalmazasforras es a package-lock.json valtozatlan. A Windows-build
kulon csomagolasi beallitasban a harom eredetileg szoveges NSIS logikai erteket
azonos jelentessel valodi logikai ertekke alakitja; a package.json fajlt nem irja at.
A rogzitett Electron 25.3.1 es a lockfile rogzitett fuggosegei kerultek bele.
A buildjelentesben a repo sajat tipusellenorzesenek eredmenye is szerepel.
A Windows-inditas, a helyi Control Center es IPC-konfiguracioolvasas ellenorizve.
A forrasegyezosegi jegyzokonyv es a valtozatlan eredeti forras-ZIP mellekelve.
'@
    Set-Content "$Release/OLVASS-EL.txt" $Readme -Encoding utf8
    Get-ChildItem $Release -File | ForEach-Object {"$((Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant())  $($_.Name)"} | Set-Content "$Release/SHA256SUMS.txt" -Encoding ascii
} finally {Pop-Location}
