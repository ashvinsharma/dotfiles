#!/usr/bin/env bash
# Fixture tests for the /cleanup scripts. Touches nothing real: every repo, transcript, note and
# GitLab response is a throwaway fixture. glab/herdr are replaced via GLAB_CMD / HERDR_CMD.
# Each run writes into a fresh directory under $WF_TEST_ROOT and leaves it there (never deleted).
#
#   bash ~/.claude/skills/cleanup/tests/run-tests.sh
# shellcheck disable=SC2016,SC2015  # single-quoted literals are matched verbatim; A && B || C is deliberate
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HERE/../bin"
WF_TEST_ROOT="${WF_TEST_ROOT:-$HOME/.claude/jobs/0dc4dc6e/tmp/wf-test}"
FX="$WF_TEST_ROOT/cleanup-run-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$FX/glab" "$FX/projects" "$FX/ws/gitlab-org" "$FX/artifacts"
FX="$(cd "$FX" && pwd -P)"

pass=0 fail=0
ok()   { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; }
has()  { if grep -qF -e "$2" <<<"$1"; then ok "$3"; else bad "$3  (missing: $2)"; printf '%s\n' "$1" | sed 's/^/       | /' | head -30; fi; }
hasnt(){ if grep -qF -e "$2" <<<"$1"; then bad "$3  (unexpected: $2)"; else ok "$3"; fi; }
eq()   { if [[ "$1" == "$2" ]]; then ok "$3"; else bad "$3  (got '$1', want '$2')"; fi; }

# ---- fake glab: GET only, answers from $FX/glab -----------------------------------------------
cat >"$FX/fake-glab.sh" <<'EOF'
#!/usr/bin/env bash
# usage: fake-glab.sh api <path> [--paginate]   — anything but GET-style `api` is an error
G="$(dirname "${BASH_SOURCE[0]}")/glab"
[[ "${1:-}" == api ]] || { echo "fake-glab: only 'api' is supported" >&2; exit 2; }
p="${2:-}"
case "$p" in
  user) cat "$G/user.json" ;;
  merge_requests\?author_username=*) cat "$G/list.json" ;;
  projects/*/merge_requests/*/discussions*) n="${p#*merge_requests/}"; n="${n%%/*}"; cat "$G/disc-$n.json" ;;
  projects/*/merge_requests\?source_branch=*)
    b="${p#*source_branch=}"; b="${b%%&*}"; b="${b//%2F/_}"
    if [[ -f "$G/by-branch-$b.json" ]]; then cat "$G/by-branch-$b.json"; else echo '[]'; fi ;;
  projects/*/repository/commits/*/merge_requests)
    s="${p#*commits/}"; s="${s%%/*}"
    if [[ -f "$G/commit-$s.json" ]]; then cat "$G/commit-$s.json"; else echo '[]'; fi ;;
  projects/*/merge_requests/*) n="${p##*/}"; if [[ -f "$G/mr-$n.json" ]]; then cat "$G/mr-$n.json"; else exit 1; fi ;;
  projects/*/issues/*) n="${p##*/}"; if [[ -f "$G/issue-$n.json" ]]; then cat "$G/issue-$n.json"; else exit 1; fi ;;
  *) echo "fake-glab: unmapped path: $p" >&2; exit 1 ;;
esac
EOF
export GLAB_CMD="bash $FX/fake-glab.sh"
export CLEANUP_STATE_FILE="$FX/state.json"
export CLAUDE_PROJECTS_DIR="$FX/projects"
export WORKSPACE_ROOT="$FX/ws"
export ARTIFACTS_ROOT="$FX/artifacts"
echo "fixtures: $FX"

# =================================================================================================
echo "== cleanup-state"
eq "$(bash "$BIN/cleanup-state" get)" "" "get is empty before any confirm"
out="$(bash "$BIN/cleanup-state" confirm 2026-11-10T09:00:00Z)"
has "$out" "last_confirmed=2026-11-10T09:00:00Z" "confirm records the given timestamp"
eq "$(bash "$BIN/cleanup-state" get)" "2026-11-10T09:00:00Z" "get returns it"
if bash "$BIN/cleanup-state" confirm "yesterday" >/dev/null 2>&1; then bad "bad timestamp rejected"; else ok "bad timestamp rejected"; fi
eq "$(bash "$BIN/cleanup-state" get)" "2026-11-10T09:00:00Z" "failed confirm left the state alone"

