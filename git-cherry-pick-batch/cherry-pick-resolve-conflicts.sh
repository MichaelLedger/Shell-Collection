#!/usr/bin/env bash
#
# Cherry-pick a commit onto one or more branches, auto-resolve simple conflicts
# by keeping the incoming patch (theirs), then push.
#
# Used for FPA-56182 when branches already diverged but the incoming side has
# the correct combined fix:
#   - PHPhotoLibrary.requestAuthorization(for: .readWrite)
#   - DispatchQueue.main.async { ... }
#
# Usage:
#   ./scripts/cherry-pick-resolve-conflicts.sh
#   ./scripts/cherry-pick-resolve-conflicts.sh origin/release/GA_5.10 origin/master
#   ./scripts/cherry-pick-resolve-conflicts.sh --dry-run origin/release/PC_10.20
#
set -euo pipefail

COMMIT="${COMMIT:-3e46d3a44102e19111513fbda571febe89b2e61d}"
CONFLICT_FILE="${CONFLICT_FILE:-Sources/PRTSelectPhoto/Source/Kits/PRTPhotoLibray.swift}"
WORKTREE_ROOT="${WORKTREE_ROOT:-/tmp/prt-cp-resolve-$$}"
DRY_RUN=0
DO_PUSH=1
DO_FETCH=1

TARGET_BRANCHES=()

