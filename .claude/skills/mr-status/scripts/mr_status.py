#!/usr/bin/env python3
"""mr_status — read-only fleet view of my open GitLab MRs, one status each, with a suggested action.

  python3 mr_status.py collect [--user U] [--snapshots DIR] [--today YYYY-MM-DD] [--no-herdr] [--no-diff] [--json]
  python3 mr_status.py diff    [--snapshots DIR] [PREV.json NEW.json]     (default: two newest snapshots)

Status per MR, first rule wins:
  draft -> blocked -> conflicts -> requested-changes -> red-pipeline -> needs-reviewer
        -> waiting-on -> pipeline-running -> ready

Read-only: only GET requests through `glab api`, plus `herdr agent list` / `herdr tab list` and
`git branch --show-current`. Nothing is posted, resolved, re-requested or pushed.
`--fixtures DIR` reads canned responses instead (same paths as the REST API, one JSON file each)
so the logic can be tested without touching real MRs.
"""
import argparse
import datetime as dt
import glob
import json
import os
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import quote

BOT_NAMES = {"GitLabDuo", "gitlab-bot", "ghost", "danger-bot", "gitlab-qa"}
NIT_RE = re.compile(r"(?i)\bnit(?:pick)?\b|💬\s*nit|non-?blocking")   # nit-class: reported, never "needs me"
RUNNING = {"running", "pending", "created", "waiting_for_resource", "preparing", "scheduled", "waiting_for_callback"}
DEFAULT_BRANCHES = {"main", "master"}
NUDGE_AFTER_WORKING_DAYS = 3
STATUS_ORDER = ["requested-changes", "conflicts", "red-pipeline", "needs-reviewer", "waiting-on",
                "pipeline-running", "ready", "blocked", "draft"]
DEFAULT_SNAPSHOTS = os.path.expanduser("~/.cache/mr-status")
DEFAULT_NOTES_INDEX = os.environ.get("NOTES_INDEX") or os.path.expanduser(
    "~/workspace/ai-workflow-artifacts/workflow-artifacts/notes-index.json")


def is_bot(user):
    return user in BOT_NAMES or user.endswith(("-bot", "_bot")) or bool(re.match(r"^(project|group)_\d+_bot", user))


def day(ts):
    return (ts or "")[:10]


def parse_ts(ts):
    return dt.datetime.fromisoformat(ts.replace("Z", "+00:00")) if ts else None


def working_days_since(since, today):
    """Mon-Fri days in (since, today]. Holidays are not known."""
    if not since:
        return 0
    d, n = dt.date.fromisoformat(since), 0
    while d < today:
        d += dt.timedelta(days=1)
        n += d.weekday() < 5
    return n


# ------------------------------------------------------------------------------- data layer

class Source:
    """GET-only access to GitLab (via glab) or to a fixtures directory with the same paths."""

    def __init__(self, fixtures=None):
        self.fixtures = fixtures
        self.warnings = []

    def get(self, path, default=None, **params):
        try:
            if self.fixtures:
                with open(os.path.join(self.fixtures, path + ".json")) as f:
                    return json.load(f)
            q = "&".join(f"{k}={quote(str(v), safe='[]')}" for k, v in params.items())
            r = subprocess.run(["glab", "api", f"{path}?{q}" if q else path],
                               capture_output=True, text=True, timeout=60)
            if r.returncode != 0:
                raise RuntimeError(r.stderr.strip()[:200] or f"exit {r.returncode}")
            return json.loads(r.stdout)
        except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as e:
            self.warnings.append(f"{path}: {str(e)[:160]}")
            return default

    def get_all(self, path, **params):
        if self.fixtures:
            return self.get(path, [], **params)
        out, page = [], 1
        while True:
            chunk = self.get(path, None, per_page=100, page=page, **params)
            if not chunk:
                return out
            out.extend(chunk)
            if len(chunk) < 100:
                return out
            page += 1

    def herdr(self, *args):
        try:
            if self.fixtures:
                name = "herdr-" + "-".join(args) + ".json"
                with open(os.path.join(self.fixtures, name)) as f:
                    return json.load(f)
            r = subprocess.run(["herdr", *args], capture_output=True, text=True, timeout=10)
            return json.loads(r.stdout) if r.returncode == 0 else None
        except (OSError, ValueError, subprocess.TimeoutExpired):
            return None