# =================================================================================================
echo "== cleanup-mrs"
echo '{"username":"tester"}' >"$FX/glab/user.json"
cat >"$FX/glab/list.json" <<'EOF'
[
 {"state":"merged","merged_at":"2026-10-25T10:00:00.000Z","iid":7001,"source_branch":"feat/a","title":"A\ttabbed","web_url":"https://gitlab.com/g/p/-/merge_requests/7001","references":{"full":"g/p!7001"}},
 {"state":"merged","merged_at":"2026-11-02T10:00:00.000Z","iid":55,"source_branch":"feat/b","title":"B","web_url":"https://gitlab.com/g/sub/q/-/merge_requests/55","references":{"full":"g/sub/q!55"}},
 {"state":"merged","merged_at":"2026-09-01T10:00:00.000Z","iid":1,"source_branch":"old","title":"updated recently, merged long ago","web_url":"u","references":{"full":"g/p!1"}},
 {"state":"opened","merged_at":null,"iid":9,"source_branch":"open","title":"open","web_url":"u","references":{"full":"g/p!9"}}
]
EOF
cat >"$FX/glab/mr-6781.json" <<'EOF'
{"state":"merged","merged_at":"2026-08-20T14:58:04.192Z","iid":6781,"source_branch":"x/old","title":"Explicit older MR","web_url":"https://gitlab.com/g/p/-/merge_requests/6781","references":{"full":"g/p!6781"}}
EOF
out="$(bash "$BIN/cleanup-mrs" --since 2026-10-20T00:00:00Z)"
eq "$(grep -c . <<<"$out")" "2" "only merged MRs after --since (client-side merged_at filter)"
has "$out" $'g/sub/q\t55\tfeat/b' "subgroup project path, iid and branch parsed"
has "$out" "A tabbed" "tabs in titles are flattened"
hasnt "$out" $'\t9\topen' "open MR excluded"
out="$(bash "$BIN/cleanup-mrs" --since 2026-10-20T00:00:00Z --mr 'g/p!6781')"
has "$out" $'g/p\t6781\tx/old' "--mr adds an explicit older merged MR"
eq "$(cut -f3 <<<"$out" | head -1)" "6781" "output is oldest first"
out="$(bash "$BIN/cleanup-mrs")"   # state file says 2026-11-10T09:00:00Z -> nothing newer
eq "$out" "" "default --since comes from cleanup-state"

# =================================================================================================
echo "== cleanup-threads"
cat >"$FX/glab/disc-7646.json" <<'EOF'
[
 {"id":"aaaaaaaa11111111","notes":[
   {"system":false,"author":{"username":"rev1"},"body":"Please don't   commit coverage.out","resolvable":true,"resolved":true,"position":{"new_path":"a/b.go","new_line":12}},
   {"system":false,"author":{"username":"tester"},"body":"Done, removed.","resolvable":true,"resolved":true,"position":{"new_path":"a/b.go","new_line":12}}]},
 {"id":"bbbbbbbb22222222","notes":[
   {"system":false,"author":{"username":"project_250833_bot_deadbeef"},"body":"Danger: MR title too long","resolvable":false}]},
 {"id":"cccccccc33333333","notes":[
   {"system":false,"author":{"username":"GitLabDuo"},"body":"Consider a nil check here","resolvable":true,"resolved":false,"position":{"new_path":"c.go","new_line":3}}]},
 {"id":"dddddddd44444444","notes":[
   {"system":true,"author":{"username":"rev1"},"body":"added 1 commit"}]},
 {"id":"eeeeeeee55555555","notes":[
   {"system":false,"author":{"username":"tester"},"body":"my own thread, nobody replied","resolvable":false}]},
 {"id":"ffffffff66666666","notes":[
   {"system":false,"author":{"username":"duo-fix-ci-cd-pipeline-gitlab-org"},"body":"CI fix suggestion","resolvable":false}]}
]
EOF
out="$(bash "$BIN/cleanup-threads" g/p 7646)"
has "$out" "### [human] a/b.go:12 · resolved · aaaaaaaa" "human thread: location, resolved state, id"
has "$out" "> @rev1: Please don't commit coverage.out" "whitespace collapsed in body"
has "$out" "↳ @tester (you): Done, removed." "own reply shown as reply"
has "$out" "### [bot] general" "Danger/project bot classified as bot"
has "$out" "### [duo] c.go:3 · OPEN" "GitLabDuo classified separately, open state kept"
has "$out" "### [duo] general" "duo-fix-ci-cd agent classified as duo"
hasnt "$out" "added 1 commit" "system notes dropped"
hasnt "$out" "my own thread" "self-only threads hidden by default"
has "$(bash "$BIN/cleanup-threads" g/p 7646 --include-self)" "my own thread" "--include-self shows them"
h="$(grep -n '\[human\]' <<<"$out" | head -1 | cut -d: -f1)"; b="$(grep -n '\[bot\]' <<<"$out" | head -1 | cut -d: -f1)"; d="$(grep -n '\[duo\]' <<<"$out" | head -1 | cut -d: -f1)"
if (( h < b && b < d )); then ok "ordered human → bot → duo"; else bad "ordering ($h,$b,$d)"; fi
has "$out" "authors: " "author counts footer present"

