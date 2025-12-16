#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Interactive Build Manager for droidrun dependencies
Consolidates all build scripts into a single interactive CLI tool

Usage:
    python build-interactive.py          # Interactive mode
    python build-interactive.py --auto   # Auto-run all steps without prompts
    python build-interactive.py -a       # Short form for auto mode
"""

import os
import sys
import subprocess
import shutil
from pathlib import Path
from typing import List, Optional, Dict
import json

# Fix Windows console encoding
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

# Colors for terminal output
class Colors:
    BLUE = '\033[0;34m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    CYAN = '\033[0;36m'
    BOLD = '\033[1m'
    NC = '\033[0m'  # No Color

def print_colored(text: str, color: str = Colors.NC):
    """Print colored text"""
    print(f"{color}{text}{Colors.NC}")

def print_header(text: str):
    """Print a header"""
    print_colored(f"\n{'='*60}", Colors.CYAN)
    print_colored(f"  {text}", Colors.CYAN + Colors.BOLD)
    print_colored(f"{'='*60}\n", Colors.CYAN)

def print_step(step_num: int, total: int, description: str):
    """Print step information"""
    print_colored(f"[{step_num}/{total}] {description}", Colors.BLUE)

def print_success(text: str):
    """Print success message"""
    print_colored(f"[OK] {text}", Colors.GREEN)

def print_error(text: str):
    """Print error message"""
    print_colored(f"[ERROR] {text}", Colors.RED)

def print_warning(text: str):
    """Print warning message"""
    print_colored(f"[WARNING] {text}", Colors.YELLOW)

def print_info(text: str):
    """Print info message"""
    print_colored(f"[INFO] {text}", Colors.BLUE)

def get_user_input(prompt: str, default: Optional[str] = None, choices: Optional[List[str]] = None) -> str:
    """Get user input with optional default and choices"""
    if choices:
        prompt += f" [{'/'.join(choices)}]"
    if default:
        prompt += f" (default: {default})"
    prompt += ": "
    
    while True:
        user_input = input(prompt).strip()
        if not user_input and default:
            return default
        if not user_input:
            continue
        if choices and user_input not in choices:
            print_error(f"Invalid choice. Please select from: {', '.join(choices)}")
            continue
        return user_input

def run_script(script_path: Path, description: str, check: bool = True) -> bool:
    """Run a shell script and return success status"""
    if not script_path.exists():
        print_error(f"Script not found: {script_path}")
        return False
    
    print_info(f"Running: {description}")
    print_colored(f"Command: {script_path}", Colors.CYAN)
    
    try:
        # Make script executable
        os.chmod(script_path, 0o755)
        
        # Run the script
        result = subprocess.run(
            [str(script_path)],
            cwd=script_path.parent,
            capture_output=False,
            text=True
        )
        
        if result.returncode == 0:
            print_success(f"Completed: {description}")
            return True
        else:
            if check:
                print_error(f"Failed: {description} (exit code: {result.returncode})")
            else:
                print_warning(f"Completed with warnings: {description}")
            return False
    except Exception as e:
        print_error(f"Error running {description}: {e}")
        return False

def check_prerequisites(scripts_dir: Path) -> Dict[str, bool]:
    """Check if all required scripts exist"""
    required_scripts = {
        "install-system-deps.sh": "Install system dependencies",
        "detect-wheels.sh": "Detect available wheels",
        "build-packages.sh": "Build packages from source",
        "export-wheels.sh": "Export built wheels"
    }
    
    status = {}
    print_info("Checking prerequisites...")
    for script_name, description in required_scripts.items():
        script_path = scripts_dir / script_name
        exists = script_path.exists()
        status[script_name] = exists
        if exists:
            print_success(f"{script_name} - {description}")
        else:
            print_error(f"{script_name} - MISSING")
    
    return status

def show_menu() -> str:
    """Show main menu and get user choice"""
    print_header("Droidrun Build Manager")
    print_colored("Select an option:", Colors.BOLD)
    print()
    print_colored("  1. Install System Dependencies + Download Sources", Colors.CYAN)
    print_colored("  2. Detect Available Wheels", Colors.CYAN)
    print_colored("  3. Build Packages from Source", Colors.CYAN)
    print_colored("  4. Export Wheels", Colors.CYAN)
    print_colored("  5. Run All Steps (Full Build) - Interactive", Colors.CYAN)
    print_colored("  6. Run All Steps (Auto Mode) - No Prompts", Colors.CYAN)
    print_colored("  7. Check Status", Colors.CYAN)
    print_colored("  8. View Logs", Colors.CYAN)
    print_colored("  9. Exit", Colors.CYAN)
    print()
    print_colored("  Tip: Run with --auto or -a flag for automatic execution", Colors.YELLOW)
    print()
    
    return get_user_input("Enter your choice", default="9", choices=["1", "2", "3", "4", "5", "6", "7", "8", "9"])

def get_build_status(scripts_dir: Path, config: Dict) -> Dict:
    """Get current build status"""
    status = {
        "sources_dir": config.get("SOURCES_DIR", ""),
        "wheels_dir": config.get("WHEELS_DIR", ""),
        "export_dir": config.get("EXPORT_DIR", ""),
        "sources_count": 0,
        "wheels_count": 0,
        "exported_wheels_count": 0,
        "need_build_file": False
    }
    
    # Check sources
    sources_dir = Path(status["sources_dir"])
    if sources_dir.exists():
        status["sources_count"] = len(list(sources_dir.glob("*.tar.gz"))) + len(list(sources_dir.glob("*.zip")))
    
    # Check wheels
    wheels_dir = Path(status["wheels_dir"])
    if wheels_dir.exists():
        status["wheels_count"] = len(list(wheels_dir.glob("*.whl")))
    
    # Check exported wheels
    export_dir = Path(status["export_dir"])
    if export_dir.exists():
        status["exported_wheels_count"] = len(list(export_dir.glob("*.whl")))
    
    # Check need_build.txt
    need_build_file = wheels_dir / "need_build.txt"
    status["need_build_file"] = need_build_file.exists()
    if status["need_build_file"]:
        with open(need_build_file, 'r') as f:
            status["need_build_packages"] = [line.strip() for line in f if line.strip()]
    else:
        status["need_build_packages"] = []
    
    return status

def show_status(scripts_dir: Path):
    """Show current build status"""
    print_header("Build Status")
    
    # Try to load config (we'll use environment or defaults)
    config = {
        "SOURCES_DIR": os.environ.get("SOURCES_DIR", "/data/data/com.termux/files/home/droidrunBuild/sources/source"),
        "WHEELS_DIR": os.environ.get("WHEELS_DIR", os.path.expanduser("~/wheels")),
        "EXPORT_DIR": os.environ.get("EXPORT_DIR", "")
    }
    
    # Try to detect architecture
    try:
        result = subprocess.run(["uname", "-m"], capture_output=True, text=True)
        arch = result.stdout.strip()
        if not config["EXPORT_DIR"]:
            project_root = scripts_dir.parent.parent
            config["EXPORT_DIR"] = str(project_root / f"wheels_{arch}")
    except:
        pass
    
    status = get_build_status(scripts_dir, config)
    
    print_colored("Directories:", Colors.BOLD)
    print(f"  Sources: {status['sources_dir']}")
    print(f"  Wheels: {status['wheels_dir']}")
    print(f"  Export: {status['export_dir']}")
    print()
    
    print_colored("File Counts:", Colors.BOLD)
    print(f"  Source files: {status['sources_count']}")
    print(f"  Built wheels: {status['wheels_count']}")
    print(f"  Exported wheels: {status['exported_wheels_count']}")
    print()
    
    if status['need_build_file']:
        print_colored(f"Packages needing build: {len(status['need_build_packages'])}", Colors.YELLOW)
        if status['need_build_packages']:
            print("  " + ", ".join(status['need_build_packages'][:10]))
            if len(status['need_build_packages']) > 10:
                print(f"  ... and {len(status['need_build_packages']) - 10} more")
    else:
        print_warning("need_build.txt not found. Run 'Detect Available Wheels' first.")
    
    print()

def view_logs(scripts_dir: Path):
    """View build logs"""
    print_header("View Logs")
    
    wheels_dir = Path(os.environ.get("WHEELS_DIR", os.path.expanduser("~/wheels")))
    log_file = wheels_dir / "build-all-wheels.log"
    
    if not log_file.exists():
        print_warning(f"Log file not found: {log_file}")
        return
    
    print_info(f"Log file: {log_file}")
    print_colored("Last 50 lines:\n", Colors.CYAN)
    
    try:
        with open(log_file, 'r') as f:
            lines = f.readlines()
            for line in lines[-50:]:
                print(line.rstrip())
    except Exception as e:
        print_error(f"Error reading log file: {e}")

def run_full_build(scripts_dir: Path):
    """Run all build steps sequentially"""
    print_header("Running Full Build")
    
    steps = [
        ("install-system-deps.sh", "Step 1: Install System Dependencies + Download Sources", True),
        ("detect-wheels.sh", "Step 2: Detect Available Wheels", True),
        ("build-packages.sh", "Step 3: Build Packages from Source", False),  # Don't fail on build errors
        ("export-wheels.sh", "Step 4: Export Wheels", True),
    ]
    
    for i, (script_name, description, required) in enumerate(steps, 1):
        script_path = scripts_dir / script_name
        print_step(i, len(steps), description)
        
        if not script_path.exists():
            print_error(f"Script not found: {script_name}")
            if required:
                print_error("Required step failed. Aborting.")
                return False
            continue
        
        success = run_script(script_path, description, check=required)
        
        if not success and required:
            print_error("Required step failed. Aborting.")
            return False
        
        # Ask user if they want to continue after each step
        if i < len(steps):
            continue_choice = get_user_input(
                f"Continue to next step?",
                default="y",
                choices=["y", "n"]
            )
            if continue_choice.lower() != "y":
                print_warning("Build interrupted by user.")
                return False
    
    print_header("Build Complete!")
    print_success("All steps completed successfully!")
    return True

def run_auto_build(scripts_dir: Path):
    """Run all build steps automatically without user input"""
    print_header("Auto Build Mode - Running All Steps Sequentially")
    print_warning("This will run all steps automatically without prompts")
    print()
    
    steps = [
        ("install-system-deps.sh", "Step 1: Install System Dependencies + Download Sources", True),
        ("detect-wheels.sh", "Step 2: Detect Available Wheels", True),
        ("build-packages.sh", "Step 3: Build Packages from Source", False),  # Don't fail on build errors
        ("export-wheels.sh", "Step 4: Export Wheels", True),
    ]
    
    for i, (script_name, description, required) in enumerate(steps, 1):
        script_path = scripts_dir / script_name
        print_step(i, len(steps), description)
        
        if not script_path.exists():
            print_error(f"Script not found: {script_name}")
            if required:
                print_error("Required step failed. Aborting.")
                return False
            continue
        
        success = run_script(script_path, description, check=required)
        
        if not success and required:
            print_error("Required step failed. Aborting.")
            return False
        
        # Small delay between steps for readability
        import time
        if i < len(steps):
            time.sleep(1)
    
    print_header("Auto Build Complete!")
    print_success("All steps completed!")
    return True

def main():
    """Main function"""
    # Get script directory
    script_dir = Path(__file__).parent.resolve()
    scripts_dir = script_dir  # build/ directory
    
    # Check for auto-run mode
    if len(sys.argv) > 1 and sys.argv[1] in ["--auto", "-a", "auto"]:
        # Auto-run mode - execute all steps without prompts
        prerequisites = check_prerequisites(scripts_dir)
        if not all(prerequisites.values()):
            print_error("Some required scripts are missing. Please check the build/ directory.")
            missing = [name for name, exists in prerequisites.items() if not exists]
            print_error(f"Missing: {', '.join(missing)}")
            return 1
        
        print_success("All prerequisites found!")
        print()
        return 0 if run_auto_build(scripts_dir) else 1
    
    # Check prerequisites
    prerequisites = check_prerequisites(scripts_dir)
    if not all(prerequisites.values()):
        print_error("Some required scripts are missing. Please check the build/ directory.")
        missing = [name for name, exists in prerequisites.items() if not exists]
        print_error(f"Missing: {', '.join(missing)}")
        return 1
    
    print_success("All prerequisites found!")
    print()
    
    # Main loop
    while True:
        choice = show_menu()
        
        if choice == "1":
            print_header("Install System Dependencies + Download Sources")
            script_path = scripts_dir / "install-system-deps.sh"
            run_script(script_path, "Install system dependencies and download sources")
            
        elif choice == "2":
            print_header("Detect Available Wheels")
            script_path = scripts_dir / "detect-wheels.sh"
            run_script(script_path, "Detect available wheels from pip")
            
        elif choice == "3":
            print_header("Build Packages from Source")
            script_path = scripts_dir / "build-packages.sh"
            run_script(script_path, "Build packages from source", check=False)
            
        elif choice == "4":
            print_header("Export Wheels")
            script_path = scripts_dir / "export-wheels.sh"
            run_script(script_path, "Export built wheels")
            
        elif choice == "5":
            run_full_build(scripts_dir)
            
        elif choice == "6":
            run_auto_build(scripts_dir)
            
        elif choice == "7":
            show_status(scripts_dir)
            
        elif choice == "8":
            view_logs(scripts_dir)
            
        elif choice == "9":
            print_colored("\nExiting...", Colors.CYAN)
            break
        
        # Ask if user wants to continue
        if choice != "9":
            print()
            continue_choice = get_user_input(
                "Return to main menu?",
                default="y",
                choices=["y", "n"]
            )
            if continue_choice.lower() != "y":
                break
    
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print_colored("\n\nInterrupted by user. Exiting...", Colors.YELLOW)
        sys.exit(1)
    except Exception as e:
        print_error(f"Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