# ------------------------------------------------------------------------------- herdr tab matching

class Tabs:
    """Which herdr tab handles an MR: (1) agent cwd on the MR's branch, (2) tab label with !iid, (3) notes index."""

    def __init__(self, src, enabled=True, index_path=DEFAULT_NOTES_INDEX):
        self.agents, self.index = [], None
        if enabled:
            tabs = (src.herdr("tab", "list") or {}).get("result", {}).get("tabs", [])
            labels = {t["tab_id"]: t["label"] for t in tabs}
            self._tabs = labels
            for a in (src.herdr("agent", "list") or {}).get("result", {}).get("agents", []):
                cwd = a.get("foreground_cwd") or a.get("cwd") or ""
                self.agents.append({"label": labels.get(a.get("tab_id"), a.get("name", "?")), "cwd": cwd,
                                    "branch": a.get("branch") or self._branch(src, cwd)})
        if index_path and os.path.exists(index_path):
            try:
                with open(index_path) as f:
                    self.index = json.load(f)
            except (OSError, ValueError):
                self.index = None

    @staticmethod
    def _branch(src, cwd):
        if src.fixtures or not cwd or not os.path.isdir(cwd):
            return ""
        r = subprocess.run(["git", "-C", cwd, "branch", "--show-current"], capture_output=True, text=True)
        return r.stdout.strip() if r.returncode == 0 else ""

    def _from_index(self, key, url, branch, project):
        """notes-index.json (owned by /checkpoint): entries[] {ref, url, branch, project, tab, ...}."""
        entries = (self.index or {}).get("entries", []) if isinstance(self.index, dict) else []
        for e in entries:                      # exact ref / url first
            if e.get("tab") and (e.get("ref") == key or e.get("url") == url):
                return e["tab"]
        for e in entries:                      # then branch, same project only
            if e.get("tab") and branch and e.get("branch") == branch and e.get("project") in (project, project.split("/")[-1]):
                return e["tab"]
        return None

    def find(self, project, iid, branch, url):
        short = project.split("/")[-1]
        for a in self.agents:
            if a["branch"] and a["branch"] == branch and short in a["cwd"]:
                return a["label"]
        for a in self.agents:
            m = re.search(r"(?:^|[\s:/-])([\w.-]*)!(\d+)\b", a["label"])
            if m and int(m[2]) == iid and (not m[1] or m[1] in short or short in m[1]):
                return a["label"]
        return self._from_index(f"{project}!{iid}", url, branch, project)


# ------------------------------------------------------------------------------- per-MR collection

