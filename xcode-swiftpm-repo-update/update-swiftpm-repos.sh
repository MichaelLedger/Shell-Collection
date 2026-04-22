#!/usr/bin/env bash
#
# FIRST — if Xcode still says “not valid git repository” / “will fetch again” after runs:
#   1) Quit Xcode.
#   2) Delete the broken folder Xcode names (or wipe that project’s DerivedData folder).
#   3) Run this script (default = all sources: global cache + DerivedData SourcePackages).
#   4) Reopen Xcode → File → Packages → Resolve Package Versions.
#
# Refresh SwiftPM bare mirrors: global cache (org.swift.swiftpm) AND Xcode DerivedData
# SourcePackages/repositories — same dedupe (fetch + rsync) for matching origins.
# Groups caches that share the same logical origin (same host:path; https vs ssh, any domain).
#
# Plain `sh` ignores the shebang — must use bash ([[, arrays, <( ) alternatives, etc.).
if [ -z "${BASH_VERSION:-}" ]; then
  if [ -x /bin/bash ]; then
    exec /bin/bash "$0" "$@"
  elif command -v bash >/dev/null 2>&1; then
    exec bash "$0" "$@"
  else
    echo "This script requires bash (macOS: /bin/bash)." >&2
    exit 1
  fi
fi

set -euo pipefail

# SwiftPM keeps clones in TWO places; Xcode resolves/build uses DerivedData copies.
SWIFTPM_GLOBAL_REPOS="${HOME}/Library/Caches/org.swift.swiftpm/repositories"
XCODE_DERIVED_DATA="${HOME}/Library/Developer/Xcode/DerivedData"
# all = global cache + every .../SourcePackages/repositories under DerivedData (recommended)
SCAN_MODE=all
# After mirror refresh: run `swift package resolve` in each DerivedData …/SourcePackages/…/Package.swift root
RUN_SWIFT_RESOLVE=0
# Only that resolve step (skip mirror fetch/rsync) — use --resolve-only / -O
RESOLVE_ONLY=0

