#!/usr/bin/env python3
"""mr_threads — unresolved review threads of ONE MR, plus guarded helpers for replying / re-requesting.

  mr_threads.py list      --project <path|id> --iid N [--user U] [--all] [--repo DIR] [--fixtures DIR]
  mr_threads.py reply     --project P --iid N --draft FILE [--execute]
  mr_threads.py rerequest --project P --iid N --users a,b [--execute]

`list` is read-only (GET). `reply` and `rerequest` only PRINT the call they would make unless --execute is given,
and --execute is refused unless the draft file carries `approved: <timestamp>` in its front matter — a stamp that
only the main session writes after the user said ok. --execute is never allowed with --fixtures.

Draft file reply blocks (everything else in the file is ignored):
    <!-- reply discussion=<discussion-id> -->
    reply body
    <!-- /reply -->
"""
import argparse
import json
import os
import re
import subprocess
import sys
from urllib.parse import quote

sys.dont_write_bytecode = True   # we import sibling skills: never drop __pycache__ into the dotfiles repo
sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "mr-status", "scripts"))
from mr_status import NIT_RE, Source, is_bot  # noqa: E402

QUESTION_RE = re.compile(r"(?i)\*\*question\b|\bquestion\b|\?\s*(\n|$)")
REPLY_RE = re.compile(r"<!--\s*reply\s+discussion=([\w-]+)\s*-->\n(.*?)\n<!--\s*/reply\s*-->", re.S)


def pid_path(project):
    return project if project.isdigit() else quote(project, safe="")


def worktree_for(repo, branch):
    if not repo or not os.path.isdir(repo):
        return None
    r = subprocess.run(["git", "-C", repo, "worktree", "list", "--porcelain"], capture_output=True, text=True)
    path = None
    for line in r.stdout.splitlines():
        if line.startswith("worktree "):
            path = line[9:]
        elif line == f"branch refs/heads/{branch}":
            return path
    return None


def cmd_list(a):
    src = Source(a.fixtures)
    me = a.user or (src.get("user", {}) or {}).get("username") or "ashvins"
    base = f"projects/{pid_path(a.project)}/merge_requests/{a.iid}"
    mr = src.get(base, None)
    if mr is None:
        print(json.dumps({"error": f"cannot fetch {base}", "warnings": src.warnings}))
        return 1
    versions = src.get(f"{base}/versions", []) or []
    last_push = max((v["created_at"] for v in versions), default="")
    rev = src.get(f"{base}/reviewers", []) or []
    reviewers = [{"username": r["user"]["username"], "id": r["user"]["id"], "gid": f"gid://gitlab/User/{r['user']['id']}",
                  "state": r.get("state"), "bot": is_bot(r["user"]["username"])} for r in rev]
    threads = []
    for d in src.get_all(f"{base}/discussions"):
        notes = [n for n in d.get("notes", []) if not n.get("system")]
        if not notes or not any(n.get("resolvable") for n in notes):
            continue
        resolved = all(n.get("resolved") for n in notes if n.get("resolvable"))
        if resolved and not a.all:
            continue
        first, last = notes[0], notes[-1]
        pos = first.get("position") or {}
        threads.append({
            "discussion_id": d["id"], "resolved": resolved, "author": first["author"]["username"],
            "where": f"{pos.get('new_path', '')}:{pos.get('new_line', '')}".strip(":"),
            "notes": [{"id": n["id"], "author": n["author"]["username"], "at": n["created_at"], "body": n["body"]} for n in notes],
            "hints": {"nit": bool(NIT_RE.search(first["body"])), "question": bool(QUESTION_RE.search(first["body"])),
                      "bot": is_bot(first["author"]["username"]), "last_is_mine": last["author"]["username"] == me,
                      "new_since_push": bool(last_push and last["author"]["username"] != me
                                             and last["created_at"] > last_push)},
        })
    threads.sort(key=lambda t: t["notes"][0]["at"])
    for i, t in enumerate(threads, 1):
        t["n"] = i
    repo = a.repo or os.path.expanduser(f"~/workspace/{a.project}")
    print(json.dumps({
        "mr": {"project": a.project, "iid": a.iid, "web_url": mr.get("web_url"), "source_branch": mr["source_branch"],
               "target_branch": mr["target_branch"], "last_push": last_push, "me": me,
               "worktree": None if a.fixtures else worktree_for(repo, mr["source_branch"])},
        "reviewers": reviewers, "threads": threads, "warnings": src.warnings}, indent=1))
    return 0


