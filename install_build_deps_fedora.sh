#!/bin/bash
# Install dependencies for cross-compiling Python packages for Android on Fedora
# Skips Android SDK/NDK as they're being installed by Android Studio

set -e

echo "=========================================="
echo "Installing build dependencies for Android cross-compilation"
echo "=========================================="

# Update system first
echo "Updating system packages..."
sudo dnf update -y

# Core build tools
echo "Installing core build tools..."
sudo dnf install -y \
    gcc \
    gcc-c++ \
    clang \
    make \
    cmake \
    ninja-build \
    autoconf \
    automake \
    libtool \
    m4 \
    bison \
    flex \
    gawk \
    gettext \
    intltool \
    pkgconfig \
    pkgconf

# Archive and compression tools
echo "Installing archive tools..."
sudo dnf install -y \
    tar \
    unzip \
    zip \
    lzip \
    lz4 \
    zstd \
    xz \
    bzip2 \
    gzip

# Python and Python build tools
echo "Installing Python and build tools..."
sudo dnf install -y \
    python3 \
    python3-pip \
    python3-devel \
    python3-setuptools \
    python3-wheel

# Install Python packages globally
echo "Installing Python packages..."
sudo pip3 install --upgrade pip setuptools wheel build

# Rust (for Rust-based Python packages like orjson)
echo "Installing Rust..."
if ! command -v rustc &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    rustup default stable
    echo "Rust installed. Please run: source ~/.cargo/env"
else
    echo "Rust already installed"
fi

# Git and version control
echo "Installing Git..."
sudo dnf install -y git

# Documentation tools
echo "Installing documentation tools..."
sudo dnf install -y \
    asciidoc \
    help2man \
    groff \
    texinfo \
    xmlto

# Additional development libraries
echo "Installing development libraries..."
sudo dnf install -y \
    openssl-devel \
    zlib-devel \
    expat-devel \
    libffi-devel \
    ncurses-devel \
    readline-devel \
    sqlite-devel \
    bzip2-devel \
    xz-devel

# Utilities
echo "Installing utilities..."
sudo dnf install -y \
    curl \
    wget \
    gnupg2 \
    jq \
    patch \
    file \
    which \
    findutils \
    coreutils

# Additional tools that might be needed
echo "Installing additional build tools..."
sudo dnf install -y \
    scons \
    re2c \
    vala \
    gobject-introspection-devel \
    glib2-devel \
    gperf

# LLVM tools (needed for some packages)
echo "Installing LLVM tools..."
sudo dnf install -y \
    llvm \
    llvm-devel \
    clang-devel

# Java (for some build tools)
echo "Installing Java..."
sudo dnf install -y \
    java-17-openjdk \
    java-17-openjdk-devel

# Ruby (for some packages)
echo "Installing Ruby..."
sudo dnf install -y \
    ruby \
    ruby-devel

# Perl (for some build scripts)
echo "Installing Perl..."
sudo dnf install -y \
    perl \
    perl-devel

# Lua (for some packages)
echo "Installing Lua..."
sudo dnf install -y \
    lua \
    lua-devel

# Set up locale
echo "Setting up locale..."
sudo dnf install -y glibc-langpack-en
sudo localedef -i en_US -f UTF-8 en_US.UTF-8

echo ""
echo "=========================================="
echo "Installation complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. If Rust was just installed, run: source ~/.cargo/env"
echo "2. Verify installations:"
echo "   - python3 --version"
echo "   - gcc --version"
echo "   - rustc --version (if Rust was installed)"
echo "   - cmake --version"
echo ""
echo "Note: Android SDK and NDK are being installed separately via Android Studio"
echo ""