usage() {
  cat <<'EOF'
Usage: update-swiftpm-repos.sh [options]

  If “not valid git repository” persists:
    1) Quit Xcode.
    2) Delete the broken folder Xcode names (or wipe that project’s DerivedData folder).
    3) Run this script (default = all sources).
    4) Reopen Xcode → File → Packages → Resolve Package Versions.

  Refreshes SPM git mirrors: grouped origins, one fetch + rsync to duplicate paths.

  Before each git fetch on a PRIMARY, repairs the bare mirror: GitHub origin is normalized
  to https://…/….git (SPM compares this to the package URL), then broken origin/HEAD, fsck
  errors; last resort for github.com is clone --mirror + rsync. Then the normal fetch runs.

  Scans (default --all-sources):
    ~/Library/Caches/org.swift.swiftpm/repositories
    ~/Library/Developer/Xcode/DerivedData/*/SourcePackages/repositories

  Updating only the global cache does NOT update Xcode’s DerivedData checkouts, so
  Xcode may still refetch and log “will fetch again” / “not valid git repository”.
  Use default scanning so project SourcePackages stay in sync.

  Groups run in A→Z order by repository name only (last path segment; e.g. lottie-ios), not
  owner/org. Origins may be any host (github.com, gitlab.com, facebook enterprise, etc.);
  tie-break by full canonical host:path. missing-origin uses cache folder name as sort key.

Options:
  -n, --dry-run            Print groups and paths; no fetch or rsync
  -q, --quiet              Minimal output (hides per-repo progress; still prints errors)
  -G, --swiftpm-cache-only Only ~/Library/Caches/org.swift.swiftpm/repositories (old behavior)
  -R, --swift-resolve      After mirrors: find Package.swift under DerivedData/…/SourcePackages/
                           and run `xcrun swift package resolve` in each package folder (checkouts)
  -O, --resolve-only       Only that swift resolve step (skip all mirror fetch/rsync). Same as “just -R”
                           without touching bare repos. Needs Xcode / xcrun only (no rsync).
  -h, --help               Show this help

Requires: git, rsync for mirror refresh  ( -O or -R: also xcrun swift )

Tip: run as  ./update-swiftpm-repos.sh  or  bash update-swiftpm-repos.sh  (not plain `sh`).

After a successful run, use Xcode: File → Packages → Resolve Package Versions (or Update).
EOF
}

# Normalize remote URL to "host:path" (lowercase) so https vs ssh match across any domain
# (GitHub, GitLab, Bitbucket, facebook.com / enterprise hosts, etc.). Unknown shapes → opaque.
canonical_origin_key() {
  local u="$1"
  local h p
  if [[ -z "$u" || "$u" == "(no origin)" ]]; then
    echo "missing-origin"
    return
  fi
  u="${u%.git}"

  # git@host:group/repo (SSH / scp-style — most hosts)
  if [[ "$u" =~ ^git@([^:]+):(.+)$ ]]; then
    h=$(echo "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')
    p=$(echo "${BASH_REMATCH[2]}" | tr '[:upper:]' '[:lower:]')
    echo "${h}:${p}"
    return
  fi

  # https://host/path  or  http://host/path  (optional user@ before host)
  if [[ "$u" =~ ^https?://([^/]+)/(.+)$ ]]; then
    h="${BASH_REMATCH[1]}"
    p="${BASH_REMATCH[2]}"
    if [[ "$h" == *@* ]]; then
      h="${h##*@}"
    fi
    h=$(echo "$h" | tr '[:upper:]' '[:lower:]')
    p=$(echo "$p" | tr '[:upper:]' '[:lower:]')
    p="${p%%\?*}"
    p="${p%%#*}"
    echo "${h}:${p}"
    return
  fi

  # ssh://git@host/path  or  ssh://host/path
  if [[ "$u" =~ ^ssh://([^/]+)/(.+)$ ]]; then
    h="${BASH_REMATCH[1]}"
    p="${BASH_REMATCH[2]}"
    h="${h#git@}"
    h=$(echo "$h" | tr '[:upper:]' '[:lower:]')
    p=$(echo "$p" | tr '[:upper:]' '[:lower:]')
    p="${p%%\?*}"
    p="${p%%#*}"
    echo "${h}:${p}"
    return
  fi

  # git://host/path
  if [[ "$u" =~ ^git://([^/]+)/(.+)$ ]]; then
    h=$(echo "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')
    p=$(echo "${BASH_REMATCH[2]}" | tr '[:upper:]' '[:lower:]')
    p="${p%%\?*}"
    p="${p%%#*}"
    echo "${h}:${p}"
    return
  fi

  printf 'opaque:%s\n' "$(printf '%s' "$u" | shasum -a 256 2>/dev/null | awk '{print $1}')"
}

# Sort key: last path segment of host:path (e.g. …/lottie-ios → lottie-ios); not owner-specific.
repo_name_sort_key_from_canonical() {
  local k="$1"
  local path base
  if [[ "$k" == "missing-origin" ]]; then
    echo ""
    return
  fi
  if [[ "$k" =~ ^opaque: ]]; then
    echo "$k"
    return
  fi
  path="${k#*:}"
  base="${path##*/}"
  echo "$base" | tr '[:upper:]' '[:lower:]'
}

run_deriveddata_swift_package_resolve() {
  if [[ ! -d "$XCODE_DERIVED_DATA" ]]; then
    echo ""
    echo "swift package resolve: DerivedData not found: $XCODE_DERIVED_DATA" >&2
    return 1
  fi
  if ! command -v xcrun &>/dev/null; then
    echo ""
    echo "swift package resolve: xcrun not in PATH (open Xcode or install CLI tools)." >&2
    return 1
  fi
  echo ""
  echo "=== swift package resolve (DerivedData …/SourcePackages/… Package.swift roots) ==="
  local roots_tmp r_ok r_fail r_n rc
  roots_tmp=$(mktemp "${TMPDIR:-/tmp}/upd-swiftpm-resolve-roots.XXXXXX") || roots_tmp=""
  if [[ -z "$roots_tmp" ]]; then
    echo "swift package resolve: could not create temp file." >&2
    return 1
  fi
  find "$XCODE_DERIVED_DATA" -path "*/SourcePackages/*" -name Package.swift 2>/dev/null \
    | sed 's|/Package\.swift$||' | LC_ALL=C sort -u > "$roots_tmp" || true
  r_ok=0
  r_fail=0
  r_n=0
  while IFS= read -r root || [[ -n "${root:-}" ]]; do
    [[ -z "${root:-}" ]] && continue
    r_n=$((r_n + 1))
    if [[ "$QUIET" -eq 0 ]]; then
      echo ""
      echo "[$r_n] xcrun swift package resolve — $root"
    fi
    set +e
    ( cd "$root" && xcrun swift package resolve )
    rc=$?
    set -e
    if [[ "$rc" -eq 0 ]]; then
      r_ok=$((r_ok + 1))
    else
      r_fail=$((r_fail + 1))
      echo "    → resolve failed (exit $rc): $root" >&2
    fi
  done < "$roots_tmp"
  rm -f "$roots_tmp"
  echo ""
  echo "swift package resolve: package roots seen=$r_n  ok=$r_ok  failed=$r_fail"
  echo "  (Dependency checkouts under SourcePackages—not your .xcodeproj; use Xcode → Resolve for the app.)"
  return 0
}

