#!/usr/bin/env bash
#
# Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.
#
# install.sh — Install the dart_skills_lint native binary.
#
# Usage (default repo + latest version):
#   curl -fsSL https://github.com/flutter/agent-plugins/releases/latest/download/install.sh | bash
#
# Pin a specific version or alternate repo:
#   curl -fsSL .../install.sh | REPO=other-org/other-repo VERSION=0.4.0-dev.1 bash
#
# Env vars:
#   REPO         GitHub owner/repo (default: flutter/agent-plugins).
#   VERSION      "latest" or a specific version like 0.4.0-dev.1 (default: latest).
#   INSTALL_DIR  Install destination (default: /usr/local/bin).

set -euo pipefail

REPO="${REPO:-flutter/agent-plugins}"
VERSION="${VERSION:-latest}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
BIN_NAME="dart_skills_lint"

err()  { echo "install.sh: error: $*" >&2; exit 1; }
info() { echo "install.sh: $*"; }

# --- Detect platform ---------------------------------------------------------
# Single source of truth: every "Supported: ..." message and the final
# platform check derive from this list, so adding a build target only
# requires touching one constant.
SUPPORTED_TARGETS="macos-arm64 macos-x64 linux-x64 linux-arm64"
err_unsupported() { err "$1. Supported platforms: ${SUPPORTED_TARGETS// /, }."; }

case "$(uname -s)" in
  Darwin) os="macos" ;;
  Linux)  os="linux" ;;
  *)      err_unsupported "unsupported OS '$(uname -s)'" ;;
esac

case "$(uname -m)" in
  arm64|aarch64) arch="arm64" ;;
  x86_64|amd64)  arch="x64" ;;
  *)             err_unsupported "unsupported architecture '$(uname -m)'" ;;
esac

target="${os}-${arch}"
case " $SUPPORTED_TARGETS " in
  *" $target "*) ;;
  *) err_unsupported "no published binary for platform '${target}'" ;;
esac

# --- Required tools ---------------------------------------------------------
require() { command -v "$1" >/dev/null 2>&1 || err "required tool '$1' not found on PATH."; }
require curl
require tar
require awk

if command -v sha256sum >/dev/null 2>&1; then
  shasum_cmd() { sha256sum "$@"; }
elif command -v shasum >/dev/null 2>&1; then
  shasum_cmd() { shasum -a 256 "$@"; }
else
  err "required tools 'sha256sum' or 'shasum' not found on PATH. Install one to verify the binary."
fi

# --- Resolve URLs ----------------------------------------------------------
if [ "$VERSION" = "latest" ]; then
  base_url="https://github.com/${REPO}/releases/latest/download"
else
  tag="dart_skills_lint-v${VERSION}"
  base_url="https://github.com/${REPO}/releases/download/${tag}"
fi
archive="${BIN_NAME}-${target}.tar.gz"
archive_url="${base_url}/${archive}"
sums_url="${base_url}/SHA256SUMS"

# --- Download into a tempdir, cleaned up on exit -----------------------------
tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/dart-skills-lint-install.XXXXXX")"
# Guard trap to prevent running rm -rf on empty/unbound tmpdir if trap triggers prematurely.
trap '[ -n "${tmpdir:-}" ] && rm -rf "$tmpdir"' EXIT INT TERM

info "downloading ${archive} from ${REPO} (${VERSION})"
curl -fsSL --retry 3 -o "${tmpdir}/${archive}" "$archive_url" \
  || err "could not download ${archive_url}"
curl -fsSL --retry 3 -o "${tmpdir}/SHA256SUMS" "$sums_url" \
  || err "could not download ${sums_url}"

# --- Verify SHA256 ----------------------------------------------------------
# Strip the optional leading '*' that `sha256sum -b` (binary mode) puts before
# the filename, so SHA256SUMS files from either text or binary mode work.
expected_sha="$(awk -v fname="$archive" '
  { sub(/^\*/, "", $2) }
  $2 == fname { print $1; exit }
' "${tmpdir}/SHA256SUMS")"
[ -n "$expected_sha" ] || err "no SHA256 entry for '${archive}' in SHA256SUMS."

actual_sha="$(shasum_cmd "${tmpdir}/${archive}" | awk '{print $1}')"
if [ "$expected_sha" != "$actual_sha" ]; then
  err "SHA256 mismatch for ${archive}. Expected ${expected_sha}, got ${actual_sha}."
fi
info "checksum verified"

# --- Extract ----------------------------------------------------------------
( cd "$tmpdir" && tar -xzf "$archive" )
extracted="${tmpdir}/${BIN_NAME}-${target}"
[ -x "$extracted" ] || err "extracted file ${extracted} not found or not executable."

# --- Install ----------------------------------------------------------------
install_path="${INSTALL_DIR}/${BIN_NAME}"

needs_sudo=0
if [ -d "$INSTALL_DIR" ]; then
  [ -w "$INSTALL_DIR" ] || needs_sudo=1
else
  parent="$(dirname "$INSTALL_DIR")"
  [ -d "$parent" ] && [ -w "$parent" ] || needs_sudo=1
fi

if [ "$needs_sudo" = "0" ]; then
  mkdir -p "$INSTALL_DIR"
  install -m 0755 "$extracted" "$install_path"
elif command -v sudo >/dev/null 2>&1; then
  info "${INSTALL_DIR} is not writable; using sudo"
  sudo mkdir -p "$INSTALL_DIR"
  sudo install -m 0755 "$extracted" "$install_path"
else
  err "${INSTALL_DIR} is not writable and 'sudo' is not available. Set INSTALL_DIR to a writable path and re-run."
fi

# --- macOS Gatekeeper note (preview binaries are unsigned) ------------------
# Print BEFORE the launch check so users see the workaround even if Gatekeeper
# blocks the --help invocation below.
if [ "$os" = "macos" ]; then
  cat <<EOF
install.sh: note: this preview binary is not yet code-signed. If you see a
Gatekeeper warning ("cannot be opened because the developer cannot be
verified"), run:
    xattr -d com.apple.quarantine "${install_path}"
This removes the quarantine flag macOS sets on downloaded binaries.
EOF
fi

# --- Verify the installed binary launches -----------------------------------
# On macOS the launch check is best-effort because Gatekeeper can block
# unsigned downloaded binaries on first launch; treat the failure as
# informational so the install isn't marked as failed when the only thing
# wrong is the quarantine flag.
if "$install_path" --help >/dev/null 2>&1; then
  info "installed ${BIN_NAME} → ${install_path}"
  info "run '${BIN_NAME} --help' to get started"
elif [ "$os" = "macos" ]; then
  info "installed ${BIN_NAME} → ${install_path}"
  info "launch check failed — likely Gatekeeper. See the note above to clear quarantine, then run '${BIN_NAME} --help'."
else
  err "installed binary at ${install_path} failed to launch."
fi
