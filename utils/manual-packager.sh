#!/bin/sh

set -o errexit
set -o nounset
set -o pipefail

# Minimal manual assembler for a Linux standalone bundle.
# Edit these variables to match your paths.
REPO_ROOT="$(cd "$(dirname "$0")/.."; pwd)"
BUILD_DIR="${REPO_ROOT}/dist/simula"
GODOT_BINARY="${REPO_ROOT}/submodules/godot/bin/godot.x11.opt.64"  # adjust
PROJECT_ROOT="${REPO_ROOT}" # project's res:// root (project.godot location)
PLUGIN_SO="${REPO_ROOT}/addons/godot-haskell-plugin/bin/x11/libgodot-haskell-plugin.so" # adjust

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/bin/x11"

echo "Copying Godot binary..."
cp -a "${GODOT_BINARY}" "${BUILD_DIR}/simula"
chmod +x "${BUILD_DIR}/simula"

echo "Copying project files..."
# copy project.godot + resources (exclude .git)
rsync -a --exclude='.git' "${PROJECT_ROOT}/" "${BUILD_DIR}/" --exclude 'dist' --exclude 'submodules/godot' --exclude 'result'

echo "Copying plugin native libs..."
mkdir -p "${BUILD_DIR}/bin/x11"
cp -a "${PLUGIN_SO}" "${BUILD_DIR}/bin/x11/" || echo "Warning: plugin .so not found, adjust PLUGIN_SO variable."

echo "Package built at ${BUILD_DIR}. Tarball:"
tar -czvf simula-manual-$(date +%Y%m%d).tar.gz -C "$(dirname "${BUILD_DIR}")" "$(basename "${BUILD_DIR}")"

echo "Done. Test by running: cd ${BUILD_DIR} && ./godot -m ./"
