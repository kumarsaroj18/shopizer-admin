# CI/CD Setup

## GitHub Actions Pipeline

The CI pipeline (`.github/workflows/ci.yml`) automatically:
- Runs on push/PR to main, master, or develop branches
- Installs dependencies with Node.js 12.22.7
- Runs tests in headless Chrome
- Builds production artifacts
- Uploads build artifacts (retained for 30 days)

## Download and Run Artifacts Locally

### Prerequisites
- GitHub Personal Access Token with `repo` scope
- Python (for local server) or `npx http-server`

### Usage

```bash
# Set your GitHub token
export GITHUB_TOKEN=your_github_token_here

# Run the script
./download-and-run.sh
```

The script will:
1. Fetch the latest successful workflow run
2. Download the build artifacts
3. Extract them to `./downloaded-artifacts`
4. Start a local web server on http://localhost:4200

### Manual Override

You can override repository detection:
```bash
REPO_OWNER=your-username REPO_NAME=shopizer-admin GITHUB_TOKEN=your_token ./download-and-run.sh
```

### Alternative: Using npx
If Python is not available:
```bash
npx http-server ./downloaded-artifacts -p 4200
```
