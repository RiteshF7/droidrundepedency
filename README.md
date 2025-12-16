# DroidRun WHL Builder for Android/Termux

Automated tool to build Python wheel files for droidrun dependencies on Android devices using Termux.

## Purpose

Some Python packages don't have pre-built wheels for Android architectures. This project provides an automated solution to build wheels from source on Android devices using Termux.

## Quick Start

```bash
# On Android device with Termux
cd ~/droidrunBuild
./build.sh
```

## Project Structure

```
.
├── build.sh                    # Main build script
├── DEPENDENCIES.md            # Complete dependency information
├── depedencies/               # Source packages and wheels
│   ├── source/               # Source tarballs (.tar.gz, .zip)
│   │   └── build_wheels.py  # Python build script
│   └── wheels/              # Built wheel files
└── docs/                     # Documentation
    ├── BUILD.md             # Build instructions
    └── TROUBLESHOOTING.md   # Common errors and solutions
```

## Features

- ✅ Automatic dependency resolution
- ✅ Builds packages in correct order
- ✅ Applies Termux-specific fixes automatically
- ✅ Handles special cases (pandas, scikit-learn, grpcio, etc.)
- ✅ Memory-safe parallelism limits
- ✅ Comprehensive error handling

## Requirements

- Android device with Termux installed
- Internet connection (for downloading source packages)
- At least 2GB free storage
- System dependencies (see [BUILD.md](docs/BUILD.md))

## Documentation

- **[BUILD.md](docs/BUILD.md)** - Complete build instructions
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Common errors and solutions
- **[DEPENDENCIES.md](DEPENDENCIES.md)** - Detailed dependency information and fixes

## Usage

### Automated Build

```bash
./build.sh
```

### Manual Build

```bash
cd depedencies/source
python3 build_wheels.py --source-dir . --wheels-dir ~/wheels
```

### Using Built Wheels

```bash
pip install <package> --find-links ~/wheels --no-index
```

## What Gets Built

The script builds wheels for all droidrun dependencies that require compilation:

- numpy, scipy, pandas, scikit-learn
- pyarrow, psutil, grpcio, pillow
- jiter, tokenizers, safetensors
- cryptography, pydantic-core, orjson
- And more...

## Support

For issues and troubleshooting, see:
1. [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
2. [DEPENDENCIES.md](DEPENDENCIES.md)

## License

See repository license file.
