#!/usr/bin/env python3
"""Fixture tests for decisions.py. Builds throwaway fixtures; never touches real logs.

  WF_TEST_DIR=/some/scratch python3 -I test_decisions.py     (each run gets a fresh run-* subdir; nothing is deleted)
"""
import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.join(HERE, "decisions.py")
_ROOT = os.environ.get("WF_TEST_DIR")
if _ROOT:
    os.makedirs(_ROOT, exist_ok=True)
BASE = tempfile.mkdtemp(prefix="run-", dir=_ROOT)  # fresh dir per run

LOG = """---
prefix: TST
epic: https://gitlab.com/groups/gitlab-org/-/work_items/99999
repos:
  - {repo}
---

# Test log

## Settled

- **TST-D01** · **Numbered already.** Because. ([!1](https://gitlab.com/g/p/-/merge_requests/1))
- **Unnumbered lead one.** Why one. ([#2](https://gitlab.com/g/p/-/issues/2), [!3](https://gitlab.com/g/p/-/merge_requests/3))
  Continuation line stays with its bullet.
- **Unnumbered lead two.** Why two. ([!4](https://gitlab.com/g/p/-/merge_requests/4))

## Reversed

- **TST-D02** · **Old decision.** Was fine once. ([!5](https://gitlab.com/g/p/-/merge_requests/5)) — Reversed by **TST-D01**: replaced.
- **TST-D09** · **Highest id lives here.** Gap and Reversed must still count. ([#9](https://gitlab.com/g/p/-/issues/9)) — Reversed: nothing replaces it.

## Assumptions

- **TST-A01** · **Relied on.** Not proven. ([!6](https://gitlab.com/g/p/-/merge_requests/6))
- **Unnumbered assumption.** Not proven either. ([!7](https://gitlab.com/g/p/-/merge_requests/7))
"""


def rd(p):
    with open(p) as f:
        return f.read()


def wr(p, s):
    with open(p, "w") as f:
        f.write(s)


def run(*args, inp=None, ok=(0,), env=None):
    r = subprocess.run([sys.executable, "-I", TOOL, *args], input=inp, capture_output=True, text=True,
                       env=dict(os.environ, **env) if env else None)
    assert r.returncode in ok, f"{args}: rc={r.returncode}\nstdout={r.stdout}\nstderr={r.stderr}"
    return r


def git(repo, *args):
    subprocess.run(["git", "-C", repo, *args], check=True, capture_output=True)


