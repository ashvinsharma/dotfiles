---
name: glci
description: Use glci to run GitLab CI/CD pipelines locally. Trigger when user asks about running CI locally, testing pipelines, GitLab CI, glci commands, or debugging CI jobs.
---

# glci — Run GitLab CI/CD Pipelines Locally

glci runs `.gitlab-ci.yml` pipelines on your machine using Docker and the official `gitlab-runner` image. No GitLab server required. A background daemon manages execution and streams results.

## Quick Start

```bash
# Install
make install && make docker

# Visualize pipeline
glci pipeline

# Run everything
glci run

# Run specific jobs
glci run build test

# Run a stage
glci run --stage build

# Interactive TUI (default when no subcommand)
glci
```

## Commands Reference

### `glci run [job...]` — Execute pipeline jobs

The primary command. Parses `.gitlab-ci.yml`, evaluates rules, builds a DAG, and dispatches jobs to the daemon.

**Key flags:**
| Flag | Default | Purpose |
|------|---------|---------|
| `-f, --file` | `.gitlab-ci.yml` | CI config path |
| `-e, --executor` | `docker` | Executor type (`docker`, `kubernetes`) |
| `--image` | `alpine:latest` | Default Docker image |
| `--stage` | | Run only jobs in this stage |
| `--env KEY=VALUE` | | Set variable (repeatable) |
| `--env-file` | | Load variables from file |
| `--secrets` | `all` | Fetch remote vars: `all`, `project`, `none` |
| `--git-strategy` | `clone` | Source strategy: `clone`, `fetch`, `none`, `remote` |
| `-j, --concurrency` | config or unlimited | Max parallel jobs (`0` = unlimited) |
| `--context` | `merge_request` | CI context: `branch=NAME`, `merge_request`, `tag=NAME`, `env=NAME`, or preset |
| `--mr-source` | | MR source branch |
| `--mr-target` | | MR target branch |
| `--input KEY=VALUE` | | Pipeline input (repeatable, for `spec: inputs:`) |
| `--inputs-file` | | Load inputs from YAML file |
| `-d, --detached` | | Start in background, exit immediately |
| `--skip` | | Skip a job (repeatable) |
| `--no-skip` | | Force-run a skipped job (repeatable) |
| `--no-skip-all` | | Disable all skip rules |
| `--manual` | | Auto-run a manual job (repeatable) |
| `--manual-all` | | Auto-run ALL manual jobs |
| `--no-manual` | | Disable manual auto-run for this run |
| `--simulate` | | Echo commands without executing |
| `--reuse-artifacts` | | Skip upstream deps when artifacts exist |
| `--registry` | | Custom registry URL |
| `--registry-user` | | Container registry username |
| `--registry-password` | | Container registry password |
| `--no-registry` | | Disable embedded registry |

**Ctrl+C behavior:** First press detaches (jobs continue in daemon). Second press cancels the pipeline.

**Exit codes:** `0` = success, `1` = job failure, `2` = other error.

**Examples:**
```bash
# Run with MR context
glci run --context merge_request --mr-source feature --mr-target main

# Run with variables
glci run --env CI_DEBUG=true --env DEPLOY_ENV=staging

# Load variables from file
glci run --env-file .env.local

# Simulate without executing
glci run --simulate

# Run detached
glci run -d

# Skip slow jobs
glci run --skip integration-tests --skip deploy

# Force manual jobs
glci run --manual deploy-staging

# Limit concurrency
glci run -j 2

# Use pipeline inputs
glci run --input version=1.2.3 --input env=staging

# Run fully offline (no secret fetching)
glci run --secrets none

# Use git-strategy none (no clone, use existing workdir)
glci run --git-strategy none

# Use a named context preset from config
glci run --context staging
```

### `glci pipeline` — Visualize pipeline

Shows ASCII pipeline graph with stages, jobs, DAG arrows, and status symbols (`○` pending, `●` running, `✓` passed, `✗` failed, `▶` manual, `⊘` skipped, `⚠` allow_failure).

| Flag | Default | Purpose |
|------|---------|---------|
| `-w, --watch` | | Live reload on file changes |
| `--debounce` | `300ms` | Debounce interval for watch mode |
| `--plain` | | Disable colors |
| `--no-dag` | | Hide inline DAG annotations |
| `--json` | | Output pipeline as JSON |
| `--context` | `merge_request` | Simulate CI context |
| `--mr-source` | | MR source branch |
| `--mr-target` | | MR target branch |
| `--input KEY=VALUE` | | Pipeline input (repeatable) |
| `--inputs-file` | | Load inputs from YAML file |

