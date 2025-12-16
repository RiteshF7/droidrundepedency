#!/usr/bin/env bash
# Script to upload sourceversion1.7z as a new GitHub release

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
GITHUB_REPO="RiteshF7/droidrundepedency"
RELEASE_TAG="sourceversion1"
RELEASE_NAME="Source Version 1"
ARCHIVE_FILE="depedencies/sourceversion1.7z"
RELEASE_NOTES="Source packages archive with all standardized source files (24 packages)"

# Check if archive exists
if [ ! -f "$ARCHIVE_FILE" ]; then
    echo -e "${RED}Error: Archive file not found: $ARCHIVE_FILE${NC}"
    exit 1
fi

# Check for GitHub token
if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo -e "${YELLOW}Warning: GITHUB_TOKEN not set${NC}"
    echo -e "${BLUE}Please set your GitHub token:${NC}"
    echo -e "${BLUE}  export GITHUB_TOKEN=your_token_here${NC}"
    echo -e "${BLUE}Or create a GitHub Personal Access Token with 'repo' scope${NC}"
    exit 1
fi

# Check for curl
if ! command -v curl >/dev/null 2>&1; then
    echo -e "${RED}Error: curl is required but not found${NC}"
    exit 1
fi

echo -e "${BLUE}Creating GitHub release: $RELEASE_TAG${NC}"

# Create release
RELEASE_RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$GITHUB_REPO/releases" \
    -d "{
        \"tag_name\": \"$RELEASE_TAG\",
        \"name\": \"$RELEASE_NAME\",
        \"body\": \"$RELEASE_NOTES\",
        \"draft\": false,
        \"prerelease\": false
    }")

# Check if release was created successfully
UPLOAD_URL=$(echo "$RELEASE_RESPONSE" | grep -o '"upload_url": "[^"]*' | cut -d'"' -f4)

if [ -z "$UPLOAD_URL" ]; then
    echo -e "${RED}Error: Failed to create release${NC}"
    ERROR_MSG=$(echo "$RELEASE_RESPONSE" | grep -o '"message": "[^"]*' | cut -d'"' -f4)
    if [ -n "$ERROR_MSG" ]; then
        echo -e "${RED}$ERROR_MSG${NC}"
    else
        echo "$RELEASE_RESPONSE"
    fi
    echo -e "${YELLOW}Note: Your GitHub token needs 'repo' scope with write access to releases${NC}"
    echo -e "${YELLOW}Create a new token at: https://github.com/settings/tokens${NC}"
    exit 1
fi

echo -e "${GREEN}Release created successfully${NC}"

# Extract upload URL template (remove {?name,label})
UPLOAD_URL=$(echo "$UPLOAD_URL" | sed 's/{.*$//')

# Upload asset
ARCHIVE_NAME=$(basename "$ARCHIVE_FILE")
ARCHIVE_SIZE=$(stat -f%z "$ARCHIVE_FILE" 2>/dev/null || stat -c%s "$ARCHIVE_FILE" 2>/dev/null || echo "unknown")

echo -e "${BLUE}Uploading archive: $ARCHIVE_NAME (${ARCHIVE_SIZE} bytes)${NC}"

UPLOAD_RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@$ARCHIVE_FILE" \
    "${UPLOAD_URL}?name=$ARCHIVE_NAME")

# Check if upload was successful
BROWSER_URL=$(echo "$UPLOAD_RESPONSE" | grep -o '"browser_download_url": "[^"]*' | cut -d'"' -f4)

if [ -z "$BROWSER_URL" ]; then
    echo -e "${RED}Error: Failed to upload asset${NC}"
    echo "$UPLOAD_RESPONSE" | grep -o '"message": "[^"]*' | cut -d'"' -f4 || echo "$UPLOAD_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ Upload successful!${NC}"
echo -e "${BLUE}Release URL: https://github.com/$GITHUB_REPO/releases/tag/$RELEASE_TAG${NC}"
echo -e "${BLUE}Download URL: $BROWSER_URL${NC}"

