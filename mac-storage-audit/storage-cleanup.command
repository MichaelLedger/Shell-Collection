#!/bin/bash
# The default mode is read-only. All filesystem changes require per-path
# approval and a separate confirmation after the final summary.
set -o pipefail
export LC_ALL=C
unset CDPATH

stop() {
  printf '%s\n' "$*" >&2
  exit 1
}

usage() {
  printf '%s\n' \
    'storage-cleanup.command                 Preview the full reviewed plan' \
    'storage-cleanup.command --delete        Choose reviewed caches and older symbols for permanent deletion' \
    'storage-cleanup.command --delete-caches Choose reviewed build intermediates and Xet chunks for permanent deletion' \
    'storage-cleanup.command --hold          Choose reviewed caches and older symbols to move to a holding folder' \
    'storage-cleanup.command --hold-caches   Choose reviewed build intermediates and Xet chunks to move' \
    'storage-cleanup.command --help          Show usage'
}

mode=${1:---preview}
operation=hold
caches_only=0
(( $# <= 1 )) || stop 'Pass one option. Use --help for the available modes.'
case "$mode" in
  --help|-h) usage; exit 0 ;;
  --preview) ;;
  --delete|--delete-caches|--hold|--hold-caches)
    [[ -t 0 && -t 1 ]] || stop 'File changes require an interactive terminal.'
    ;;
  *) usage >&2; exit 2 ;;
esac
case "$mode" in --delete|--delete-caches) operation=delete ;; esac
case "$mode" in --delete-caches|--hold-caches) caches_only=1 ;; esac