def collect_mr(src, item, me, tabs, today, fleet):
    pid, iid = item["project_id"], item["iid"]
    base = f"projects/{pid}/merge_requests/{iid}"
    mr = src.get(base, None)
    if mr is None:                      # list data is a fallback only: it can be stale
        mr = item
        src.warnings.append(f"{base}: using list data (conflict/pipeline may be stale)")
    full = (item.get("references") or {}).get("full") or ""
    project = full.split("!")[0] or re.sub(r"^https://gitlab.com/|/-/merge_requests/\d+$", "", item["web_url"])
    reviewers_api = src.get(f"{base}/reviewers", None)
    approval = src.get(f"{base}/approval_state", {}) or {}
    discussions = src.get_all(f"{base}/discussions")
    versions = src.get(f"{base}/versions", []) or []
    blocks = src.get(f"{base}/blocks", []) or []
    closes = src.get(f"{base}/closes_issues", []) or []

    # --- reviewers (live state comes from the reviewers API; the MR's own list has no state)
    if reviewers_api is not None:
        reviewers = [{"username": r["user"]["username"], "state": r.get("state", "unreviewed"),
                      "created_at": r.get("created_at")} for r in reviewers_api]
    else:
        reviewers = [{"username": r["username"], "state": "unknown", "created_at": None}
                     for r in mr.get("reviewers", [])]
    for r in reviewers:
        r["bot"] = is_bot(r["username"])

    # --- notes / threads
    last_push = max((v["created_at"] for v in versions), default=None)
    my_notes, feedback_at, rerequest_at, threads = [], {}, {}, []
    for d in discussions:
        notes = d.get("notes", [])
        for n in notes:
            who = n["author"]["username"]
            if n.get("system"):
                if who == me:
                    m = re.match(r"requested review from (.+)", n["body"])
                    if m:
                        for u in re.findall(r"@([\w.-]+)", m[1]):
                            rerequest_at[u] = max(rerequest_at.get(u, ""), n["created_at"])
                    my_notes.append(n["created_at"])
                m = re.match(r"requested changes", n["body"])
                if m:
                    feedback_at[who] = max(feedback_at.get(who, ""), n["created_at"])
                continue
            if who == me:
                my_notes.append(n["created_at"])
            else:
                feedback_at[who] = max(feedback_at.get(who, ""), n["created_at"])
        human = [n for n in notes if not n.get("system")]
        if not human or not any(n.get("resolvable") for n in notes):
            continue
        resolved = all(n.get("resolved") for n in notes if n.get("resolvable"))
        first, last = human[0], human[-1]
        pos = first.get("position") or {}
        threads.append({
            "id": d["id"], "resolved": resolved, "first_author": first["author"]["username"],
            "last_author": last["author"]["username"], "last_at": last["created_at"],
            "bot": is_bot(first["author"]["username"]), "nit": bool(NIT_RE.search(first["body"])),
            "where": f"{pos.get('new_path', '')}:{pos.get('new_line', '')}".strip(":"),
            "body": re.sub(r"\s+", " ", first["body"])[:140],
        })
    open_threads = [t for t in threads if not t["resolved"] and t["last_author"] != me]
    pending = [t for t in open_threads if not t["bot"]]
    bot_threads = [t for t in open_threads if t["bot"]]
    nits = [t for t in pending if t["nit"]]
    new_since_push = [t for t in pending if not t["nit"] and last_push and t["last_at"] > last_push]

    # --- re-request after my last push
    humans_open = [r for r in reviewers if not r["bot"] and r["state"] != "approved"]
    for r in humans_open:
        t = rerequest_at.get(r["username"], "")
        r["re_requested"] = bool(last_push) and (t > last_push or
                                                 (r["state"] == "unreviewed" and (r["created_at"] or "") > last_push))
        fb = feedback_at.get(r["username"])
        r["fix_shipped"] = bool(fb and last_push and last_push > fb)

    # --- approvals
    rules = approval.get("rules", [])
    unmet = [r["name"] for r in rules if r.get("approvals_required", 0) > len(r.get("approved_by", []))]
    left = sum(max(0, r.get("approvals_required", 0) - len(r.get("approved_by", []))) for r in rules)

    # --- blocked: formal blocks API, or stacked on another of my open MRs
    blockers = [f"!{b['blocking_merge_request']['iid']}" for b in blocks
                if (b.get("blocking_merge_request") or {}).get("state") == "opened"]
    if mr["target_branch"] not in DEFAULT_BRANCHES:
        for o in fleet:
            if o["project_id"] == pid and o["iid"] != iid and o["source_branch"] == mr["target_branch"]:
                blockers.append(f"!{o['iid']}")

    hp = mr.get("head_pipeline") or {}
    pipeline = {"id": hp.get("id"), "status": hp.get("status"), "web_url": hp.get("web_url"), "failed_jobs": []}
    if hp.get("status") == "failed" and hp.get("id"):
        jobs = src.get(f"projects/{pid}/pipelines/{hp['id']}/jobs", [], **{"scope[]": "failed"}) or []
        pipeline["failed_jobs"] = [j["name"] for j in jobs if not j.get("allow_failure")]

    status, detail = classify(mr, reviewers, blockers, pipeline, humans_open, unmet,
                              reviewers_known=reviewers_api is not None,
                              last_push=last_push, rerequest_at=rerequest_at, my_notes=my_notes)
    tab = tabs.find(project, iid, mr["source_branch"], item["web_url"])
    out = {
        "key": f"{project}!{iid}", "project": project, "iid": iid, "title": mr["title"], "web_url": item["web_url"],
        "source_branch": mr["source_branch"], "target_branch": mr["target_branch"],
        "status": status, "detail": detail, "draft": mr.get("draft", False),
        "pipeline": pipeline, "approvals_left": left, "unmet_rules": unmet,
        "reviewers": reviewers, "last_push": day(last_push),
        "threads": {"needs_me": len(pending), "new_since_push": len(new_since_push), "nits": len(nits),
                    "bot": len(bot_threads), "items": pending + bot_threads},
        "re_requested": rerequest_summary(humans_open),
        "closes": [{"ref": f"#{c['iid']}" if c.get("project_id") == pid else c.get("references", {}).get("full", f"#{c['iid']}"),
                    "url": c["web_url"]} for c in closes],
        "tab": tab, "auto_merge": bool(mr.get("merge_when_pipeline_succeeds")),
    }
    out["action"] = suggest(out, humans_open, new_since_push, today)
    return out


