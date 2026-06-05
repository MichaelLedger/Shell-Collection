#!/usr/bin/env bash
#
# Cherry-pick a commit onto selected remote branches, then push.
# By default targets only the latest release branch per app plus main/master.
# Uses a disposable git worktree per branch to avoid memory blow-up.
#
# Usage:
#   ./scripts/cherry-pick-to-release-branches.sh
#   ./scripts/cherry-pick-to-release-branches.sh --dry-run
#   ./scripts/cherry-pick-to-release-branches.sh --all-branches
#   ./scripts/cherry-pick-to-release-branches.sh --commit abc1234
#
set -euo pipefail

COMMIT="${COMMIT:-3e46d3a44102e19111513fbda571febe89b2e61d}"
BRANCH_PREFIX="${BRANCH_PREFIX:-origin/release/}"
WORKTREE_ROOT="${WORKTREE_ROOT:-/tmp/prt-cherry-pick-$$}"
DRY_RUN=0
DO_PUSH=1
DO_FETCH=1
LATEST_ONLY=1
INCLUDE_MAIN=1

usage() {
  cat <<'EOF'
Cherry-pick a commit onto remote release branches.

Default mode (--latest-only):
  - One branch per app: highest version among origin/release/* branches
  - Also includes origin/main and/or origin/master when present
  - Skips merge branches (names containing "merge")

Options:
  --commit SHA         Commit to cherry-pick (default: 3e46d3a44102e19111513fbda571febe89b2e61d)
  --prefix PREFIX      Remote branch prefix (default: origin/release/)
  --worktree-root DIR  Temp worktree parent dir (default: /tmp/prt-cherry-pick-$$)
  --latest-only        Only latest release branch per app (default)
  --all-branches       Cherry-pick to every matching release branch
  --no-main            Do not include origin/main or origin/master
  --dry-run            Show actions only; do not cherry-pick or push
  --no-push            Cherry-pick locally in worktree but do not push
  --no-fetch           Skip initial `git fetch --prune origin`
  -h, --help           Show this help

Examples:
  ./scripts/cherry-pick-to-release-branches.sh --dry-run
  ./scripts/cherry-pick-to-release-branches.sh
  ./scripts/cherry-pick-to-release-branches.sh --all-branches --prefix 'origin/release/PB/'
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --commit)
      COMMIT="$2"
      shift 2
      ;;
    --prefix)
      BRANCH_PREFIX="$2"
      shift 2
      ;;
    --worktree-root)
      WORKTREE_ROOT="$2"
      shift 2
      ;;
    --latest-only)
      LATEST_ONLY=1
      shift
      ;;
    --all-branches)
      LATEST_ONLY=0
      shift
      ;;
    --no-main)
      INCLUDE_MAIN=0
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      DO_PUSH=0
      shift
      ;;
    --no-push)
      DO_PUSH=0
      shift
      ;;
    --no-fetch)
      DO_FETCH=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if ! git cat-file -e "${COMMIT}^{commit}" 2>/dev/null; then
  echo "Error: commit not found: $COMMIT" >&2
  exit 1
fi

mkdir -p "$WORKTREE_ROOT"
LOG_FILE="${WORKTREE_ROOT}/cherry-pick-$(date +%Y%m%d-%H%M%S).log"
touch "$LOG_FILE"

SUCCESS_FILE="${WORKTREE_ROOT}/success.txt"
SKIPPED_FILE="${WORKTREE_ROOT}/skipped.txt"
CONFLICT_FILE="${WORKTREE_ROOT}/conflicts.txt"
FAILED_FILE="${WORKTREE_ROOT}/failed.txt"
: >"$SUCCESS_FILE"
: >"$SKIPPED_FILE"
: >"$CONFLICT_FILE"
: >"$FAILED_FILE"

CURRENT_WORKTREE=""
LATEST_INDEX_DIR=""

cleanup() {
  if [[ -n "$CURRENT_WORKTREE" && -d "$CURRENT_WORKTREE" ]]; then
    git worktree remove -f "$CURRENT_WORKTREE" >/dev/null 2>&1 || true
    CURRENT_WORKTREE=""
  fi
  git worktree prune >/dev/null 2>&1 || true
  if [[ -n "$LATEST_INDEX_DIR" && -d "$LATEST_INDEX_DIR" ]]; then
    rm -rf "$LATEST_INDEX_DIR"
  fi
}
trap cleanup EXIT INT TERM

log() {
  echo "$*" | tee -a "$LOG_FILE"
}

remove_worktree() {
  if [[ -n "$CURRENT_WORKTREE" ]]; then
    git worktree remove -f "$CURRENT_WORKTREE" >/dev/null 2>&1 || true
    rm -rf "$CURRENT_WORKTREE"
    CURRENT_WORKTREE=""
  fi
}

branch_to_dirname() {
  local name="$1"
  name="${name#origin/}"
  echo "${name//\//__}"
}

version_gt() {
  local a="$1"
  local b="$2"
  [[ "$(printf '%s\n%s\n' "$a" "$b" | sort -V | tail -1)" == "$a" && "$a" != "$b" ]]
}

parse_release_branch() {
  local remote="$1"
  local branch="${remote#origin/}"
  branch="${branch#release/}"
  local app version

  if [[ "$branch" == *merge* ]]; then
    return 1
  fi

  if [[ "$branch" == */* ]]; then
    app="${branch%%/*}"
    version="${branch#*/}"
  elif [[ "$branch" == *_* ]]; then
    app="${branch%%_*}"
    version="${branch#${app}_}"
  else
    return 1
  fi

  printf '%s\t%s\t%s\n' "$app" "$version" "$remote"
}

