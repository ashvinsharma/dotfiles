#!/usr/bin/env python3
"""Deterministic half of the /decisions skill. Stdlib only. Format: template.md.

  decisions.py init   --epic URL --prefix P [--repo DIR ...] [--root DIR | --path FILE]
  decisions.py path   <epic-iid|epic-url|file> [--allow-missing]
  decisions.py number <log> [--dry-run]
  decisions.py add    <log> --section settled|assumptions --text BODY [--dry-run]
  decisions.py reverse <log> <id> [--by NEW_ID] --why TEXT [--dry-run]
  decisions.py list   <log> [--all] [--json]
  decisions.py find   <log> TERM... [--all] [--json]
  decisions.py index  <log> [--live]
  decisions.py lint   <log>
  decisions.py check  <log> [--stdin] [--file F ...] [--no-repos] [--no-notes] [--json] [--fail-on-reversed]

<log> is a DECISIONS.md path, or an epic iid/URL resolved under $DECISIONS_ROOT
(default ~/workspace/ai-workflow-artifacts/workflow-artifacts). Writes are atomic;
--dry-run prints a unified diff.
Exit: 0 ok | 1 findings (lint, check unknown, find no-hit) | 2 usage/IO error (real error) | 3 no log for this epic.
"""
import argparse
import difflib
import glob
import json
import os
import re
import subprocess
import sys
import tempfile

DEFAULT_ROOT = os.path.expanduser("~/workspace/ai-workflow-artifacts/workflow-artifacts")
SECTION_ORDER = ["settled", "reversed", "assumptions"]
SECTION_TITLE = {"settled": "Settled", "reversed": "Reversed", "assumptions": "Assumptions"}
PREFIX_RE = re.compile(r"^[A-Z][A-Z0-9]*$")
BULLET_ID_RE = re.compile(r"^- \*\*([A-Z][A-Z0-9]*-[DA]\d+)\*\* · ")
BULLET_HEAD_RE = re.compile(r"^- \*\*([A-Z][A-Z0-9]*-[DA]\d+)\*\*")  # id present, separator maybe wrong
EPIC_URL_RE = re.compile(r"/groups/([^/]+(?:/[^/]+)*?)/-/(?:work_items|epics)/(\d+)/?(?:[?#].*)?$")
LINK_RE = re.compile(r"\[([^\]]+)\]\((https?://[^)\s]+)\)")
REPLACED_RE = re.compile(r"\s+— (Reversed by|Promoted to) \*\*([A-Z][A-Z0-9]*-[DA]\d+)\*\*: (.*)$|\s+— Reversed: (.*)$")


class Fail(Exception):
    pass


def die(msg, code=2):
    print(f"decisions: {msg}", file=sys.stderr)
    sys.exit(code)


def id_re(prefix):
    # (?<![\w-]) stops XRJ-D1 / FOO-RJ-D1; (?!\w) stops RJ-D1 matching inside RJ-D10; RJ never matches RJ2-D01.
    return re.compile(r"(?<![\w-])" + re.escape(prefix) + r"-[DA]\d+(?!\w)")


# ---------------------------------------------------------------- parsing
def split_front(text):
    """Return (front_dict, body_start_line_index). Minimal YAML subset: scalars and `- item` lists."""
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return {}, 0
    front, key = {}, None
    for i in range(1, len(lines)):
        ln = lines[i]
        if ln.strip() == "---":
            return front, i + 1
        if not ln.strip() or ln.lstrip().startswith("#"):
            continue
        m = re.match(r"^([A-Za-z_]+):\s*(.*)$", ln)
        if m:
            key, val = m.group(1), m.group(2).strip()
            if val.startswith("[") and val.endswith("]"):
                front[key] = [v.strip().strip("\"'") for v in val[1:-1].split(",") if v.strip()]
            elif val == "":
                front[key] = []
            else:
                front[key] = val.strip("\"'")
            continue
        m = re.match(r"^\s+-\s+(.*)$", ln)
        if m and key is not None:
            if not isinstance(front.get(key), list):
                front[key] = []
            front[key].append(m.group(1).strip().strip("\"'"))
    return {}, 0  # unterminated frontmatter


