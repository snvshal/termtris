#!/bin/sh

set -e

REPO="snvshal/termtris"
BINARY_NAME="termtris"

detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "macos";;
        MINGW*|MSYS*|CYGWIN*) echo "windows";;
        *)          echo "unknown";;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64)    echo "x86_64";;
        aarch64|arm64) echo "aarch64";;
        *)         echo "x86_64";;
    esac
}

detect_suffix() {
    OS="$1"
    case "$OS" in
        linux)     echo "unknown-linux-gnu";;
        macos)     echo "apple-darwin";;
        windows)   echo "pc-windows-msvc";;
    esac
}

get_download_url() {
    OS="$1"
    ARCH="$2"
    SUFFIX="$3"

    TAG=$(curl -sL https://api.github.com/repos/${REPO}/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')

    if [ -z "$TAG" ]; then
        echo "Error: Could not fetch latest release" >&2
        exit 1
    fi

    EXT=".tar.gz"
    if [ "$OS" = "windows" ]; then
        EXT=".zip"
    fi

    FILENAME="${BINARY_NAME}-v${TAG}-${ARCH}-${SUFFIX}${EXT}"
    echo "https://github.com/${REPO}/releases/download/v${TAG}/${FILENAME}"
}

install() {
    OS=$(detect_os)
    ARCH=$(detect_arch)
    SUFFIX=$(detect_suffix "$OS")

    if [ "$OS" = "unknown" ]; then
        echo "Error: Unsupported operating system" >&2
        exit 1
    fi

    echo "Detected: $OS ($ARCH)"

    URL=$(get_download_url "$OS" "$ARCH" "$SUFFIX")
    echo "Downloading: $URL"

    TEMP_DIR=$(mktemp -d)
    ARCHIVE="${TEMP_DIR}/archive.tar.gz"
    curl -L "$URL" -o "$ARCHIVE"

    if [ ! -s "$ARCHIVE" ]; then
        echo "Error: Download failed" >&2
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    EXTRACTED="${TEMP_DIR}/extracted"
    mkdir -p "$EXTRACTED"
    tar -xzf "$ARCHIVE" -C "$EXTRACTED"

    BINARY="${EXTRACTED}/${BINARY_NAME}"
    if [ ! -f "$BINARY" ]; then
        BINARY=$(find "$EXTRACTED" -type f -name "$BINARY_NAME*" -executable | head -1)
    fi

    if [ -z "$BINARY" ] || [ ! -f "$BINARY" ]; then
        echo "Error: Could not find binary in archive" >&2
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    chmod +x "$BINARY"

    if [ "$(id -u)" -ne 0 ]; then
        INSTALL_DIR="${HOME}/.local/bin"
        mkdir -p "$INSTALL_DIR"
        mv "$BINARY" "${INSTALL_DIR}/${BINARY_NAME}"
        echo "Installed to: ${INSTALL_DIR}/${BINARY_NAME}"

        if ! echo "$PATH" | grep -q ".local/bin"; then
            echo ""
            echo "Warning: ${INSTALL_DIR} is not in your PATH"
            echo "Add this to your shell profile:"
            echo "  export PATH=\"\${HOME}/.local/bin:\$PATH\""
        fi
    else
        mv "$BINARY" "/usr/local/bin/${BINARY_NAME}"
        echo "Installed to: /usr/local/bin/${BINARY_NAME}"
    fi

    rm -rf "$TEMP_DIR"
    echo "Done! Run 'termtris' to play."
}

for arg in "$@"; do
    case "$arg" in
        -h|--help)
            echo "termtris installer"
            echo ""
            echo "Usage: curl ... | sh"
            echo ""
            echo "Or download manually from: https://github.com/${REPO}/releases"
            exit
            ;;
    esac
done

install
