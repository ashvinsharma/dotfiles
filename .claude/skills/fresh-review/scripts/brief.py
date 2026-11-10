#!/usr/bin/env python3
"""brief.py — build the prompt for a fresh-eyes MR reviewer. The brief contains ONLY:
repo, base/head branch, checkout path, the linked issue text verbatim, and neutral facts passed with --fact.
It deliberately never reads (and so cannot leak) the MR description, MR notes/threads, reviews, or chat context.

  python3 brief.py --project <group/project|id> --iid N [--worktree DIR | --repo DIR] [--fact "text"]... [--fixtures DIR]

Prints the brief on stdout. Exit 1 when the MR cannot be fetched. A missing issue is reported on stderr and in the brief.
"""
import argparse
import os
import sys
from urllib.parse import quote

sys.dont_write_bytecode = True   # we import sibling skills: never drop __pycache__ into the dotfiles repo
sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "mr-status", "scripts"))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "address-mr-comments", "scripts"))
from mr_status import Source  # noqa: E402
from mr_threads import worktree_for  # noqa: E402

TEMPLATE = """You are reviewing a change you have never seen. Form your own model of it from the issue and the code.

Repository: {project}
Checkout: {checkout}   (read-only for you: do not edit, commit, push or run anything that writes)
Base branch: {target}
Head branch: {source}
Diff to review: git -C {checkout} diff origin/{target}...HEAD   (the base may not be the default branch: this is the whole change)
Read the surrounding files as needed; use the base-branch version of a file to see what the change altered.

The issue this change is meant to resolve, verbatim:
<<<ISSUE
{issue}
ISSUE>>>
{facts}
Work only from the issue text, the checkout and the diff. Do NOT fetch the merge request description, its notes or
threads, or any earlier review (no `glab mr view/note`, no GitLab MR tools). If the issue text is missing or unclear, say so.

Look for: correctness bugs, unhandled edge cases, concurrency and ordering problems, error handling, regressions to
existing flows, tests that don't test what they claim, code or docs that contradict the issue, security gaps.

Output, nothing else:
1. Findings, ranked most severe first. Each: `file:line` — one-sentence claim — a concrete failure scenario
   (inputs/state -> wrong behaviour). No style nits unless they hide a bug.
2. "Verified sound": what you checked and found correct.
3. "Could not assess": anything you could not determine and why.
Do not fix anything.
"""


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--project", required=True)
    ap.add_argument("--iid", required=True, type=int)
    ap.add_argument("--worktree")
    ap.add_argument("--repo", help="local checkout to look the worktree up in (default ~/workspace/<project>)")
    ap.add_argument("--fact", action="append", default=[], help="bare neutral fact (repeatable); no opinions, no rationale")
    ap.add_argument("--fixtures")
    a = ap.parse_args()

    src = Source(a.fixtures)
    pid = a.project if a.project.isdigit() else quote(a.project, safe="")
    base = f"projects/{pid}/merge_requests/{a.iid}"
    mr = src.get(base, None)   # only branches are read from it; description is ignored on purpose
    if not mr:
        print(f"cannot fetch {base}: {src.warnings}", file=sys.stderr)
        return 1
    issues = src.get(f"{base}/closes_issues", []) or []
    if issues:
        issue = "\n\n".join(f"{i.get('references', {}).get('full', '#' + str(i['iid']))}: {i['title']}\n\n{i.get('description') or '(empty)'}"
                            for i in issues)
    else:
        issue = "(no issue is linked to this change; judge the diff on its own merits and say what you assumed)"
        print("warning: no closing issue linked; ask the user for the issue text and re-run with it", file=sys.stderr)
    checkout = a.worktree or (None if a.fixtures else worktree_for(a.repo or os.path.expanduser(f"~/workspace/{a.project}"),
                                                                   mr["source_branch"]))
    if not checkout:
        print("warning: no worktree for the head branch; pass --worktree", file=sys.stderr)
        checkout = "<NO-WORKTREE: pass --worktree>"
    facts = "".join(f"- {f}\n" for f in a.fact)
    print(TEMPLATE.format(project=a.project, checkout=checkout, target=mr["target_branch"], source=mr["source_branch"],
                          issue=issue.strip(), facts=("\nFacts:\n" + facts) if facts else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