class Entry:
    def __init__(self, section, start, end, ident, text, bad_sep=None):
        self.section, self.start, self.end, self.id, self.text = section, start, end, ident, text
        self.bad_sep = bad_sep  # id typed by hand with a separator other than " · "

    @property
    def kind(self):
        return "assumption" if (self.id and self.id.split("-")[-1][0] == "A") else "decision"

    @property
    def status(self):
        return {"settled": "settled", "reversed": "reversed", "assumptions": "assumption"}[self.section]


class Log:
    def __init__(self, path, text):
        self.path, self.text = path, text
        self.lines = text.split("\n")
        self.front, self.body_start = split_front(text)
        self.prefix = self.front.get("prefix", "")
        self._scan()

    def _scan(self):
        self.entries, self.headings = [], {}
        section, fence, i, n = None, False, self.body_start, len(self.lines)
        while i < n:
            ln = self.lines[i]
            if ln.lstrip().startswith("```"):
                fence = not fence
            elif fence:
                pass
            elif ln.startswith("<!--"):  # skip HTML comment blocks (the spec lives in one)
                while i < n and "-->" not in self.lines[i]:
                    i += 1
            elif ln.startswith("## "):
                name = ln[3:].strip().lower()
                section = name if name in SECTION_TITLE else None
                if section:
                    self.headings.setdefault(section, i)
            elif section and ln.startswith("- "):
                j = i + 1
                while j < n and self.lines[j].strip() and self.lines[j][0] in " \t":
                    j += 1
                m, hm = BULLET_ID_RE.match(ln), BULLET_HEAD_RE.match(ln)
                self.entries.append(Entry(section, i, j, m.group(1) if m else None, "\n".join(self.lines[i:j]),
                                          hm.group(1) if (hm and not m) else None))
                i = j
                continue
            i += 1

    def validate_front(self):
        if not PREFIX_RE.match(self.prefix or ""):
            raise Fail(f"{self.path}: frontmatter `prefix` missing or invalid (want ^[A-Z][A-Z0-9]*$)")

    def by_id(self):
        return {e.id: e for e in self.entries if e.id}

    def next_id(self, letter):
        rx = re.compile(r"(?<![\w-])" + re.escape(self.prefix) + r"-" + letter + r"(\d+)(?!\w)")
        live = re.sub(r"```.*?```", "", re.sub(r"<!--.*?-->", "", self.text, flags=re.S), flags=re.S)  # spec comments/examples don't count
        nums = [int(x) for x in rx.findall(live)]
        return f"{self.prefix}-{letter}{(max(nums) + 1 if nums else 1):02d}"


def load(arg):
    path = resolve(arg)
    try:
        text = open(path, encoding="utf-8").read()
    except OSError as e:
        die(f"cannot read {path}: {e.strerror}")
    return Log(path, text)


def resolve(arg, allow_missing=False):
    if os.path.isfile(arg):
        return arg
    org = iid = None
    if arg.isdigit():
        org, iid = "gitlab-org", arg
    else:
        um = EPIC_URL_RE.search(arg)
        if um:
            org, iid = um.group(1).split("/")[0], um.group(2)
    if iid is None:
        if arg.startswith("http"):
            die(f"not an epic URL (want .../groups/<g>/-/work_items/<iid>): {arg} -- resolve the MR/issue's epic first")
        die(f"not a file, epic iid or epic URL: {arg}")
    root = os.path.expanduser(os.environ.get("DECISIONS_ROOT", DEFAULT_ROOT))
    path = os.path.join(root, org, f"workitem-{iid}", "DECISIONS.md")
    if os.path.isfile(path) or allow_missing:
        return path
    die(f"no decision log at {path} (create one with `init`)", 3)


