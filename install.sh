#!/usr/bin/env bash
# Loop Commander — install.sh
# https://github.com/anthropics/loop-commander
#
# Installs the Loop Commander CLI binaries and macOS app from GitHub Releases.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/anthropics/loop-commander/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/anthropics/loop-commander/main/install.sh | bash -s -- --version v1.2.0
#   curl -fsSL https://raw.githubusercontent.com/anthropics/loop-commander/main/install.sh | bash -s -- --cli-only

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

REPO="anthropics/loop-commander"
GITHUB_API="https://api.github.com/repos/${REPO}/releases/latest"
GITHUB_RELEASES="https://github.com/${REPO}/releases/download"

BIN_DIR="${HOME}/.local/bin"
APP_DIR="${HOME}/Applications"

BINARIES=("loop-commander" "lc-runner" "lc")

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

VERSION=""
CLI_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --version=*)
            VERSION="${1#*=}"
            shift
            ;;
        --cli-only)
            CLI_ONLY=true
            shift
            ;;
        -h|--help)
            cat <<EOF
Loop Commander installer

Usage:
  install.sh [OPTIONS]

Options:
  --version <tag>   Install a specific release (e.g. v1.2.0). Default: latest.
  --cli-only        Install CLI binaries only; skip the .app bundle.
  -h, --help        Show this help and exit.
EOF
            exit 0
            ;;
        *)
            echo "error: unknown option: $1" >&2
            echo "Run with --help for usage." >&2
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info()    { printf "[install] %s\n" "$*"; }
success() { printf "[install] %s\n" "$*"; }
warn()    { printf "[install] warning: %s\n" "$*" >&2; }
die()     { printf "[install] error: %s\n" "$*" >&2; exit 1; }

require_cmd() {
    if ! command -v "$1" &>/dev/null; then
        die "required command not found: $1 — please install it and re-run."
    fi
}

# ---------------------------------------------------------------------------
# Platform checks
# ---------------------------------------------------------------------------

if [[ "$(uname -s)" != "Darwin" ]]; then
    die "Loop Commander requires macOS. Linux and Windows are not supported."
fi

ARCH="$(uname -m)"
if [[ "${ARCH}" != "arm64" ]]; then
    die "Loop Commander currently only provides pre-built binaries for Apple Silicon (arm64). \
Detected architecture: ${ARCH}. \
Please build from source: https://github.com/${REPO}#installation"
fi

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------

require_cmd curl
require_cmd tar
require_cmd unzip
require_cmd shasum

# ---------------------------------------------------------------------------
# Resolve version
# ---------------------------------------------------------------------------

if [[ -z "${VERSION}" ]]; then
    info "Fetching latest release version from GitHub..."
    VERSION="$(
        curl -fsSL "${GITHUB_API}" \
          -H "Accept: application/vnd.github+json" \
        | grep '"tag_name"' \
        | head -1 \
        | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/'
    )"
    if [[ -z "${VERSION}" ]]; then
        die "Could not determine latest release version. \
Check your internet connection or specify a version with --version."
    fi
fi

info "Installing Loop Commander ${VERSION}..."

# ---------------------------------------------------------------------------
# Build asset names
# ---------------------------------------------------------------------------

TARBALL="loop-commander-${VERSION}-darwin-arm64.tar.gz"
APP_ZIP="LoopCommander-${VERSION}.zip"
CHECKSUMS="checksums.txt"

TARBALL_URL="${GITHUB_RELEASES}/${VERSION}/${TARBALL}"
APP_ZIP_URL="${GITHUB_RELEASES}/${VERSION}/${APP_ZIP}"
CHECKSUMS_URL="${GITHUB_RELEASES}/${VERSION}/${CHECKSUMS}"

# ---------------------------------------------------------------------------
# Working directory
# ---------------------------------------------------------------------------

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# ---------------------------------------------------------------------------
# Download assets
# ---------------------------------------------------------------------------

info "Downloading CLI tarball..."
curl -fsSL --progress-bar -o "${TMP_DIR}/${TARBALL}" "${TARBALL_URL}" \
    || die "Failed to download ${TARBALL_URL}"

if [[ "${CLI_ONLY}" == "false" ]]; then
    info "Downloading macOS app bundle..."
    curl -fsSL --progress-bar -o "${TMP_DIR}/${APP_ZIP}" "${APP_ZIP_URL}" \
        || die "Failed to download ${APP_ZIP_URL}"
fi

info "Downloading checksums..."
curl -fsSL -o "${TMP_DIR}/${CHECKSUMS}" "${CHECKSUMS_URL}" \
    || die "Failed to download ${CHECKSUMS_URL}"

# ---------------------------------------------------------------------------
# Verify checksums
# ---------------------------------------------------------------------------

info "Verifying SHA256 checksums..."

pushd "${TMP_DIR}" > /dev/null

# shasum -c expects lines in "hash  filename" format. Filter to only the files
# we downloaded so we do not fail on entries we have not fetched.
VERIFY_FILES=("${TARBALL}")
if [[ "${CLI_ONLY}" == "false" ]]; then
    VERIFY_FILES+=("${APP_ZIP}")