def rerequest_summary(humans_open):
    if not humans_open:
        return "-"
    yes = [r["username"] for r in humans_open if r["re_requested"]]
    if len(yes) == len(humans_open):
        return "yes"
    return "no" if not yes else "partial"


def classify(mr, reviewers, blockers, pipeline, humans_open, unmet,
             reviewers_known, last_push, rerequest_at, my_notes):
    if mr.get("draft"):
        return "draft", ""
    if blockers:
        return "blocked", ",".join(sorted(set(blockers)))
    if mr.get("has_conflicts") or mr.get("detailed_merge_status") == "conflict":
        return "conflicts", ""
    changers = [r["username"] for r in reviewers if r["state"] == "requested_changes"]
    if not reviewers_known and mr.get("detailed_merge_status") == "requested_changes":
        changers = ["(unknown reviewer)"]
    if changers:
        return "requested-changes", ",".join(changers)
    if pipeline["status"] == "failed":
        return "red-pipeline", ", ".join(pipeline["failed_jobs"]) or "no blocking job named"
    human_reviewers = [r for r in reviewers if not r["bot"]]
    if not human_reviewers:
        return "needs-reviewer", ""
    if humans_open or unmet:
        who = [r["username"] for r in humans_open]
        stamps = [t for u in who for t in [rerequest_at.get(u)] if t] + my_notes + ([last_push] if last_push else [])
        since = day(max(stamps)) if stamps else ""
        label = ",".join(who) if who else "approval rules: " + ", ".join(unmet)
        if not reviewers_known:
            label += " (reviewer states unknown)"
        return "waiting-on", f"{label} since {since}".strip()
    if pipeline["status"] in RUNNING:
        return "pipeline-running", ""
    return "ready", "auto-merge set" if mr.get("merge_when_pipeline_succeeds") else ""


def suggest(m, humans_open, new_since_push, today):
    """The user's rules: shipped fix + not re-requested -> re-request; + re-requested -> close tab; silent > 3 working days -> nudge."""
    acts, st = [], m["status"]
    if new_since_push:
        who = sorted({t["last_author"] for t in new_since_push})
        acts.append(f"address {len(new_since_push)} new thread(s) from @{', @'.join(who)}")
    shipped = [r for r in humans_open if r["fix_shipped"]]
    if shipped and not new_since_push:
        todo = [r["username"] for r in shipped if not r["re_requested"]]
        if todo:
            acts.append("re-request @" + ", @".join(todo))
        elif m["tab"]:
            acts.append(f"close tab {m['tab']}")
    if st == "draft":
        acts.append("finish draft")
    elif st == "blocked":
        acts.append(f"wait for {m['detail']}")
    elif st == "conflicts":
        acts.append("rebase (force-push needs user ok)")
    elif st == "requested-changes" and not acts:
        acts.append("address feedback (/address-mr-comments)")
    elif st == "red-pipeline":
        acts.append("check failed jobs: flake -> retry, real -> fix")
    elif st == "needs-reviewer":
        acts.append("pick a reviewer")
    elif st == "waiting-on":
        since = m["detail"].rsplit(" since ", 1)[-1]
        silent = [r["username"] for r in humans_open if not r["fix_shipped"] or r["re_requested"]]
        if not acts and working_days_since(since, today) > NUDGE_AFTER_WORKING_DAYS and silent:
            acts.append("nudge @" + ", @".join(silent))
    elif st == "ready":
        acts.append("ready to merge" if not m["tab"] else f"ready to merge; close tab {m['tab']} after")
    return "; ".join(acts) or "wait"