def insert_into_section(scan, out, sec, block):
    """Insert bullet lines `block` at the end of `sec`, creating the section in canonical position if missing.
    `scan` is a Log parsed from `out` (it supplies the line offsets)."""
    if sec not in scan.headings:
        later = [scan.headings[s] for s in SECTION_ORDER[SECTION_ORDER.index(sec) + 1:] if s in scan.headings]
        new = [f"## {SECTION_TITLE[sec]}", "", *block, ""]
        if later:
            out[min(later):min(later)] = new
        else:
            while out and out[-1] == "":
                out.pop()
            out += ["", *new]
        return
    existing = [e for e in scan.entries if e.section == sec]
    if existing:
        out[existing[-1].end:existing[-1].end] = block
        return
    pos = scan.headings[sec] + 1  # empty section: keep a blank line after the heading and before the next one
    if pos < len(out) and out[pos] == "":
        pos += 1
    else:
        out.insert(pos, "")
        pos += 1
    out[pos:pos] = block + ([""] if pos < len(out) and out[pos].strip() else [])


def write_or_diff(log, new_lines, dry):
    new = "\n".join(new_lines)
    if new == log.text:
        print("no change")
        return
    if dry:
        sys.stdout.writelines(difflib.unified_diff(
            log.text.splitlines(True), new.splitlines(True), "a/" + os.path.basename(log.path), "b/" + os.path.basename(log.path)))
        return
    d = os.path.dirname(os.path.abspath(log.path))
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".decisions-", suffix=".tmp")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(new)
    os.replace(tmp, log.path)


# ---------------------------------------------------------------- entry views
def parts(e):
    """lead / why / sources / replacement for a bullet."""
    body = BULLET_ID_RE.sub("", e.text.split("\n")[0]) if e.id else e.text.split("\n")[0][2:]
    body = " ".join([body] + [x.strip() for x in e.text.split("\n")[1:]])
    repl = None
    rm = REPLACED_RE.search(body)
    if rm:
        body = body[:rm.start()]
        repl = {"how": rm.group(1) or "Reversed", "by": rm.group(2), "why": (rm.group(3) or rm.group(4) or "").strip()}
    lm = re.match(r"\*\*(.+?)\*\*\s*(.*)$", body)
    lead, rest = (lm.group(1), lm.group(2)) if lm else (body, "")
    sources = list(dict.fromkeys(f"[{t}]({u})" for t, u in LINK_RE.findall(rest)))
    why = re.sub(r"\s*\((?:\[[^\]]+\]\([^)]+\)(?:,\s*)?)+\)\s*$", "", rest).strip()
    return lead.strip(), why, sources, repl


def view(e):
    lead, why, sources, repl = parts(e)
    return {"id": e.id, "kind": e.kind, "status": e.status, "lead": lead, "why": why,
            "sources": sources, "replaced": repl, "text": e.text.replace("\n", " ")}


def select(log, all_):
    es = [e for e in log.entries if e.id and (all_ or e.section != "reversed")]
    return sorted(es, key=lambda e: (e.id.split("-")[-1][0] != "D", int(re.sub(r"\D", "", e.id.split("-")[-1]))))  # decisions, then assumptions


# ---------------------------------------------------------------- commands
def cmd_init(a):
    um = EPIC_URL_RE.search(a.epic)
    if not a.path and not um:
        die("--epic must be .../groups/<g>/-/work_items/<iid> (or pass --path)")
    if not PREFIX_RE.match(a.prefix):
        die("invalid --prefix (want ^[A-Z][A-Z0-9]*$)")
    root = os.path.expanduser(a.root or os.environ.get("DECISIONS_ROOT", DEFAULT_ROOT))
    path = a.path or os.path.join(root, um.group(1).split("/")[0], f"workitem-{um.group(2)}", "DECISIONS.md")
    if os.path.exists(path):
        die(f"{path} exists; refusing to overwrite")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    repos = "repos:\n" + "".join(f"  - {r}\n" for r in a.repo) if a.repo else "repos: []\n"
    open(path, "w", encoding="utf-8").write(
        f"---\nprefix: {a.prefix}\nepic: {a.epic}\n{repos}---\n\n# Decision log\n\n"
        f"## Settled\n\n## Reversed\n\n## Assumptions\n")
    print(path)


