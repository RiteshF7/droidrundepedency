#!/data/data/com.termux/files/usr/bin/bash
# build-status.sh
# Track build progress and handle failures
# Supports resumable builds and progress reporting

set -e

STATUS_FILE="${BUILD_STATUS_FILE:-$HOME/wheels/build-status.json}"
REPORT_FILE="${BUILD_REPORT_FILE:-$HOME/wheels/build-report.json}"

# Initialize status file if it doesn't exist
init_status() {
    if [ ! -f "$STATUS_FILE" ]; then
        echo "{}" > "$STATUS_FILE"
    fi
}

# Mark package as built
mark_built() {
    local pkg_name="$1"
    init_status
    python3 <<PYTHON
import json
with open("$STATUS_FILE", "r") as f:
    data = json.load(f)
data["$pkg_name"] = {"status": "built", "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
with open("$STATUS_FILE", "w") as f:
    json.dump(data, f, indent=2)
PYTHON
}

# Mark package as failed
mark_failed() {
    local pkg_name="$1"
    local error_msg="${2:-unknown error}"
    init_status
    python3 <<PYTHON
import json
with open("$STATUS_FILE", "r") as f:
    data = json.load(f)
data["$pkg_name"] = {"status": "failed", "error": "$error_msg", "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
with open("$STATUS_FILE", "w") as f:
    json.dump(data, f, indent=2)
PYTHON
}

# Mark package as skipped
mark_skipped() {
    local pkg_name="$1"
    local reason="${2:-already built}"
    init_status
    python3 <<PYTHON
import json
with open("$STATUS_FILE", "r") as f:
    data = json.load(f)
data["$pkg_name"] = {"status": "skipped", "reason": "$reason", "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
with open("$STATUS_FILE", "w") as f:
    json.dump(data, f, indent=2)
PYTHON
}

# Check package status
get_status() {
    local pkg_name="$1"
    init_status
    python3 <<PYTHON
import json, sys
try:
    with open("$STATUS_FILE", "r") as f:
        data = json.load(f)
    pkg_data = data.get("$pkg_name", {})
    print(pkg_data.get("status", "pending"))
except:
    print("pending")
PYTHON
}

# Check if package is built
is_built() {
    local status=$(get_status "$1")
    [ "$status" = "built" ]
}

# Generate progress report
generate_report() {
    local manifest_file="${1:-$HOME/dependency-manifest.json}"
    
    if [ ! -f "$manifest_file" ]; then
        echo "Error: Manifest file not found: $manifest_file" >&2
        return 1
    fi
    
    init_status
    
    python3 <<PYTHON
import json
from datetime import datetime

# Load manifest
with open("$manifest_file", "r") as f:
    manifest = json.load(f)

# Load status
with open("$STATUS_FILE", "r") as f:
    status = json.load(f)

packages = manifest.get("packages", [])
total = len(packages)
built = sum(1 for pkg in packages if status.get(pkg["name"], {}).get("status") == "built")
failed = sum(1 for pkg in packages if status.get(pkg["name"], {}).get("status") == "failed")
skipped = sum(1 for pkg in packages if status.get(pkg["name"], {}).get("status") == "skipped")
pending = total - built - failed - skipped

report = {
    "generated_at": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    "summary": {
        "total": total,
        "built": built,
        "failed": failed,
        "skipped": skipped,
        "pending": pending,
        "progress_percent": round((built / total * 100) if total > 0 else 0, 2)
    },
    "packages": []
}

for pkg in packages:
    pkg_name = pkg["name"]
    pkg_status = status.get(pkg_name, {})
    report["packages"].append({
        "name": pkg_name,
        "version": pkg.get("version", "unknown"),
        "status": pkg_status.get("status", "pending"),
        "error": pkg_status.get("error"),
        "timestamp": pkg_status.get("timestamp")
    })

with open("$REPORT_FILE", "w") as f:
    json.dump(report, f, indent=2)

print(f"Report generated: $REPORT_FILE")
print(f"Total: {total}, Built: {built}, Failed: {failed}, Skipped: {skipped}, Pending: {pending}")
PYTHON
}

# Show progress
show_progress() {
    local manifest_file="${1:-$HOME/dependency-manifest.json}"
    
    if [ ! -f "$manifest_file" ]; then
        echo "Error: Manifest file not found: $manifest_file" >&2
        return 1
    fi
    
    init_status
    
    python3 <<PYTHON
import json

with open("$manifest_file", "r") as f:
    manifest = json.load(f)

with open("$STATUS_FILE", "r") as f:
    status = json.load(f)

packages = manifest.get("packages", [])
total = len(packages)
built = sum(1 for pkg in packages if status.get(pkg["name"], {}).get("status") == "built")
failed = sum(1 for pkg in packages if status.get(pkg["name"], {}).get("status") == "failed")

print(f"\nBuild Progress:")
print(f"  Total packages: {total}")
print(f"  Built: {built}")
print(f"  Failed: {failed}")
print(f"  Remaining: {total - built - failed}")
print(f"  Progress: {round((built / total * 100) if total > 0 else 0, 1)}%")
PYTHON
}

# Reset status (for retry)
reset_status() {
    local pkg_name="${1:-}"
    if [ -z "$pkg_name" ]; then
        # Reset all
        echo "{}" > "$STATUS_FILE"
        echo "All build status reset"
    else
        # Reset specific package
        init_status
        python3 <<PYTHON
import json
with open("$STATUS_FILE", "r") as f:
    data = json.load(f)
if "$pkg_name" in data:
    del data["$pkg_name"]
with open("$STATUS_FILE", "w") as f:
    json.dump(data, f, indent=2)
PYTHON
        echo "Status reset for $pkg_name"
    fi
}

# Main command handler
case "${1:-}" in
    mark-built)
        mark_built "$2"
        ;;
    mark-failed)
        mark_failed "$2" "${3:-}"
        ;;
    mark-skipped)
        mark_skipped "$2" "${3:-}"
        ;;
    get-status)
        get_status "$2"
        ;;
    is-built)
        is_built "$2" && echo "yes" || echo "no"
        ;;
    report)
        generate_report "${2:-}"
        ;;
    progress)
        show_progress "${2:-}"
        ;;
    reset)
        reset_status "${2:-}"
        ;;
    *)
        echo "Usage: build-status.sh {mark-built|mark-failed|mark-skipped|get-status|is-built|report|progress|reset} [package-name] [args...]"
        exit 1
        ;;
esac