# =================================================================================================
echo "== cleanup-note"
N="$FX/artifacts/workflow-artifacts/g/workitem-1/p/mr-9"
mkdir -p "$N" "$FX/artifacts/workflow-artifacts/g/p/issue-4" \
         "$FX/artifacts/workflow-artifacts/g/workitem-2/fleeting-taskscaler/mr-118" "$FX/artifacts/workflow-artifacts/g/workitem-2/other/mr-118"
printf -- '---\nkind: mr\nref: g/p!9\nstatus: opened\nlast_updated: 2026-01-01\n---\n\n# Goal\nkeep me\n' >"$N/NOTE.md"
printf -- '---\nkind: issue\nref: g/p#4\n---\nbody\n' >"$FX/artifacts/workflow-artifacts/g/p/issue-4/NOTE.md"
printf 'no frontmatter\n' >"$FX/artifacts/workflow-artifacts/g/p/issue-4/OTHER.md"
printf -- '---\nkind: mr\nref: "g/fleeting/taskscaler!118"\nstatus: opened\n---\nA\n' >"$FX/artifacts/workflow-artifacts/g/workitem-2/fleeting-taskscaler/mr-118/NOTE.md"
printf -- '---\nkind: mr\nref: g/other!118\nstatus: opened\n---\nB ref: g/fleeting/taskscaler!118 in the body\n' >"$FX/artifacts/workflow-artifacts/g/workitem-2/other/mr-118/NOTE.md"
eq "$(bash "$BIN/cleanup-note" find 'g/p!9' | sed "s#$FX/artifacts/##")" "workflow-artifacts/g/workitem-1/p/mr-9/NOTE.md" "find by ref"
eq "$(bash "$BIN/cleanup-note" find 'g/p!99')" "" "find with no match is empty"
eq "$(bash "$BIN/cleanup-note" find 'g/fleeting/taskscaler!118' | sed "s#$FX/artifacts/##")" "workflow-artifacts/g/workitem-2/fleeting-taskscaler/mr-118/NOTE.md" "same mr-118 dir name in two projects: only the matching ref (quoted ref value too)"
eq "$(bash "$BIN/cleanup-note" find 'g/other!118' | sed "s#$FX/artifacts/##")" "workflow-artifacts/g/workitem-2/other/mr-118/NOTE.md" "…and the other one (a ref in a note BODY is ignored)"
eq "$(bash "$BIN/cleanup-note" find 'g/p#4' | sed "s#$FX/artifacts/##")" "workflow-artifacts/g/p/issue-4/NOTE.md" "find an issue note by #ref"
if bash "$BIN/cleanup-note" find 'not-a-ref' >/dev/null 2>&1; then bad "malformed ref rejected"; else ok "malformed ref rejected"; fi
bash "$BIN/cleanup-note" status "$N/NOTE.md" merged >/dev/null
note="$(cat "$N/NOTE.md")"
has "$note" "status: merged" "status updated"
has "$note" "last_updated: $(date +%F)" "last_updated bumped"
has "$note" "keep me" "body untouched"
eq "$(grep -c '^status:' "$N/NOTE.md")" "1" "no duplicate status key"
I="$FX/artifacts/workflow-artifacts/g/p/issue-4/NOTE.md"
bash "$BIN/cleanup-note" status "$I" closed >/dev/null
has "$(cat "$I")" "status: closed" "missing status key is added inside frontmatter"
eq "$(sed -n '1p;$p' "$I" | head -1)" "---" "frontmatter fence intact"
if bash "$BIN/cleanup-note" status "$FX/artifacts/workflow-artifacts/g/p/issue-4/OTHER.md" merged >/dev/null 2>&1; then bad "no-frontmatter file refused"; else ok "no-frontmatter file refused"; fi
if bash "$BIN/cleanup-note" status "$N/NOTE.md" bogus >/dev/null 2>&1; then bad "bad status refused"; else ok "bad status refused"; fi

