/**
 * This script removes patchedDependencies and overrides from package.json files.
 *
 * The pnpm workspace uses patchedDependencies to apply source code patches to certain
 * dependencies. These patches are stored in a separate directory and referenced in the
 * lockfile. When we build the conda package, we don't include the patches directory,
 * which causes lockfile inconsistencies.
 *
 * To fix this, we:
 * 1. Remove patchedDependencies and overrides from all package.json files
 * 2. Delete all lockfiles (done in the build script)
 * 3. Let pnpm regenerate the lockfiles without patch references
 *
 * This script processes both the root package.json and all workspace package.json files
 * since any of them might contain patch references.
 */

const fs = require('fs')
const path = require('path')

/**
 * Recursively find all package.json files in the workspace.
 * @param {string} dir - Directory to search
 * @param {Array<string>} files - Accumulator for found files
 * @returns {Array<string>} - Array of package.json file paths
 */
function findPackageJsonFiles(dir, files = []) {
  const entries = fs.readdirSync(dir, { withFileTypes: true })

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name)

    if (entry.isDirectory()) {
      // Skip node_modules to avoid processing installed dependencies
      if (entry.name !== 'node_modules') {
        findPackageJsonFiles(fullPath, files)
      }
    } else if (entry.isFile() && entry.name === 'package.json') {
      files.push(fullPath)
    }
  }

  return files
}

// Update root package.json
const packageJson = JSON.parse(fs.readFileSync('./package.json'));
if (packageJson.pnpm) {
  // Remove patchedDependencies - references to source code patches
  delete packageJson.pnpm.patchedDependencies
  // Remove overrides - can contain references to patched versions
  delete packageJson.pnpm.overrides
}
if (packageJson.scripts) {
  // Remove prepare script - runs patch application during install
  delete packageJson.scripts.prepare
}
fs.writeFileSync('./package.json', JSON.stringify(packageJson, null, 2) + '\n')

// Update all workspace package.json files
// Filter out the root package.json since we already processed it
const workspacePackages = findPackageJsonFiles('.').filter(p => p !== './package.json' && p !== '.\\package.json')

workspacePackages.forEach(pkgPath => {
  try {
    const pkg = JSON.parse(fs.readFileSync(pkgPath));
    let modified = false

    if (pkg.pnpm) {
      // Remove patchedDependencies from workspace packages
      if (pkg.pnpm.patchedDependencies) {
        delete pkg.pnpm.patchedDependencies
        modified = true
      }
      // Remove overrides from workspace packages
      if (pkg.pnpm.overrides) {
        delete pkg.pnpm.overrides
        modified = true
      }
    }

    // Only write if we actually modified something to avoid unnecessary file updates
    if (modified) {
      fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n')
      console.log('Updated:', pkgPath)
    }
  } catch (e) {
    console.error('Error processing', pkgPath, ':', e.message)
  }
})

