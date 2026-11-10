#!/bin/bash
# PreToolUse(Bash) hook — blocks `git push` when the commits being pushed
#   * ADD generated/scratch files (coverage.out, *.prof, *.test, .DS_Store, scratch dirs, files > 1 MB), or
#   * TOUCH .gitignore / lint configs (.golangci.y*ml, .markdownlint*, docs/.vale/**, ...).
# MRs carry logic-related changes only. Override (the USER's call, never the agent's): ALLOW_PUSH_SCOPE=1.
#
# Contract: stdin = PreToolUse JSON; exit 2 + stderr = block (stderr is fed back to the agent);
# exit 0 = allow. Fails OPEN on anything it cannot parse. Local git only, no network.

MAX_BYTES=${PUSH_SCOPE_MAX_BYTES:-1048576}
EMPTY_TREE=4b825dc642cb6eb9a060e54bf8d69288fbee4904
SEP=$'\x1f'

command -v perl >/dev/null 2>&1 || exit 0   # perl (not jq) parses the JSON: the mise jq shim costs ~100ms per call

INPUT=$(cat)

# Cheap pre-filter on the raw JSON.
case "$INPUT" in *push*) ;; *) exit 0 ;; esac

# --- Parse the command: emit one record per real `git push` invocation ---------------------------
# Handles quotes, heredocs, redirections, `cd X &&`, `git -C X`, env prefixes, `mise exec --`.
# Record: dir SEP override SEP remote SEP refspecs(space-joined)
analyze() {
  PWD_FALLBACK="$PWD" perl -MJSON::PP -e '
    use strict; use warnings;
    my $req = eval { decode_json(do { local $/; <STDIN> }) } or exit 0;
    my $cmd = $req->{tool_input}{command} // ""; exit 0 unless length $cmd;
    my ($home, $sep) = ($ENV{HOME} // "", "\x1f");
    my (@segs, @words, @heredocs); my ($cur, $in, $skip) = ("", 0, 0);
    my ($i, $n) = (0, length $cmd);
    my $flush_word = sub { if ($in) { if ($skip) { $skip = 0 } else { push @words, $cur } $cur = ""; $in = 0 } };
    my $flush_seg  = sub { $flush_word->(); if (@words) { push @segs, [@words]; @words = () } };
    while ($i < $n) {
      my $c = substr($cmd, $i, 1);
      if ($c eq "\x27") { my $j = index($cmd, "\x27", $i + 1); $j = $n if $j < 0;
        $cur .= substr($cmd, $i + 1, $j - $i - 1); $in = 1; $i = $j + 1; next }
      if ($c eq "\"") { my ($j, $buf) = ($i + 1, "");
        while ($j < $n) { my $d = substr($cmd, $j, 1);
          if ($d eq "\\" && $j + 1 < $n) { $buf .= substr($cmd, $j + 1, 1); $j += 2; next }
          last if $d eq "\""; $buf .= $d; $j++ }
        $cur .= $buf; $in = 1; $i = $j + 1; next }
      if ($c eq "\\" && $i + 1 < $n) { $cur .= substr($cmd, $i + 1, 1); $in = 1; $i += 2; next }
      if (substr($cmd, $i, 2) eq "<<" && substr($cmd, $i, 3) ne "<<<"
          && substr($cmd, $i) =~ /\A<<-?\s*(?:\x27([^\x27]+)\x27|"([^"]+)"|(\w+))/) {
        push @heredocs, $1 // $2 // $3; $i += length($&); next }
      if ($c eq "\n") { $flush_seg->(); $i++;
        while (defined(my $d = shift @heredocs)) {
          while ($i < $n) { my $e = index($cmd, "\n", $i); $e = $n if $e < 0;
            my $line = substr($cmd, $i, $e - $i); $i = $e + 1; $line =~ s/^\s+|\s+$//g; last if $line eq $d } }
        next }
      if ($c eq "&" && substr($cmd, $i + 1, 1) eq ">") { $i++; $c = ">" }          # &> redirect
      if ($c =~ /[<>]/) {
        if ($in && $cur =~ /^\d+$/) { $cur = ""; $in = 0 } else { $flush_word->() }   # 2> : drop fd number
        $i++; $i++ while $i < $n && substr($cmd, $i, 1) =~ /[<>]/;
        if (substr($cmd, $i, 1) eq "&") { $i++; $i++ while $i < $n && substr($cmd, $i, 1) =~ /[\d-]/ }  # >&2
        else { $skip = 1 }                                                               # next word = target file
        next }
      if ($c =~ /[;&|()]/) { $flush_seg->(); $i++; $i++ if substr($cmd, $i, 1) eq $c && $c =~ /[&|]/; next }
      if ($c =~ /\s/) { $flush_word->(); $i++; next }
      $cur .= $c; $in = 1; $i++;
    }
    $flush_seg->();
    my $resolve = sub { my ($base, $p) = @_; $p =~ s/^~(?=\/|$)/$home/;
      return $p if $p =~ m{^/}; return "$base/$p" };
    my $dir = $req->{cwd} || $ENV{PWD_FALLBACK} || ".";
    for my $seg (@segs) {
      my @w = @$seg; my %env;
      my $assign = sub { while (@w && $w[0] =~ /^([A-Za-z_]\w*)=(.*)$/s) { $env{$1} = $2; shift @w } };
      $assign->();
      while (@w) {
        if ($w[0] =~ /^(env|command|time|nice|exec)$/) { shift @w; $assign->(); next }
        if ($w[0] eq "mise" && @w > 1 && $w[1] eq "exec") {
          my $k = 2; $k++ while $k < @w && $w[$k] ne "--";
          if ($k < @w) { @w = @w[($k + 1) .. $#w]; next } }
        last }
      next unless @w;
      if ($w[0] eq "cd" || $w[0] eq "pushd") { $dir = $resolve->($dir, $w[1]) if defined $w[1] && $w[1] ne "-"; next }
      next unless $w[0] eq "git";
      shift @w; my $gd = $dir;
      while (@w && $w[0] =~ /^-/) { my $o = shift @w;
        if ($o eq "-C") { my $p = shift @w; $gd = $resolve->($gd, $p) if defined $p }
        elsif ($o =~ /^(-c|--git-dir|--work-tree|--namespace)$/) { shift @w } }
      next unless @w && $w[0] eq "push"; shift @w;
      my ($dry, $del, @pos) = (0, 0);
      while (@w) { my $a = shift @w;
        if    ($a =~ /^(--dry-run|-n)$/)   { $dry = 1 }
        elsif ($a =~ /^(--delete|-d)$/)    { $del = 1 }
        elsif ($a =~ /^(-o|--push-option|--repo|--receive-pack|--exec)$/) { shift @w }
        elsif ($a =~ /^-/)                 { }
        else                               { push @pos, $a } }
      next if $dry || $del;
      my $ov = (defined $env{ALLOW_PUSH_SCOPE} && $env{ALLOW_PUSH_SCOPE} !~ /^(0|)$/) ? 1 : 0;
      my $remote = shift @pos // "";
      print join($sep, $gd, $ov, $remote, join(" ", @pos)), "\n";
    }'
}

# --- File classification -------------------------------------------------------------------------
is_generated() {  # $1 = path
  local p=$1 b=${1##*/}
  case "$b" in
    coverage.out|coverage.txt|coverage.html|coverage.xml|coverage.json|coverage-*|cover.out|cover.html|\
    cpu.out|mem.out|c.out|profile.out|lcov.info|.coverage|\
    *.prof|*.pprof|*.test|.DS_Store|*.orig|*.rej|*.swp|*~|*.pyc) return 0 ;;
  esac
  case "/$p" in
    */tmp/*|*/.tmp/*|*/scratch/*|*/scratchpad/*|*/.scratch/*|*/.claude/worktrees/*|*/node_modules/*|*/.idea/*|*/__pycache__/*) return 0 ;;
  esac
  return 1
}

is_config() {  # $1 = path
  local p=$1 b=${1##*/}
  case "$b" in
    .gitignore|.golangci.y*ml|.golangci.toml|.golangci.json|.markdownlint*|.eslintrc*|\
    .rubocop*.yml|.shellcheckrc|.yamllint*|.vale.ini) return 0 ;;
  esac
  case "/$p" in */docs/.vale/*|/.vale/*) return 0 ;; esac
  return 1
}

# --- Check one push ------------------------------------------------------------------------------
check_push() {  # dir override remote refspecs
  local dir=$1 override=$2 specs=$4
  [ "$override" = 1 ] && return 0
  [ -d "$dir" ] || return 0
  git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || return 0

  local -a srcs=()
  local s
  for s in $specs; do
    s=${s#+}; s=${s%%:*}
    [ -n "$s" ] && srcs+=("$s")
  done
  [ ${#srcs[@]} -gt 0 ] || srcs=(HEAD)

  # Which remote's refs count as "already published": the named remote, else the branch's, else all.
  local rname=$3 br
  if [ -z "$rname" ]; then
    br=$(git -C "$dir" symbolic-ref -q --short HEAD 2>/dev/null) && rname=$(git -C "$dir" config "branch.$br.remote" 2>/dev/null)
  fi
  local -a rargs=(--remotes)
  if [ -n "$rname" ] && git -C "$dir" remote 2>/dev/null | grep -Fxq -- "$rname"; then rargs=("--remotes=$rname"); fi

  local src tip oldest base
  local -a gen=() cfg=() big=() batch=() touched=() added=()
  for src in "${srcs[@]}"; do
    tip=$(git -C "$dir" rev-parse --verify -q "${src}^{commit}" 2>/dev/null) || continue

    # Only the commits NOT yet on the remote. Never merge-base(@{u}, tip): after a rebase that is the OLD fork
    # point and the diff would blame the MR for everything main changed in between.
    oldest=$(git -C "$dir" rev-list --reverse --topo-order "$tip" --not "${rargs[@]}" 2>/dev/null | head -n1)
    [ -n "$oldest" ] || continue
    base=$(git -C "$dir" rev-parse --verify -q "${oldest}^" 2>/dev/null) || base=$EMPTY_TREE

    # Paths touched by those commits themselves (no merges: what a merge pulled in from main is not the MR's).
    local st path
    while IFS= read -r -d '' st && IFS= read -r -d '' path; do
      touched+=("$path")
      [ "$st" = A ] && added+=("$path")
    done < <(git -C "$dir" log --no-merges --no-renames --name-status -z --format= "$tip" --not "${rargs[@]}" 2>/dev/null)
    [ ${#touched[@]} -gt 0 ] || continue
    local tset aset nl=$'\n'
    tset=$nl$(printf '%s\n' "${touched[@]}" | sort -u)$nl
    aset=$nl$(printf '%s\n' "${added[@]}" | sort -u)$nl

    # Net effect base..tip, restricted to those paths (add-then-remove or edit-then-revert in one push = no finding).
    local meta mode sha status
    while IFS= read -r -d '' meta && IFS= read -r -d '' path; do
      case "$tset" in *"$nl$path$nl"*) ;; *) continue ;; esac
      status=${meta: -1}; mode=${meta:8:6}; sha=$(awk '{print $4}' <<<"$meta")
      is_config "$path" && cfg+=("$path ($status)")
      if [ "$status" != D ]; then
        if [ "$status" = A ]; then
          case "$aset" in *"$nl$path$nl"*) is_generated "$path" && gen+=("$path") ;; esac
        fi
        [ "$mode" != 160000 ] && batch+=("$sha $path")
      fi
    done < <(git -C "$dir" diff --raw --no-abbrev --no-renames -z "$base" "$tip" 2>/dev/null)

    local size rest
    if [ ${#batch[@]} -gt 0 ]; then
      while read -r size rest; do
        [[ $size =~ ^[0-9]+$ ]] && [ "$size" -gt "$MAX_BYTES" ] && big+=("$rest ($((size / 1024)) KiB)")
      done < <(printf '%s\n' "${batch[@]}" | git -C "$dir" cat-file --batch-check='%(objectsize) %(rest)' 2>/dev/null)
    fi
  done

  [ $(( ${#gen[@]} + ${#cfg[@]} + ${#big[@]} )) -eq 0 ] && return 0

  {
    echo "BLOCKED by pre-push-scope: this push would publish files outside the MR's logic scope."
    [ ${#gen[@]} -gt 0 ] && { echo "Generated/scratch files added:"; printf '  %s\n' "${gen[@]}"; }
    [ ${#big[@]} -gt 0 ] && { echo "Files larger than $((MAX_BYTES / 1024)) KiB:"; printf '  %s\n' "${big[@]}"; }
    [ ${#cfg[@]} -gt 0 ] && { echo ".gitignore / lint config changed:"; printf '  %s\n' "${cfg[@]}"; }
    echo "Only files changed by YOUR unpushed commits are listed. Never revert changes that came from the base branch."
    echo "Fix: remove them from your commits (git rm --cached <file>, amend or fixup) and push again."
    echo "If the user explicitly wants them in this push, only the user may approve: re-run with ALLOW_PUSH_SCOPE=1 git push ..."
  } >&2
  return 1
}

rc=0
while IFS=$SEP read -r dir override remote specs; do
  [ -n "$dir" ] || continue
  [ -n "${ALLOW_PUSH_SCOPE:-}" ] && [ "${ALLOW_PUSH_SCOPE}" != 0 ] && override=1
  check_push "$dir" "$override" "$remote" "$specs" || rc=2
done < <(printf '%s' "$INPUT" | analyze 2>/dev/null)

exit $rc