def front_matter(text):
    m = re.match(r"---\n(.*?)\n---\n", text, re.S)
    return {k: v.strip() for k, v in re.findall(r"^(\w+):[ \t]*(.*)$", m[1], re.M)} if m else {}


def guard(execute, fixtures, approved_ok=True):
    if execute and fixtures:
        sys.exit("refusing --execute together with --fixtures")
    if execute and not approved_ok:
        sys.exit("refusing --execute: draft has no `approved:` stamp. The main session adds it only after the user says ok.")


def glab_write(args, stdin=None):
    r = subprocess.run(["glab", "api", *args], capture_output=True, text=True, input=stdin)
    if r.returncode:
        sys.exit(f"glab api failed: {r.stderr.strip()[:300]}")
    return r.stdout


def cmd_reply(a):
    with open(a.draft) as f:
        text = f.read()
    guard(a.execute, a.fixtures, bool(front_matter(text).get("approved")))
    base = f"projects/{pid_path(a.project)}/merge_requests/{a.iid}"
    blocks = [(d, b.strip()) for d, b in REPLY_RE.findall(text)]
    if not blocks:
        print("no reply blocks in draft (nothing to post)")
        return 0
    for disc, body in blocks:
        if a.execute:   # idempotent: skip when an identical note is already in the discussion
            existing = json.loads(glab_write([f"{base}/discussions/{disc}"]))
            if any(n["body"].strip() == body for n in existing.get("notes", [])):
                print(f"skip {disc}: identical note already posted")
                continue
            out = glab_write(["-X", "POST", f"{base}/discussions/{disc}/notes", "-f", f"body={body}"])
            print(f"posted to {disc}: note id {json.loads(out).get('id')}")
        else:
            print(f"DRY-RUN  glab api -X POST {base}/discussions/{disc}/notes -f body=<{len(body)} chars>\n---\n{body}\n---")
    return 0


def cmd_rerequest(a):
    approved = True
    if a.execute and not a.draft:
        approved = False
    elif a.execute:
        with open(a.draft) as f:
            approved = bool(front_matter(f.read()).get("approved"))
    guard(a.execute, a.fixtures, approved)
    src = Source(a.fixtures)
    base = f"projects/{pid_path(a.project)}/merge_requests/{a.iid}"
    rev = {r["user"]["username"]: r["user"]["id"] for r in (src.get(f"{base}/reviewers", []) or [])}
    mutation = ("mutation($p:ID!,$i:String!,$u:UserID!){ mergeRequestReviewerRereview(input:{projectPath:$p,iid:$i,userId:$u})"
                "{ errors } }")
    for u in [x.strip().lstrip("@") for x in a.users.split(",") if x.strip()]:
        if is_bot(u):
            print(f"skip @{u}: bot (re-request humans only)")
            continue
        if u not in rev:
            print(f"skip @{u}: not a reviewer of this MR")
            continue
        body = json.dumps({"query": mutation, "variables": {"p": a.project, "i": str(a.iid), "u": f"gid://gitlab/User/{rev[u]}"}})
        if a.execute:
            out = json.loads(glab_write(["graphql", "--input", "-", "-H", "Content-Type: application/json"], stdin=body))
            errs = (((out.get("data") or {}).get("mergeRequestReviewerRereview") or {}).get("errors")) or out.get("errors")
            print(f"re-requested @{u}" if not errs else f"re-request @{u} FAILED: {errs}")
        else:
            print(f"DRY-RUN  glab api graphql --input -   <<< {body}")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("list", "reply", "rerequest"):
        p = sub.add_parser(name)
        p.add_argument("--project", required=True, help="group/project path (live) or numeric id (fixtures)")
        p.add_argument("--iid", required=True, type=int)
        p.add_argument("--fixtures")
        if name == "list":
            p.add_argument("--user")
            p.add_argument("--all", action="store_true", help="include resolved threads")
            p.add_argument("--repo", help="local checkout (default ~/workspace/<project>) to find the worktree")
        else:
            p.add_argument("--execute", action="store_true")
        if name == "reply":
            p.add_argument("--draft", required=True)
        if name == "rerequest":
            p.add_argument("--users", required=True, help="comma-separated usernames (humans)")
            p.add_argument("--draft", help="draft file whose `approved:` stamp authorises --execute")
    a = ap.parse_args()
    return {"list": cmd_list, "reply": cmd_reply, "rerequest": cmd_rerequest}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
