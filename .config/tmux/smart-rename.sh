#!/usr/bin/env zsh
# Renames each tmux window to the minimum path suffix that makes it unique
# e.g. two windows at foo/api and bar/api become "foo/api" and "bar/api"
# Preserves [prefix] in window name across renames, e.g. "[api] foo/bar"
# Usage: smart-rename.sh [current_path]
#   current_path: override the active pane's path (used when called from chpwd
#                 before tmux has updated #{pane_current_path})

tmux=/opt/homebrew/bin/tmux
override_path="${1:-}"

LOG_FILE="${TMUX_RENAME_LOG:-/tmp/tmux-rename.log}"
log() { [[ -n "$LOG_FILE" ]] && echo "[$(/bin/date '+%H:%M:%S')] $*" >> "$LOG_FILE" }

session=$($tmux display-message -p '#S' 2>/dev/null) || exit 1
active_idx=$($tmux display-message -p '#{window_index}' 2>/dev/null)

log "--- triggered | session=$session active=$active_idx override=${override_path:-none}"

typeset -A win_paths
typeset -A win_prefixes
while IFS='|' read -r idx name path; do
    [[ -n "$idx" && -n "$path" ]] || continue
    win_paths[$idx]="$path"
    # Extract [prefix] if present at start of window name
    if [[ "$name" =~ '^(\[[^]]+\])' ]]; then
        win_prefixes[$idx]="${match[1]} "
    fi
done < <($tmux list-windows -t "$session" -F '#{window_index}|#{window_name}|#{pane_current_path}' 2>/dev/null)

# Override active window's path if provided (chpwd fires before tmux updates it)
[[ -n "$override_path" && -n "$active_idx" ]] && win_paths[$active_idx]="$override_path"

[[ ${#win_paths} -eq 0 ]] && log "no windows found, exiting" && exit 0

log "windows: $(for i in ${(k)win_paths}; do printf '%s=%s(prefix=%s) ' $i ${win_paths[$i]} ${win_prefixes[$i]:-none}; done)"

for idx in ${(k)win_paths}; do
    path="${win_paths[$idx]}"
    prefix="${win_prefixes[$idx]:-}"
    parts=("${(@s:/:)${path#/}}")
    n=${#parts[@]}
    [[ $n -eq 0 ]] && continue

    for (( depth = 1; depth <= n; depth++ )); do
        start=$((n - depth + 1))
        candidate="${(j:/:)parts[$start,-1]}"

        clash=false
        for other_idx in ${(k)win_paths}; do
            [[ "$other_idx" == "$idx" ]] && continue
            oparts=("${(@s:/:)${win_paths[$other_idx]#/}}")
            on=${#oparts[@]}
            ostart=$((on - depth + 1))
            [[ $ostart -lt 1 ]] && ostart=1
            ocandidate="${(j:/:)oparts[$ostart,-1]}"
            [[ "$candidate" == "$ocandidate" ]] && clash=true && break
        done

        if [[ "$clash" == false ]]; then
            log "  window $idx: '$path' -> '${prefix}${candidate}'"
            $tmux rename-window -t "$session:$idx" "${prefix}${candidate}" 2>/dev/null
            break
        else
            log "  window $idx: '$candidate' clashes at depth=$depth, trying deeper"
        fi
    done

    # All depths clashed — paths are identical, just use the last component
    if (( depth > n )); then
        candidate="${parts[-1]}"
        log "  window $idx: '$path' -> '${prefix}${candidate}' (identical paths, using last component)"
        $tmux rename-window -t "$session:$idx" "${prefix}${candidate}" 2>/dev/null
    fi
done