# ------------------------------------------------------------------------------- rendering

def md_link(text, url):
    return f"[{text}]({url})"


def status_cell(m):
    s, d = m["status"], m["detail"]
    if s in ("blocked", "requested-changes"):
        return f"{s} by {d}"
    if s == "waiting-on":
        return f"waiting-on {d}"
    return f"{s} ({d})" if d else s


def thread_cell(m):
    t = m["threads"]
    if not (t["needs_me"] or t["bot"]):
        return "0"
    parts = [str(t["needs_me"])]
    extra = []
    if t["new_since_push"]:
        extra.append(f"{t['new_since_push']} new")
    if t["nits"]:
        extra.append(f"{t['nits']} nit")
    s = parts[0] + (f" ({', '.join(extra)})" if extra else "")
    return s + (f" +{t['bot']} bot" if t["bot"] else "")


def render_table(rows, meta):
    head = "| MR | Title | Status | Appr left | Threads | Re-req'd | Closes | Tab | Suggested action |"
    lines = [f"MRs by @{meta['user']} as of {meta['today']} (snapshot {meta['snapshot_name']})", "",
             head, "|" + "---|" * 9]
    for m in rows:
        ref = md_link(f"{m['project'].split('/')[-1]}!{m['iid']}", m["web_url"])
        closes = ", ".join(md_link(c["ref"], c["url"]) for c in m["closes"]) or "-"
        title = (m["title"][:34] + "…") if len(m["title"]) > 35 else m["title"]
        lines.append(f"| {ref} | {title.replace('|', '/')} | {status_cell(m)} | {m['approvals_left']} | "
                     f"{thread_cell(m)} | {m['re_requested']} | {closes} | {m['tab'] or '-'} | {m['action']} |")
    return "\n".join(lines)


# ------------------------------------------------------------------------------- snapshot diff

def diff_snapshots(prev, new):
    pm, nm = {m["key"]: m for m in prev["mrs"]}, {m["key"]: m for m in new["mrs"]}
    out = []
    for k in sorted(nm.keys() - pm.keys()):
        out.append(f"+ new open MR {k}: {nm[k]['status']} {nm[k]['detail']}".rstrip())
    for k in sorted(pm.keys() - nm.keys()):
        out.append(f"- {k} no longer open (merged or closed)")
    for k in sorted(pm.keys() & nm.keys()):
        a, b = pm[k], nm[k]
        if (a["status"], a["detail"]) != (b["status"], b["detail"]):
            out.append(f"~ {k}: {a['status']} {a['detail']} -> {b['status']} {b['detail']}".replace("  ", " ").strip())
        if a["approvals_left"] != b["approvals_left"]:
            out.append(f"~ {k}: approvals left {a['approvals_left']} -> {b['approvals_left']}")
        if a["pipeline"]["status"] != b["pipeline"]["status"]:
            out.append(f"~ {k}: pipeline {a['pipeline']['status']} -> {b['pipeline']['status']}")
        if a["last_push"] != b["last_push"]:
            out.append(f"~ {k}: new push {a['last_push']} -> {b['last_push']}")
        if a["threads"]["needs_me"] != b["threads"]["needs_me"]:
            out.append(f"~ {k}: threads needing me {a['threads']['needs_me']} -> {b['threads']['needs_me']}")
        ar = {r["username"]: r["state"] for r in a["reviewers"]}
        br = {r["username"]: r["state"] for r in b["reviewers"]}
        for u in sorted(ar.keys() | br.keys()):
            if ar.get(u) != br.get(u):
                out.append(f"~ {k}: reviewer @{u} {ar.get(u, '(none)')} -> {br.get(u, '(removed)')}")
        if a["re_requested"] != b["re_requested"]:
            out.append(f"~ {k}: re-requested {a['re_requested']} -> {b['re_requested']}")
        if a["action"] != b["action"]:
            out.append(f"~ {k}: action '{a['action']}' -> '{b['action']}'")
    return out