usage() {
  cat <<'EOF'
Cherry-pick with conflict auto-resolution (keep incoming / theirs side).

Options:
  --commit SHA          Commit to cherry-pick (default: 3e46d3a44102e19111513fbda571febe89b2e61d)
  --file PATH           Conflict file path (default: Sources/PRTSelectPhoto/Source/Kits/PRTPhotoLibray.swift)
  --worktree-root DIR   Temp worktree parent dir (default: /tmp/prt-cp-resolve-$$)
  --dry-run             Show actions only
  --no-push             Resolve locally but do not push
  --no-fetch            Skip initial `git fetch --prune origin`
  -h, --help            Show this help

Arguments:
  Remote branches to process (e.g. origin/release/GA_5.10).
  If omitted, uses the default FPA-56182 conflict branches:
    origin/release/GA_5.10
    origin/release/PC_10.20
    origin/master

Examples:
  ./scripts/cherry-pick-resolve-conflicts.sh --dry-run
  ./scripts/cherry-pick-resolve-conflicts.sh origin/release/GA_5.10 origin/master
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --commit)
      COMMIT="$2"
      shift 2
      ;;
    --file)
      CONFLICT_FILE="$2"
      shift 2
      ;;
    --worktree-root)
      WORKTREE_ROOT="$2"
      shift 2
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
    origin/*)
      TARGET_BRANCHES+=("$1")
      shift
      ;;
    *)
      echo "Unknown option or branch: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ${#TARGET_BRANCHES[@]} -eq 0 ]]; then
  TARGET_BRANCHES=(
    "origin/release/GA_5.10"
    "origin/release/PC_10.20"
    "origin/master"
  )
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if ! git cat-file -e "${COMMIT}^{commit}" 2>/dev/null; then
  echo "Error: commit not found: $COMMIT" >&2
  exit 1
fi

mkdir -p "$WORKTREE_ROOT"

SUCCESS=()
SKIPPED=()
FAILED=()

resolve_incoming_side() {
  local file_path="$1"
  python3 - <<'PY' "$file_path"
import sys
import re

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    content = f.read()

pattern = re.compile(
    r"<<<<<<< HEAD\n.*?\n=======\n(.*?)\n>>>>>>>[^\n]*",
    re.DOTALL,
)
new_content, count = pattern.subn(lambda m: m.group(1).rstrip(), content)

if count == 0:
    raise SystemExit(f"no conflict markers found in {path}")
if "<<<<<<<" in new_content or ">>>>>>>" in new_content:
    raise SystemExit(f"unresolved conflict markers remain in {path}")

with open(path, "w", encoding="utf-8") as f:
    f.write(new_content)

print(f"resolved {count} conflict block(s) in {path}")
PY
}

resolve_branch() {
  local remote="$1"
  local branch="${remote#origin/}"
  local wt_dir="${WORKTREE_ROOT}/${branch//\//__}"

  echo "=== ${branch} ==="

  if [[ $DRY_RUN -eq 1 ]]; then
    if git merge-base --is-ancestor "$COMMIT" "$remote" 2>/dev/null; then
      echo "DRY-RUN skip: already contains commit"
      SKIPPED+=("$branch")
    else
      echo "DRY-RUN would cherry-pick $COMMIT, resolve $CONFLICT_FILE (keep incoming), push"
    fi
    echo ""
    return 0
  fi

  rm -rf "$wt_dir"
  if ! git worktree add -f --detach "$wt_dir" "$remote" >/dev/null 2>&1; then
    echo "FAILED: could not create worktree"
    FAILED+=("$branch (worktree setup failed)")
    echo ""
    return 1
  fi

  cleanup_worktree() {
    git worktree remove -f "$wt_dir" >/dev/null 2>&1 || true
    rm -rf "$wt_dir"
  }

  if git -C "$wt_dir" merge-base --is-ancestor "$COMMIT" HEAD 2>/dev/null; then
    echo "SKIP: already contains commit"
    SKIPPED+=("$branch")
    cleanup_worktree
    echo ""
    return 0
  fi

  local remote_head
  remote_head="$(git rev-parse "$remote")"

  if git -C "$wt_dir" cherry-pick --empty=drop "$COMMIT" >/dev/null 2>&1; then
    local wt_head
    wt_head="$(git -C "$wt_dir" rev-parse HEAD)"
    if [[ "$remote_head" == "$wt_head" ]]; then
      echo "SKIP: patch already present"
      SKIPPED+=("$branch")
      cleanup_worktree
      echo ""
      return 0
    fi
    if [[ $DO_PUSH -eq 1 ]]; then
      if git -C "$wt_dir" push origin "HEAD:refs/heads/${branch}" >/dev/null 2>&1; then
        echo "OK: cherry-picked cleanly and pushed ($(git -C "$wt_dir" rev-parse --short HEAD))"
        SUCCESS+=("$branch")
      else
        echo "FAILED: push rejected"
        git -C "$wt_dir" reset --hard "$remote" >/dev/null 2>&1 || true
        FAILED+=("$branch (push failed)")
      fi
    else
      echo "OK: cherry-picked cleanly (push skipped)"
      SUCCESS+=("$branch")
    fi
    cleanup_worktree
    echo ""
    return 0
  fi

  local target_file="${wt_dir}/${CONFLICT_FILE}"
  if [[ ! -f "$target_file" ]] || ! grep -q '<<<<<<<' "$target_file"; then
    echo "FAILED: expected conflict in ${CONFLICT_FILE}"
    git -C "$wt_dir" cherry-pick --abort >/dev/null 2>&1 || git -C "$wt_dir" reset --hard "$remote" >/dev/null 2>&1 || true
    FAILED+=("$branch (unexpected conflict state)")
    cleanup_worktree
    echo ""
    return 1
  fi

  if ! resolve_incoming_side "$target_file"; then
    echo "FAILED: could not auto-resolve conflict"
    git -C "$wt_dir" cherry-pick --abort >/dev/null 2>&1 || git -C "$wt_dir" reset --hard "$remote" >/dev/null 2>&1 || true
    FAILED+=("$branch (resolve failed)")
    cleanup_worktree
    echo ""
    return 1
  fi

  git -C "$wt_dir" add "$CONFLICT_FILE"
  if ! GIT_EDITOR=true git -C "$wt_dir" cherry-pick --continue >/dev/null 2>&1; then
    echo "FAILED: cherry-pick --continue failed"
    git -C "$wt_dir" cherry-pick --abort >/dev/null 2>&1 || git -C "$wt_dir" reset --hard "$remote" >/dev/null 2>&1 || true
    FAILED+=("$branch (continue failed)")
    cleanup_worktree
    echo ""
    return 1
  fi

  if [[ $DO_PUSH -eq 1 ]]; then
    if git -C "$wt_dir" push origin "HEAD:refs/heads/${branch}" >/dev/null 2>&1; then
      echo "OK: conflict resolved and pushed ($(git -C "$wt_dir" rev-parse --short HEAD))"
      SUCCESS+=("$branch")
    else
      echo "FAILED: push rejected after resolve"
      git -C "$wt_dir" reset --hard "$remote" >/dev/null 2>&1 || true
      FAILED+=("$branch (push failed)")
    fi
  else
    echo "OK: conflict resolved (push skipped)"
    SUCCESS+=("$branch")
  fi

  cleanup_worktree
  echo ""
}

BRANCHES=("${TARGET_BRANCHES[@]}")

echo "Repo:          $REPO_ROOT"
echo "Commit:        $COMMIT"
echo "Conflict file: $CONFLICT_FILE"
echo "Dry run:       $([[ $DRY_RUN -eq 1 ]] && echo yes || echo no)"
echo "Branches:      ${#BRANCHES[@]}"
echo ""

if [[ $DO_FETCH -eq 1 ]]; then
  echo "Fetching origin..."
  git fetch --prune origin
  echo ""
fi

for remote in "${BRANCHES[@]}"; do
  resolve_branch "$remote"
done

git worktree prune >/dev/null 2>&1 || true

echo "========== SUMMARY =========="
echo "Success: ${#SUCCESS[@]}"
echo "Skipped: ${#SKIPPED[@]}"
echo "Failed:  ${#FAILED[@]}"
echo ""

if [[ ${#SUCCESS[@]} -gt 0 ]]; then
  echo "Success:"
  printf '  %s\n' "${SUCCESS[@]}"
  echo ""
fi

if [[ ${#SKIPPED[@]} -gt 0 ]]; then
  echo "Skipped:"
  printf '  %s\n' "${SKIPPED[@]}"
  echo ""
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo "Failed:"
  printf '  %s\n' "${FAILED[@]}"
  echo ""
  exit 1
fi