# =================================================================================================
echo "== cleanup-issue-state"
echo '{"iid":77,"state":"closed"}' >"$FX/glab/issue-77.json"
eq "$(bash "$BIN/cleanup-issue-state" g/p 77)" "closed" "issue state printed"
if bash "$BIN/cleanup-issue-state" g/p abc >/dev/null 2>&1; then bad "non-numeric iid rejected"; else ok "non-numeric iid rejected"; fi

# =================================================================================================
echo "== cleanup-digest"
enc() { printf '%s' "$1" | sed -E 's/[^A-Za-z0-9]/-/g'; }
REPO="$FX/ws/gitlab-org/demo"
mkdir -p "$REPO"
git -C "$REPO" init -q -b main
git -C "$REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
git -C "$REPO" remote add origin git@gitlab.com:gitlab-org/demo.git
WT="$REPO/.claude/worktrees/x-work"           # dir name != branch name, like the real layout
git -C "$REPO" worktree add -q "$WT" -b feat/x
mkdir -p "$FX/projects/$(enc "$WT")" "$FX/projects/$(enc "$REPO")"
rec() { # type branch sid ts json-fragment-for-message
  printf '{"type":"%s","isSidechain":false,"gitBranch":%s,"sessionId":"%s","timestamp":"%s","message":%s}\n' "$1" "$2" "$3" "$4" "$5"
}
{
  rec user null sessB 2026-11-03T10:00:00.000Z '{"role":"user","content":"Task: get the pipeline green. <huge paste here>"}'
  rec assistant null sessB 2026-11-03T10:01:00.000Z '{"role":"assistant","content":[{"type":"text","text":"on it"},{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"git push origin feat/x"}}]}'
  rec user null sessB 2026-11-03T10:01:05.000Z '{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","is_error":true,"content":"The user doesn'"'"'t want to proceed with this tool use."}]}'
  rec user null sessB 2026-11-03T10:02:00.000Z '{"role":"user","content":"no, don'"'"'t push generated files like coverage.out"}'
  for i in 1 2 3 4; do
    rec assistant null sessB 2026-11-03T10:0${i}:30.000Z '{"role":"assistant","content":[{"type":"tool_use","id":"u'$i'","name":"Bash","input":{"command":"go test ./helpers/..."}}]}'
    rec user null sessB 2026-11-03T10:0${i}:40.000Z '{"role":"user","content":[{"type":"tool_result","tool_use_id":"u'$i'","content":"--- FAIL: TestThing (0.00s)\nFAIL"}]}'
  done
  rec assistant null sessB 2026-11-03T10:09:00.000Z '{"role":"assistant","content":[{"type":"text","text":"Fixed; pipeline green."}]}'
} >"$FX/projects/$(enc "$WT")/sessB.jsonl"
{ # main-checkout session spanning two branches: only feat/x records may appear
  rec user '"feat/x"' sessA 2026-11-02T09:00:00.000Z '{"role":"user","content":"start on feat/x work"}'
  rec user '"feat/other"' sessA 2026-11-02T09:30:00.000Z '{"role":"user","content":"UNRELATED prompt on another branch"}'
  rec user '"feat/x"' sessA 2026-11-02T09:40:00.000Z '{"role":"user","content":"why did you add .gitignore changes"}'
} >"$FX/projects/$(enc "$REPO")/sessA.jsonl"
{ rec user '"feat/other"' sessC 2026-11-02T08:00:00.000Z '{"role":"user","content":"OTHER BRANCH ONLY SESSION"}'
} >"$FX/projects/$(enc "$REPO")/sessC.jsonl"

