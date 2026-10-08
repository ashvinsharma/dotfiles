---
name: backbench
description: Test GitLab Runner changes end to end against runner-backbench (a fake GitLab job API) instead of GDK — when to pick backbench vs GDK, runner config, writing job YAML with asserts, reading reports, multi-job flows like suspend/resume, and gotchas
---

# Testing Runner changes with backbench

[runner-backbench](https://gitlab.com/gitlab-org/ci-cd/runner-tools/runner-backbench) is a small Go
server that plays GitLab's role for a runner. It implements the runner API: register/verify,
`POST /api/v4/jobs/request`, `PUT /api/v4/jobs/:id`, trace `PATCH` and artifacts. It serves jobs
written in YAML, checks `asserts` against what the runner sends back, and writes a JSON report.
A real `gitlab-runner` connects to it as if it were GitLab.

---

## backbench or GDK? Pick by what you are testing

| Use **backbench** when | Use **GDK** when |
|---|---|
| The change is in the runner, an executor, the helper or a fleeting plugin | The change touches Rails: CI keywords, job payload building, the API, the UI |
| You need to send a job field Rails can't produce yet, e.g. a feature still behind a runner FF | You need to prove the whole product flow: `.gitlab-ci.yml` → pipeline → job → runner |
| You want repeatable runs with pass/fail asserts: `-count 100`, flake hunting, before/after `compare` | The behaviour depends on server-side logic: job routing, tags, protected refs, retries, job tokens, CI_JOB_TOKEN auth to other APIs |
| You want a fast loop: one binary, starts in seconds, no DB | You need real git clone/fetch, real cache or artifact servers, dependencies across a pipeline |
| CI or a throwaway VM, where GDK is too heavy | Final sign-off before release, once both runner and Rails sides are merged |

**Don't be biased either way:**
- backbench only proves the runner side. If a field's JSON tag drifts between backbench and Rails, backbench
  passes and production breaks; for example, backbench's `SuspendOptions` mirrors runner `common/spec`
  by hand.
- GDK proves integration but is slow, hard to script and noisy for runner-only changes.
- A good sequence: iterate on backbench, then do one GDK run when the Rails side exists.

---

## Setup

```shell
git clone https://gitlab.com/gitlab-org/ci-cd/runner-tools/runner-backbench.git
cd runner-backbench
# testing an unmerged backbench MR:
git fetch origin merge-requests/<iid>/head && git checkout FETCH_HEAD
go build -o bin/backbench .
```

Build the runner from the commit under test. Homebrew or released runners often lack new features:

```shell
git -C gitlab-runner worktree add --detach /tmp/runner-src <sha>
(cd /tmp/runner-src && go build -o /tmp/bin/gitlab-runner .)
```

If `go.mod` needs a newer Go than the shell's default (mise-pinned), use `mise exec go@<ver> -- go build`.
Setting `GOTOOLCHAIN` alone fails with "compile: version X does not match go tool version Y", because
mise sets GOROOT.

## Runner config

```toml
concurrent = 1
check_interval = 3

[[runners]]
  name     = "bb-test"
  id       = 1                       # backbench registers runners as ID 1; required by features that check runner ID (suspend)
  url      = "http://localhost:8085" # backbench default -addr
  token    = "glrt-anything"         # any token is accepted
  executor = "docker"
  shell    = "bash"
  [runners.docker]
    image = "busybox:latest"
```

Run it with its own config dir so state files such as `.runner_system_id` stay put across restarts:
`gitlab-runner run --config ./cfg/config.toml`.

## Writing jobs

```yaml
# <file>.yaml → test name is "<file>/<key with spaces→_>"
my_test:
  runner: {executor: [docker]}        # only served to matching runners; others are "skipped!"
  job:
    variables:
      - {key: GIT_STRATEGY, value: "none"}   # no repo to clone
    steps:
      - name: script
        script: ['echo "MY""_MARKER"']        # split the marker so the runner's command echo can't satisfy the assert
  asserts:
    - !expr "job.state == 'success'"
    - !expr "job.trace contains 'MY_MARKER'"
```

Assert fields: `job.state`, `job.exit_code`, `job.failure_reason`, `job.trace`, `job.checksum`,
`job.artifacts`, `job.started_at`, `job.runtime_environment_key` (from MR !16).

## Running

```shell
bin/backbench serve -jobs-dir ./myjobs -run '^myfile/' -output-dir ./reports \
  -inject-var MY_VAR=value      # added to every job; test YAML wins on duplicates
```

The report goes to `<output-dir>/<timestamp>_<runner>-<executor>.json`, with shape `results.<test>.job.{state,exit_code,trace,runtime_environment_key}`
and `results.<test>.assert_errors`. Compare two runs with `backbench compare a.json b.json`.

## Multi-job flows (e.g. suspend → resume)

backbench can't chain jobs itself. Run one `serve` per job:

1. Serve job 1 with `suspend_options: {suspend_on_success: true}`, then wait for the report and read the key:
   `jq -r '[.. | objects | .runtime_environment_key? // empty][0]'`.
2. Check the side effect outside backbench, e.g. the cloud VM state.
3. Optionally restart the runner. That's the real-world case, and the key's runner ID and system ID must still match.
4. Render job 2 from a template with `suspend_options: {runtime_environment_key: "<key>"}` into a fresh
   `-jobs-dir` and serve it.
5. To prove state survived, write a marker in job 1 and read it in job 2. To prove the machine really
   stopped, print `/proc/sys/kernel/random/boot_id`; containers see the host's value.

Suspend requires `FF_SUSPENDABLE_ENVIRONMENTS = true` under `[runners.feature_flags]` and `id > 0`.

## Gotchas

- **Always pass `-run`.** The embedded default suite is loaded alongside `-jobs-dir`.
- **Files are loaded by directory.** Put each job of a multi-job flow in its own dir, or both get served at once.
- **Jobs that touch the network from inside the job** (git clone, artifacts or cache via the helper) need the
  helper to reach backbench. If the runner's workers are remote VMs, `localhost` won't work. Use
  `-addr 0.0.0.0:8085 -public-url http://<reachable-host>:8085`, or avoid those features (`GIT_STRATEGY: none`).
- **backbench doesn't exit after writing the report** (from reading `cmd/serve.go`). Poll for the JSON file, then kill it.
- **`suspend.yaml` in MR !16 is Kubernetes-only.** It asserts `pvc=` in the key and filters on `executor: [kubernetes]`.
  For docker or docker-autoscaler, write your own job file. Docker's resume reuses the stopped build and helper
  containers whose IDs are in the key, so the container filesystem survives.
- For docker-autoscaler on fresh cloud VMs, install Docker with cloud-init and set
  `instance_ready_command = "cloud-init status --wait"` in `[runners.autoscaler]`.
