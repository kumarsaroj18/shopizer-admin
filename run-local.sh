#!/usr/bin/env bash
# =============================================================================
# run-local.sh — Run Shopizer Admin UI locally
# =============================================================================
# Usage:
#   ./run-local.sh [OPTIONS]
#
# Options:
#   --mode docker   (default) Pull latest Docker image from ghcr.io and run
#   --mode dist     Download latest Angular dist from GitHub Actions CI and serve
#   --mode local    Build from source locally with npm and run (no CI artifacts needed)
#   --owner <name>  GitHub owner/org name (defaults to git remote origin owner)
#   --tag <tag>     Docker image tag to pull (default: latest)
#   --backend <url> Shopizer backend base URL (default: http://localhost:8080)
#   --help          Show this help message
#
# Prerequisites:
#   docker         Required for all modes
#   node / npm     Required only for --mode local
#   gh             Required only for --mode dist (GitHub CLI: https://cli.github.com)
# =============================================================================

set -euo pipefail

# ─── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m';  GREEN='\033[0;32m'
YELLOW='\033[1;33m'; BLUE='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ─── Defaults ─────────────────────────────────────────────────────────────────
MODE="docker"
TAG="latest"
APP_PORT=4200
APP_CONTAINER=shopizer-admin-app
BACKEND_URL="http://localhost:8080"
OWNER=""

usage() {
  sed -n '/^# Usage/,/^# ====/p' "$0" | grep -v '^# ====' | sed 's/^# //'
  exit 0
}

# ─── Parse arguments ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)    MODE="$2";       shift 2 ;;
    --owner)   OWNER="$2";      shift 2 ;;
    --tag)     TAG="$2";        shift 2 ;;
    --backend) BACKEND_URL="$2"; shift 2 ;;
    --help|-h) usage ;;
    *) error "Unknown option: $1"; usage ;;
  esac
done

if [[ "$MODE" != "docker" && "$MODE" != "dist" && "$MODE" != "local" ]]; then
  error "--mode must be 'docker', 'dist', or 'local'"; exit 1
fi

# ─── Detect GitHub owner/repo from git remote ─────────────────────────────────
detect_owner_repo() {
  local remote_url
  remote_url=$(git remote get-url origin 2>/dev/null || true)

  if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
  else
    OWNER=""
    REPO="shopizer-admin"
  fi
}

if [[ -z "$OWNER" ]]; then
  detect_owner_repo
  if [[ -z "$OWNER" ]]; then
    error "Could not detect GitHub owner from git remote. Pass --owner <name>."
    exit 1
  fi
else
  REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
  REPO=$(echo "$REMOTE_URL" | sed 's|.*github\.com[:/][^/]*/||;s|\.git$||')
  REPO="${REPO:-shopizer-admin}"
fi

IMAGE="ghcr.io/${OWNER}/shopizer-admin:${TAG}"

# ─── Check prerequisites ──────────────────────────────────────────────────────
check_cmd() {
  if ! command -v "$1" &>/dev/null; then
    error "Required tool not found: $1. $2"
    exit 1
  fi
}

info "Checking prerequisites..."
check_cmd docker "Install Docker: https://docs.docker.com/get-docker/"
if [[ "$MODE" == "dist" ]]; then
  check_cmd gh "Install GitHub CLI: https://cli.github.com/"
fi
if [[ "$MODE" == "local" ]]; then
  check_cmd node "Install Node.js 12+: https://nodejs.org/"
  check_cmd npm  "npm comes with Node.js"
fi
success "All prerequisites satisfied"

# ─── Cleanup helper ───────────────────────────────────────────────────────────
cleanup_containers() {
  info "Stopping and removing containers..."
  docker rm -f "$APP_CONTAINER" 2>/dev/null || true
  success "Cleanup done."
}

trap '
  echo ""
  warn "Interrupt received — cleaning up..."
  cleanup_containers
' INT TERM

# ─── GHCR Authentication ──────────────────────────────────────────────────────
ghcr_login() {
  info "Authenticating with GitHub Container Registry (ghcr.io)..."

  if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
    gh auth token | docker login ghcr.io -u "$OWNER" --password-stdin 2>/dev/null \
      && { success "Logged in to ghcr.io via GitHub CLI token"; return; }
  fi

  warn "Could not authenticate automatically. Please enter your GitHub credentials."
  warn "Use a Personal Access Token (PAT) with 'read:packages' scope as the password."
  warn "Create one at: https://github.com/settings/tokens/new?scopes=read:packages"
  docker login ghcr.io -u "$OWNER"
}

