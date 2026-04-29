#!/usr/bin/env bash
# =============================================================================
#  docker-prune.sh — Compose-aware Docker cleanup utility
#  Prunes images, containers, volumes, networks, and build cache tied to the
#  docker-compose.yml (or docker-compose.yaml) in the current directory.
# =============================================================================

set -euo pipefail

# ── Colour palette ────────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
log()     { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARN]${RESET}  $*"; }
success() { echo -e "${GREEN}${BOLD}[ OK ]${RESET}  $*"; }
error()   { echo -e "${RED}${BOLD}[ERR ]${RESET}  $*" >&2; }
die()     { error "$*"; exit 1; }
sep()     { echo -e "${DIM}──────────────────────────────────────────────────${RESET}"; }

# ── Flags (defaults) ──────────────────────────────────────────────────────────
DRY_RUN=false
FORCE=false
PRUNE_VOLUMES=true
PRUNE_IMAGES=true
PRUNE_NETWORKS=true
PRUNE_BUILD_CACHE=true
GLOBAL_PRUNE=false   # wipe ALL docker resources, not just compose-scoped ones

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF

${BOLD}Usage:${RESET}
  $(basename "$0") [OPTIONS]

${BOLD}Description:${RESET}
  Stops and removes all Docker resources (containers, images, volumes,
  networks, build cache) associated with the docker-compose project in the
  current directory.

${BOLD}Options:${RESET}
  -h, --help            Show this help message and exit
  -n, --dry-run         Print what would be removed without doing anything
  -f, --force           Skip all confirmation prompts
      --no-volumes      Keep named volumes
      --no-images       Keep images
      --no-networks     Keep project networks
      --no-cache        Skip build-cache pruning
      --global          Also run a full system prune (affects ALL projects)

${BOLD}Examples:${RESET}
  $(basename "$0")                  # interactive, prune everything
  $(basename "$0") --dry-run        # preview only
  $(basename "$0") --force          # no prompts
  $(basename "$0") --no-volumes -f  # skip volumes, no prompt

EOF
}

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)         usage; exit 0 ;;
    -n|--dry-run)      DRY_RUN=true ;;
    -f|--force)        FORCE=true ;;
    --no-volumes)      PRUNE_VOLUMES=false ;;
    --no-images)       PRUNE_IMAGES=false ;;
    --no-networks)     PRUNE_NETWORKS=false ;;
    --no-cache)        PRUNE_BUILD_CACHE=false ;;
    --global)          GLOBAL_PRUNE=true ;;
    *) die "Unknown option: $1  (use --help for usage)" ;;
  esac
  shift
done

# ── Locate compose file ───────────────────────────────────────────────────────
COMPOSE_FILE=""
for candidate in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
  if [[ -f "$candidate" ]]; then
    COMPOSE_FILE="$candidate"
    break
  fi
done

[[ -n "$COMPOSE_FILE" ]] || die "No docker-compose file found in $(pwd)"

# Derive the project name (partial Compose precedence)
# Note: this does not parse a top-level 'name:' from the compose file.
# If you rely on that, set COMPOSE_PROJECT_NAME explicitly when running.
PROJECT_NAME="$(basename "$(pwd)")"
# Allow override via COMPOSE_PROJECT_NAME env variable (standard Compose behaviour)
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-$PROJECT_NAME}"

# ── Dependency checks ─────────────────────────────────────────────────────────
for cmd in docker; do
  command -v "$cmd" &>/dev/null || die "'$cmd' is not installed or not in PATH"
done

# Detect whether to use 'docker compose' (V2) or 'docker-compose' (V1)
if docker compose version &>/dev/null 2>&1; then
  DC=(docker compose)
else
  command -v docker-compose &>/dev/null || die "Neither 'docker compose' (V2) nor 'docker-compose' (V1) found"
  DC=(docker-compose)
fi

# ── Banner ────────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}╔══════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║        Docker Compose — Prune Utility        ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${RESET}"
echo
log "Compose file : ${COMPOSE_FILE}"
log "Project name : ${PROJECT_NAME}"
log "Dry-run mode : ${DRY_RUN}"
sep

# ── Confirmation ──────────────────────────────────────────────────────────────
if [[ "$FORCE" == false && "$DRY_RUN" == false ]]; then
  warn "This will ${RED}${BOLD}permanently delete${RESET} Docker resources for project '${PROJECT_NAME}'."
  $GLOBAL_PRUNE && warn "  --global is set: ALL dangling/unused Docker resources will also be removed."
  echo
  read -rp "$(echo -e "${YELLOW}Are you sure? [y/N] ${RESET}")" answer
  [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]] || { log "Aborted."; exit 0; }
  echo
fi

