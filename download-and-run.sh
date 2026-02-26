#!/bin/bash

set -e

REPO_OWNER="${REPO_OWNER:-$(git config --get remote.origin.url | sed -n 's/.*github.com[:/]\([^/]*\)\/.*/\1/p')}"
REPO_NAME="${REPO_NAME:-$(basename -s .git $(git config --get remote.origin.url))}"
ARTIFACT_NAME="shopizer-admin-dist"
OUTPUT_DIR="./downloaded-artifacts"

if [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: GITHUB_TOKEN environment variable is required"
  echo "Usage: GITHUB_TOKEN=your_token ./download-and-run.sh"
  exit 1
fi

echo "Fetching latest workflow run..."
RUN_ID=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/actions/runs?status=success&per_page=1" \
  | grep -o '"id": [0-9]*' | head -1 | grep -o '[0-9]*')

if [ -z "$RUN_ID" ]; then
  echo "Error: No successful workflow runs found"
  exit 1
fi

echo "Latest run ID: $RUN_ID"

echo "Fetching artifact ID..."
ARTIFACT_ID=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/actions/runs/$RUN_ID/artifacts" \
  | grep -A 3 "\"name\": \"$ARTIFACT_NAME\"" | grep '"id"' | grep -o '[0-9]*')

if [ -z "$ARTIFACT_ID" ]; then
  echo "Error: Artifact not found"
  exit 1
fi

echo "Artifact ID: $ARTIFACT_ID"

mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

echo "Downloading artifact..."
curl -L -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/actions/artifacts/$ARTIFACT_ID/zip" \
  -o artifact.zip

echo "Extracting artifact..."
unzip -o artifact.zip
rm artifact.zip

cd ..

echo "Starting local server..."
echo "Serving from: $OUTPUT_DIR"

if command -v python3 &> /dev/null; then
  cd "$OUTPUT_DIR"
  python3 -m http.server 4200
elif command -v python &> /dev/null; then
  cd "$OUTPUT_DIR"
  python -m SimpleHTTPServer 4200
else
  echo "Python not found. Install a web server or use: npx http-server $OUTPUT_DIR -p 4200"
fi