select_latest_release_branches() {
  LATEST_INDEX_DIR="$(mktemp -d "${WORKTREE_ROOT}/latest-index.XXXXXX")"
  local remote parsed app version

  while IFS= read -r remote; do
    parsed="$(parse_release_branch "$remote" || true)"
    [[ -z "$parsed" ]] && continue

    IFS=$'\t' read -r app version remote <<<"$parsed"
    local index_file="${LATEST_INDEX_DIR}/${app}"

    if [[ ! -f "$index_file" ]]; then
      printf '%s\t%s\n' "$version" "$remote" >"$index_file"
      continue
    fi

    local current_version current_remote
    IFS=$'\t' read -r current_version current_remote <"$index_file"
    if version_gt "$version" "$current_version"; then
      printf '%s\t%s\n' "$version" "$remote" >"$index_file"
    fi
  done < <(git branch -r | sed 's/^[[:space:]]*//' | grep "^${BRANCH_PREFIX}" | sort -u)

  local index_file
  for index_file in "$LATEST_INDEX_DIR"/*; do
    [[ -f "$index_file" ]] || continue
    cut -f2 "$index_file"
  done | sort -u
}

collect_target_branches() {
  REMOTE_BRANCHES=()

  if [[ $LATEST_ONLY -eq 1 ]]; then
    while IFS= read -r remote; do
      REMOTE_BRANCHES+=("$remote")
    done < <(select_latest_release_branches)

    if [[ $INCLUDE_MAIN -eq 1 ]]; then
      if git show-ref --verify --quiet refs/remotes/origin/main; then
        REMOTE_BRANCHES+=("origin/main")
      fi
      if git show-ref --verify --quiet refs/remotes/origin/master; then
        REMOTE_BRANCHES+=("origin/master")
      fi
    fi
  else
    while IFS= read -r line; do
      REMOTE_BRANCHES+=("$line")
    done < <(git branch -r | sed 's/^[[:space:]]*//' | grep "^${BRANCH_PREFIX}" | sort -u)
  fi

  local -a deduped=()
  local remote
  for remote in "${REMOTE_BRANCHES[@]}"; do
    local found=0
    local existing
    for existing in "${deduped[@]:-}"; do
      if [[ "$existing" == "$remote" ]]; then
        found=1
        break
      fi
    done
    if [[ $found -eq 0 ]]; then
      deduped+=("$remote")
    fi
  done
  REMOTE_BRANCHES=("${deduped[@]}")
}

log "Repo:            $REPO_ROOT"
log "Commit:          $COMMIT"
log "Branch prefix:   $BRANCH_PREFIX"
log "Latest only:     $([[ $LATEST_ONLY -eq 1 ]] && echo yes || echo no)"
log "Include main:    $([[ $INCLUDE_MAIN -eq 1 ]] && echo yes || echo no)"
log "Worktree root:   $WORKTREE_ROOT"
log "Log file:        $LOG_FILE"
log "Dry run:         $([[ $DRY_RUN -eq 1 ]] && echo yes || echo no)"
log ""

if [[ $DO_FETCH -eq 1 ]]; then
  log "Fetching origin..."
  git fetch --prune origin
  log ""
fi

collect_target_branches