# ─── Run container helper ─────────────────────────────────────────────────────
start_container() {
  local img="$1"
  info "Starting Shopizer Admin container from image: $img"
  docker rm -f "$APP_CONTAINER" 2>/dev/null || true

  docker run -d \
    --name "$APP_CONTAINER" \
    -e APP_BASE_URL="${BACKEND_URL}/api/v1" \
    -e APP_SHIPPING_URL="${BACKEND_URL}" \
    -e APP_MAP_API_KEY="" \
    -e APP_DEFAULT_LANGUAGE="en" \
    -p "${APP_PORT}:80" \
    "$img"
}

# ─── MODE: docker ─────────────────────────────────────────────────────────────
run_docker_mode() {
  info "Mode: docker — pulling $IMAGE"

  if ! docker pull "$IMAGE" --quiet 2>/dev/null; then
    ghcr_login
    if ! docker pull "$IMAGE"; then
      echo ""
      error "Could not pull $IMAGE"
      error "This usually means either:"
      error "  1. The GitHub Actions CI pipeline hasn't run yet on main/master."
      error "     → Push the .github/workflows/ci.yml to your repo and let it complete."
      error "  2. The package is private and auth failed."
      error "     → Make it public: https://github.com/users/${OWNER}/packages"
      error "  3. Or use --mode local to build and run from source instead:"
      error "     → ./run-local.sh --mode local"
      exit 1
    fi
  fi
  success "Image ready: $IMAGE"

  start_container "$IMAGE"
  print_startup_info "docker rm -f ${APP_CONTAINER}"
}

# ─── MODE: dist ───────────────────────────────────────────────────────────────
run_dist_mode() {
  info "Mode: dist — downloading latest Angular dist from GitHub Actions CI"

  if ! gh auth status &>/dev/null; then
    error "Not logged in to GitHub CLI. Run: gh auth login"
    exit 1
  fi

  DIST_DIR="/tmp/shopizer-admin-dist-run"
  mkdir -p "$DIST_DIR"

  info "Fetching latest successful workflow run from ${OWNER}/${REPO}..."

  RUN_ID=$(gh run list \
    --repo "${OWNER}/${REPO}" \
    --workflow ci.yml \
    --status success \
    --limit 1 \
    --json databaseId \
    --jq '.[0].databaseId')

  if [[ -z "$RUN_ID" || "$RUN_ID" == "null" ]]; then
    error "No successful CI workflow runs found for ${OWNER}/${REPO}."
    error "Make sure the CI pipeline has run at least once successfully on main/master."
    error "Or use --mode local to build from source: ./run-local.sh --mode local"
    exit 1
  fi

  info "Found successful run ID: $RUN_ID. Downloading artifact..."

  # Download the artifact (contains shopizer-admin-*.tar.gz)
  ARTIFACT_DOWNLOAD_DIR="${DIST_DIR}/artifact"
  mkdir -p "$ARTIFACT_DOWNLOAD_DIR"

  gh run download "$RUN_ID" \
    --repo "${OWNER}/${REPO}" \
    --pattern "shopizer-admin-build-*" \
    --dir "$ARTIFACT_DOWNLOAD_DIR"

  TARBALL=$(find "$ARTIFACT_DOWNLOAD_DIR" -name "shopizer-admin-*.tar.gz" | head -1)
  if [[ -z "$TARBALL" ]]; then
    error "Could not find shopizer-admin-*.tar.gz in downloaded artifacts."
    ls -la "$ARTIFACT_DOWNLOAD_DIR" || true
    exit 1
  fi

  success "Downloaded: $(basename "$TARBALL")"

  SERVE_DIR="${DIST_DIR}/dist"
  mkdir -p "$SERVE_DIR"
  tar -xzf "$TARBALL" -C "$SERVE_DIR"
  success "Angular dist extracted to: $SERVE_DIR"

  info "Starting Shopizer Admin container (nginx + volume mount)..."
  docker rm -f "$APP_CONTAINER" 2>/dev/null || true

  docker run -d \
    --name "$APP_CONTAINER" \
    -v "${SERVE_DIR}:/usr/share/nginx/html:ro" \
    -e APP_BASE_URL="${BACKEND_URL}/api/v1" \
    -e APP_SHIPPING_URL="${BACKEND_URL}" \
    -e APP_MAP_API_KEY="" \
    -e APP_DEFAULT_LANGUAGE="en" \
    -p "${APP_PORT}:80" \
    nginx:1.25-alpine \
    /bin/sh -c "
      if [ -f /usr/share/nginx/html/assets/env.template.js ]; then
        envsubst < /usr/share/nginx/html/assets/env.template.js \
                 > /usr/share/nginx/html/assets/env.js
      fi
      exec nginx -g 'daemon off;'
    "

  print_startup_info "docker rm -f ${APP_CONTAINER}"
}