class Fixture(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.repo = os.path.join(BASE, "scratch-repo")
        os.makedirs(cls.repo)
        git(cls.repo, "init", "-q")
        git(cls.repo, "config", "user.email", "t@example.com")
        git(cls.repo, "config", "user.name", "t")
        with open(os.path.join(cls.repo, "code.go"), "w") as f:
            f.write("package x\n// See TST-D01 for why.\n// Old approach: TST-D02.\n// Bogus: TST-D99.\n"
                    "// Boundaries: TST2-D01 and XTST-D01 are not ours; TST-D1 and TST-D10 are distinct ids.\n"
                    "// Assumption: TST-A01.\n")
        git(cls.repo, "add", ".")
        git(cls.repo, "commit", "-qm", "fixture")

    def setUp(self):
        self.dir = os.path.join(BASE, self._testMethodName)
        os.makedirs(self.dir)
        self.log = os.path.join(self.dir, "DECISIONS.md")
        with open(self.log, "w") as f:
            f.write(LOG.format(repo=self.repo))

    def read(self):
        return rd(self.log)

    # ---- number
    def test_number_assigns_max_plus_one_and_is_idempotent(self):
        run("number", self.log)
        t = self.read()
        self.assertIn("- **TST-D10** · **Unnumbered lead one.**", t)   # max is D09 (in Reversed) -> D10, D11
        self.assertIn("- **TST-D11** · **Unnumbered lead two.**", t)
        self.assertIn("- **TST-A02** · **Unnumbered assumption.**", t)
        self.assertIn("  Continuation line stays with its bullet.", t)
        run("number", self.log)
        self.assertEqual(t, self.read(), "second run must not change the file")
        self.assertIn("no change", run("number", self.log, "--dry-run").stdout)

    def test_number_dry_run_does_not_write(self):
        before = self.read()
        r = run("number", self.log, "--dry-run")
        self.assertIn("+- **TST-D10**", r.stdout)
        self.assertEqual(before, self.read())

    def test_number_never_reuses_gap(self):
        t = self.read().replace("TST-D09", "TST-D05")
        wr(self.log, t)
        run("number", self.log)
        self.assertIn("TST-D06", self.read())

    # ---- add / reverse
    def test_add_then_reverse_then_next_is_max_plus_one(self):
        run("add", self.log, "--section", "settled", "--text", "**Fresh.** Reason. ([!8](https://gitlab.com/g/p/-/merge_requests/8))")
        self.assertIn("- **TST-D10** · **Fresh.**", self.read())
        run("reverse", self.log, "TST-D10", "--why", "dropped")        # nothing replaced it
        t = self.read()
        sec_rev = t.index("## Reversed")
        self.assertGreater(t.index("**TST-D10**"), sec_rev)
        self.assertIn("— Reversed: dropped.", t)
        run("add", self.log, "--section", "settled", "--text", "**After reversal.** Why. ([!9](https://gitlab.com/g/p/-/merge_requests/9))")
        self.assertIn("- **TST-D11** · **After reversal.**", self.read())   # never reuses D10
        run("lint", self.log, ok=(1,))  # still has unnumbered fixtures
        run("number", self.log)
        run("lint", self.log)

    def test_reverse_with_replacement_and_promotion(self):
        run("number", self.log)
        run("reverse", self.log, "TST-D10", "--by", "TST-D11", "--why", "superseded")
        self.assertIn("— Reversed by **TST-D11**: superseded.", self.read())
        run("reverse", self.log, "TST-A01", "--by", "TST-D11", "--why", "proved by test")
        self.assertIn("— Promoted to **TST-D11**: proved by test.", self.read())
        run("lint", self.log)
        r = run("reverse", self.log, "TST-D11", "--by", "TST-D99", "--why", "x", ok=(2,))
        self.assertIn("existing id", r.stderr)
        run("reverse", self.log, "TST-D02", "--why", "x", ok=(2,))  # already reversed

    def test_missing_sections_do_not_crash(self):
        wr(self.log, "---\nprefix: TST\nepic: x\nrepos: []\n---\n\n# only a title\n")
        run("lint", self.log)
        self.assertEqual("[]", run("list", self.log, "--json").stdout.strip())
        run("add", self.log, "--section", "assumptions", "--text", "**A.** Why. ([!1](https://x.example/1))")
        run("add", self.log, "--section", "settled", "--text", "**D.** Why. ([!2](https://x.example/2))")
        t = self.read()
        self.assertLess(t.index("## Settled"), t.index("## Assumptions"))   # canonical order
        run("reverse", self.log, "TST-D01", "--why", "gone")
        t = self.read()
        self.assertLess(t.index("## Reversed"), t.index("## Assumptions"))
        run("lint", self.log)
        # no sections at all, no frontmatter body issues
        wr(self.log, "---\nprefix: TST\n---\n")
        run("number", self.log)
        run("index", self.log)
        run("check", self.log, "--no-repos", "--no-notes")

    def test_bad_frontmatter_is_a_clean_error(self):
        wr(self.log, "# no frontmatter\n## Settled\n- **X.** y\n")
        r = run("number", self.log, ok=(2,))
        self.assertIn("prefix", r.stderr)
        self.assertNotIn("Traceback", r.stderr)

    # ---- list / find / index
    def test_list_find_index(self):
        run("number", self.log)
        live = json.loads(run("list", self.log, "--json").stdout)
        ids = [v["id"] for v in live]
        self.assertEqual(ids, ["TST-D01", "TST-D10", "TST-D11", "TST-A01", "TST-A02"])  # no reversed
        self.assertEqual(live[1]["sources"], ["[#2](https://gitlab.com/g/p/-/issues/2)", "[!3](https://gitlab.com/g/p/-/merge_requests/3)"])
        allv = json.loads(run("list", self.log, "--json", "--all").stdout)
        self.assertEqual({v["id"] for v in allv} - set(ids), {"TST-D02", "TST-D09"})
        rev = [v for v in allv if v["id"] == "TST-D02"][0]
        self.assertEqual(rev["replaced"], {"how": "Reversed by", "by": "TST-D01", "why": "replaced."})
        f = json.loads(run("find", self.log, "lead", "one", "--json").stdout)
        self.assertEqual([v["id"] for v in f], ["TST-D10"])
        run("find", self.log, "nonexistent-term", ok=(1,))
        idx = run("index", self.log).stdout
        self.assertTrue(idx.startswith("| Id | Decision | Status | Source |"))
        self.assertIn("| `TST-D02` | Old decision. → TST-D01 | reversed |", idx)
        self.assertNotIn("TST-D02", run("index", self.log, "--live").stdout)

    # ---- lint
    def test_lint_catches_problems(self):
        t = self.read().replace("TST-A01", "TST-D01")      # dup id + decision in Assumptions
        wr(self.log, t)
        out = run("lint", self.log, ok=(1,)).stdout
        self.assertIn("duplicate id TST-D01", out)
        self.assertIn("decision but sits in ## Assumptions", out)

    # ---- check
    def test_check_repo_notes_and_stdin(self):
        run("number", self.log)
        note_dir = os.path.join(self.dir, "gitlab-runner", "mr-1")
        os.makedirs(note_dir)
        wr(os.path.join(note_dir, "NOTE.md"), "## Decisions in force\n- TST-D10 holds\n- TST-D02 was reversed\n- TST-D77 typo\n")
        r = run("check", self.log, "--stdin", inp="MR desc cites TST-D11 and TST-D55.\nand RJ-D01 from another log\n", ok=(1,))
        out = r.stdout
        self.assertIn("settled    TST-D01", out)                                   # code.go
        self.assertRegex(out, r"reversed   TST-D02 .*code\.go:3  -> TST-D01")
        self.assertRegex(out, r"unknown    TST-D99 .*code\.go:4")
        self.assertRegex(out, r"assumption TST-A01 .*code\.go:6")
        self.assertRegex(out, r"settled    TST-D10 .*NOTE\.md:2")
        self.assertRegex(out, r"unknown    TST-D77 .*NOTE\.md:4")
        self.assertRegex(out, r"settled\s+TST-D11\s+<stdin>:1")
        self.assertRegex(out, r"unknown\s+TST-D55\s+<stdin>:1")
        self.assertNotIn("RJ-D01", out)                                          # other prefix ignored
        self.assertNotIn("TST2-D01", out)                                        # prefix boundary
        self.assertNotIn("XTST-D01", out)
        self.assertRegex(out, r"unknown\s+TST-D1\s+\S+code\.go:5")                # TST-D1 is its own id ...
        self.assertRegex(out, r"settled\s+TST-D10\s+\S+code\.go:5")               # ... and not a prefix-match of TST-D10
        # json shape
        j = json.loads(run("check", self.log, "--json", "--no-notes", ok=(1,)).stdout)
        self.assertTrue(all(set(x) == {"id", "status", "file", "line", "replaced_by", "context"} for x in j["results"]))

    def test_check_clean_exits_zero_and_flags(self):
        run("number", self.log)
        r = run("check", self.log, "--no-repos", "--no-notes", "--stdin", inp="cites TST-D01 only\n")
        self.assertIn("summary: settled=1", r.stdout)
        run("check", self.log, "--no-repos", "--no-notes", "--stdin", "--fail-on-reversed", inp="TST-D02\n", ok=(1,))
        r = run("check", self.log, "--no-notes", "--stdin", inp="x\n", ok=(1,))   # repo has unknowns
        r = run("check", self.log, "--no-repos", "--no-notes", "--stdin", inp="no ids\n")
        self.assertIn("no citations found", r.stdout)

    def test_check_missing_repo_warns_not_crashes(self):
        t = self.read().replace(self.repo, os.path.join(self.dir, "nope"))
        wr(self.log, t)
        r = run("check", self.log, "--no-notes")
        self.assertIn("repo not found", r.stderr)

    def test_prefixes_do_not_cross_match(self):
        a = os.path.join(self.dir, "a.md")
        wr(a, "---\nprefix: RJ\nepic: x\nrepos: []\n---\n## Settled\n- **RJ-D01** · **One.** Why. ([!1](https://x.example/1))\n")
        b = os.path.join(self.dir, "b.md")
        wr(b, "---\nprefix: RJ2\nepic: x\nrepos: []\n---\n## Settled\n- **RJ2-D01** · **Two.** Why. ([!2](https://x.example/2))\n")
        txt = "RJ-D01 RJ2-D01 RJ-D10 RJ2-D1 ARJ-D01\n"
        ra = run("check", a, "--no-repos", "--no-notes", "--stdin", inp=txt, ok=(1,)).stdout
        rb = run("check", b, "--no-repos", "--no-notes", "--stdin", inp=txt, ok=(1,)).stdout
        self.assertIn("settled    RJ-D01", ra); self.assertIn("unknown    RJ-D10", ra); self.assertNotIn("RJ2", ra)
        self.assertIn("settled    RJ2-D01", rb); self.assertIn("unknown    RJ2-D1 ", rb); self.assertNotIn("RJ-D", rb)
        # counters are independent
        run("add", a, "--section", "settled", "--text", "**Next.** Why. ([!3](https://x.example/3))")
        run("add", b, "--section", "settled", "--text", "**Next.** Why. ([!3](https://x.example/3))")
        self.assertIn("RJ-D02", rd(a)); self.assertIn("RJ2-D02", rd(b))

    def test_add_into_empty_sections_keeps_layout(self):
        root = os.path.join(self.dir, "root")
        out = run("init", "--epic", "https://gitlab.com/groups/acme/-/work_items/7", "--prefix", "EX", "--root", root).stdout.strip()
        run("add", out, "--section", "settled", "--text", "**One.** Why. ([!1](https://x.example/1))")
        run("add", out, "--section", "assumptions", "--text", "**Two.** Why. ([!2](https://x.example/2))")
        run("reverse", out, "EX-D01", "--why", "gone")
        t = rd(out)
        self.assertIn("## Settled\n\n## Reversed\n\n- **EX-D01**", t)     # blank line after each heading
        self.assertIn("gone.\n\n## Assumptions\n\n- **EX-A01**", t)        # blank line before the next heading
        run("lint", out)

    # ---- exit codes: 2 = real error, 3 = no log for this epic
    def test_mr_url_is_an_error_and_missing_log_is_3(self):
        empty = os.path.join(self.dir, "empty-root")
        os.makedirs(empty)
        env = {"DECISIONS_ROOT": empty}
        for bad in ("https://gitlab.com/gitlab-org/gitlab-runner/-/merge_requests/7643",
                    "https://gitlab.com/gitlab-org/gitlab-runner/-/issues/39603", "not-a-thing"):
            r = run("find", bad, "x", ok=(2,), env=env)                       # never "no decisions logged"
            self.assertNotIn("Traceback", r.stderr)
        self.assertIn("resolve the MR/issue's epic first", run("list", "https://gitlab.com/gitlab-org/gitlab-runner/-/merge_requests/7643", ok=(2,), env=env).stderr)
        for ok_arg in ("21159", "https://gitlab.com/groups/gitlab-org/-/work_items/21159", "https://gitlab.com/groups/gitlab-org/-/epics/21159"):
            r = run("find", ok_arg, "x", ok=(3,), env=env)                    # valid epic, no log
            self.assertIn("no decision log at", r.stderr)
            run("list", ok_arg, "--json", ok=(3,), env=env)
        self.assertNotEqual(run("path", "21159", "--allow-missing", env=env).stdout.strip(), "")

    # ---- hand-typed ids
    def test_hand_typed_separator_is_never_renumbered(self):
        t = self.read().replace("- **TST-D01** · **Numbered already.**", "- **TST-D07** - **Hand typed.**")
        wr(self.log, t)
        out = run("lint", self.log, ok=(1,)).stdout
        self.assertIn("TST-D07 has a malformed separator", out)
        self.assertNotIn("TST-D07 unnumbered", out)
        r = run("number", self.log, ok=(2,))
        self.assertIn("will not renumber", r.stderr)
        self.assertEqual(t, self.read(), "file must be untouched")
        wr(self.log, t.replace("**TST-D07** - ", "**TST-D07** · "))             # fixing the separator by hand
        run("number", self.log)
        self.assertNotIn("**TST-D12** · **TST-D07**", self.read())
        self.assertIn("**TST-D07** · **Hand typed.**", self.read())

    # ---- next id ignores spec comments / fences
    def test_next_id_ignores_comments_and_template_copy(self):
        t = self.read().replace("## Settled\n", "## Settled\n\n<!-- example: TST-D50 -->\n```\n- **TST-D60** · x\n```\n", 1)
        wr(self.log, t)
        run("add", self.log, "--section", "settled", "--text", "**Next.** Why. ([!1](https://x.example/1))")
        self.assertIn("- **TST-D10** · **Next.**", self.read())                 # D09 is the max live id
        tpl = os.path.join(self.dir, "DECISIONS.md.tpl")
        wr(tpl, rd(os.path.join(HERE, "template.md")))                          # template carries RJ-D10 in its spec comment
        r = run("add", tpl, "--section", "settled", "--text", "**First real.** Why. ([!1](https://x.example/1))")
        self.assertIn("RJ-D03", r.stdout)                                       # template has live D01, D02 only

    # ---- init / path
    def test_init_and_path(self):
        root = os.path.join(self.dir, "root")
        out = run("init", "--epic", "https://gitlab.com/groups/acme/-/work_items/42", "--prefix", "ZZ2", "--repo", "~/r", "--root", root).stdout.strip()
        self.assertEqual(out, os.path.join(root, "acme", "workitem-42", "DECISIONS.md"))
        run("lint", out)
        run("init", "--epic", "https://gitlab.com/groups/acme/-/work_items/42", "--prefix", "ZZ2", "--root", root, ok=(2,))  # no overwrite
        env = dict(os.environ, DECISIONS_ROOT=root)
        r = subprocess.run([sys.executable, "-I", TOOL, "path", "42", "--allow-missing"], capture_output=True, text=True, env=env)
        self.assertIn("gitlab-org/workitem-42/DECISIONS.md", r.stdout)   # bare iid defaults to gitlab-org
        r = subprocess.run([sys.executable, "-I", TOOL, "path", "https://gitlab.com/groups/acme/-/work_items/42"], capture_output=True, text=True, env=env)
        self.assertEqual(r.stdout.strip(), out)


if __name__ == "__main__":
    print(f"fixtures under {BASE}")
    unittest.main(verbosity=2)
