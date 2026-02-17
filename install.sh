#!/bin/sh

set -e

REPO="snvshal/termtris"
BINARY_NAME="termtris"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_info() { printf "${CYAN}➜${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}✓${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}⚠${NC} %s\n" "$1"; }
log_error() { printf "${RED}✗${NC} %s\n" "$1"; }
log_header() {
    printf '\n'
    printf "${CYAN}"
    cat << 'EOF'
████████╗███████╗██████╗ ███╗   ███╗████████╗██████╗ ██╗███████╗
╚══██╔══╝██╔════╝██╔══██╗████╗ ████║╚══██╔══╝██╔══██╗██║██╔════╝
   ██║   █████╗  ██████╔╝██╔████╔██║   ██║   ██████╔╝██║███████╗
   ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║   ██║   ██╔══██╗██║╚════██║
   ██║   ███████╗██║  ██║██║ ╚═╝ ██║   ██║   ██║  ██║██║███████║
   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝╚══════╝
                                                              
EOF
    printf "${NC}"
}

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
            [ "$LIBC" = "musl" ] && echo "unknown-linux-musl" || echo "unknown-linux-gnu"
            ;;
        macos)     echo "apple-darwin";;
        windows)   echo "pc-windows-msvc";;
    esac
}

detect_libc() {
    [ "$(uname -s)" != "Linux" ] && echo "none" && return

    [ -f /etc/alpine-release ] && echo "musl" && return

    command -v ldd >/dev/null 2>&1 && ldd --version 2>/dev/null | grep -qi musl && echo "musl" && return

    echo "gnu"
}

get_download_url() {
    OS="$1"
    ARCH="$2"
    SUFFIX="$3"

    TAG=$(curl -sL "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')

    [ -z "$TAG" ] && log_error "Could not fetch latest release" && exit 1

    EXT=".tar.gz"
    [ "$OS" = "windows" ] && EXT=".zip"

    FILENAME="${BINARY_NAME}-v${TAG}-${ARCH}-${SUFFIX}${EXT}"
    echo "https://github.com/${REPO}/releases/download/v${TAG}/${FILENAME}"
}

install_alpine_compat() {
    [ "$(id -u)" -ne 0 ] && log_error "Need root to install Alpine compatibility libs" && exit 1
    command -v apk >/dev/null 2>&1 || { log_error "apk not found"; exit 1; }

    log_info "Installing Alpine compatibility libraries..."
    apk add --no-cache libgcc libstdc++ gcompat
}

install() {
    log_header

    OS=$(detect_os)
    ARCH=$(detect_arch)
    LIBC=$(detect_libc)
    SUFFIX=$(detect_suffix "$OS" "$LIBC")

    [ "$OS" = "unknown" ] && log_error "Unsupported operating system" && exit 1

    if [ "$OS" = "linux" ]; then
        log_info "Detected: $OS ($ARCH, $LIBC)"
    else
        log_info "Detected: $OS ($ARCH)"
    fi

    TEMP_DIR=$(mktemp -d)
    ARCHIVE="${TEMP_DIR}/archive.tar.gz"
    URL=$(get_download_url "$OS" "$ARCH" "$SUFFIX")

    log_info "Downloading latest release..."
    if ! curl -fL "$URL" -o "$ARCHIVE" 2>/dev/null; then
        if [ "$OS" = "linux" ] && [ "$LIBC" = "musl" ] && [ "$SUFFIX" = "unknown-linux-musl" ]; then
            log_warn "musl artifact not found, falling back to glibc binary..."
            install_alpine_compat
            SUFFIX="unknown-linux-gnu"
            URL=$(get_download_url "$OS" "$ARCH" "$SUFFIX")
            curl -fL "$URL" -o "$ARCHIVE" 2>/dev/null || { log_error "Download failed"; rm -rf "$TEMP_DIR"; exit 1; }
        else
            log_error "Download failed"
            rm -rf "$TEMP_DIR"
            exit 1
        fi
    fi

    [ ! -s "$ARCHIVE" ] && log_error "Download failed (empty file)" && rm -rf "$TEMP_DIR" && exit 1

    log_info "Extracting..."
    EXTRACTED="${TEMP_DIR}/extracted"
    mkdir -p "$EXTRACTED"
    tar -xzf "$ARCHIVE" -C "$EXTRACTED"

    BINARY="${EXTRACTED}/${BINARY_NAME}"
    [ ! -f "$BINARY" ] && BINARY=$(find "$EXTRACTED" -type f -name "$BINARY_NAME*" -executable | head -1)

    [ -z "$BINARY" ] || [ ! -f "$BINARY" ] && log_error "Could not find binary in archive" && rm -rf "$TEMP_DIR" && exit 1

    chmod +x "$BINARY"

    if [ "$(id -u)" -ne 0 ]; then
        INSTALL_DIR="${HOME}/.local/bin"
        mkdir -p "$INSTALL_DIR"
        mv "$BINARY" "${INSTALL_DIR}/${BINARY_NAME}"
        printf '\n'
        log_success "Installed to: ${INSTALL_DIR}/${BINARY_NAME}"

        if ! echo "$PATH" | grep -q ".local/bin"; then
            echo ""
            log_warn "${INSTALL_DIR} not in PATH"
            echo "  Add to shell profile: ${YELLOW}export PATH=\"\${HOME}/.local/bin:\$PATH\"${NC}"
        fi
    else
        mv "$BINARY" "/usr/local/bin/${BINARY_NAME}"
        log_success "Installed to: /usr/local/bin/${BINARY_NAME}"
    fi

    rm -rf "$TEMP_DIR"
    printf '\n'
    printf "${GREEN}✓${NC} Done! Run ${GREEN}${BOLD}termtris${NC} to play.\n"
    printf '\n'
    printf '\n'
}

for arg in "$@"; do
    case "$arg" in
        -h|--help)
            echo "termtris installer"
            echo ""
            echo "Usage: curl ... | sh"
            echo ""
            echo "Or download manually: https://github.com/${REPO}/releases"
            exit
            ;;
    esac
done

install