def cmd_path(a):
    print(resolve(a.log, a.allow_missing))


def cmd_number(a):
    log = load(a.log)
    log.validate_front()
    for e in log.entries:
        if e.bad_sep:
            die(f"{log.path}:{e.start + 1}: {e.bad_sep} has a malformed separator (want '**{e.bad_sep}** · '); "
                "fix it by hand, `number` will not renumber a hand-typed id")
    out, bad = list(log.lines), [e for e in log.entries if not e.id and e.section == "reversed"]
    if bad:
        die(f"{log.path}:{bad[0].start + 1}: unnumbered bullet in ## Reversed; reversing keeps an existing id")
    nxt = {"D": int(re.sub(r"\D", "", log.next_id("D").split("-")[-1])), "A": int(re.sub(r"\D", "", log.next_id("A").split("-")[-1]))}
    for e in log.entries:  # in file order; edit lines in place so indexes stay valid
        if e.id:
            continue
        letter = "A" if e.section == "assumptions" else "D"
        ident = f"{log.prefix}-{letter}{nxt[letter]:02d}"
        nxt[letter] += 1
        out[e.start] = f"- **{ident}** · " + out[e.start][2:]
        print(f"{ident} <- {parts(e)[0]}")
    write_or_diff(log, out, a.dry_run)


def cmd_add(a):
    log = load(a.log)
    log.validate_front()
    sec = a.section
    if sec not in ("settled", "assumptions"):
        die("--section must be settled or assumptions")
    body = a.text.strip()
    if not body.startswith("**"):
        die("--text must start with a bold lead clause: **Lead.** Why. ([ref](url))")
    ident = log.next_id("A" if sec == "assumptions" else "D")
    bullet = f"- **{ident}** · {body}"
    out = list(log.lines)
    insert_into_section(log, out, sec, [bullet])
    print(bullet)
    write_or_diff(log, out, a.dry_run)


def cmd_reverse(a):
    log = load(a.log)
    log.validate_front()
    ents = log.by_id()
    e = ents.get(a.id)
    if not e:
        die(f"{a.id} not found in {log.path}")
    if e.section == "reversed":
        die(f"{a.id} is already reversed")
    if a.by:
        if a.by == a.id or a.by not in ents:
            die(f"--by {a.by} must be an existing id (add the replacement first)")
        if ents[a.by].section == "reversed":
            die(f"--by {a.by} is itself reversed")
        how = "Promoted to" if (e.kind == "assumption" and ents[a.by].kind == "decision") else "Reversed by"
        suffix = f" — {how} **{a.by}**: {a.why.strip().rstrip('.')}."
    else:
        suffix = f" — Reversed: {a.why.strip().rstrip('.')}."
    block = log.lines[e.start:e.end]
    block[-1] += suffix
    out = log.lines[:e.start] + log.lines[e.end:]
    if 0 < e.start < len(out) and out[e.start - 1] == "" and out[e.start] == "":  # section just became empty
        del out[e.start]
    insert_into_section(Log(log.path, "\n".join(out)), out, "reversed", block)  # re-scan after the removal
    write_or_diff(log, out, a.dry_run)


def cmd_list(a):
    log = load(a.log)
    vs = [view(e) for e in select(log, a.all)]
    if a.json:
        print(json.dumps(vs, indent=2))
        return
    for v in vs:
        tag = {"settled": "D", "reversed": "R", "assumption": "A"}[v["status"]]
        print(f"{v['id']:<9} {tag}  {v['lead']}")


def cmd_find(a):
    log = load(a.log)
    terms = [t.lower() for t in a.terms]
    vs = [view(e) for e in select(log, a.all) if all(t in e.text.lower() for t in terms)]
    if a.json:
        print(json.dumps(vs, indent=2))
    else:
        for v in vs:
            print(f"{v['id']:<9} {v['status']:<10} {v['lead']}")
    sys.exit(0 if vs else 1)