DRY_RUN=0
QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=1; shift ;;
    -q|--quiet)   QUIET=1; shift ;;
    -G|--swiftpm-cache-only) SCAN_MODE=swiftpm-global; shift ;;
    -R|--swift-resolve) RUN_SWIFT_RESOLVE=1; shift ;;
    -O|--resolve-only) RESOLVE_ONLY=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    *)            echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ "$RESOLVE_ONLY" -eq 1 ]]; then
  run_deriveddata_swift_package_resolve
  exit 0
fi

if ! command -v rsync &>/dev/null; then
  echo "rsync not found in PATH (required for duplicate-origin mirrors)." >&2
  exit 1
fi

shopt -s nullglob
repo_scan_roots=()
if [[ "$SCAN_MODE" == "swiftpm-global" ]]; then
  if [[ ! -d "$SWIFTPM_GLOBAL_REPOS" ]]; then
    echo "SwiftPM global repositories directory not found:" >&2
    echo "  $SWIFTPM_GLOBAL_REPOS" >&2
    echo "Open a project once so SwiftPM creates the cache, or check the path." >&2
    exit 1
  fi
  repo_scan_roots=( "$SWIFTPM_GLOBAL_REPOS" )
else
  [[ -d "$SWIFTPM_GLOBAL_REPOS" ]] && repo_scan_roots+=( "$SWIFTPM_GLOBAL_REPOS" )
  for __dd in "${XCODE_DERIVED_DATA}"/*/SourcePackages/repositories; do
    [[ -d "$__dd" ]] && repo_scan_roots+=( "$__dd" )
  done
  if (( ${#repo_scan_roots[@]} == 0 )); then
    echo "No SPM repository roots found. Expected at least one of:" >&2
    echo "  $SWIFTPM_GLOBAL_REPOS" >&2
    echo "  ${XCODE_DERIVED_DATA}/*/SourcePackages/repositories" >&2
    echo "Open the project in Xcode and resolve packages at least once." >&2
    exit 1
  fi
fi
unset __dd

