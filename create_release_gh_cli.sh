#!/usr/bin/env bash
# Alternative script using GitHub CLI (gh) if available

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

GITHUB_REPO="RiteshF7/droidrundepedency"
RELEASE_TAG="sourceversion1"
RELEASE_NAME="Source Version 1"
ARCHIVE_FILE="depedencies/sourceversion1.7z"
RELEASE_NOTES="Source packages archive with all standardized source files (24 packages)

This archive contains 24 standardized source packages:
- numpy, scipy, pandas, scikit-learn
- jiter, pyarrow, psutil, grpcio, pillow
- tokenizers, safetensors, cryptography, pydantic-core, orjson
- and more...

All files are renamed to standardized names for easy recognition."

# Check if archive exists
if [ ! -f "$ARCHIVE_FILE" ]; then
    echo -e "${RED}Error: Archive file not found: $ARCHIVE_FILE${NC}"
    exit 1
fi

# Check for GitHub CLI
if ! command -v gh >/dev/null 2>&1; then
    echo -e "${YELLOW}GitHub CLI (gh) not found${NC}"
    echo -e "${BLUE}Installing GitHub CLI or using manual upload...${NC}"
    echo ""
    echo -e "${BLUE}Option 1: Install GitHub CLI${NC}"
    echo -e "${BLUE}  Windows: winget install GitHub.cli${NC}"
    echo -e "${BLUE}  Then run: gh auth login${NC}"
    echo ""
    echo -e "${BLUE}Option 2: Manual Upload${NC}"
    echo -e "${BLUE}  1. Go to: https://github.com/$GITHUB_REPO/releases/new${NC}"
    echo -e "${BLUE}  2. Tag: $RELEASE_TAG${NC}"
    echo -e "${BLUE}  3. Title: $RELEASE_NAME${NC}"
    echo -e "${BLUE}  4. Description: $RELEASE_NOTES${NC}"
    echo -e "${BLUE}  5. Upload: $ARCHIVE_FILE${NC}"
    echo ""
    echo -e "${BLUE}Archive location: $(pwd)/$ARCHIVE_FILE${NC}"
    echo -e "${BLUE}Size: $(ls -lh "$ARCHIVE_FILE" | awk '{print $5}')${NC}"
    exit 1
fi

# Check if authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo -e "${YELLOW}Not authenticated with GitHub CLI${NC}"
    echo -e "${BLUE}Running: gh auth login${NC}"
    gh auth login
fi

echo -e "${BLUE}Creating release: $RELEASE_TAG${NC}"

# Create release and upload asset
if gh release create "$RELEASE_TAG" \
    --repo "$GITHUB_REPO" \
    --title "$RELEASE_NAME" \
    --notes "$RELEASE_NOTES" \
    "$ARCHIVE_FILE"; then
    echo -e "${GREEN}✓ Release created successfully!${NC}"
    echo -e "${BLUE}Release URL: https://github.com/$GITHUB_REPO/releases/tag/$RELEASE_TAG${NC}"
else
    echo -e "${RED}Failed to create release${NC}"
    exit 1
fi

