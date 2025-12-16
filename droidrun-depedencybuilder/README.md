# DroidRun Dependency Builder

A Python tool to download source archives from GitHub releases and extract them to the Termux `localsource` directory.

## Features

- Downloads source archives (zip, tar.gz, 7z) from GitHub releases
- Extracts archives automatically
- Copies extracted files to Termux home directory in `localsource` folder
- Supports latest release or specific release tags

## Installation

```bash
pip install -r requirements.txt
```

## Usage

```bash
python main.py --repo owner/repo --release latest --archive source.7z
```

### Arguments

- `--repo`: GitHub repository (e.g., `RiteshF7/droidrundepedency`)
- `--release`: Release tag (default: `latest`)
- `--archive`: Archive filename (default: `source.7z`)
- `--termux-home`: Termux home directory path (default: `/data/data/com.termux/files/home`)
- `--force`: Force re-download even if files exist

## Requirements

- Python 3.8+
- ADB (Android Debug Bridge) for copying files to Termux
- Connected Android device with Termux installed