uid=$(/usr/bin/id -u) || stop 'Cannot identify the current user.'
username=$(/usr/bin/id -un) || stop 'Cannot identify the current user.'
[[ "$uid" != 0 && "$HOME" == /Users/* ]] || stop 'Run as your usual Mac account, without sudo.'

device_root="$HOME/Library/Developer/Xcode/iOS DeviceSupport"
keeper="$device_root/iPhone17,3 27.0.1 (24A446)"
held="$device_root/iPhone17,3 27.0 (24A437)"
old_devices=(
  "$device_root/iPhone17,3 27.0 (24A5370h)"
  "$device_root/iPhone17,3 27.0 (24A5408d)"
)
xet_root="$HOME/.cache/huggingface/xet"
xet_chunks="$xet_root/https___cas_serv-tGqkUaZf_CBPHQ6h/chunk-cache"
temp_roots=(
  '/private/tmp/pb-cover-offset-build'
  '/private/tmp/pinned-header-color-validation-20261118'
  '/private/tmp/codex-memories-wrenda.An9NlU/DerivedData'
  '/private/tmp/wbk-myprojects-navigation-build'
  '/private/tmp/codex-pb-size-picker-build'
)
temp_children=(
  Build/Intermediates.noindex CompilationCache.noindex Index.noindex ModuleCache.noindex
  SDKExplicitPrecompiledModules SDKStatCaches.noindex
)
expected_project="$HOME/Downloads/freeprints_ios_4/PhotoBooks/Wrenda.xcodeproj"
holding_parent="$HOME/Library/Application Support"
holding_root="$holding_parent/Storage Cleanup Hold"

is_reviewed_target() {
  local item="$1" root child old_device
  case "$item" in
    /|/private/tmp|/tmp|"$HOME"|"$xet_root"|"$device_root") return 1 ;;
  esac
  [[ "$item" == "$xet_chunks" ]] && return 0
  for old_device in "${old_devices[@]}"; do
    [[ "$item" == "$old_device" && "$caches_only" == 0 ]] && return 0
  done
  for root in "${temp_roots[@]}"; do
    for child in "${temp_children[@]}"; do
      [[ "$item" == "$root/$child" ]] && return 0
    done
  done
  return 1
}

identity() {
  local item="$1" parent="${1%/*}" physical metadata filesystem inode owner modified
  [[ -d "$item" && ! -L "$item" ]] || return 1
  physical=$(cd -P -- "$item" && pwd -P) || return 1
  [[ "$physical" == "$item" ]] || return 1
  metadata=$(/usr/bin/stat -f '%d %i %u %m' "$item") || return 1
  read -r filesystem inode owner modified <<< "$metadata"
  [[ "$owner" == "$uid" && "$filesystem" == "$(/usr/bin/stat -f '%d' "$parent")" ]] || return 1
  printf '%s:%s:%s:%s\n' "$filesystem" "$inode" "$owner" "$modified"
}

check_keeper() {
  identity "$keeper" >/dev/null &&
    [[ -f "$keeper/arm64e/.finalized" && ! -L "$keeper/arm64e/.finalized" ]] &&
    identity "$keeper/arm64e/Symbols" >/dev/null
}

protected_entry() {
  /usr/bin/find -x "$1" -mindepth 1 \( \
    -name .git -o -name .svn -o -name SourcePackages -o \
    -iname '*.xcarchive' -o -iname '*.ipa' -o -iname '*.dsym' -o \
    -iname '*.xcodeproj' -o -iname '*.xcworkspace' -o \
    -iname '*.patch' -o -iname '*.diff' -o -iname '*.ips' -o -iname '*.crash' -o \
    -iname '*.p12' -o -iname '*.mobileprovision' \
  \) -print -quit
}

check_holding_volume() {
  local source_device holding_device
  source_device=$(/usr/bin/stat -f '%d' "$1") || stop "Could not verify the volume for $1"
  holding_device=$(/usr/bin/stat -f '%d' "$2") || stop 'Could not verify the holding folder’s volume.'
  [[ "$source_device" == "$holding_device" ]] || stop "Target and holding folder are on different volumes: $1"
}

check_nested_mounts() {
  local mounted
  mounted=$(/sbin/mount | /usr/bin/awk -v item="$1" '
    {
      separator = index($0, " on ")
      if (!separator) next
      location = substr($0, separator + 4)
      sub(/ \([^()]*\)$/, "", location)
      sub(/^\/System\/Volumes\/Data\//, "/", location)
      sub(/^\/tmp\//, "/private/tmp/", location)
      if (location == item || index(location, item "/") == 1) print location
    }
  ') || stop 'Could not verify mounted volumes.'
  [[ -z "$mounted" ]] || stop "Target contains a mounted volume: $mounted"
}

targets=()
identities=()
sizes_kib=()
activity_roots=()
total_kib=0

measure_kib() {
  local measurement kib
  measurement=$(/usr/bin/du -skx "$1") || return 1
  kib=${measurement%%$'\t'*}
  [[ "$kib" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$kib"
}

format_size() {
  /usr/bin/awk -v kib="$1" 'BEGIN {
    bytes = kib * 1024
    if (bytes >= 1000000000) printf "%.2f GB", bytes / 1000000000
    else if (bytes >= 1000000) printf "%.2f MB", bytes / 1000000
    else if (bytes >= 1000) printf "%.2f KB", bytes / 1000
    else printf "%.0f B", bytes
  }'
}

add_target() {
  local item="$1" check_root="${2:-$1}" before after kib protected
  is_reviewed_target "$item" || stop "Path is outside the reviewed list: $item"
  if [[ ! -e "$item" && ! -L "$item" ]]; then
    return 0
  fi
  before=$(identity "$item") || stop "Unsafe or unexpected directory: $item"
  protected=$(protected_entry "$item") || stop "Could not check contents: $item"
  if [[ -n "$protected" ]]; then
    printf '  Skipping %s because it contains %s\n' "$item" "$protected"
    return 0
  fi
  kib=$(measure_kib "$item") || stop "Could not measure: $item"
  after=$(identity "$item") || stop "Directory changed while scanning: $item"
  [[ "$before" == "$after" ]] || stop "Directory changed while scanning: $item"
  targets+=("$item")
  identities+=("$before")
  sizes_kib+=("$kib")
  activity_roots+=("$check_root")
  total_kib=$((total_kib + kib))
}

is_build_group() {
  local index="$1" root
  root=${activity_roots[$index]}
  [[ "$root" != "$xet_root" && "${targets[$index]}" == "$root/"* ]]
}

print_targets() {
  local index root label previous_root=''
  for index in "$@"; do
    root=${activity_roots[$index]}
    label=${targets[$index]}
    if is_build_group "$index"; then
      if [[ "$root" != "$previous_root" ]]; then
        printf '\n%s/\n' "$root"
      fi
      label=${label#"$root/"}
    fi
    printf '%10s   %s\n' "$(format_size "${sizes_kib[$index]}")" "$label"
    previous_root=$root
  done
}

select_targets() {
  local index
  for index in "$@"; do
    selected+=("$index")
    selected_roots+=("${activity_roots[$index]}")
    selected_kib=$((selected_kib + sizes_kib[index]))
  done
}

choose_path() {
  local index="$1" label="$2" answer
  while :; do
    printf '%s %s (%s)%s? [y/N] ' "$choose_verb" "$label" "$(format_size "${sizes_kib[$index]}")" "$choose_destination"
    IFS= read -r answer || stop 'Cancelled.'
    case "$answer" in
      y|Y) select_targets "$index"; return 0 ;;
      n|N|'') return 0 ;;
      *) printf 'Enter y or n.\n' ;;
    esac
  done
}

choose_build_group() {
  local root="$1" index total=0 answer
  shift
  print_targets "$@"
  for index in "$@"; do
    total=$((total + sizes_kib[index]))
  done
  while :; do
    printf '%s these %d listed paths (%s)%s? [y/N/s] ' "$choose_verb" "$#" "$(format_size "$total")" "$choose_destination"
    IFS= read -r answer || stop 'Cancelled.'
    case "$answer" in
      y|Y) select_targets "$@"; return 0 ;;
      n|N|'') return 0 ;;
      s|S)
        for index in "$@"; do
          choose_path "$index" "${targets[$index]#"$root/"}"
        done
        return 0
        ;;
      *) printf 'Enter y for all listed paths, n to skip, or s to choose individually.\n' ;;
    esac
  done
}

check_open_files() {
  local listed paths
  paths=$(printf '%s\n' "$@")
  listed=$(/usr/sbin/lsof -nP -a -u "$username" -Fpcn |
    CLEANUP_SCAN_PATHS="$paths" /usr/bin/awk '
      BEGIN {count = split(ENVIRON["CLEANUP_SCAN_PATHS"], roots, "\n")}
      /^p/ {pid = substr($0, 2); processes++; next}
      /^c/ {command = substr($0, 2); next}
      /^n\// {
        name = substr($0, 2)
        sub(/^\/System\/Volumes\/Data\//, "/", name)
        sub(/^\/tmp\//, "/private/tmp/", name)
        for (i = 1; i <= count; i++) {
          if (roots[i] != "" && (name == roots[i] || index(name, roots[i] "/") == 1)) {
            key = pid SUBSEP roots[i]
            if (!seen[key]++) print command, "(PID " pid ")", roots[i]
          }
        }
      }
      END {if (!processes) exit 1}
    ') || {
    printf 'Could not verify open files.\n' >&2
    return 1
  }
  if [[ -n "$listed" ]]; then
    printf '\nOpen files were detected:\n%s\n' "$listed" >&2
    return 1
  fi
}

print_action_summary() {
  printf '\n%s summary\n' "$summary_title"
  print_targets "${completed[@]}"
  printf 'Directories %s: %d. Total size: %s (measured before the operation).\n' \
    "$completed_verb" "${#completed[@]}" "$(format_size "$completed_kib")"
  if [[ "$operation" == hold ]] && (( ${#completed[@]} > 0 )); then
    printf 'Holding batch: %s\n' "$holding_batch"
    printf 'Each item retains its original directory structure inside the batch.\n'
    printf 'The holding folder is on this disk. Moving into it does not free disk space.\n'
  fi
}

prepare_holding_folder() {
  if [[ ! -e "$holding_root" && ! -L "$holding_root" ]]; then
    /bin/mkdir -m 700 "$holding_root" || stop 'Could not create the holding folder.'
  fi
  identity "$holding_root" >/dev/null || stop 'Could not verify the holding folder.'
  holding_batch=$(/usr/bin/mktemp -d "$holding_root/cleanup.XXXXXXXX") || stop 'Could not create the batch folder.'
  identity "$holding_batch" >/dev/null || stop 'Could not verify the batch folder.'
}

move_to_holding() {
  local item="$1" destination="$holding_batch$1"
  check_holding_volume "$item" "$holding_batch"
  /bin/mkdir -p "${destination%/*}" || stop "Could not create the destination for $item"
  identity "${destination%/*}" >/dev/null || stop "Could not verify the destination for $item"
  # A same-volume rename fails rather than falling back to copy and remove.
  /usr/bin/perl -e '
    my ($source, $destination) = @ARGV;
    die "Destination already exists: $destination\n" if -e $destination || -l $destination;
    rename($source, $destination) or die "Could not move $source: $!\n";
  ' "$item" "$destination" || stop "Could not move this path: $item"
}

printf 'Checking reviewed cleanup paths.\n'
for build_root in "${temp_roots[@]}"; do
  if [[ ! -e "$build_root" && ! -L "$build_root" ]]; then
    continue
  fi
  identity "$build_root" >/dev/null || stop "Unexpected build directory: $build_root"
  [[ ! -L "$build_root/info.plist" ]] || stop "Unexpected build metadata: $build_root"
  project=$(/usr/bin/plutil -extract WorkspacePath raw -o - "$build_root/info.plist") ||
    stop "Could not verify the Xcode workspace for $build_root"
  [[ "$project" == "$expected_project" ]] || stop "The Xcode workspace changed for $build_root"
  for child in "${temp_children[@]}"; do
    add_target "$build_root/$child" "${build_root%/DerivedData}"
  done
done
printf '  Built app products, build logs, and metadata are preserved.\n'

add_target "$xet_chunks" "$xet_root"
printf '  Upload staging and the Hugging Face Hub cache are preserved.\n'

if (( ! caches_only )); then
  if check_keeper; then
    for item in "${old_devices[@]}"; do
      add_target "$item"
    done
    printf '  Keeping %s\n' "$keeper"
    printf '  Keeping %s because its symbols report 27.1 and differ from 24A446.\n' "$held"
    printf '  Older crash reports may require the exact symbols listed above.\n'
  else
    printf '  Skipping older symbols because the retained 27.0.1 symbol cache could not be verified.\n'
  fi
fi

printf '\n%d eligible directories, approximately %s before APFS sharing.\n' \
  "${#targets[@]}" "$(format_size "$total_kib")"

if [[ "$mode" == --preview ]]; then
  print_targets "${!targets[@]}"
  if (( ${#targets[@]} > 0 )) && ! check_open_files "${activity_roots[@]}"; then
    printf 'Close the listed processes before changing these paths.\n'
  fi
  printf 'Preview only. Use --help for the interactive move and delete modes.\n'
  exit 0
fi

completed=()
completed_kib=0
if [[ "$operation" == delete ]]; then
  choose_verb='Permanently delete'
  choose_destination=''
  selection_title='Paths selected for permanent deletion'
  summary_title='Deletion'
  completed_verb='deleted'
else
  choose_verb='Move'
  choose_destination=' to the holding folder'
  selection_title='Paths selected for the holding folder'
  summary_title='Move'
  completed_verb='moved'
fi
trap print_action_summary EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
(( ${#targets[@]} > 0 )) || exit 0

selected=()
selected_roots=()
selected_kib=0
printf '\nChoose a group or path. Press Enter for no. For a group, s lets you choose individual paths.\n'
printf 'Finish active builds and transfers, and quit Xcode before removing device symbols.\n'
index=0
while (( index < ${#targets[@]} )); do
  if is_build_group "$index"; then
    group_root=${activity_roots[$index]}
    group_indices=()
    while (( index < ${#targets[@]} )) && [[ "${activity_roots[$index]}" == "$group_root" ]]; do
      group_indices+=("$index")
      (( index += 1 ))
    done
    choose_build_group "$group_root" "${group_indices[@]}"
  else
    choose_path "$index" "${targets[$index]}"
    (( index += 1 ))
  fi
done
if (( ${#selected[@]} == 0 )); then
  printf 'No paths selected.\n'
  exit 0
fi
check_open_files "${selected_roots[@]}" ||
  stop 'Cancelled before final confirmation. Close the affected processes and run again.'

printf '\n%s\n' "$selection_title"
print_targets "${selected[@]}"
printf '%d directories, approximately %s.\n' "${#selected[@]}" "$(format_size "$selected_kib")"
if [[ "$operation" == hold ]]; then
  printf 'Holding folder: %s\n' "$holding_root"
fi

# Discard type-ahead so the final approval is entered after the summary.
/usr/bin/perl -MPOSIX=tcflush,TCIFLUSH -e '
  my $result = tcflush(fileno(STDIN), TCIFLUSH);
  exit(defined($result) && $result == 0 ? 0 : 1);
' || stop 'Could not clear pending terminal input. No files were changed.'
printf 'Final confirmation. Proceed with the listed paths? [y/N] '
IFS= read -r answer || stop 'Cancelled. No files were changed.'
[[ "$answer" == y ]] || stop 'Cancelled. No files were changed.'

check_open_files "${selected_roots[@]}" ||
  stop 'Cancelled after confirmation. Close the affected processes and run again.'
if [[ "$operation" == hold ]]; then
  identity "$holding_parent" >/dev/null || stop 'Could not verify the holding folder’s parent.'
fi
for index in "${selected[@]}"; do
  item=${targets[$index]}
  is_reviewed_target "$item" || stop "Path is outside the reviewed list: $item"
  [[ "$(identity "$item")" == "${identities[$index]}" ]] || stop "Directory changed after preview: $item"
  check_nested_mounts "$item"
  if [[ "$operation" == hold ]]; then
    check_holding_volume "$item" "$holding_parent"
  fi
done

if [[ "$operation" == hold ]]; then
  prepare_holding_folder
fi

for index in "${selected[@]}"; do
  item=${targets[$index]}
  is_reviewed_target "$item" || stop "Path is outside the reviewed list: $item"
  check_open_files "${activity_roots[$index]}" || stop "Path is in use: $item"
  [[ "$(identity "$item")" == "${identities[$index]}" ]] || stop "Directory changed after preview: $item"
  protected=$(protected_entry "$item") || stop "Could not check contents: $item"
  [[ -z "$protected" ]] || stop "Protected entry found: $protected"
  kib=$(measure_kib "$item") || stop "Could not remeasure: $item"
  [[ "$kib" == "${sizes_kib[$index]}" ]] || stop "Size changed after preview: $item. Run the preview again."
  check_nested_mounts "$item"
  if [[ "$item" == "$device_root/"* ]]; then
    check_keeper || stop 'The retained device symbol cache changed.'
  fi
  [[ "$(identity "$item")" == "${identities[$index]}" ]] || stop "Directory changed after preview: $item"
  if [[ "$operation" == delete ]]; then
    /bin/rm -rfx -- "$item" || stop "Deletion failed or was incomplete: $item"
    [[ ! -e "$item" && ! -L "$item" ]] || stop "Deletion was incomplete: $item"
  else
    move_to_holding "$item"
  fi
  completed+=("$index")
  completed_kib=$((completed_kib + kib))
done
