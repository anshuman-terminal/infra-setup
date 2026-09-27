#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Terraform installer for Linux
# Installs Terraform under:
#   $HOME/.local/bin
#
# No sudo required.
#
# Current stable version verified from HashiCorp:
#   Terraform 1.16.4
# ============================================================

TERRAFORM_VERSION="1.16.4"

INSTALL_DIR="${HOME}/.local/bin"
TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "=============================================="
echo " Terraform Installation"
echo " Version : ${TERRAFORM_VERSION}"
echo " Install : ${INSTALL_DIR}"
echo "=============================================="

# ------------------------------------------------------------
# Check required commands
# ------------------------------------------------------------

for cmd in curl unzip sha256sum; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo
        echo "ERROR: Required command '$cmd' is not installed."
        echo
        echo "Please install it using your Linux distribution's package manager."
        exit 1
    fi
done

# ------------------------------------------------------------
# Detect CPU architecture
# ------------------------------------------------------------

ARCH="$(uname -m)"

case "$ARCH" in
    x86_64)
        TERRAFORM_ARCH="amd64"
        ;;
    aarch64|arm64)
        TERRAFORM_ARCH="arm64"
        ;;
    armv7l|armv6l)
        TERRAFORM_ARCH="arm"
        ;;
    s390x)
        TERRAFORM_ARCH="s390x"
        ;;
    i386|i686)
        TERRAFORM_ARCH="386"
        ;;
    *)
        echo "ERROR: Unsupported CPU architecture: $ARCH"
        exit 1
        ;;
esac

echo "Detected architecture: ${ARCH}"
echo "Terraform architecture: ${TERRAFORM_ARCH}"

# ------------------------------------------------------------
# Download Terraform
# ------------------------------------------------------------

ZIP_FILE="terraform_${TERRAFORM_VERSION}_linux_${TERRAFORM_ARCH}.zip"
BASE_URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}"

echo
echo "Downloading:"
echo "${BASE_URL}/${ZIP_FILE}"

curl -fL \
    "${BASE_URL}/${ZIP_FILE}" \
    -o "${TMP_DIR}/${ZIP_FILE}"

# ------------------------------------------------------------
# Download official SHA256SUMS
# ------------------------------------------------------------

echo
echo "Downloading checksum file..."

curl -fL \
    "${BASE_URL}/terraform_${TERRAFORM_VERSION}_SHA256SUMS" \
    -o "${TMP_DIR}/SHA256SUMS"

# ------------------------------------------------------------
# Verify checksum
# ------------------------------------------------------------

echo
echo "Verifying Terraform checksum..."

cd "$TMP_DIR"

EXPECTED_CHECKSUM="$(
    grep " ${ZIP_FILE}$" SHA256SUMS | awk '{print $1}'
)"

if [[ -z "$EXPECTED_CHECKSUM" ]]; then
    echo "ERROR: Could not find checksum for ${ZIP_FILE}"
    exit 1
fi

ACTUAL_CHECKSUM="$(
    sha256sum "${ZIP_FILE}" | awk '{print $1}'
)"

echo "Expected : ${EXPECTED_CHECKSUM}"
echo "Actual   : ${ACTUAL_CHECKSUM}"

if [[ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]]; then
    echo
    echo "ERROR: Checksum verification FAILED."
    exit 1
fi

echo "Checksum verification successful."

# ------------------------------------------------------------
# Extract
# ------------------------------------------------------------

unzip -oq "${ZIP_FILE}" -d "$TMP_DIR"

if [[ ! -f "${TMP_DIR}/terraform" ]]; then
    echo "ERROR: terraform binary was not found after extraction."
    exit 1
fi

# ------------------------------------------------------------
# Install
# ------------------------------------------------------------

mkdir -p "$INSTALL_DIR"

install -m 0755 \
    "${TMP_DIR}/terraform" \
    "${INSTALL_DIR}/terraform"

# ------------------------------------------------------------
# Configure PATH
# ------------------------------------------------------------

PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'

add_path_to_file() {
    local file="$1"

    if [[ -f "$file" ]] && ! grep -Fqx "$PATH_LINE" "$file"; then
        echo "$PATH_LINE" >> "$file"
        echo "Added PATH configuration to $file"
    fi
}

add_path_to_file "${HOME}/.bashrc"
add_path_to_file "${HOME}/.bash_profile"
add_path_to_file "${HOME}/.profile"

export PATH="${INSTALL_DIR}:${PATH}"

# ------------------------------------------------------------
# Verify
# ------------------------------------------------------------

echo
echo "=============================================="
echo "Terraform installed successfully"
echo "=============================================="

"${INSTALL_DIR}/terraform" version

echo
echo "Terraform location:"
command -v terraform || echo "${INSTALL_DIR}/terraform"

echo
echo "If 'terraform' isn't found in a new shell, run:"
echo
echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
echo
