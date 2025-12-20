"""Common utilities and functions for droidrun installation phases."""

import os
import sys
import subprocess
import shutil
import logging
from pathlib import Path
from typing import Optional, List

# Color codes for terminal output
class Colors:
    GREEN = '\033[0;32m'
    BLUE = '\033[0;34m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    NC = '\033[0m'  # No Color

# Package name (can be changed for different Termux variants)
PACKAGE_NAME = os.environ.get("PACKAGE_NAME", "com.termux")

# Detect environment (Termux, WSL, or other)
IS_TERMUX = False
if os.environ.get("TERMUX_VERSION"):
    IS_TERMUX = True
elif Path("/data/data/com.termux/files/usr/bin/pkg").exists():
    IS_TERMUX = True

# Setup PREFIX
if not os.environ.get("PREFIX"):
    if IS_TERMUX:
        PREFIX = f"/data/data/{PACKAGE_NAME}/files/usr"
    else:
        PREFIX = "/usr"
else:
    PREFIX = os.environ["PREFIX"]

# Setup script directory
SCRIPT_DIR = Path(__file__).parent.absolute()

# Progress tracking and logging paths
HOME = Path.home()
PROGRESS_FILE = HOME / ".droidrun_install_progress"
ENV_FILE = HOME / ".droidrun_install_env"
LOG_FILE = HOME / ".droidrun_install.log"
ERROR_LOG_FILE = HOME / ".droidrun_install_errors.log"

# Initialize log files
LOG_FILE.touch()
ERROR_LOG_FILE.touch()

# Setup logging
logger = logging.getLogger("droidrun_installer")
logger.setLevel(logging.DEBUG)

# File handler for log file
file_handler = logging.FileHandler(LOG_FILE)
file_handler.setLevel(logging.DEBUG)
file_formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
file_handler.setFormatter(file_formatter)
logger.addHandler(file_handler)

# Console handler with colors
class ColoredFormatter(logging.Formatter):
    """Custom formatter that adds colors to log messages."""
    
    COLORS = {
        'DEBUG': Colors.BLUE,
        'INFO': Colors.BLUE,
        'WARNING': Colors.YELLOW,
        'ERROR': Colors.RED,
        'CRITICAL': Colors.RED,
    }
    
    def format(self, record):
        log_color = self.COLORS.get(record.levelname, Colors.NC)
        record.levelname = f"{log_color}{record.levelname}{Colors.NC}"
        return super().format(record)

console_handler = logging.StreamHandler(sys.stdout)
console_handler.setLevel(logging.INFO)
console_formatter = ColoredFormatter('%(levelname)s - %(message)s')
console_handler.setFormatter(console_formatter)
logger.addHandler(console_handler)


def log_info(msg: str) -> None:
    """Log info message."""
    logger.info(msg)
    print(f"{Colors.BLUE}[INFO]{Colors.NC} {msg}")


def log_success(msg: str) -> None:
    """Log success message."""
    logger.info(msg)
    print(f"{Colors.GREEN}[✓]{Colors.NC} {msg}")


def log_warning(msg: str) -> None:
    """Log warning message."""
    logger.warning(msg)
    print(f"{Colors.YELLOW}[⚠]{Colors.NC} {msg}")
    # Also write to error log
    with open(ERROR_LOG_FILE, 'a') as f:
        f.write(f"{msg}\n")


def log_error(msg: str) -> None:
    """Log error message."""
    logger.error(msg)
    print(f"{Colors.RED}[✗]{Colors.NC} {msg}", file=sys.stderr)
    # Also write to error log
    with open(ERROR_LOG_FILE, 'a') as f:
        f.write(f"{msg}\n")


def command_exists(cmd: str) -> bool:
    """Check if a command exists in PATH."""
    return shutil.which(cmd) is not None


def pkg_installed(pkg_name: str) -> bool:
    """Check if a system package is installed."""
    if IS_TERMUX:
        if not command_exists("pkg"):
            return False
        try:
            result = subprocess.run(
                ["pkg", "list-installed"],
                capture_output=True,
                text=True,
                check=False
            )
            return f"{pkg_name} " in result.stdout
        except Exception:
            return False
    else:
        # Non-Termux: check if command exists
        cmd_map = {
            "python": "python3",
            "python-pip": "pip",
            "rust": "rustc",
            "clang": "clang",
            "cmake": "cmake",
            "make": "make",
        }
        if pkg_name in cmd_map:
            return command_exists(cmd_map[pkg_name])
        return False


def python_pkg_installed(pkg_name: str, version_spec: Optional[str] = None) -> bool:
    """Check if a Python package is installed and satisfies version requirement."""
    # Normalize package name for import (replace dashes with underscores)
    import_name = pkg_name.replace('-', '_')
    
    # Try importing the package directly (fastest check)
    try:
        __import__(import_name)
        package_importable = True
    except ImportError:
        package_importable = False
    
    # If no version spec, just check if importable
    if not version_spec or version_spec == pkg_name:
        if package_importable:
            return True
    
    # Check version requirement using pip
    if version_spec and version_spec != pkg_name:
        # Check if version_spec contains version operators
        if any(op in version_spec for op in ['>=', '<=', '==', '!=', '<', '>']):
            try:
                # Use pip install --dry-run to check if requirement is satisfied
                result = subprocess.run(
                    [sys.executable, "-m", "pip", "install", "--dry-run", "--no-deps", version_spec],
                    capture_output=True,
                    text=True,
                    check=False
                )
                output = result.stdout + result.stderr
                if "Requirement already satisfied" in output:
                    return True
                if "Would install" in output or "Would upgrade" in output:
                    return False
                # If unclear, assume satisfied
                return True
            except Exception:
                pass
    
    # Fallback: Use pip show
    try:
        result = subprocess.run(
            [sys.executable, "-m", "pip", "show", pkg_name],
            capture_output=True,
            text=True,
            check=False
        )
        if result.returncode == 0:
            # If version spec provided, check it
            if version_spec and version_spec != pkg_name:
                if any(op in version_spec for op in ['>=', '<=', '==', '!=', '<', '>']):
                    # Use dry-run again for version check
                    result = subprocess.run(
                        [sys.executable, "-m", "pip", "install", "--dry-run", "--no-deps", version_spec],
                        capture_output=True,
                        text=True,
                        check=False
                    )
                    output = result.stdout + result.stderr
                    return "Requirement already satisfied" in output
            return True
    except Exception:
        pass
    
    return False


def run_command(cmd: List[str], check: bool = True, capture_output: bool = False, 
                quiet: bool = False) -> subprocess.CompletedProcess:
    """Run a shell command and return the result."""
    try:
        result = subprocess.run(
            cmd,
            check=check,
            capture_output=capture_output,
            text=True
        )
        if not quiet and not capture_output:
            # Output goes to stdout/stderr automatically
            pass
        return result
    except subprocess.CalledProcessError as e:
        if not quiet:
            log_error(f"Command failed: {' '.join(cmd)}")
            log_error(f"Exit code: {e.returncode}")
        raise


def is_phase_complete(phase: int) -> bool:
    """Check if a phase is marked as complete."""
    if not PROGRESS_FILE.exists():
        return False
    
    try:
        with open(PROGRESS_FILE, 'r') as f:
            content = f.read()
            return f"PHASE_{phase}_COMPLETE=" in content
    except Exception:
        return False


def should_skip_phase(phase: int) -> bool:
    """Check if phase should be skipped (respects FORCE_RERUN)."""
    # If FORCE_RERUN is set, don't skip
    if os.environ.get("FORCE_RERUN"):
        log_warning(f"FORCE_RERUN is set - Phase {phase} will be rerun even if previously completed")
        # Clear phase completion status
        if PROGRESS_FILE.exists():
            try:
                with open(PROGRESS_FILE, 'r') as f:
                    lines = f.readlines()
                with open(PROGRESS_FILE, 'w') as f:
                    for line in lines:
                        if not line.startswith(f"PHASE_{phase}_COMPLETE="):
                            f.write(line)
                log_info(f"Phase {phase} completion status cleared")
            except Exception:
                pass
        return False
    
    return is_phase_complete(phase)


def mark_phase_complete(phase: int) -> None:
    """Mark a phase as complete."""
    import time
    timestamp = int(time.time())
    
    # Read existing content
    lines = []
    if PROGRESS_FILE.exists():
        try:
            with open(PROGRESS_FILE, 'r') as f:
                lines = f.readlines()
        except Exception:
            pass
    
    # Remove existing entry for this phase
    lines = [line for line in lines if not line.startswith(f"PHASE_{phase}_COMPLETE=")]
    
    # Add new entry
    lines.append(f"PHASE_{phase}_COMPLETE={timestamp}\n")
    
    # Write back
    try:
        with open(PROGRESS_FILE, 'w') as f:
            f.writelines(lines)
        
        # Format timestamp
        try:
            from datetime import datetime
            formatted_date = datetime.fromtimestamp(timestamp).strftime("%Y-%m-%d %H:%M:%S")
        except Exception:
            formatted_date = str(timestamp)
        
        log_info(f"Progress saved: Phase {phase} completed at {formatted_date}")
    except Exception as e:
        log_error(f"Failed to save progress: {e}")


def save_env_vars() -> None:
    """Save environment variables to file."""
    env_vars = {
        "PREFIX": PREFIX,
        "WHEELS_DIR": os.environ.get("WHEELS_DIR", str(HOME / "wheels")),
        "SCRIPT_DIR": str(SCRIPT_DIR),
        "PACKAGE_NAME": PACKAGE_NAME,
        "CC": os.environ.get("CC", ""),
        "CXX": os.environ.get("CXX", ""),
        "CMAKE_PREFIX_PATH": os.environ.get("CMAKE_PREFIX_PATH", ""),
        "CMAKE_INCLUDE_PATH": os.environ.get("CMAKE_INCLUDE_PATH", ""),
        "TMPDIR": os.environ.get("TMPDIR", ""),
        "NINJAFLAGS": os.environ.get("NINJAFLAGS", ""),
        "MAKEFLAGS": os.environ.get("MAKEFLAGS", ""),
        "MAX_JOBS": os.environ.get("MAX_JOBS", ""),
        "LD_LIBRARY_PATH": os.environ.get("LD_LIBRARY_PATH", ""),
    }
    
    try:
        with open(ENV_FILE, 'w') as f:
            for key, value in env_vars.items():
                f.write(f'export {key}="{value}"\n')
        log_info(f"Environment variables saved to {ENV_FILE}")
    except Exception as e:
        log_error(f"Failed to save environment variables: {e}")


def load_env_vars() -> None:
    """Load environment variables from file."""
    if not ENV_FILE.exists():
        return
    
    try:
        with open(ENV_FILE, 'r') as f:
            for line in f:
                line = line.strip()
                if line.startswith("export "):
                    # Parse export KEY="VALUE"
                    line = line[7:]  # Remove "export "
                    if '=' in line:
                        key, value = line.split('=', 1)
                        # Remove quotes
                        value = value.strip('"\'')
                        os.environ[key] = value
        log_info(f"Environment variables loaded from {ENV_FILE}")
    except Exception as e:
        log_warning(f"Failed to load environment variables: {e}")


def setup_build_environment() -> None:
    """Setup build environment variables."""
    log_info("Setting up build environment...")
    
    # Set PREFIX
    os.environ["PREFIX"] = PREFIX
    
    # Set build parallelization based on available system memory
    try:
        if Path("/proc/meminfo").exists():
            with open("/proc/meminfo", 'r') as f:
                for line in f:
                    if line.startswith("MemTotal:"):
                        mem_kb = int(line.split()[1])
                        mem_mb = mem_kb // 1024
                        break
                else:
                    mem_mb = 0
        else:
            mem_mb = 0
    except Exception:
        mem_mb = 0
    
    if mem_mb >= 3500:
        jobs = 4
    elif mem_mb >= 2000:
        jobs = 2
    else:
        jobs = 1
    
    os.environ["NINJAFLAGS"] = f"-j{jobs}"
    os.environ["MAKEFLAGS"] = f"-j{jobs}"
    os.environ["MAX_JOBS"] = str(jobs)
    
    # CMAKE configuration
    os.environ["CMAKE_PREFIX_PATH"] = PREFIX
    os.environ["CMAKE_INCLUDE_PATH"] = f"{PREFIX}/include"
    
    # Compiler environment variables
    os.environ["CC"] = f"{PREFIX}/bin/clang"
    os.environ["CXX"] = f"{PREFIX}/bin/clang++"
    
    # Temporary directory
    tmpdir = HOME / "tmp"
    tmpdir.mkdir(exist_ok=True)
    os.environ["TMPDIR"] = str(tmpdir)
    
    # Ensure wheels directory exists
    wheels_dir = HOME / "wheels"
    wheels_dir.mkdir(exist_ok=True)
    os.environ["WHEELS_DIR"] = str(wheels_dir)
    
    log_success("Build environment configured")
    save_env_vars()


def init_logging() -> None:
    """Initialize logging system."""
    if not LOG_FILE.exists() or LOG_FILE.stat().st_size == 0:
        with open(LOG_FILE, 'a') as f:
            from datetime import datetime
            f.write(f"=== droidrun Installation Log - Started at {datetime.now()} ===\n")
    
    if not ERROR_LOG_FILE.exists() or ERROR_LOG_FILE.stat().st_size == 0:
        with open(ERROR_LOG_FILE, 'a') as f:
            from datetime import datetime
            f.write(f"=== Error Log - Started at {datetime.now()} ===\n")