def snapshots(dirpath):
    return sorted(glob.glob(os.path.join(dirpath, "snapshot-*.json")))


# ------------------------------------------------------------------------------- commands

def cmd_collect(a):
    src = Source(a.fixtures)
    today = dt.date.fromisoformat(a.today) if a.today else dt.date.today()
    me = a.user or (src.get("user", {}) or {}).get("username") or "ashvins"
    q = {"author_username": me, "state": "opened", "scope": "all"}
    items = src.get_all("merge_requests", **q)
    tabs = Tabs(src, enabled=not a.no_herdr, index_path=a.notes_index)
    with ThreadPoolExecutor(max_workers=8) as ex:
        rows = list(ex.map(lambda i: collect_mr(src, i, me, tabs, today, items), items))
    rows.sort(key=lambda m: (STATUS_ORDER.index(m["status"]), m["project"], m["iid"]))
    os.makedirs(a.snapshots, exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y%m%dT%H%M%S%f")
    path = os.path.join(a.snapshots, f"snapshot-{stamp}.json")
    prev = snapshots(a.snapshots)
    meta = {"user": me, "today": today.isoformat(), "taken_at": dt.datetime.now().isoformat(timespec="seconds"),
            "snapshot_name": os.path.basename(path)}
    snap = {"meta": meta, "mrs": rows, "warnings": src.warnings}
    with open(path, "w") as f:
        json.dump(snap, f, indent=1)
    if a.json:
        print(json.dumps(snap, indent=1))
        return 0
    print(render_table(rows, meta))
    if not rows:
        print("\n(no open MRs)")
    if not a.no_diff and prev:
        with open(prev[-1]) as f:
            old = json.load(f)
        lines = diff_snapshots(old, snap)
        print(f"\nChanged since {old['meta']['taken_at']} ({os.path.basename(prev[-1])}):")
        print("\n".join(lines) if lines else "  nothing")
    elif not prev:
        print("\n(first snapshot — nothing to diff against yet)")
    if src.warnings:
        print("\nWarnings (data above may be incomplete):")
        print("\n".join(f"  - {w}" for w in src.warnings))
    print(f"\nsnapshot: {path}")
    return 0


def cmd_diff(a):
    if a.prev and a.new:
        p, n = a.prev, a.new
    else:
        snaps = snapshots(a.snapshots)
        if len(snaps) < 2:
            print("need two snapshots to diff", file=sys.stderr)
            return 1
        p, n = snaps[-2], snaps[-1]
    with open(p) as f1, open(n) as f2:
        old, new = json.load(f1), json.load(f2)
    print(f"{os.path.basename(p)} ({old['meta']['taken_at']}) -> {os.path.basename(n)} ({new['meta']['taken_at']})")
    lines = diff_snapshots(old, new)
    print("\n".join(lines) if lines else "nothing changed")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("collect")
    c.add_argument("--user")
    c.add_argument("--fixtures", help="read canned API responses from DIR instead of GitLab (tests)")
    c.add_argument("--snapshots", default=DEFAULT_SNAPSHOTS)
    c.add_argument("--today", help="YYYY-MM-DD, for deterministic tests")
    c.add_argument("--notes-index", default=DEFAULT_NOTES_INDEX)
    c.add_argument("--no-herdr", action="store_true")
    c.add_argument("--no-diff", action="store_true")
    c.add_argument("--json", action="store_true")
    d = sub.add_parser("diff")
    d.add_argument("--snapshots", default=DEFAULT_SNAPSHOTS)
    d.add_argument("prev", nargs="?")
    d.add_argument("new", nargs="?")
    a = ap.parse_args()
    return {"collect": cmd_collect, "diff": cmd_diff}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
