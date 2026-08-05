#!/bin/bash
set -e

MOD_ID="welcomenote"
VERSION_DIR="42"

# Copy preview image to workspace root (where SteamCMD expects it)
cp img/preview-512x512.png preview.png

# Stage content in Workshop directory structure
rm -rf content
mkdir -p "content/mods/${MOD_ID}/${VERSION_DIR}"
cp mod.info "content/mods/${MOD_ID}/"
cp mod.info "content/mods/${MOD_ID}/${VERSION_DIR}/"
cp -r ${VERSION_DIR}/media "content/mods/${MOD_ID}/${VERSION_DIR}/"

echo "Workshop content staged: content/mods/${MOD_ID}/${VERSION_DIR}/"
