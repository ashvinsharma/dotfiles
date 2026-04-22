---
description: Weekly retrospective from git history — commits, LOC, churn hotspots, commit type distribution, shipping streak, coverage trends, week-over-week comparison
---

Ask the user: "Single repo (current directory) or global (all repos under ~/workspace/)?"

Wait for the answer, then collect metrics for the chosen scope.

---

## Data Collection

All metrics are derived from `git log` only. No external tools or telemetry required.

For each repo in scope, run these commands:

```bash
# Commits in last 7 days
git log --oneline --since="7 days ago"

# LOC added/removed
git log --since="7 days ago" --numstat --format="" | \
  awk 'NF==3 {add+=$1; del+=$2} END {print "Added:", add, "Removed:", del}'

# Author breakdown
git log --since="7 days ago" --format="%an" | sort | uniq -c | sort -rn

# File churn — most frequently changed files
git log --since="7 days ago" --name-only --format="" | \
  sort | uniq -c | sort -rn | head -10

# Commit type distribution (conventional commits)
git log --since="7 days ago" --format="%s" | \
  grep -oE "^(feat|fix|test|refactor|docs|style|perf|chore)" | \
  sort | uniq -c | sort -rn

# Peak activity hours
git log --since="7 days ago" --format="%ad" --date=format:"%H" | \
  sort | uniq -c | sort -rn | head -5

# Test file ratio — what fraction of changed files were test files
TOTAL=$(git diff --name-only HEAD~7 HEAD 2>/dev/null | wc -l)
TESTS=$(git diff --name-only HEAD~7 HEAD 2>/dev/null | grep -cE "_test\.|\.test\.|_spec\.|\.spec\." || true)
echo "Test files: $TESTS / $TOTAL changed files"
```

**Shipping streak** — consecutive days with at least one commit:
```bash
git log --format="%ad" --date=short | sort -u | \
  awk 'BEGIN{streak=0; prev=""} {
    if (prev == "") { streak=1 }
    else {
      cmd = "date -d \""prev"\" +%s 2>/dev/null || date -j -f %Y-%m-%d \""prev"\" +%s"
      cmd | getline prev_ts; close(cmd)
      cmd = "date -d \""$0"\" +%s 2>/dev/null || date -j -f %Y-%m-%d \""$0"\" +%s"
      cmd | getline cur_ts; close(cmd)
      if (cur_ts - prev_ts <= 86400) streak++
      else streak=1
    }
    prev=$0; max=(streak>max?streak:max)
  } END {print "Current streak:", streak, "days | Best:", max, "days"}'
```

**Coverage trend** — check for local coverage output files:
```bash
for f in coverage.out coverage.xml .coverage lcov.info coverage/lcov.info; do
  [ -f "$f" ] && echo "Coverage file found: $f" && break
done
```
If found, extract the current coverage percentage. Compare against the version from 7 days ago in git history if available:
```bash
git show HEAD~7:coverage.out 2>/dev/null | go tool cover -func=- 2>/dev/null | tail -1
```

---

## Week-over-Week Comparison

Check `~/.claude/retro/last-week.json` for prior week metrics. If found, show delta (▲/▼) for: commits, LOC, streak, coverage.

After generating the report, save current metrics to `~/.claude/retro/last-week.json` (create `~/.claude/retro/` if it doesn't exist).

---

## Output Format

```
WEEKLY RETRO — [start date] to [end date]
==========================================
Mode: [single: repo-name | global: N repos]

COMMITS:     [N]  [▲N vs last week | first retro]
LOC:         +[N added] / -[N removed]
Test ratio:  [N]% of changed files were test files
Streak:      [N] consecutive days  [▲N vs last week]

TOP AUTHORS:
  [N commits]  [name]

HOTSPOT FILES (most churn):
  [N changes]  [file path]

COMMIT TYPES:
  feat: N  |  fix: N  |  test: N  |  refactor: N  |  chore: N  |  other: N

PEAK HOURS:  [HH]: N commits  [HH]: N commits

COVERAGE:    [N%]  [▲N% vs last week | N/A — no coverage file]

---

OBSERVATIONS:
- [Data-driven observation 1]
- [Data-driven observation 2 if meaningful]

RECOMMENDED ACTION:
[One specific, time-boxed action based on the data — not generic advice]
```

---

## Global Mode

For global mode, collect the above metrics for each git repo found under `~/workspace/`:

```bash
find ~/workspace -maxdepth 3 -name ".git" -type d 2>/dev/null | \
  sed 's/\/.git$//' | sort
```

Aggregate totals across all repos, then show per-repo breakdown for: commits, LOC, hotspot files.

Add a cross-project section:

```
CROSS-PROJECT
=============
Most active repo:    [repo name] ([N] commits)
Hottest file:        [path] ([N] changes across all repos)
Time split:          [repo: N% | repo: N% | ...]
```
