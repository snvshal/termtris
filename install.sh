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
    LIBC="$2"
    case "$OS" in
        linux)
            if [ "$LIBC" = "musl" ]; then
                echo "unknown-linux-musl"
            else
                echo "unknown-linux-gnu"
            fi
            ;;
        macos)     echo "apple-darwin";;
        windows)   echo "pc-windows-msvc";;
    esac
}

detect_libc() {
    if [ "$(uname -s)" != "Linux" ]; then
        echo "none"
        return
    fi

    if [ -f /etc/alpine-release ]; then
        echo "musl"
        return
    fi

    if command -v ldd >/dev/null 2>&1; then
        if ldd --version 2>/dev/null | grep -qi musl; then
            echo "musl"
            return
        fi
    fi

    echo "gnu"
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

install_alpine_compat() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: Need root to install Alpine compatibility libs for gnu binary fallback" >&2
        exit 1
    fi

    if ! command -v apk >/dev/null 2>&1; then
        echo "Error: apk not found, cannot install Alpine compatibility libs" >&2
        exit 1
    fi

    apk add --no-cache libgcc libstdc++ gcompat
}

install() {
    OS=$(detect_os)
    ARCH=$(detect_arch)
    LIBC=$(detect_libc)
    SUFFIX=$(detect_suffix "$OS" "$LIBC")

    if [ "$OS" = "unknown" ]; then
        echo "Error: Unsupported operating system" >&2
        exit 1
    fi

    if [ "$OS" = "linux" ]; then
        echo "Detected: $OS ($ARCH, $LIBC)"
    else
        echo "Detected: $OS ($ARCH)"
    fi

    TEMP_DIR=$(mktemp -d)
    ARCHIVE="${TEMP_DIR}/archive.tar.gz"
    URL=$(get_download_url "$OS" "$ARCH" "$SUFFIX")
    echo "Downloading: $URL"
    if ! curl -fL "$URL" -o "$ARCHIVE"; then
        if [ "$OS" = "linux" ] && [ "$LIBC" = "musl" ] && [ "$SUFFIX" = "unknown-linux-musl" ]; then
            echo "musl artifact not found, falling back to glibc binary with Alpine compatibility libs..."
            install_alpine_compat
            SUFFIX="unknown-linux-gnu"
            URL=$(get_download_url "$OS" "$ARCH" "$SUFFIX")
            echo "Downloading: $URL"
            curl -fL "$URL" -o "$ARCHIVE"
        else
            echo "Error: Download failed" >&2
            rm -rf "$TEMP_DIR"
            exit 1
        fi
    fi

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