if [[ ${#REMOTE_BRANCHES[@]} -eq 0 ]]; then
  echo "No target branches found." >&2
  exit 1
fi

log "Target branches (${#REMOTE_BRANCHES[@]}):"
for remote in "${REMOTE_BRANCHES[@]}"; do
  log "  ${remote#origin/}"
done
log ""

for remote in "${REMOTE_BRANCHES[@]}"; do
  branch="${remote#origin/}"
  wt_dir="${WORKTREE_ROOT}/$(branch_to_dirname "$remote")"

  log "=== ${branch} ==="

  if [[ $DRY_RUN -eq 1 ]]; then
    if git merge-base --is-ancestor "$COMMIT" "$remote"; then
      log "DRY-RUN skip: already contains commit"
      echo "$branch" >>"$SKIPPED_FILE"
    else
      log "DRY-RUN would cherry-pick onto $remote and push to origin/$branch"
    fi
    log ""
    continue
  fi

  remove_worktree
  mkdir -p "$wt_dir"

  if ! git worktree add -f --detach "$wt_dir" "$remote" >>"$LOG_FILE" 2>&1; then
    log "FAILED: could not create worktree for $remote"
    echo "$branch (worktree setup failed)" >>"$FAILED_FILE"
    rm -rf "$wt_dir"
    log ""
    continue
  fi
  CURRENT_WORKTREE="$wt_dir"

  if git -C "$wt_dir" merge-base --is-ancestor "$COMMIT" HEAD; then
    log "SKIP: already contains commit"
    echo "$branch" >>"$SKIPPED_FILE"
    remove_worktree
    log ""
    continue
  fi

  remote_head="$(git rev-parse "$remote")"

  if git -C "$wt_dir" cherry-pick --empty=drop "$COMMIT" >>"$LOG_FILE" 2>&1; then
    wt_head="$(git -C "$wt_dir" rev-parse HEAD)"
    if [[ "$remote_head" == "$wt_head" ]]; then
      log "SKIP: change already present (empty cherry-pick)"
      echo "$branch" >>"$SKIPPED_FILE"
      remove_worktree
      log ""
      continue
    fi
    if [[ $DO_PUSH -eq 1 ]]; then
      if git -C "$wt_dir" push origin "HEAD:refs/heads/${branch}" >>"$LOG_FILE" 2>&1; then
        log "OK: cherry-picked and pushed"
        echo "$branch" >>"$SUCCESS_FILE"
      else
        log "FAILED: push rejected for $branch"
        git -C "$wt_dir" reset --hard "$remote" >>"$LOG_FILE" 2>&1 || true
        echo "$branch (push failed)" >>"$FAILED_FILE"
      fi
    else
      log "OK: cherry-picked (push skipped)"
      echo "$branch" >>"$SUCCESS_FILE"
    fi
  else
    log "CONFLICT: cherry-pick failed on $branch"
    git -C "$wt_dir" cherry-pick --abort >>"$LOG_FILE" 2>&1 || git -C "$wt_dir" reset --hard "$remote" >>"$LOG_FILE" 2>&1 || true
    echo "$branch" >>"$CONFLICT_FILE"
  fi

  remove_worktree
  log ""
done

success_count=$(wc -l <"$SUCCESS_FILE" | tr -d ' ')
skipped_count=$(wc -l <"$SKIPPED_FILE" | tr -d ' ')
conflict_count=$(wc -l <"$CONFLICT_FILE" | tr -d ' ')
failed_count=$(wc -l <"$FAILED_FILE" | tr -d ' ')

log "========== SUMMARY =========="
log "Success:   ${success_count}"
log "Skipped:   ${skipped_count}"
log "Conflicts: ${conflict_count}"
log "Failed:    ${failed_count}"
log ""

if [[ $success_count -gt 0 ]]; then
  log "Success:"
  sed 's/^/  /' "$SUCCESS_FILE" | tee -a "$LOG_FILE"
  log ""
fi

if [[ $skipped_count -gt 0 ]]; then
  log "Skipped:"
  sed 's/^/  /' "$SKIPPED_FILE" | tee -a "$LOG_FILE"
  log ""
fi

if [[ $conflict_count -gt 0 ]]; then
  log "Conflicts:"
  sed 's/^/  /' "$CONFLICT_FILE" | tee -a "$LOG_FILE"
  log ""
fi

if [[ $failed_count -gt 0 ]]; then
  log "Failed:"
  sed 's/^/  /' "$FAILED_FILE" | tee -a "$LOG_FILE"
  log ""
fi

log "Full log: $LOG_FILE"

if [[ $conflict_count -gt 0 || $failed_count -gt 0 ]]; then
  exit 1
fi