list="$(bash "$BIN/cleanup-digest" --branch feat/x --repo "$REPO" --list)"
has "$list" "sessB.jsonl" "worktree-dir session found although its records carry gitBranch=null"
has "$list" "sessA.jsonl" "main-checkout session found via gitBranch grep"
hasnt "$list" "sessC.jsonl" "session of another branch excluded"
out="$(bash "$BIN/cleanup-digest" --branch feat/x --repo "$REPO")"
has "$out" "⚠ - no, don't push generated files" "user correction flagged"
has "$out" "⚠ - why did you add .gitignore changes" "second correction flagged"
hasnt "$out" "UNRELATED prompt" "records of other branches filtered out of a shared-checkout session"
has "$out" "### Tool calls the user rejected" "rejected tool calls listed"
has "$out" '`git push origin feat/x`' "rejected command named"
has "$out" "×4 \`go test ./helpers/...\`" "command run 4× reported"
has "$out" "--- FAIL: TestThing" "failing Bash output surfaced"
has "$out" "Fixed; pipeline green." "last assistant message shown"
has "$(bash "$BIN/cleanup-digest" --branch nope --repo "$REPO")" "no sessions found" "unknown branch reports none"
if bash "$BIN/cleanup-digest" --branch main --repo "$REPO" >/dev/null 2>&1; then bad "default branch refused"; else ok "default branch refused"; fi
# resolved from project!iid through the (fake) API
echo '{"source_branch":"feat/x","state":"merged"}' >"$FX/glab/mr-4242.json"
has "$(bash "$BIN/cleanup-digest" gitlab-org/demo 4242 --list)" "sessB.jsonl" "<project> <iid> resolves branch via API and repo via WORKSPACE_ROOT"

# =================================================================================================
echo "== worktree-audit"
AR="$FX/artifacts"
git -C "$AR" init -q -b main
git -C "$AR" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
mk_wt() { # name branch [detached]  -> prints path
  local br="$2" path="$3"
  if [[ "$br" == DETACH ]]; then git -C "$REPO" worktree add -q --detach "$path"
  else git -C "$REPO" worktree add -q "$path" -b "$br"; fi
}
commit_in() { git -C "$1" -c user.name=t -c user.email=t@t commit -q --allow-empty -m "$2"; }
push_fake() { # path branch — pretend the branch was pushed
  git -C "$1" update-ref "refs/remotes/origin/$2" HEAD
  git -C "$1" branch -q --set-upstream-to="origin/$2" "$2"
}
W="$REPO/.claude/worktrees"
mk_wt a feat/merged-clean "$W/merged-clean";   commit_in "$W/merged-clean" c1;   push_fake "$W/merged-clean" feat/merged-clean
mk_wt a feat/merged-dirty "$W/merged-dirty";   commit_in "$W/merged-dirty" c2;   push_fake "$W/merged-dirty" feat/merged-dirty
printf 'uncommitted work\n' >"$W/merged-dirty/wip.txt"
mk_wt a feat/merged-unpushed "$W/merged-unpushed"; commit_in "$W/merged-unpushed" c3; push_fake "$W/merged-unpushed" feat/merged-unpushed
commit_in "$W/merged-unpushed" extra-local-commit
mk_wt a feat/open "$W/open-mr";                commit_in "$W/open-mr" c4;        push_fake "$W/open-mr" feat/open
mk_wt a scratch "$W/no-mr-scratch"
mk_wt a DETACH "$FX/ws/gitlab-org/demo-review-105"          # sibling dir, detached, only the name hints at an MR
mk_wt a feat/squash "$W/squash-merged";        commit_in "$W/squash-merged" c5   # remote branch deleted after squash merge
mk_wt a feat/in-artifacts "$AR/runner-src";    commit_in "$AR/runner-src" c6;    push_fake "$AR/runner-src" feat/in-artifacts
mk_wt a feat/gone "$FX/gone-wt"
mk_wt a feat/suspendable-ttl-docker "$W/suspendable-ttl-docker";             commit_in "$W/suspendable-ttl-docker" c7;       push_fake "$W/suspendable-ttl-docker" feat/suspendable-ttl-docker
mk_wt a feat/suspendable-ttl-docker-sweep "$W/suspendable-ttl-docker-sweep"; commit_in "$W/suspendable-ttl-docker-sweep" c8; push_fake "$W/suspendable-ttl-docker-sweep" feat/suspendable-ttl-docker-sweep
printf 'uncommitted in the main checkout\n' >"$REPO/untracked-in-main.txt"
gd="$(ls -d "$REPO"/.git/worktrees/gone-wt)"; printf '%s\n' "$FX/definitely-missing/.git" >"$gd/gitdir"