```bash
glci pipeline                    # One-shot render
glci pipeline --watch            # Live reload on file changes
glci pipeline --json             # JSON output
glci pipeline --context tag=v1.0 # Simulate tag pipeline
glci pipeline --no-dag           # Hide inline DAG annotations
glci pipeline --plain            # No colors
```

### `glci pipelines` — Pipeline history

```bash
glci pipelines                   # List recent pipelines
glci pipelines --limit 5         # Limit output
glci pipelines show              # Show latest pipeline details
glci pipelines show 5            # Show pipeline #5 (flags: --plain, --no-dag)
glci pipelines log               # All logs from latest (streams live if running)
glci pipelines log 5 build-job   # Specific job log
glci pipelines stop              # Stop active pipeline
glci pipelines stop 5 --job build # Stop specific job
glci pipelines clean             # Delete all history
glci pipelines clean --keep 5    # Keep last 5
```

### `glci stop [pipeline-id]` — Stop running pipelines

```bash
glci stop                        # Stop active pipeline
glci stop 5                      # Stop pipeline #5
glci stop 5 --job build          # Stop specific job
```

### `glci artifacts` — Manage artifacts

```bash
glci artifacts list              # List from latest pipeline
glci artifacts list --all        # List from all pipelines
glci artifacts download build    # Download artifact zip
glci artifacts download 38 build -o /tmp/out.zip
glci artifacts extract build     # Unzip artifact
glci artifacts inspect build     # List zip contents
glci artifacts delete 38         # Delete pipeline artifacts
glci artifacts delete --all      # Delete all artifacts
glci artifacts delete --older-than 7d
glci artifacts diff build 41 42  # Compare between runs
```

### `glci daemon` — Manage background daemon

The daemon auto-starts on first `glci run`. Usually no manual management needed.

```bash
glci daemon start                # Manual start
glci daemon stop                 # Graceful stop
glci daemon stop --force         # Force kill
glci daemon status               # Show PID, uptime, active pipelines
glci daemon logs                 # Last 50 lines
glci daemon logs -F              # Follow (tail -f)
glci daemon logs -n 100          # Last 100 lines
```

### `glci registry` — Embedded container registry

glci runs an OCI-compliant registry for `docker push`/`pull` within pipelines.

```bash
glci registry list               # List images
glci registry list --project grp/proj
glci registry pull <image> [prefix]  # Pull to local Docker
glci registry clean              # Delete all registry data
glci registry clean --project grp
glci registry stats              # Show storage usage
```

### `glci config show` — Show configuration

```bash
glci config show                 # Skip/manual rules
glci config show --gitlab        # GitLab instance config
glci config show --network       # Network, paths, TLS
```

### `glci version` — Version info

Shows CLI commit, daemon commit (if running), and detects version mismatch.

## Configuration

### Global: `~/.glci/config.toml`

```toml
[defaults]
concurrency = 4
executor = "docker"
image = "alpine:latest"

[runner]
default_version = ""       # pin gitlab-runner version
args = []                  # extra runner args

[daemon]
idle_timeout = "30m"
socket = ""                # override daemon socket path
log_file = ""              # override daemon log path

[registry]
url = ""                   # external registry URL override
username = ""
password = ""

[registry.upstream]
username = ""              # pull-through proxy credentials
password = ""

[network]
mock_server_bind = ""      # mock server listen address
container_host = ""        # container-visible host address
host_gateway = ""          # host gateway for containers
registry_bind = ""         # registry listen address
registry_http_bind = ""    # registry HTTP listen address
daemon_socket = ""         # override daemon socket

[network.extra_hosts]
entries = []               # additional /etc/hosts entries

[paths]
home = ""                  # override ~/.glci data dir
container_builds_dir = ""
container_cache_dir = ""
container_certs_dir = ""
registry_storage = ""
registry_ca_dir = ""

[tls]
extra_sans = []            # extra SANs for generated TLS certs
cert_validity = ""         # TLS cert validity duration

[contexts.staging]
context = "branch=staging"
env = { DEPLOY_ENV = "staging" }
mr_source = ""
mr_target = ""

[gitlab]
url = "https://gitlab.example.com"
token = "$GITLAB_TOKEN"
runner_releases_url = ""   # custom runner releases endpoint
```