# ── Utility: run or echo ──────────────────────────────────────────────────────
run() {
  local cmd=("$@");
  if [[ "$DRY_RUN" == true ]]; then
    printf '  %b[dry-run]%b ' "${DIM}" "${RESET}"
    printf '%s ' "${cmd[@]}"
    echo
  else
    "${cmd[@]}"
  fi
}

# ── 1. Stop running containers ────────────────────────────────────────────────
sep
log "Step 1/7 — Stopping running containers …"
RUNNING=$("${DC[@]}" -f "$COMPOSE_FILE" ps -q 2>/dev/null || true)
if [[ -n "$RUNNING" ]]; then
  run "${DC[@]}" -f "$COMPOSE_FILE" stop
  success "Containers stopped."
else
  log "No running containers found."
fi

# ── 2. Bring down project (containers + networks + optional volumes) ───────────
sep
log "Step 2/7 — Removing containers and project networks …"
DOWN_FLAGS="--remove-orphans"
$PRUNE_VOLUMES  && DOWN_FLAGS="$DOWN_FLAGS --volumes"
$PRUNE_IMAGES   && DOWN_FLAGS="$DOWN_FLAGS --rmi all"

run "${DC[@]}" -f "$COMPOSE_FILE" down $DOWN_FLAGS
success "Compose stack removed."

# ── 3. Remove any leftover containers for this project ────────────────────────
sep
log "Step 3/7 — Checking for orphaned containers …"
ORPHANS=$(docker ps -a --filter "label=com.docker.compose.project=${PROJECT_NAME}" -q 2>/dev/null || true)
if [[ -n "$ORPHANS" ]]; then
  log "Found orphaned containers: ${ORPHANS}"
  run docker rm -f $ORPHANS
  success "Orphaned containers removed."
else
  log "No orphaned containers."
fi

# ── 4. Remove project images (if not already removed by 'down --rmi all') ─────
if [[ "$PRUNE_IMAGES" == true ]]; then
  sep
  log "Step 4/7 — Removing project images …"
  IMG_IDS=$(docker images --filter "label=com.docker.compose.project=${PROJECT_NAME}" -q 2>/dev/null || true)
  if [[ -n "$IMG_IDS" ]]; then
    run docker rmi -f $IMG_IDS
    success "Project images removed."
  else
    log "No project-labelled images found (already cleaned or externally sourced)."
  fi
else
  log "Step 4/7 — Skipping image removal (--no-images)."
fi

# ── 5. Remove project networks (if any remain after 'compose down') ───────────
if [[ "$PRUNE_NETWORKS" == true ]]; then
  sep
  log "Step 5/7 — Removing project networks …"
  NET_IDS=$(docker network ls --filter "label=com.docker.compose.project=${PROJECT_NAME}" -q 2>/dev/null || true)
  if [[ -n "$NET_IDS" ]]; then
    run docker network rm $NET_IDS
    success "Project networks removed."
  else
    log "No project-labelled networks found."
  fi
else
  log "Step 5/7 — Skipping network removal (--no-networks)."
fi

# ── 6. Remove project volumes (if not already removed by 'down --volumes') ────
if [[ "$PRUNE_VOLUMES" == true ]]; then
  sep
  log "Step 6/7 — Removing project volumes …"
  VOL_IDS=$(docker volume ls --filter "label=com.docker.compose.project=${PROJECT_NAME}" -q 2>/dev/null || true)
  if [[ -n "$VOL_IDS" ]]; then
    run docker volume rm -f $VOL_IDS
    success "Project volumes removed."
  else
    log "No project-labelled volumes found."
  fi
else
  log "Step 6/7 — Skipping volume removal (--no-volumes)."
fi

# ── 7. Build cache ────────────────────────────────────────────────────────────
if [[ "$PRUNE_BUILD_CACHE" == true ]]; then
  sep
  log "Step 7/7 — Pruning Docker build cache …"
  run docker builder prune -f
  success "Build cache cleared."
else
  log "Step 7/7 — Skipping build cache (--no-cache)."
fi

# ── Optional: global system prune ─────────────────────────────────────────────
if [[ "$GLOBAL_PRUNE" == true ]]; then
  sep
  warn "Running global system prune (all unused resources, ALL projects) …"
  GLOBAL_FLAGS="-f"
  $PRUNE_VOLUMES && GLOBAL_FLAGS="$GLOBAL_FLAGS --volumes"
  run docker system prune $GLOBAL_FLAGS
  success "Global system prune complete."
fi

# ── Summary ───────────────────────────────────────────────────────────────────
sep
if [[ "$DRY_RUN" == true ]]; then
  echo -e "${YELLOW}${BOLD}Dry-run complete — nothing was deleted.${RESET}"
else
  echo -e "${GREEN}${BOLD}All done! Project '${PROJECT_NAME}' has been fully pruned.${RESET}"
fi
echo
