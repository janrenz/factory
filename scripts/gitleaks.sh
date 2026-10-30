#!/usr/bin/env bash
# Secret scan for the factory. Pinned, checksum-verified gitleaks.
# Usage:  bash scripts/gitleaks.sh [dir]   (default: repo root; scans the full history of the checked-out branch)
# Exit 0 = clean, 1 = finding(s), 2 = could not run.
set -eu
VERSION=8.30.1
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)  ASSET=linux_x64;    SHA=551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb ;;
  Linux-aarch64) ASSET=linux_arm64;  SHA=e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080 ;;
  Darwin-arm64)  ASSET=darwin_arm64; SHA=b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5 ;;
  Darwin-x86_64) ASSET=darwin_x64;   SHA=dfe101a4db2255fc85120ac7f3d25e4342c3c20cf749f2c20a18081af1952709 ;;
  *) echo "gitleaks.sh: unsupported platform $(uname -s)-$(uname -m)" >&2; exit 2 ;;
esac
dir=${1:-$(git rev-parse --show-toplevel)}
cache="${XDG_CACHE_HOME:-$HOME/.cache}/factory/gitleaks-$VERSION"
bin="$cache/gitleaks"
if [ ! -x "$bin" ]; then
  mkdir -p "$cache"
  tgz="$cache/gitleaks.tar.gz"
  url="https://github.com/gitleaks/gitleaks/releases/download/v$VERSION/gitleaks_${VERSION}_$ASSET.tar.gz"
  # Retries: the network may drop (trains).
  curl -fsSL --retry 6 --retry-delay 5 --retry-all-errors -o "$tgz" "$url" || { echo "gitleaks.sh: download failed" >&2; exit 2; }
  if command -v sha256sum >/dev/null; then got=$(sha256sum "$tgz" | cut -d' ' -f1); else got=$(shasum -a 256 "$tgz" | cut -d' ' -f1); fi
  [ "$got" = "$SHA" ] || { rm -f "$tgz"; echo "gitleaks.sh: checksum mismatch" >&2; exit 2; }
  tar -xzf "$tgz" -C "$cache" gitleaks && rm -f "$tgz"
fi
cd "$dir"
# Only the checked-out branch's history (what CI sees on a push), not every ref of a shared repo.
"$bin" git --redact --no-banner -v --exit-code 1 --log-opts=HEAD . || exit 1
# Plus what is staged but not yet committed, so a scan before `git commit` sees new files too.
"$bin" git --pre-commit --staged --redact --no-banner -v --exit-code 1 . || exit 1