# ─── MODE: local ──────────────────────────────────────────────────────────────
run_local_mode() {
  info "Mode: local — building from source and running"
  warn "This will run a full npm build. It may take a few minutes on first run."

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [[ ! -d "${SCRIPT_DIR}/node_modules" ]]; then
    info "Installing npm dependencies (--legacy-peer-deps)..."
    (cd "$SCRIPT_DIR" && npm install --legacy-peer-deps)
  else
    info "node_modules already present — skipping npm install."
    info "Run 'npm install --legacy-peer-deps' manually if dependencies have changed."
  fi

  info "Building Angular production bundle..."
  (cd "$SCRIPT_DIR" && npm run build)

  if [[ ! -d "${SCRIPT_DIR}/dist" ]]; then
    error "Build failed — ${SCRIPT_DIR}/dist not found."
    exit 1
  fi
  success "Build complete: ${SCRIPT_DIR}/dist"

  info "Building Docker image shopizer-admin:local-latest..."
  (cd "$SCRIPT_DIR" && docker build -f Dockerfile.local -t shopizer-admin:local-latest .)
  success "Image built: shopizer-admin:local-latest"

  start_container "shopizer-admin:local-latest"
  print_startup_info "docker rm -f ${APP_CONTAINER}"
}

# ─── Print startup banner ─────────────────────────────────────────────────────
print_startup_info() {
  local stop_cmd="$1"
  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}  Shopizer Admin is starting up!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "  🌐  Admin UI URL    : ${BLUE}http://localhost:${APP_PORT}${NC}"
  echo -e "  🔌  Backend URL     : ${BLUE}${BACKEND_URL}${NC}"
  echo ""
  echo -e "  🔑  Admin Login (auto-created on first backend startup):"
  echo -e "      Username: ${YELLOW}admin@shopizer.com${NC}"
  echo -e "      Password: ${YELLOW}password${NC}"
  echo ""
  echo -e "${YELLOW}┌────────────────────────────────────────────────────────────┐${NC}"
  echo -e "${YELLOW}│  ⚠️  IMPORTANT: Database is NOT persisted                  │${NC}"
  echo -e "${YELLOW}│                                                            │${NC}"
  echo -e "${YELLOW}│  All data is lost when you stop the backend.              │${NC}"
  echo -e "${YELLOW}│  Run ONCE after EVERY backend start from shopizer/:       │${NC}"
  echo -e "${YELLOW}│                                                            │${NC}"
  echo -e "${YELLOW}│      ${NC}cd ../shopizer && ./populate-db.sh${YELLOW}                 │${NC}"
  echo -e "${YELLOW}│                                                            │${NC}"
  echo -e "${YELLOW}│  This creates stores, products, and customer accounts.    │${NC}"
  echo -e "${YELLOW}└────────────────────────────────────────────────────────────┘${NC}"
  echo ""
  echo -e "  ℹ️   The app may take a few seconds for nginx to become ready."
  echo ""
  echo -e "  To view logs : ${YELLOW}docker logs -f ${APP_CONTAINER}${NC}"
  echo -e "  To stop      : ${YELLOW}${stop_cmd}${NC}"
  echo -e "  Or press     : ${YELLOW}Ctrl+C${NC} (cleans up automatically)"
  echo ""
  echo -e "  ⚠️  Make sure Shopizer backend is running at ${BACKEND_URL}"
  echo -e "     Run the backend: cd ../shopizer && ./run-local.sh"
  echo ""
  echo -e "  💡 If login fails, ensure the backend has started successfully"
  echo -e "     and the database has been initialized (check backend logs)."
  echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║    Shopizer Admin — Local Runner         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
info "Repository : ${OWNER}/${REPO}"
info "Mode       : ${MODE}"
info "Backend    : ${BACKEND_URL}"
[[ "$MODE" == "docker" ]] && info "Image      : ${IMAGE}"
echo ""

case "$MODE" in
  docker) run_docker_mode ;;
  dist)   run_dist_mode ;;
  local)  run_local_mode ;;
esac