candidates=()
for __root in "${repo_scan_roots[@]}"; do
  [[ -d "$__root" ]] || continue
  for __d in "$__root"/*/; do
    [[ -d "$__d" ]] && candidates+=( "$__d" )
  done
done
unset __root __d

if (( ${#candidates[@]} == 0 )); then
  echo "No package repository folders found under:"
  for __root in "${repo_scan_roots[@]}"; do
    echo "  $__root"
  done
  echo "Open the project in Xcode once (resolve packages), or build, then retry." >&2
  exit 0
fi

bare_repos=()
for repo in "${candidates[@]}"; do
  if git -C "$repo" rev-parse --is-bare-repository &>/dev/null; then
    bare_repos+=( "$repo" )
  else
    echo "Skipping (not a valid bare git repo — remove this folder and use Xcode: Packages → Reset Package Caches):" >&2
    echo "  $repo" >&2
  fi
done

total=${#bare_repos[@]}
if (( total == 0 )); then
  echo "No valid bare Git repositories found (see skips above)." >&2
  exit 0
fi

if [[ "$QUIET" -eq 0 ]]; then
  echo "Scanned roots (${#repo_scan_roots[@]}):"
  for __root in "${repo_scan_roots[@]}"; do
    echo "  $__root"
  done
  echo "Bare repos to process: $total"
  echo ""
fi
unset __root

# key<TAB>path lines, sorted so duplicate origins are adjacent (primary = first path per key)
# (Avoid "done < <(...)" — POSIX sh cannot parse process substitution.)
__pair_tmp=$(mktemp "${TMPDIR:-/tmp}/upd-swiftpm-repos.XXXXXX") || exit 1
__cleanup_pair_tmp() { rm -f "$__pair_tmp"; }
trap __cleanup_pair_tmp EXIT
for repo in "${bare_repos[@]}"; do
  ou=$(git -C "$repo" remote get-url origin 2>/dev/null || echo "")
  k="$(canonical_origin_key "$ou")"
  printf '%s\t%s\n' "$k" "$repo"
done | sort -t $'\t' -k1,1 -k2,2 > "$__pair_tmp"
pair_lines=()
while IFS= read -r __line; do
  pair_lines+=( "$__line" )
done < "$__pair_tmp"
__cleanup_pair_tmp
trap - EXIT
unset __pair_tmp __line

# Collapse pair_lines into origin groups, then sort by last path segment of host:path,
# then full canonical key (LC_ALL=C).
__ung=""
__sorted_out=""
__ung=$(mktemp "${TMPDIR:-/tmp}/upd-swiftpm-groups.XXXXXX") || exit 1
__cleanup_ung() { rm -f "$__ung" "$__sorted_out" 2>/dev/null; }
trap __cleanup_ung EXIT

cur_key=""
bucket=()
flush_to_ung() {
  ((${#bucket[@]} == 0)) && return
  local mb rsort out
  rsort=$(repo_name_sort_key_from_canonical "$cur_key")
  if [[ -z "$rsort" ]]; then
    mb=$(printf '%s\n' "${bucket[@]}" | sed 's|.*/||' | LC_ALL=C sort | head -1)
    rsort="$mb"
  fi
  out="${rsort}"$'\t'"${cur_key}"
  for ph in "${bucket[@]}"; do
    out+=$'\t'"$ph"
  done
  printf '%s\n' "$out" >> "$__ung"
}
for line in "${pair_lines[@]}"; do
  k="${line%%$'\t'*}"
  p="${line#*$'\t'}"
  if [[ -n "$cur_key" && "$k" != "$cur_key" ]]; then
    flush_to_ung
    bucket=()
  fi
  cur_key="$k"
  bucket+=( "$p" )
done
flush_to_ung

__sorted_out=$(mktemp "${TMPDIR:-/tmp}/upd-swiftpm-sorted.XXXXXX") || exit 1
LC_ALL=C sort -t $'\t' -k1,1 -k2,2 "$__ung" > "$__sorted_out"
rm -f "$__ung"
__ung=""

sorted_group_lines=()
while IFS= read -r __gl || [[ -n "${__gl:-}" ]]; do
  [[ -z "${__gl:-}" ]] && continue
  sorted_group_lines+=( "$__gl" )
done < "$__sorted_out"

rm -f "$__sorted_out"
__sorted_out=""
trap - EXIT
unset __ung