def cmd_index(a):
    log = load(a.log)
    rows = ["| Id | Decision | Status | Source |", "|---|---|---|---|"]
    for e in select(log, not a.live):
        v = view(e)
        lead = v["lead"].replace("|", "\\|")
        if v["replaced"]:
            lead += f" → {v['replaced']['by']}" if v["replaced"]["by"] else ""
        rows.append(f"| `{v['id']}` | {lead} | {v['status']} | {', '.join(v['sources']) or '—'} |")
    print("\n".join(rows))


def lint_problems(log):
    probs, seen = [], {}
    for e in log.entries:
        loc = f"{log.path}:{e.start + 1}"
        if e.bad_sep:
            probs.append(f"{loc}: {e.bad_sep} has a malformed separator (want ' · ' after the bold id)")
            continue
        if not e.id:
            probs.append(f"{loc}: unnumbered bullet (run `number`)")
            continue
        if not e.id.startswith(log.prefix + "-"):
            probs.append(f"{loc}: {e.id} does not use prefix {log.prefix}")
        if e.id in seen:
            probs.append(f"{loc}: duplicate id {e.id} (first at line {seen[e.id] + 1})")
        seen[e.id] = e.start
        if e.section == "settled" and e.kind == "assumption":
            probs.append(f"{loc}: {e.id} is an assumption but sits in ## Settled")
        if e.section == "assumptions" and e.kind == "decision":
            probs.append(f"{loc}: {e.id} is a decision but sits in ## Assumptions")
        if e.section == "reversed" and not parts(e)[3]:
            probs.append(f"{loc}: {e.id} in ## Reversed lacks '— Reversed by/Promoted to **id**: why' or '— Reversed: why'")
        if e.section != "reversed" and parts(e)[3]:
            probs.append(f"{loc}: {e.id} carries a reversal suffix but is not in ## Reversed")
    ents = log.by_id()
    for e in log.entries:
        r = parts(e)[3] if e.id else None
        if r and r["by"] and r["by"] not in ents:
            probs.append(f"{log.path}:{e.start + 1}: {e.id} points at unknown replacement {r['by']}")
    return probs


def cmd_lint(a):
    log = load(a.log)
    log.validate_front()
    probs = lint_problems(log)
    print("\n".join(probs) if probs else f"ok: {len(log.entries)} entries")
    sys.exit(1 if probs else 0)


def scan_text(rx, text, label):
    hits = []
    for n, ln in enumerate(text.split("\n"), 1):
        for m in rx.finditer(ln):
            hits.append((m.group(0), label, n, ln.strip()[:160]))
    return hits


