@echo on

:: Ensure the build environment's node is used first
set "PATH=%BUILD_PREFIX%\Scripts;%BUILD_PREFIX%;%PATH%"

md %LIBRARY_PREFIX%\share\pnpm
pushd %LIBRARY_PREFIX%\share\pnpm
md node_modules
:: Use npm from PATH (which now has BUILD_PREFIX first)
cmd /c "npm install pnpm@%PKG_VERSION%"
if errorlevel 1 exit 1
popd

pushd %LIBRARY_PREFIX%\bin
for %%c in (pnpm) do (
  echo @echo off >> %%c.bat
  echo "%LIBRARY_PREFIX%\share\pnpm\node_modules\.bin\%%c.cmd" %%* >> %%c.bat
)
popd

rmdir pnpm\artifacts\exe /s /q
if errorlevel 1 exit 1

:: Delete all lockfiles and cached state BEFORE modifying package.json
if exist pnpm-lock.yaml del pnpm-lock.yaml
:: Delete any workspace lockfiles
for /r %%i in (pnpm-lock.yaml) do (
    if exist "%%i" del "%%i"
)
if exist .pnpm-store rmdir /s /q .pnpm-store
if exist node_modules rmdir /s /q node_modules

node %RECIPE_DIR%\deletePatchedDependencies.js
if errorlevel 1 exit 1

:: When npx try to install pnpm it automatically tries to install fuse-native -> https://github.com/pnpm/pnpm/blob/v10.4.1/package.json#L119
:: fuse-native have dependency on fuse-shared-library -> https://github.com/pnpm/pnpm/blob/v10.4.1/pnpm-lock.yaml#L18713
:: fuse-shared-library is not currently supported on: win -> https://github.com/fuse-friends/fuse-shared-library/blob/master/index.js#L17
:: Skip installing optional dependencies for windows
@echo "## Installing prod dependencies"
:: Use npx from PATH and add --engine-strict=false to bypass Node.js version checks
:: Use --node-linker=hoisted on Windows to avoid symlink permission issues
cmd /c "npx pnpm@%PKG_VERSION% install --prod --no-optional --engine-strict=false --node-linker=hoisted"
if errorlevel 1 exit 1

@echo "## Generating ThirdPartyLicenses.txt"
:: Use npx from PATH
cmd /c "npx pnpm@%PKG_VERSION% licenses list --json | npx @quantco/pnpm-licenses generate-disclaimer --json-input "--filter=["""@pnpm/*"""]" --output-file=ThirdPartyLicenses.txt"
if errorlevel 1 exit 1