### Project: `.glciconfig.toml`

If no `.glciconfig.toml` exists, glci creates one automatically with `[skip] stages = [".pre"]` (the `.pre` stage contains GitLab-internal jobs that cannot run locally). Set `GLCI_NO_DEFAULT_CONFIG=1` to disable.

```toml
[skip]
stages = ["deploy"]
jobs = ["deploy-production"]
job_patterns = ["*.db-*"]

[manual]
auto_run = true
jobs = ["deploy-staging"]
job_patterns = ["deploy-*"]

[gitlab]
url = "https://gitlab.example.com"
token = "$GITLAB_TOKEN"
```

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `GITLAB_TOKEN` / `GITLAB_PRIVATE_TOKEN` | GitLab API token |
| `GITLAB_URL` | GitLab instance URL |
| `GLCI_PREFER_API=1` | Use GitLab Lint API as primary parser |
| `GLCI_HOME` | Override `~/.glci` data directory |
| `GLCI_DAEMON_SOCK` | Override daemon socket path |
| `GLCI_NO_DEFAULT_CONFIG=1` | Disable auto-creation of default `.glciconfig.toml` |

### Local overrides: `.glci.env`

`KEY=VALUE` file auto-loaded from project root (gitignored).

## Global Flags (all subcommands)

| Flag | Purpose |
|------|---------|
| `-f, --file` | Path to CI config file |
| `--token` | GitLab private token |
| `--gitlab-url` | GitLab instance URL |
| `--project` | GitLab project path (e.g., `group/project`) |

## Key Behaviors

- **Offline parser** handles `include:`, `extends:`, `!reference`, `default:`, `workflow:`, `rules:`, parallel matrix. API fallback with `GLCI_PREFER_API=1`.
- **~49 CI/CD variables** set automatically (git-derived, server-derived, job-derived, registry).
- **Variable precedence**: CI-derived > YAML > Group > Project > CLI flags > env file > .glci.env > Job YAML.
- **DAG-aware scheduling**: `needs:` respected, independent jobs run in parallel.
- **Docker-in-Docker**: Privileged mode, socket mounting, embedded registry with `CI_REGISTRY_*` variables.
- **Crash recovery**: Orphaned containers cleaned up, stuck pipelines finalized on daemon restart.
- **Version mismatch detection**: Daemon auto-restarts when CLI version differs.
- **TUI mode**: Running `glci` with no subcommand launches an interactive terminal UI. Navigate with arrow keys/hjkl, Enter to drill in, Esc to go back, `?` for help.

## Common Workflows

**Debug a failing CI job locally:**
```bash
glci pipeline                          # See what would run
glci run failing-job --env CI_DEBUG=true  # Run just that job with debug
glci pipelines log                     # Check the output
```

**Test MR pipeline rules:**
```bash
glci pipeline --context merge_request --mr-source feature --mr-target main
```

**Iterate quickly on a single job:**
```bash
glci run build --reuse-artifacts       # Skip upstream deps
```

**Run full pipeline but skip slow jobs:**
```bash
glci run --skip e2e-tests --skip deploy-production
```

**Check what config is active:**
```bash
glci config show
glci config show --gitlab
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| "daemon is not running" | Run `glci daemon start` or just `glci run` (auto-starts) |
| "version mismatch" | Daemon auto-restarts; or run `glci daemon stop && glci run` |
| `include: project:` fails | Set `GITLAB_TOKEN` env var or `--token` flag |
| Jobs fail with `CI_JOB_TOKEN` | Not supported locally; mock the API call or skip the job |
| "no Docker image" errors | Run `make docker` to build the glci Docker image |
| Stale daemon after code changes | `make install && glci daemon stop` then re-run |

## Limitations

- `CI_JOB_TOKEN` not available (jobs using it to call GitLab API will fail)
- `include: project:` and `include: component:` require `GITLAB_TOKEN`
- `retry:` and `timeout:` keywords parsed but not enforced
- Child pipelines (`trigger: include:`) parsed but not executed
- Kubernetes executor not yet supported
- ~25 server-only CI variables cannot be faked locally