mrjson() { # state iid sha branch
  printf '[{"state":"%s","iid":%s,"sha":"%s","updated_at":"2026-11-0%s","source_branch":"%s"}]\n' "$1" "$2" "$3" "$2" "$4"
}
sha_of() { git -C "$1" rev-parse HEAD; }
mrjson merged 101 "$(sha_of "$W/merged-clean")" x feat/merged-clean >"$FX/glab/by-branch-feat_merged-clean.json"
mrjson merged 102 "$(sha_of "$W/merged-dirty")" x feat/merged-dirty >"$FX/glab/by-branch-feat_merged-dirty.json"
mrjson merged 103 "deadbeef0000000000000000000000000000dead" x feat/merged-unpushed >"$FX/glab/by-branch-feat_merged-unpushed.json"
mrjson opened 104 "$(sha_of "$W/open-mr")" x feat/open >"$FX/glab/by-branch-feat_open.json"
mrjson merged 106 "$(sha_of "$W/squash-merged")" x feat/squash >"$FX/glab/by-branch-feat_squash.json"   # HEAD == MR head
mrjson merged 107 "$(sha_of "$AR/runner-src")" x feat/in-artifacts >"$FX/glab/by-branch-feat_in-artifacts.json"
printf '{"state":"merged","iid":105,"sha":"abc"}\n' >"$FX/glab/mr-105.json"
mrjson merged 108 "$(sha_of "$W/suspendable-ttl-docker")" x feat/suspendable-ttl-docker >"$FX/glab/by-branch-feat_suspendable-ttl-docker.json"
mrjson opened 109 "$(sha_of "$W/suspendable-ttl-docker-sweep")" x feat/suspendable-ttl-docker-sweep >"$FX/glab/by-branch-feat_suspendable-ttl-docker-sweep.json"

# the main checkout AND one of its worktrees are both passed: must be de-duplicated
out="$(bash "$BIN/worktree-audit" --repo "$REPO" --repo "$W/merged-clean" --script "$FX/proposed-worktrees.sh")"
echo "$out" | sed 's/^/       | /' | head -40
has "$out" "repos: 1 ·" "main checkout + its worktree de-duplicated by common dir"
row() { grep -F "$1" <<<"$out" | head -1; }
has "$(row merged-clean)" "!101 MERGED" "merged-clean resolved by branch"
has "$(row merged-clean)" "git worktree remove (clean, in MR)" "merged + clean + pushed → remove proposed"
has "$(row merged-dirty)" "dirty(1)" "dirty worktree flagged"
hasnt "$(row merged-dirty)" "git worktree remove" "dirty worktree is never proposed"
has "$(row merged-unpushed)" "local-only(" "commit not in remote or MR head flagged"
hasnt "$(row merged-unpushed)" "git worktree remove" "local-only commits are never proposed"
has "$(row open-mr)" "!104 ACTIVE" "open MR is ACTIVE"
hasnt "$(row open-mr)" "git worktree remove" "active worktree kept"
has "$(row no-mr-scratch)" "NO-MR" "no MR classified NO-MR"
has "$(row demo-review-105)" "heuristic(name)" "detached worktree matched by dir name is marked heuristic"
hasnt "$(row demo-review-105)" "git worktree remove" "heuristic match never proposed"
has "$(row squash-merged)" "git worktree remove" "squash-merged (HEAD == MR head, remote branch gone) proposed"
has "$(row runner-src)" "IN-ARTIFACTS" "worktree inside the artifacts repo flagged"
hasnt "$(row runner-src)" "git worktree remove" "…and not auto-removed"
has "$(row definitely-missing)" "PRUNABLE" "missing directory classified PRUNABLE"
has "$(grep -F '| main |' <<<"$out")" "dirty(" "main checkout gets a row with its dirty flag"
has "$(grep -F '| main |' <<<"$out")" "main checkout — never removed" "main checkout is never proposed for removal"
has "$out" "main checkout — dirty(" "dirty main checkout surfaced in the attention list"
has "$(row suspendable-ttl-docker-sweep)" "!109 ACTIVE" "stacked sibling resolved to its own (open) MR"
has "$(grep -F '`feat/suspendable-ttl-docker` |' <<<"$out")" "git worktree remove" "merged stacked-series worktree proposed for removal"
has "$out" "## ⚠ Needs your attention" "attention section lists risky worktrees"
has "$out" "merged-dirty" "dirty merged worktree surfaced in attention list"
s="$(cat "$FX/proposed-worktrees.sh")"
has "$s" 'worktree remove' "script has a remove line"
has "$s" "worktree prune -v" "script has a prune line"
hasnt "$(grep -v "^#" <<<"$s")" "--force" "script never forces"
hasnt "$s" "worktree remove \"$W/merged-dirty\"" "dirty worktree absent from script"
bash -n "$FX/proposed-worktrees.sh" && ok "proposed script parses (bash -n)" || bad "proposed script parses"
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck "$FX/proposed-worktrees.sh" >/dev/null; then ok "proposed script passes shellcheck"; else bad "proposed script passes shellcheck"; fi
fi
if [[ -d "$W/merged-clean" && -f "$W/merged-dirty/wip.txt" ]]; then ok "audit changed nothing on disk"; else bad "audit changed nothing on disk"; fi