fi

for asset in "${VERIFY_FILES[@]}"; do
    expected_line="$(grep "${asset}" "${CHECKSUMS}" || true)"
    if [[ -z "${expected_line}" ]]; then
        die "No checksum entry found for ${asset} in checksums.txt"
    fi
    printf '%s\n' "${expected_line}" | shasum -a 256 -c - \
        || die "Checksum verification failed for ${asset}. The download may be corrupted."
done

popd > /dev/null

success "Checksums verified."

# ---------------------------------------------------------------------------
# Install CLI binaries
# ---------------------------------------------------------------------------

info "Extracting CLI binaries..."
tar -xzf "${TMP_DIR}/${TARBALL}" -C "${TMP_DIR}"

# The tarball is expected to place binaries at the root or a single directory
# level. Find each binary regardless of the directory layout inside the archive.
mkdir -p "${BIN_DIR}"

for binary in "${BINARIES[@]}"; do
    binary_path="$(find "${TMP_DIR}" -type f -name "${binary}" | head -1)"
    if [[ -z "${binary_path}" ]]; then
        die "Binary '${binary}' not found in ${TARBALL}. The release archive may be malformed."
    fi
    chmod +x "${binary_path}"
    cp "${binary_path}" "${BIN_DIR}/${binary}"
    info "  Installed ${BIN_DIR}/${binary}"
done

success "CLI binaries installed to ${BIN_DIR}."

# ---------------------------------------------------------------------------
# Install macOS app bundle
# ---------------------------------------------------------------------------

if [[ "${CLI_ONLY}" == "false" ]]; then
    info "Installing Loop Commander.app to ${APP_DIR}..."
    mkdir -p "${APP_DIR}"

    # Remove prior installation to ensure a clean copy.
    if [[ -d "${APP_DIR}/Loop Commander.app" ]]; then
        info "  Removing previous installation of Loop Commander.app..."
        rm -rf "${APP_DIR}/Loop Commander.app"
    fi

    unzip -q "${TMP_DIR}/${APP_ZIP}" -d "${TMP_DIR}/app_unzip"

    APP_BUNDLE="$(find "${TMP_DIR}/app_unzip" -maxdepth 2 -name "Loop Commander.app" -type d | head -1)"
    if [[ -z "${APP_BUNDLE}" ]]; then
        die "'Loop Commander.app' not found inside ${APP_ZIP}. The release archive may be malformed."
    fi

    cp -R "${APP_BUNDLE}" "${APP_DIR}/Loop Commander.app"
    info "  Installed ${APP_DIR}/Loop Commander.app"
    success "macOS app installed to ${APP_DIR}."
fi

# ---------------------------------------------------------------------------
# PATH advisory
# ---------------------------------------------------------------------------

path_contains_bin_dir() {
    # Split PATH on colons and check each component.
    local dir
    while IFS= read -r -d ':' dir; do
        # Resolve ~ manually since PATH entries rarely expand it.
        dir="${dir/#\~/$HOME}"
        if [[ "${dir}" == "${BIN_DIR}" ]]; then
            return 0
        fi
    done <<< "${PATH}:"
    return 1
}

if ! path_contains_bin_dir; then
    SHELL_NAME="$(basename "${SHELL:-bash}")"
    case "${SHELL_NAME}" in
        zsh)  RC_FILE="${HOME}/.zshrc" ;;
        bash) RC_FILE="${HOME}/.bash_profile" ;;
        fish) RC_FILE="${HOME}/.config/fish/config.fish" ;;
        *)    RC_FILE="${HOME}/.profile" ;;
    esac

    warn "${BIN_DIR} is not in your PATH."
    warn "Add the following line to ${RC_FILE}:"
    warn ""
    warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    warn ""
    warn "Then reload your shell or run:"
    warn "  source ${RC_FILE}"
fi

# ---------------------------------------------------------------------------
# Success message
# ---------------------------------------------------------------------------

printf "\n"
printf "Loop Commander %s installed successfully.\n" "${VERSION}"
printf "\n"
printf "Next steps:\n"
printf "\n"
printf "  1. Start the daemon:\n"
printf "       loop-commander &\n"
printf "\n"
printf "  2. Verify the daemon is running:\n"
printf "       lc daemon status\n"
printf "\n"
printf "  3. Create your first task:\n"
printf "       lc add \\\\\n"
printf "         --name \"My First Task\" \\\\\n"
printf "         --command \"claude -p 'Review recent commits for issues.'\" \\\\\n"
printf "         --schedule \"0 9 * * 1-5\"\n"
printf "\n"

if [[ "${CLI_ONLY}" == "false" ]]; then
    printf "  4. Open the dashboard:\n"
    printf "       open \"~/Applications/Loop Commander.app\"\n"
    printf "\n"
fi

printf "Documentation: https://github.com/%s\n" "${REPO}"
printf "\n"