def cmd_check(a):
    log = load(a.log)
    log.validate_front()
    rx = id_re(log.prefix)
    logdir = os.path.dirname(os.path.abspath(log.path))
    hits, warnings = [], []
    if a.stdin:
        hits += scan_text(rx, sys.stdin.read(), "<stdin>")
    for f in a.file or []:
        try:
            hits += scan_text(rx, open(f, encoding="utf-8", errors="replace").read(), f)
        except OSError as e:
            warnings.append(f"cannot read {f}: {e.strerror}")
    if not a.no_repos:
        for repo in log.front.get("repos") or []:
            repo = os.path.expanduser(repo)
            if not os.path.isdir(repo):
                warnings.append(f"repo not found, skipped: {repo}")
                continue
            r = subprocess.run(["git", "-C", repo, "grep", "-n", "-I", "-E", re.escape(log.prefix) + r"-[DA][0-9]+"],
                               capture_output=True, text=True)
            if r.returncode == 128:
                warnings.append(f"not a git repo, skipped: {repo}")
                continue
            for row in r.stdout.splitlines():
                path, _, rest = row.partition(":")
                num, _, line = rest.partition(":")
                for m in rx.finditer(line):
                    hits.append((m.group(0), os.path.join(repo, path), int(num), line.strip()[:160]))
    if not a.no_notes:
        globs = ["**/NOTE.md"] + list(log.front.get("note_globs") or [])
        files = set()
        for g in globs:
            g = os.path.expanduser(g)
            g = g if os.path.isabs(g) else os.path.join(logdir, g)
            files.update(glob.glob(g, recursive=True))
        for f in sorted(files):
            if os.path.abspath(f) == os.path.abspath(log.path) or not os.path.isfile(f):
                continue
            hits += scan_text(rx, open(f, encoding="utf-8", errors="replace").read(), f)
    ents = log.by_id()
    results = []
    for ident, f, n, line in hits:
        e = ents.get(ident)
        status = "unknown" if not e else e.status
        repl = None
        if e and e.section == "reversed":
            r = parts(e)[3]
            repl = r["by"] if r else None
        results.append({"id": ident, "status": status, "file": f, "line": n, "replaced_by": repl, "context": line})
    if a.json:
        print(json.dumps({"results": results, "warnings": warnings}, indent=2))
    else:
        for r in results:
            extra = f"  -> {r['replaced_by']}" if r["replaced_by"] else ""
            print(f"{r['status']:<10} {r['id']:<9} {r['file']}:{r['line']}{extra}")
        for w in warnings:
            print(f"warn: {w}", file=sys.stderr)
        c = {}
        for r in results:
            c[r["status"]] = c.get(r["status"], 0) + 1
        print("summary: " + (", ".join(f"{k}={v}" for k, v in sorted(c.items())) or "no citations found"))
    bad = any(r["status"] == "unknown" for r in results) or (a.fail_on_reversed and any(r["status"] == "reversed" for r in results))
    sys.exit(1 if bad else 0)


def main():
    p = argparse.ArgumentParser(prog="decisions.py", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sp = p.add_subparsers(dest="cmd", required=True)

    s = sp.add_parser("init"); s.add_argument("--epic", required=True); s.add_argument("--prefix", required=True)
    s.add_argument("--repo", action="append"); s.add_argument("--root"); s.add_argument("--path"); s.set_defaults(f=cmd_init)
    s = sp.add_parser("path"); s.add_argument("log"); s.add_argument("--allow-missing", action="store_true"); s.set_defaults(f=cmd_path)
    s = sp.add_parser("number"); s.add_argument("log"); s.add_argument("--dry-run", action="store_true"); s.set_defaults(f=cmd_number)
    s = sp.add_parser("add"); s.add_argument("log"); s.add_argument("--section", required=True)
    s.add_argument("--text", required=True); s.add_argument("--dry-run", action="store_true"); s.set_defaults(f=cmd_add)
    s = sp.add_parser("reverse"); s.add_argument("log"); s.add_argument("id"); s.add_argument("--by"); s.add_argument("--why", required=True)
    s.add_argument("--dry-run", action="store_true"); s.set_defaults(f=cmd_reverse)
    s = sp.add_parser("list"); s.add_argument("log"); s.add_argument("--all", action="store_true"); s.add_argument("--json", action="store_true"); s.set_defaults(f=cmd_list)
    s = sp.add_parser("find"); s.add_argument("log"); s.add_argument("terms", nargs="+"); s.add_argument("--all", action="store_true")
    s.add_argument("--json", action="store_true"); s.set_defaults(f=cmd_find)
    s = sp.add_parser("index"); s.add_argument("log"); s.add_argument("--live", action="store_true"); s.set_defaults(f=cmd_index)
    s = sp.add_parser("lint"); s.add_argument("log"); s.set_defaults(f=cmd_lint)
    s = sp.add_parser("check"); s.add_argument("log"); s.add_argument("--stdin", action="store_true")
    s.add_argument("--file", action="append"); s.add_argument("--no-repos", action="store_true"); s.add_argument("--no-notes", action="store_true")
    s.add_argument("--json", action="store_true"); s.add_argument("--fail-on-reversed", action="store_true"); s.set_defaults(f=cmd_check)

    a = p.parse_args()
    try:
        a.f(a)
    except Fail as e:
        die(str(e))
    except BrokenPipeError:
        pass


if __name__ == "__main__":
    main()
