# mac-tools

Personal CLI tools for macOS.

## Install

Put the `scripts` directory on your `PATH`:

```sh
export PATH="$PATH:/path/to/mac-tools/scripts"
```

**Requirements:** `python3`, plus `jq`, `curl` and the [`gh`](https://cli.github.com) CLI for `ai_limits` and `ai_builds`.

## Tools

### `multiping`

A curses-based terminal dashboard for monitoring latency across multiple hosts simultaneously.

```
multiping <interval_secs> <host1> [host2] ...
```

Displays a column per host with a live scrolling ping history and a stats header showing median, average, p95 latency, and drop % over the last ~60 seconds. Timeouts and unreachable hosts are tracked separately and shown in red. Stats are recomputed only when new pings arrive to keep CPU usage low.

Interval must be ≥ 0.2 seconds.

### `ai_limits`

Reports free-tier quota usage across developer services in a single dashboard.

```
ai_limits [interval_mins]
```

Covers:

- **Claude**: 5-hour and 7-day rate limit windows with % used and time remaining
- **GitHub Actions**: monthly minutes used vs. included allowance
- **Render.com**: monthly build minutes used vs. free-tier allowance
- **Neon**: per-project compute (CU-hours), storage (MiB), and account-wide egress
- **Cloudflare**: Pages builds (monthly) and Workers requests (daily)

Each metric is shown as a progress bar with a traffic-light indicator (🟢🟠🔴) based on whether usage is ahead of or behind the elapsed time in the billing period. Pass an optional interval in minutes to keep the display auto-refreshing.

### `ai_builds`

Displays the current status of CI/CD workflow runs, service deploys, and database endpoints across your infrastructure.

```
ai_builds [interval_mins]
```

Sections:

- **Rebuilds**: last run of the sandbox rebuild workflow per repo
- **Delete merged branches**: last run of the branch cleanup workflow per repo
- **Checks (production / sandbox01)**: CI, CD, and database migration workflow status per repo; Render.com deploy status per service; Neon endpoint state (active/idle) per project branch

Each entry has a traffic-light dot: 🟢 passed/live/active · 🔵 in progress · 🟠 cancelled/idle · 🔴 failed · ⚪ unknown or no runs.

Pass an optional interval in minutes to keep the display auto-refreshing. Workflow filenames and environments are set at the top of the script; edit them to match your project.

## Configuration

| Variable | Used by | Default | Description |
|---|---|---|---|
| `GITHUB_ORG` | both | _(required)_ | GitHub org or username |
| `BACKEND_REPO` | `ai_builds` | `backend` | Name of the backend repo |
| `IOS_REPO` | `ai_builds` | `ios-app` | Name of the iOS app repo |

## Credentials

| Service | How to provide |
|---|---|
| Claude | Read automatically from the macOS keychain (Claude Code stores it there) |
| GitHub | Uses the `gh` CLI; run `gh auth login` if not already authenticated |
| Neon | `NEON_API_KEY` env var, or `security add-generic-password -s "neon-api-key" -a "$USER" -w "<key>"` |
| Cloudflare | `CF_API_TOKEN` env var, or `security add-generic-password -s "cloudflare-api-token" -a "$USER" -w "<key>"` |
| Render | `RENDER_API_KEY` env var only |

## Licence

MIT, see [LICENSE](LICENSE).
