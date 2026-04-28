# docker-prune

> A compose-aware Docker cleanup utility that surgically removes every resource tied to the project in your current directory — containers, images, volumes, networks, and build cache — without touching unrelated projects.

---

## Table of Contents

- [Why this exists](#why-this-exists)
- [How it works](#how-it-works)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
  - [Basic invocation](#basic-invocation)
  - [All options](#all-options)
  - [Common recipes](#common-recipes)
- [Cleanup steps explained](#cleanup-steps-explained)
- [Project name resolution](#project-name-resolution)
- [Supported compose file names](#supported-compose-file-names)
- [Dry-run mode](#dry-run-mode)
- [Global prune mode](#global-prune-mode)
- [Exit codes](#exit-codes)
- [Safety notes](#safety-notes)
- [FAQ](#faq)
- [License](#license)

---

## Why this exists

Running `docker compose down` is often not enough. It stops containers and removes the default network, but it leaves behind:

- Named volumes (unless you pass `-v`)
- Images built or pulled for the project (unless you pass `--rmi all`)
- Orphaned containers from previous runs
- The Docker build cache, which can grow to many gigabytes over time

Passing every flag every time is tedious and error-prone. `docker-prune.sh` wraps all of that into a single command with sensible defaults, coloured output, and a dry-run mode so you always know exactly what will be deleted before it happens.

---

## How it works

The script performs six sequential cleanup steps, all scoped to the Compose project in the current directory:

```
Step 1  →  Stop all running project containers
Step 2  →  docker compose down (removes containers, networks, volumes, images)
Step 3  →  Force-remove any orphaned containers by project label
Step 4  →  Force-remove any remaining project-labelled images
Step 5  →  Force-remove any remaining project-labelled volumes
Step 6  →  docker builder prune (clears the build cache)
```

Each step reports its status with coloured log output (`[INFO]`, `[ OK ]`, `[WARN]`, `[ERR ]`). If a step finds nothing to clean up it skips gracefully — no errors, no noise.

---

## Requirements

| Requirement | Minimum version | Notes |
|---|---|---|
| Bash | 4.0+ | Available on all modern Linux distros and macOS with Homebrew |
| Docker Engine | 20.10+ | Required for label-based filtering |
| Docker Compose | V2 (`docker compose`) **or** V1 (`docker-compose`) | Script auto-detects which is available |

The script checks for all dependencies at startup and exits with a clear error message if anything is missing.

---

## Installation

### Option A — Copy into your project

Place `docker-prune.sh` directly in the root of your project, next to your `docker-compose.yml`:

```
my-project/
├── docker-compose.yml
├── docker-prune.sh   ← here
├── backend/
└── frontend/
```

### Option B — Install globally

Copy the script to a directory on your `PATH` so it is available from any project:

```bash
sudo cp docker-prune.sh /usr/local/bin/docker-prune
sudo chmod +x /usr/local/bin/docker-prune
```

Then call it from any directory that contains a compose file:

```bash
cd ~/projects/my-app
docker-prune
```

### Make it executable (both options)

```bash
chmod +x docker-prune.sh
```

---

## Usage

### Basic invocation

```bash
# Run from the directory containing your docker-compose.yml
./docker-prune.sh
```

Without any flags the script will:

1. Detect your compose file and project name.
2. Show a confirmation prompt listing what will be deleted.
3. Execute all six cleanup steps on confirmation.

### All options

```
Usage:
  docker-prune.sh [OPTIONS]

Options:
  -h, --help        Show help and exit
  -n, --dry-run     Print every command that would run — nothing is deleted
  -f, --force       Skip the confirmation prompt (useful in CI/CD)
      --no-volumes  Keep named volumes, skip volume removal steps
      --no-images   Keep images, skip image removal steps
      --no-networks Keep project networks (networks are still removed by
                    'compose down'; this flag suppresses the label sweep)
      --no-cache    Skip 'docker builder prune'
      --global      After project cleanup, also run 'docker system prune'
                    to remove ALL dangling resources across every project
```

### Common recipes

```bash
# Preview everything that would be deleted (safe — nothing is changed)
./docker-prune.sh --dry-run

# Full wipe, no prompt — ideal for CI pipelines or reset scripts
./docker-prune.sh --force

# Wipe everything except the database volume (so your data survives)
./docker-prune.sh --no-volumes

# Wipe containers and networks only — keep images to avoid re-pulling
./docker-prune.sh --no-images --no-cache

# Nuclear option: wipe this project AND all dangling Docker resources globally
./docker-prune.sh --global --force

# Combine flags freely
./docker-prune.sh --no-volumes --no-cache --force
```

---

## Cleanup steps explained

### Step 1 — Stop running containers

```bash
docker compose -f <file> stop
```

Gracefully stops all containers that are currently running in the project. Skipped automatically if no containers are running.

### Step 2 — Compose down

```bash
docker compose -f <file> down --remove-orphans [--volumes] [--rmi all]
```

The core teardown command. Removes containers, the default project network, and (unless `--no-volumes` or `--no-images` are passed) volumes and images declared in the compose file. `--remove-orphans` cleans up containers from services that no longer exist in the compose file.

### Step 3 — Orphaned container sweep

```bash
docker rm -f $(docker ps -a --filter "label=com.docker.compose.project=<name>" -q)
```

Catches any containers that `compose down` missed — for example containers that were started manually with `docker run` but tagged with the project label, or containers left behind from a crashed previous run.

### Step 4 — Image sweep

```bash
docker rmi -f $(docker images --filter "label=com.docker.compose.project=<name>" -q)
```

Removes images that carry the project label. This catches images built locally with `docker compose build` that `compose down --rmi all` may not fully clean up, for example when image names were changed between runs.

### Step 5 — Volume sweep

```bash
docker volume rm -f $(docker volume ls --filter "label=com.docker.compose.project=<name>" -q)
```

Removes named volumes that carry the project label. Complements `compose down --volumes`, which only removes volumes declared in the compose file's `volumes:` section — this sweep catches any volumes created at runtime.

### Step 6 — Build cache prune

```bash
docker builder prune -f
```

Clears the entire Docker BuildKit cache. This is a **global** operation (Docker does not expose per-project cache filtering), so it affects cached layers from all projects. It is the single fastest way to reclaim large amounts of disk space after intensive builds.

> **Tip:** Use `--no-cache` if you share a build host with other teams and want to avoid evicting their cache layers.

---

## Project name resolution

The script derives the project name using the same logic Docker Compose itself uses:

1. If the environment variable `COMPOSE_PROJECT_NAME` is set, that value is used.
2. Otherwise, the name defaults to the **basename of the current working directory**.

```bash
# Override the project name without renaming your directory
COMPOSE_PROJECT_NAME=myapp ./docker-prune.sh
```

This matters for steps 3–5, which filter Docker resources by the label `com.docker.compose.project=<name>`. If the project name does not match what Compose used when the stack was originally created, those steps will find nothing — which is safe (no false deletions), but you may need to set `COMPOSE_PROJECT_NAME` explicitly to match the original name.

---

## Supported compose file names

The script checks for these filenames in order and uses the first one it finds:

| Priority | Filename |
|---|---|
| 1 | `docker-compose.yml` |
| 2 | `docker-compose.yaml` |
| 3 | `compose.yml` |
| 4 | `compose.yaml` |

If none are present in the current directory the script exits immediately with an error. It will never silently operate on the wrong directory.

---

## Dry-run mode

Dry-run mode (`-n` / `--dry-run`) is the safest way to explore what the script would do:

```bash
./docker-prune.sh --dry-run
```

Every command that *would* be executed is printed to stdout prefixed with `[dry-run]`. No Docker resources are created, modified, or deleted. The compose file detection, project name resolution, and dependency checks still run normally, so any configuration problems are surfaced without risk.

Example output:

```
╔══════════════════════════════════════════════╗
║        Docker Compose — Prune Utility        ║
╚══════════════════════════════════════════════╝

[INFO]  Compose file : docker-compose.yml
[INFO]  Project name : my-app
[INFO]  Dry-run mode : true
──────────────────────────────────────────────────
[INFO]  Step 1/6 — Stopping running containers …
  [dry-run] docker compose -f 'docker-compose.yml' stop
──────────────────────────────────────────────────
[INFO]  Step 2/6 — Removing containers and project networks …
  [dry-run] docker compose -f 'docker-compose.yml' down --remove-orphans --volumes --rmi all
──────────────────────────────────────────────────
[INFO]  Step 3/6 — Checking for orphaned containers …
  [dry-run] docker rm -f <ids>
...

Dry-run complete — nothing was deleted.
```

---

## Global prune mode

The `--global` flag appends a `docker system prune` call **after** the project-scoped cleanup:

```bash
./docker-prune.sh --global --force
```

This removes **all** unused Docker resources on the host — dangling images, stopped containers, unused networks, and (when combined without `--no-volumes`) all unused volumes — regardless of which project they belong to.

> ⚠️ **Use with caution on shared hosts.** Global prune affects every Docker project on the machine, not just the current one. It is most appropriate on development machines or dedicated single-project CI runners.

---

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success, or dry-run completed, or user chose to abort at the prompt |
| `1` | Fatal error — missing compose file, missing dependency, or unknown flag |

---

## Safety notes

**Confirmation prompt** — without `--force`, the script always asks before deleting anything. Type `y` or `yes` to proceed; anything else (including pressing Enter without typing) aborts cleanly.

**Scope** — steps 1–5 are strictly scoped to the current project by Docker label. Resources belonging to other projects are never touched unless `--global` is passed.

**Build cache** — step 6 (`docker builder prune`) is the only inherently global step. Pass `--no-cache` to preserve cache layers shared with other projects on the same host.

**Irreversibility** — deleted volumes and their contents cannot be recovered. Always run `--dry-run` first if you are unsure, and ensure important data (e.g. database volumes) is either backed up or excluded with `--no-volumes`.

**`set -euo pipefail`** — the script runs with strict error handling. Any unexpected command failure causes an immediate exit rather than silently continuing.

---

## FAQ

**Q: The script says "No project-labelled images/volumes found" even though they exist.**

Compose only attaches the `com.docker.compose.project` label to resources it manages directly. Images pulled externally (e.g. with `docker pull`) or volumes created outside of Compose will not carry the label. Use `docker rmi` / `docker volume rm` to remove them manually, or run with `--global` to catch all dangling resources system-wide.

---

**Q: Can I use this in a CI/CD pipeline?**

Yes. Pass `--force` to suppress the interactive prompt:

```yaml
# GitHub Actions example
- name: Clean up Docker environment
  run: ./docker-prune.sh --force
```

---

**Q: I renamed my project directory and now the label filter finds nothing.**

Set `COMPOSE_PROJECT_NAME` to the name that was in use when the stack was first started:

```bash
COMPOSE_PROJECT_NAME=old-name ./docker-prune.sh
```

---

**Q: Does this work with Docker Compose V1 (`docker-compose`)?**

Yes. The script auto-detects whether `docker compose` (V2, the CLI plugin) or `docker-compose` (V1, the standalone binary) is available, preferring V2. If neither is found it exits with a clear error.

---

**Q: Will this remove volumes from other projects?**

No — unless you pass `--global`. Steps 3–5 filter strictly by the label `com.docker.compose.project=<your-project-name>`, which is unique per project.

---

**Q: What if my compose file is in a subdirectory?**

`cd` into the directory containing the compose file before running the script. The script always operates on the current working directory.

---

## License

MIT — see [LICENSE](LICENSE) for details.
