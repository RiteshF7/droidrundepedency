# How to Create a droidrun .deb Package

## Overview

While Python packages are typically installed via `pip`, it's possible to create a `.deb` package for droidrun that:
1. Installs droidrun itself as a system package
2. Uses pip to install Python dependencies (via post-install script)
3. Provides system-level integration

## Why This Approach Works

Termux packages Python applications as `.deb` by:
- Installing the main package via pip during build
- Using a `postinst` script to install Python dependencies via pip after package installation
- Listing system dependencies (like `python`, `python-pip`) in the `.deb` control file

## Step-by-Step Guide

### 1. Create the Package Directory Structure

```bash
cd termux-packages/packages
mkdir -p droidrun
cd droidrun
```

### 2. Create `build.sh`

The build script should:

```bash
TERMUX_PKG_HOMEPAGE=https://github.com/droidrun/droidrun
TERMUX_PKG_DESCRIPTION="Droidrun - AI agent framework for Android/Termux"
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="1.0.0"
TERMUX_PKG_SRCURL=https://pypi.org/packages/source/d/droidrun/droidrun-${TERMUX_PKG_VERSION}.tar.gz
TERMUX_PKG_SHA256=""  # Get from PyPI

# System dependencies (Termux packages)
TERMUX_PKG_DEPENDS="python, python-pip, python-numpy, python-pandas, python-scipy, python-scikit-learn"

# Build settings
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_PLATFORM_INDEPENDENT=true
TERMUX_PKG_PYTHON_COMMON_DEPS="wheel, setuptools"

# Python dependencies installed via pip in postinst
TERMUX_PKG_PYTHON_TARGET_DEPS="'droidrun[google,anthropic,openai,deepseek,ollama,openrouter]'"

termux_step_make() {
	:
}

termux_step_make_install() {
	# Install droidrun package
	pip install . --prefix=$TERMUX_PREFIX --no-build-isolation --no-deps || \
	pip install "droidrun==${TERMUX_PKG_VERSION}" --prefix=$TERMUX_PREFIX --no-deps
}

termux_step_create_debscripts() {
	cat <<- EOF > ./postinst
	#!$TERMUX_PREFIX/bin/sh
	echo "Installing droidrun Python dependencies through pip..."
	pip3 install ${TERMUX_PKG_PYTHON_TARGET_DEPS//, / }
	EOF
}
```

### 3. Build the Package

```bash
cd /path/to/termux-packages
./build-package.sh droidrun
```

### 4. Install the .deb

```bash
dpkg -i droidrun_1.0.0_all.deb
```

## Key Points

### Why This Works Despite the "No pip packages" Policy

1. **Main Package is System-Installed**: The `.deb` installs droidrun itself as a system package
2. **Dependencies via pip**: Python dependencies are installed via pip in postinst (this is acceptable)
3. **System Integration**: Provides system-level integration (like command-line tools, service scripts)

### Limitations

1. **Dependency Management**: Python dependencies are still managed by pip, not dpkg
2. **Version Conflicts**: Python dependency versions might conflict with other packages
3. **Size**: The package will be large due to all dependencies
4. **Maintenance**: Need to update both .deb version and pip dependencies

### Alternative: Metapackage Approach

Instead of installing droidrun in the .deb, create a metapackage that:
- Only provides a wrapper script
- Installs everything via pip in postinst
- Acts as a convenience package

```bash
TERMUX_PKG_METAPACKAGE=true
TERMUX_PKG_DEPENDS="python, python-pip"

termux_step_create_debscripts() {
	cat <<- EOF > ./postinst
	#!$TERMUX_PREFIX/bin/sh
	echo "Installing droidrun and all dependencies..."
	pip3 install 'droidrun[google,anthropic,openai,deepseek,ollama,openrouter]'
	EOF
}
```

## Comparison: .deb vs pip

| Aspect | .deb Package | pip install |
|--------|-------------|-------------|
| **System Integration** | ✅ Better | ❌ Limited |
| **Dependency Management** | ⚠️ Mixed (system + pip) | ✅ Pure pip |
| **Version Control** | ⚠️ Complex | ✅ Simple |
| **Installation** | `pkg install droidrun` | `pip install droidrun` |
| **Updates** | `pkg upgrade` | `pip install --upgrade` |
| **Maintenance** | ⚠️ More complex | ✅ Easier |

## Recommendation

For droidrun specifically, **pip installation is recommended** because:
1. It's a Python application with complex Python dependencies
2. Version management is easier with pip
3. Dependency resolution works better
4. Less maintenance overhead

However, a `.deb` package makes sense if:
- You want system-level integration
- You need it available via `pkg install`
- You're creating a Termux repository package

## Example: Complete Package

See `termux-packages/packages/droidrun/build.sh` for a complete example.



