#!/bin/bash
# Script to create a GitHub release and upload the wheels archive

REPO="RiteshF7/droidrundepedency"
FILE_PATH="depedencies/wheels/_x86_64_wheels.7z"
RELEASE_TAG="v1.0.0-wheels"
RELEASE_NAME="Pre-built Wheels for x86_64"
RELEASE_NOTES="Pre-built Python wheels for x86_64 architecture (Termux/Android). Contains all compiled dependencies needed for droidrun installation."

# Check if file exists
if [ ! -f "$FILE_PATH" ]; then
    echo "Error: File not found: $FILE_PATH"
    exit 1
fi

# Check for GitHub token
if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_TOKEN environment variable not set"
    echo "Please set it with: export GITHUB_TOKEN=your_token_here"
    echo "You can create a token at: https://github.com/settings/tokens"
    exit 1
fi

FILE_SIZE=$(stat -f%z "$FILE_PATH" 2>/dev/null || stat -c%s "$FILE_PATH" 2>/dev/null)
FILE_NAME=$(basename "$FILE_PATH")

echo "Creating release: $RELEASE_TAG"
echo "File: $FILE_NAME ($FILE_SIZE bytes)"

# Create release
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/$REPO/releases \
  -d "{
    \"tag_name\": \"$RELEASE_TAG\",
    \"name\": \"$RELEASE_NAME\",
    \"body\": \"$RELEASE_NOTES\",
    \"draft\": false,
    \"prerelease\": false
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "201" ]; then
    echo "Error creating release. HTTP code: $HTTP_CODE"
    echo "Response: $BODY"
    exit 1
fi

# Extract upload URL from response
UPLOAD_URL=$(echo "$BODY" | grep -o '"upload_url": "[^"]*' | cut -d'"' -f4 | sed 's/{?name,label}//')

if [ -z "$UPLOAD_URL" ]; then
    echo "Error: Could not extract upload URL from response"
    echo "Response: $BODY"
    exit 1
fi

echo "Release created successfully!"
echo "Upload URL: $UPLOAD_URL"
echo ""
echo "Uploading file: $FILE_NAME"

# Upload asset
UPLOAD_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Content-Type: application/x-7z-compressed" \
  --data-binary "@$FILE_PATH" \
  "$UPLOAD_URL?name=$FILE_NAME")

UPLOAD_HTTP_CODE=$(echo "$UPLOAD_RESPONSE" | tail -1)
UPLOAD_BODY=$(echo "$UPLOAD_RESPONSE" | sed '$d')

if [ "$UPLOAD_HTTP_CODE" != "201" ]; then
    echo "Error uploading file. HTTP code: $UPLOAD_HTTP_CODE"
    echo "Response: $UPLOAD_BODY"
    exit 1
fi

echo "File uploaded successfully!"
echo "Release URL: https://github.com/$REPO/releases/tag/$RELEASE_TAG"