# --tabs
cat >"$FX/fake-herdr.sh" <<'EOF'
#!/usr/bin/env bash
echo '{"result":{"tabs":[{"tab_id":"w1:t1","label":"runner!101"},{"tab_id":"w1:t2","label":"unrelated"},{"tab_id":"w1:t3","label":"suspendable-ttl-docker-sweep"},{"tab_id":"w1:t4","label":"suspendable-ttl-docker"},{"tab_id":"w1:t5","label":"runner!1010"},{"tab_id":"w1:t6","label":"runner!102"},{"tab_id":"w1:t7","label":"runner!109"}]}}'
EOF
out="$(HERDR_CMD="bash $FX/fake-herdr.sh" bash "$BIN/worktree-audit" --repo "$REPO" --tabs)"
has "$out" "herdr tab close w1:t1" "tab of a finished MR proposed for closing"
hasnt "$out" "w1:t2" "unrelated tab left alone"
has "$out" "herdr tab close w1:t4" "tab named exactly like a finished worktree is proposed"
hasnt "$out" "w1:t3" "tab of the ACTIVE stacked sibling (suspendable-ttl-docker-sweep) is NOT proposed (no substring match)"
hasnt "$out" "w1:t5" "runner!1010 does not match !101 (anchored)"
hasnt "$out" "w1:t6" "tab of a finished-but-dirty worktree (!102) is not proposed"
hasnt "$out" "w1:t7" "tab of an open MR (!109) is not proposed"

# =================================================================================================
echo "== layout-audit"
LA="$FX/layout"
mkdir -p "$LA"
git -C "$LA" init -q -b main
P="$LA/workflow-artifacts/gitlab-org/gitlab-runner"
mkdir -p "$P/epic-5/misc" "$P/2026-10-12-foo" "$P/general-2026-10-13-bar" "$P/39145" "$P/mr-7306" "$P/issue-28770" "$P/issue-9" \
         "$LA/workflow-artifacts/gitlab-org/workitem-21159/mr-1" "$LA/workflow-artifacts/gitlab-org/workitem-21159/fleeting/42" \
         "$LA/workflow-artifacts/gitlab-com/content-sites/handbook/issue-3/misc" "$LA/workflow-artifacts/general/2026-11-10-in-flight" \
         "$LA/workflow-artifacts/gitlab-org/workitem-30/a-plan" \
         "$LA/gitlab-org/gitlab-runner/6887" "$LA/gitlab-org/gitlab-runner/issue-9" "$LA/personal/x"
for f in "$P/epic-5/misc/a.md" "$P/2026-10-12-foo/x.md" "$P/general-2026-10-13-bar/x.md" "$P/39145/x.md" "$P/mr-7306/x.md" \
         "$P/issue-28770/draft.md" "$P/issue-28770/NOTE.md" "$P/issue-9/b.md" "$P/stray-at-project.md" \
         "$LA/workflow-artifacts/gitlab-org/workitem-21159/mr-1/x.md" "$LA/workflow-artifacts/gitlab-org/workitem-21159/fleeting/42/x.md" \
         "$LA/workflow-artifacts/gitlab-com/content-sites/handbook/issue-3/misc/ok.md" "$LA/workflow-artifacts/general/2026-11-10-in-flight/n.md" \
         "$LA/workflow-artifacts/gitlab-org/workitem-30/a-plan/ok.md" \
         "$LA/gitlab-org/gitlab-runner/6887/a.md" "$LA/gitlab-org/gitlab-runner/issue-9/b.md" "$LA/personal/x/y.md" "$LA/stray.md"; do
  printf 'x\n' >"$f"
done
printf '# Artifacts\n' >"$LA/README.md"
git -C "$LA" add README.md workflow-artifacts/gitlab-org/gitlab-runner/2026-10-12-foo workflow-artifacts/gitlab-org/gitlab-runner/39145
git -C "$LA" -c user.name=t -c user.email=t@t commit -q -m seed
echo '{"iid":39145}' >"$FX/glab/issue-39145.json"

