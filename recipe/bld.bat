@echo on

md %LIBRARY_PREFIX%\share\pnpm
pushd %LIBRARY_PREFIX%\share\pnpm
md node_modules
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
del pnpm-lock.yaml
if errorlevel 1 exit 1
node %RECIPE_DIR%\deletePatchedDependencies.js
if errorlevel 1 exit 1

:: When npx try to install pnpm it automatically tries to install fuse-native -> https://github.com/pnpm/pnpm/blob/v10.4.1/package.json#L119
:: fuse-native have dependency on fuse-shared-library -> https://github.com/pnpm/pnpm/blob/v10.4.1/pnpm-lock.yaml#L18713
:: fuse-shared-library is not currently supported on: win -> https://github.com/fuse-friends/fuse-shared-library/blob/master/index.js#L17
:: Skip installing optional dependencies for windows
@echo "## Installing prod dependencies"
cmd /c npx pnpm@%PKG_VERSION% install --prod --no-optional
if errorlevel 1 exit 1

@echo "## Generating ThirdPartyLicenses.txt"
cmd /c npx pnpm@%PKG_VERSION% licenses list --json | npx @quantco/pnpm-licenses generate-disclaimer --json-input "--filter=["""@pnpm/*"""]" --output-file=ThirdPartyLicenses.txt
if errorlevel 1 exit 1
