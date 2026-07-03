#!/usr/bin/env bash
#
# Package LootG for distribution.
#
# Reads the version from LootG.toc and produces LootG-v<version>.zip
# containing a single top-level `LootG/` folder that extracts straight
# into Interface/AddOns/. The Ace3 libraries under Libs/ are bundled.
#
# Usage: bash release.sh
set -euo pipefail

ADDON="LootG"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if [ ! -f "$ROOT/$ADDON.toc" ]; then
    echo "error: expected $ADDON.toc at $ROOT" >&2
    exit 1
fi

VERSION="$(grep -E '^## Version:' "$ROOT/$ADDON.toc" | head -1 | sed -E 's/^## Version:[[:space:]]*//')"
if [ -z "$VERSION" ]; then
    echo "error: could not read '## Version' from $ADDON.toc" >&2
    exit 1
fi

ZIP="$ADDON-v$VERSION.zip"
STAGE="$(mktemp -d)"
DEST="$STAGE/$ADDON"
mkdir -p "$DEST"

# LootG has a flat repo layout — addon files sit at repo root alongside
# CI/docs/tests we don't ship. We rsync from $ROOT/ with an explicit
# exclude list, then re-include the addon icon.
rsync -a \
    --exclude '.git' \
    --exclude '.github' \
    --exclude '.gitignore' \
    --exclude '.claude' \
    --exclude '.agents' \
    --exclude '.superpowers' \
    --exclude 'CLAUDE.md' \
    --exclude 'AGENTS.md' \
    --exclude 'README*.md' \
    --exclude 'release.sh' \
    --exclude 'scripts' \
    --exclude 'tests' \
    --exclude 'docs' \
    --exclude '*.zip' \
    --exclude '.DS_Store' \
    --exclude '*.png' \
    --include 'icon.png' \
    "$ROOT/" "$DEST/"

# The --exclude '*.png' + --include 'icon.png' pair keeps the addon icon and
# drops the README screenshots (loot.png, income.png).
# We have to hand-copy icon.png back in because rsync applies the exclude
# before the include in this ordering.
if [ -f "$ROOT/icon.png" ]; then
    cp "$ROOT/icon.png" "$DEST/icon.png"
fi

rm -f "$ROOT/$ZIP"
( cd "$STAGE" && zip -r -q "$ROOT/$ZIP" "$ADDON" )
rm -rf "$STAGE"

echo "Created $ZIP (version $VERSION)"