out="$(bash "$BIN/layout-audit" --root "$LA" --exclude 'workflow-artifacts/general/*' --script "$FX/proposed-layout.sh")"
echo "$out" | sed 's/^/       | /' | head -60
has "$out" "epic-5\` → \`workflow-artifacts/gitlab-org/gitlab-runner/workitem-5" "epic- → workitem-"
has "$out" "2026-10-12-foo\` → \`workflow-artifacts/gitlab-org/gitlab-runner/general-20261012-foo" "date form → general-YYYYMMDD"
has "$out" "general-2026-10-13-bar\` → \`workflow-artifacts/gitlab-org/gitlab-runner/general-20261013-bar" "hyphenated date after general- → compact"
has "$out" "issue-28770/draft.md\` → \`workflow-artifacts/gitlab-org/gitlab-runner/issue-28770/misc/draft.md" "loose identifier file → misc/"
hasnt "$out" "issue-28770/NOTE.md" "NOTE.md is allowed at identifier root"
has "$out" "39145\` — bare number" "bare number reported ambiguous without --resolve"
has "$out" "mr-7306\` — MR dir at project/org level" "top-level MR dir reported"
has "$out" "workitem-21159/mr-1\` — mr dir directly under an epic" "MR directly under an epic reported"
has "$out" "workitem-21159/fleeting/42\` — bare number inside an epic's project dir" "bare number under epic/project reported"
has "$out" "stray-at-project.md\` — loose file in container" "loose file in project container reported"
has "$out" "\`gitlab-org/gitlab-runner/6887\` → \`workflow-artifacts/gitlab-org/gitlab-runner/6887\`" "root-level org dir merged child by child"
has "$out" "CONFLICT" "colliding file at root reported as CONFLICT"
has "$out" "\`personal\` → \`workflow-artifacts/personal\`" "root org dir without counterpart moves whole"
has "$out" "stray.md\` — loose file at repo root" "root loose file reported"
hasnt "$out" "content-sites" "nested subgroup project dir is not flagged"
hasnt "$out" "2026-11-10-in-flight" "--exclude honoured"
has "$out" "README.md does not describe" "README gap noted"
has "$(bash "$BIN/layout-audit" --root "$LA" --resolve --exclude 'workflow-artifacts/general/*')" "39145\` → \`workflow-artifacts/gitlab-org/gitlab-runner/issue-39145" "--resolve turns an issue-only bare number into issue-N"
s="$(cat "$FX/proposed-layout.sh")"
has "$s" "mv_path 'workflow-artifacts/gitlab-org/gitlab-runner/epic-5'" "script renames epic dir"
has "$s" 'git -C "$ROOT" mv' "script uses git mv for tracked paths"
has "$s" "skip (target exists)" "script guards against existing targets"
hasnt "$s" "mv_path 'workflow-artifacts/gitlab-org/gitlab-runner/39145'" "ambiguous dirs are not in the script"
lo="$(grep -n 'mv_path .*issue-28770/draft.md' <<<"$s" | head -1 | cut -d: -f1)"; rn="$(grep -n "mv_path .*epic-5" <<<"$s" | head -1 | cut -d: -f1)"
if [[ -n "$lo" && -n "$rn" ]] && (( lo < rn )); then ok "script moves loose files before renaming their parent dirs"; else bad "script order loose→rename ($lo,$rn)"; fi
has "$s" "mv_path 'workflow-artifacts/gitlab-org/gitlab-runner/2026-10-12-foo/x.md' 'workflow-artifacts/gitlab-org/gitlab-runner/2026-10-12-foo/misc/x.md'" "loose move inside a to-be-renamed dir uses the old name"
bash -n "$FX/proposed-layout.sh" && ok "proposed script parses (bash -n)" || bad "proposed script parses"
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck "$FX/proposed-layout.sh" >/dev/null; then ok "proposed script passes shellcheck"; else bad "proposed script passes shellcheck"; fi
fi
if [[ -d "$P/epic-5" && -f "$LA/stray.md" ]]; then ok "audit moved nothing on disk"; else bad "audit moved nothing on disk"; fi
clean="$FX/layout-clean"; mkdir -p "$clean/workflow-artifacts/o/p/issue-1/a-plan"; printf 'x\n' >"$clean/workflow-artifacts/o/p/issue-1/a-plan/x.md"
printf 'See mr- and NOTE.md and cross-repo\n' >"$clean/README.md"
has "$(bash "$BIN/layout-audit" --root "$clean")" "No drift found." "canonical tree reports no drift"

# =================================================================================================
echo
echo "passed: $pass  failed: $fail   (fixtures kept in $FX)"
[[ "$fail" -eq 0 ]]
