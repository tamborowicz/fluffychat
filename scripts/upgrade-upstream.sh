#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 tamborowicz (fork tooling)
# SPDX-License-Identifier: MIT
#
# Upgrade the FluffyChat fork to the current upstream main in one command:
# probe -> rebase -> static check -> release build -> APK verification -> publish.
#
# Usage:   ./scripts/upgrade-upstream.sh [--no-build] [--fast] [--branch terminal-skin]
#
#   --fast      skip "gradlew clean" before the build. Only safe when no Flutter
#               plugin changed version; a plugin AAR considered up-to-date across
#               a dependency bump produces "cannot find symbol <PluginClass>".
#
# Exit codes: 0 ok, 1 dirty tree, 2 rebase conflict, 3 analysis failed, 4 build failed.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

BRANCH="terminal-skin"
DO_BUILD=1
FAST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --no-build) DO_BUILD=0 ;;
    --fast) FAST=1 ;;
    --branch) shift; BRANCH="${1:?}" ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
  shift
done

PUBLISH_DIR="$HOME/www-apks"
ANALYZE_COPY="$HOME/.hermes/cache/scratch/fc-check"
APK="build/app/outputs/flutter-apk/app-release.apk"
export PATH="$HOME/flutter/bin:$HOME/.cargo/bin:$PATH"
export RUSTC="$HOME/.cargo/bin/rustc"
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
AAPT="$(ls "$ANDROID_HOME"/build-tools/*/aapt 2>/dev/null | tail -1)"
APKSIGNER="$(ls "$ANDROID_HOME"/build-tools/*/apksigner 2>/dev/null | tail -1)"

say() { printf '\n\033[1;33m== %s\033[0m\n' "$*"; }

# Files this fork patches; used only to warn which ones upstream touched.
FORK_FILES=(
  lib/config/app_config.dart lib/config/setting_keys.dart lib/config/themes.dart
  lib/pages/chat/chat.dart lib/pages/chat/chat_event_list.dart lib/pages/chat/chat_view.dart
  lib/pages/chat/events/html_message.dart lib/pages/chat/events/message.dart
  lib/pages/chat/events/message_content.dart lib/pages/chat/input_bar.dart
  lib/pages/chat_list/chat_list_view.dart lib/pages/settings_style
  lib/utils/code_highlight_theme.dart lib/widgets/fluffy_chat_app.dart
  lib/widgets/theme_builder.dart pubspec.yaml
)

say "1/6 working tree"
if [ -n "$(git status --porcelain)" ]; then
  echo "!! working tree is dirty - commit or stash first" >&2
  git status --short >&2
  exit 1
fi
echo "clean"

say "2/6 current branch + upstream"
git checkout -q "$BRANCH" || exit 1
BASE="$(git merge-base HEAD origin/main)"
BEFORE="$(git rev-parse --short HEAD)"
git fetch --filter=blob:none -q origin main || exit 1
AFTER_UP="$(git rev-parse --short origin/main)"
echo "branch      : $BRANCH ($BEFORE)"
echo "merge base  : $BASE"
echo "upstream    : $AFTER_UP  ($(git rev-list --count "$BASE"..origin/main) new commits)"
echo
echo "upstream touched these files that we also patch:"
TOUCHED="$(git diff --name-only "$BASE"..origin/main -- "${FORK_FILES[@]}" || true)"
if [ -z "$TOUCHED" ]; then echo "  (none - merge should be trivial)"; else echo "$TOUCHED" | sed 's/^/  /'; fi
echo
echo "dry run merge (merge-tree):"
if git merge-tree --write-tree origin/main HEAD >/tmp/fc-mergetree.out 2>&1; then
  echo "  clean"
else
  echo "  CONFLICTS:"; sed -n '1,20p' /tmp/fc-mergetree.out
fi

say "3/6 rebase onto origin/main"
if ! git rebase origin/main; then
  echo "!! rebase stopped - resolve, then: git rebase --continue (or --abort)" >&2
  exit 2
fi
NEW="$(git rev-parse --short HEAD)"
echo "now at $NEW ($(git rev-list --count "$BASE"..HEAD) fork commits)"

say "4/6 static check (on a copy, upstream analysis_options untouched)"
rm -rf "$ANALYZE_COPY"
mkdir -p "$ANALYZE_COPY"
rsync -a --exclude build --exclude .git --exclude .dart_tool ./ "$ANALYZE_COPY/"
python3 - "$ANALYZE_COPY/analysis_options.yaml" <<'PY'
import sys
p = sys.argv[1]
t = open(p).read().replace("plugins:\n  dart_code_linter: latest", "")
open(p, "w").write(t)
PY
cp .dart_tool/package_config.json "$ANALYZE_COPY/.dart_tool/" 2>/dev/null || true
if ! (cd "$ANALYZE_COPY" && dart analyze lib 2>&1 | tail -12 | tee /tmp/fc-analyze.out | grep -q "No issues found"); then
  echo "!! dart analyze reported issues:" >&2
  cat /tmp/fc-analyze.out >&2
  exit 3
fi
echo "No issues found!"

if [ "$DO_BUILD" -eq 0 ]; then
  say "done (build skipped)"
  echo "branch $BRANCH now at $NEW. Push with: git push --force-with-lease fork $BRANCH"
  exit 0
fi

say "5/6 release build"
(cd android && ./gradlew --stop >/dev/null 2>&1)
if [ "$FAST" -eq 0 ]; then
  # A plugin module can be considered up-to-date across a dependency bump, which
  # ships an empty AAR and breaks GeneratedPluginRegistrant with "cannot find
  # symbol <PluginClass>" (seen with livekit_client 2.13.1 -> 2.13.2). Clean is
  # the reliable fix and costs one full gradle rebuild.
  echo "gradlew clean (skip with --fast)"
  (cd android && ./gradlew clean -q >/dev/null 2>&1)
fi
if ! flutter build apk --release --target-platform android-arm64 2>&1 | tail -4; then
  echo "!! build failed" >&2
  exit 4
fi

say "6/6 verify + publish"
"$AAPT" dump badging "$APK" | head -1
"$APKSIGNER" verify --print-certs "$APK" 2>/dev/null | head -1
SHA="$(sha256sum "$APK" | cut -d' ' -f1)"
SIZE="$(stat -c %s "$APK")"
FCVER="$("$AAPT" dump badging "$APK" | head -1 | sed -n "s/.*versionName='\([^']*\)'.*/\1/p")"
TAG="$(git describe --tags --abbrev=0 origin/main 2>/dev/null || echo unknown)"
STAMP="$(date +%F)"
NAME="fluffychat-terminal-${TAG}-${STAMP}.apk"
mkdir -p "$PUBLISH_DIR"
cp "$APK" "$PUBLISH_DIR/fluffychat-terminal-skin.apk"
cp "$APK" "$PUBLISH_DIR/$NAME"
echo "sha256 : $SHA"
echo "bytes  : $SIZE"
echo "version: $FCVER (upstream tag $TAG)"
echo "served : http://192.168.43.249:8899/fluffychat-terminal-skin.apk"
echo "         http://192.168.43.249:8899/$NAME"

say "summary"
cat <<EOF
from $BEFORE to $NEW on $BRANCH, upstream $AFTER_UP ($TAG)
next steps:  git push --force-with-lease fork $BRANCH
rollback :  ~/www-apks/fluffychat-threads-before-skin.apk
EOF