uniq_groups=0
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run — $((${#pair_lines[@]})) bare repo path(s), grouped by canonical origin:"
  echo "Groups run in  A→Z order  by last path segment (repo name), not host/org; then full host:path key."
  for __gl in "${sorted_group_lines[@]}"; do
    IFS=$'\t' read -r -a __gp <<< "$__gl"
    __sk="${__gp[0]}"
    __gk="${__gp[1]}"
    __paths=()
    for ((__pp = 2; __pp < ${#__gp[@]}; __pp++)); do
      __paths+=( "${__gp[$__pp]}" )
    done
    ((uniq_groups++))
    echo ""
    echo "  [$uniq_groups] ${__gk}  (sort by repo: ${__sk})"
    echo "      primary:  $(basename "${__paths[0]}")"
    echo "        ${__paths[0]}"
    for ((__i = 1; __i < ${#__paths[@]}; __i++)); do
      echo "      mirror:   $(basename "${__paths[$__i]}")"
      echo "        ${__paths[$__i]}"
    done
  done
  echo ""
  echo "Done (dry run). Distinct origin groups: $uniq_groups  |  cache dirs: $total"
  exit 0
fi

ok=0
fail=0
head_unchanged=0
head_moved=0
head_unknown=0
fetch_runs=0
rsync_runs=0
group_idx=0
repo_slot=0

# Updates head_* counters; sets HEAD_SUMMARY (must not run inside $( ) subshell)
HEAD_SUMMARY=""
record_head_change() {
  local repo="$1"
  local before="$2"
  local after
  after=$(git -C "$repo" rev-parse HEAD 2>/dev/null || true)
  HEAD_SUMMARY=""
  if [[ -n "$before" && -n "$after" ]]; then
    if [[ "$before" == "$after" ]]; then
      head_unchanged=$((head_unchanged + 1))
      HEAD_SUMMARY="HEAD unchanged ($(git -C "$repo" rev-parse --short "$after" 2>/dev/null || echo "?"))"
    else
      head_moved=$((head_moved + 1))
      HEAD_SUMMARY="HEAD moved  $(git -C "$repo" rev-parse --short "$before" 2>/dev/null || echo "?") → $(git -C "$repo" rev-parse --short "$after" 2>/dev/null || echo "?")"
    fi
  else
    head_unknown=$((head_unknown + 1))
    HEAD_SUMMARY="HEAD before/after not comparable (missing ref?)"
  fi
}

# Xcode/SPM often matches package URL against `git remote get-url origin` as an exact
# string (e.g. https://github.com/org/repo.git). git@… or https without .git → “not valid”.
repair_normalize_github_origin_for_spm() {
  local repo="$1"
  local url path newu rf
  rf=(--quiet)

  url=$(git -C "$repo" remote get-url origin 2>/dev/null) || return 0
  newu=""

  if [[ "$url" =~ ^git@github\.com:.+ ]]; then
    path="${url#git@github.com:}"
    path="${path%.git}"
    newu="https://github.com/${path}.git"
  elif [[ "$url" =~ ^ssh://git@github\.com/(.+)$ ]]; then
    path="${BASH_REMATCH[1]}"
    path="${path#/}"
    path="${path%.git}"
    newu="https://github.com/${path}.git"
  elif [[ "$url" =~ ^https://github\.com/[^[:space:]]+$ ]] && [[ "$url" != *.git ]]; then
    newu="${url}.git"
  fi

  if [[ -n "$newu" && "$newu" != "$url" ]]; then
    [[ "${QUIET:-0}" -eq 0 ]] && echo "    (repair) canonical GitHub origin for SPM: $newu" >&2
    git -C "$repo" remote set-url origin "$newu"
    git -C "$repo" fetch origin --prune "${rf[@]}" 2>/dev/null || true
    git -C "$repo" remote set-head origin -a 2>/dev/null || true
  fi
  return 0
}

# Last resort: replace bare tree with a fresh git clone --mirror (GitHub only).
repair_reclone_github_mirror_inplace() {
  local repo="$1"
  local url tmp mir path
  url=$(git -C "$repo" remote get-url origin 2>/dev/null) || return 1
  [[ "$url" =~ github\.com ]] || return 1
  if [[ "$url" =~ ^git@github\.com: ]]; then
    path="${url#git@github.com:}"
    path="${path%.git}"
    url="https://github.com/${path}.git"
  elif [[ "$url" =~ ^https://github\.com/ ]] && [[ "$url" != *.git ]]; then
    url="${url}.git"
  fi

  [[ "${QUIET:-0}" -eq 0 ]] && echo "    (repair) last resort: git clone --mirror → rsync over this bare dir" >&2
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/spm-repair-mirror.XXXXXX") || return 1
  mir="${tmp}/mirror.git"
  if git clone --quiet --mirror "$url" "$mir" 2>/dev/null; then
    rsync -a --delete "${mir}/" "${repo%/}/"
    rm -rf "$tmp"
    git -C "$repo" remote set-url origin "$url"
    git -C "$repo" remote set-head origin -a 2>/dev/null || true
    return 0
  fi
  rm -rf "$tmp"
  return 1
}

# Fix common SPM bare-mirror corruption before fetch: missing refs/remotes/origin/* target,
# unresolved HEAD, fsck errors. Then caller refreshes refs with a normal fetch.
repair_spm_bare_mirror() {
  local repo="$1"
  local ohead line target fsck_out rf

  if ! git -C "$repo" rev-parse --is-bare-repository &>/dev/null; then
    return 1
  fi

  rf=(--quiet)
  repair_normalize_github_origin_for_spm "$repo"

  ohead="${repo%/}/refs/remotes/origin/HEAD"

  if [[ -f "$ohead" ]]; then
    line=$(head -1 "$ohead" 2>/dev/null | tr -d '\r')
    if [[ "$line" =~ ^ref:[[:space:]]+(.+)$ ]]; then
      target="${BASH_REMATCH[1]}"
      if ! git -C "$repo" rev-parse "$target" &>/dev/null; then
        [[ "${QUIET:-0}" -eq 0 ]] && echo "    (repair) origin/HEAD → $target missing — remove symref, fetch, set remote HEAD" >&2
        rm -f "$ohead"
        if git -C "$repo" remote get-url origin &>/dev/null; then
          git -C "$repo" fetch origin --prune "${rf[@]}" 2>/dev/null || true
          git -C "$repo" remote set-head origin -a 2>/dev/null || true
        fi
      fi
    fi
  fi

  if ! git -C "$repo" rev-parse HEAD &>/dev/null; then
    [[ "${QUIET:-0}" -eq 0 ]] && echo "    (repair) HEAD unresolved — fetch --all" >&2
    git -C "$repo" fetch --all --tags --prune "${rf[@]}" 2>/dev/null || true
    git -C "$repo" remote set-head origin -a 2>/dev/null || true
  fi

  fsck_out=$(git -C "$repo" fsck --no-full --no-progress 2>&1) || true
  if echo "$fsck_out" | grep -qE '^error'; then
    [[ "${QUIET:-0}" -eq 0 ]] && echo "    (repair) git fsck reported errors — fetch --all + remote set-head" >&2
    git -C "$repo" fetch --all --tags --prune "${rf[@]}" 2>/dev/null || true
    git -C "$repo" remote set-head origin -a 2>/dev/null || true
  fi

  # fsck or HEAD still broken → replace tree (GitHub packages only)
  fsck_out=$(git -C "$repo" fsck --no-full --no-progress 2>&1) || true
  if ! git -C "$repo" rev-parse HEAD &>/dev/null || echo "$fsck_out" | grep -qE '^error'; then
    if repair_reclone_github_mirror_inplace "$repo"; then
      fsck_out=$(git -C "$repo" fsck --no-full --no-progress 2>&1) || true
      if echo "$fsck_out" | grep -qE '^error'; then
        [[ "${QUIET:-0}" -eq 0 ]] && echo "    (repair) fsck still failing after mirror reclone" >&2
      fi
    fi
  fi

  if ! git -C "$repo" rev-parse HEAD &>/dev/null; then
    [[ "${QUIET:-0}" -eq 0 ]] && echo "    (repair) failed: still no HEAD after repair" >&2
    return 1
  fi
  return 0
}

process_repo_fetch() {
  local repo="$1"
  local label="$2"
  local name
  name=$(basename "$repo")
  repo_slot=$((repo_slot + 1))

  if ! repair_spm_bare_mirror "$repo"; then
    fail=$((fail + 1))
    echo "    → FAILED (bare repo still unusable after repair)  $repo" >&2
    return 1
  fi

  local head_before
  head_before=$(git -C "$repo" rev-parse HEAD 2>/dev/null || true)

  if [[ "$QUIET" -eq 0 ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[$repo_slot/$total]  $label  $name"
    remote_url=$(git -C "$repo" remote get-url origin 2>/dev/null || echo "(no origin)")
    echo "    origin: $remote_url"
    echo "    path:   $repo"
    if [[ -n "$head_before" ]]; then
      echo "    HEAD before fetch: $(git -C "$repo" rev-parse --short "$head_before" 2>/dev/null || echo "?")"
    else
      echo "    HEAD before fetch: (not resolved)"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  fi

  local fetch_flags=(fetch --all --tags --prune)
  if [[ "$QUIET" -eq 1 ]]; then
    fetch_flags+=(--quiet)
  else
    fetch_flags+=(--progress)
  fi

  local stat=0
  git -C "$repo" "${fetch_flags[@]}" || stat=$?

  if [[ "$stat" -eq 0 ]]; then
    ok=$((ok + 1))
    fetch_runs=$((fetch_runs + 1))
    record_head_change "$repo" "$head_before"
    if [[ "$QUIET" -eq 0 ]]; then
      echo "    → ok — $HEAD_SUMMARY"
    fi
    return 0
  fi
  fail=$((fail + 1))
  echo "    → FAILED (exit $stat)  $repo" >&2
  return 1
}

process_repo_rsync() {
  local primary="$1"
  local repo="$2"
  local label="$3"
  local name
  name=$(basename "$repo")
  repo_slot=$((repo_slot + 1))

  local head_before
  head_before=$(git -C "$repo" rev-parse HEAD 2>/dev/null || true)

  if [[ "$QUIET" -eq 0 ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[$repo_slot/$total]  $label  $name"
    remote_url=$(git -C "$repo" remote get-url origin 2>/dev/null || echo "(no origin)")
    echo "    origin: $remote_url"
    echo "    path:   $repo"
    echo "    action: rsync from primary  $(basename "$primary")"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  fi

  local stat=0
  rsync -a --delete "${primary%/}/" "${repo%/}/" || stat=$?

  if [[ "$stat" -eq 0 ]]; then
    ok=$((ok + 1))
    rsync_runs=$((rsync_runs + 1))
    record_head_change "$repo" "$head_before"
    if [[ "$QUIET" -eq 0 ]]; then
      echo "    → ok (rsync) — $HEAD_SUMMARY"
    fi
    return 0
  fi
  fail=$((fail + 1))
  echo "    → FAILED rsync (exit $stat)  $repo" >&2
  return 1
}

cur_key=""
group_paths=()

flush_group() {
  ((${#group_paths[@]} == 0)) && return
  group_idx=$((group_idx + 1))
  local n=${#group_paths[@]}
  local primary="${group_paths[0]}"

  if [[ "$QUIET" -eq 0 ]]; then
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════"
    echo "Origin group $group_idx  [$cur_key]"
    local gextra=""
    ((n > 1)) && gextra=" + $((n - 1))× rsync"
    echo "  Cache dirs in this group: $n  (1× git fetch${gextra})"
    echo "══════════════════════════════════════════════════════════════════════════════"
  fi

  if (( n == 1 )); then
    process_repo_fetch "$primary" "PRIMARY"
    group_paths=()
    return
  fi

  local i
  process_repo_fetch "$primary" "PRIMARY"
  local okp=$?
  if [[ "$okp" -ne 0 ]]; then
    for ((i = 1; i < n; i++)); do
      repo_slot=$((repo_slot + 1))
      fail=$((fail + 1))
      echo "[$repo_slot/$total]  SKIPPED (primary fetch failed)  ${group_paths[$i]}" >&2
    done
    group_paths=()
    return
  fi

  for ((i = 1; i < n; i++)); do
    process_repo_rsync "$primary" "${group_paths[$i]}" "MIRROR"
  done
  group_paths=()
}

for __gl in "${sorted_group_lines[@]}"; do
  IFS=$'\t' read -r -a __gp <<< "$__gl"
  cur_key="${__gp[1]}"
  group_paths=()
  for ((__pp = 2; __pp < ${#__gp[@]}; __pp++)); do
    group_paths+=( "${__gp[$__pp]}" )
  done
  flush_group
done
unset __gp __gl

echo ""
echo "Done."
echo "  Cache directories:     $total"
echo "  Origin groups:         $group_idx"
echo "  Git fetch runs:        $fetch_runs"
echo "  Rsync mirror runs:     $rsync_runs"
echo "  Repos ok:              $ok"
echo "  Repos failed / skip:   $fail"
if (( ok > 0 )); then
  echo "  — Resolved HEAD after update (per cache dir):"
  echo "      unchanged:     $head_unchanged"
  echo "      moved:         $head_moved"
  (( head_unknown > 0 )) && echo "      n/a:           $head_unknown"
fi

if [[ "$RUN_SWIFT_RESOLVE" -eq 1 ]]; then
  run_deriveddata_swift_package_resolve
fi

exit 0
