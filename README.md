# mac-tools

Personal CLI tools for macOS.

## Tools

### `multiping`

A curses-based terminal dashboard for monitoring latency across multiple hosts simultaneously.

```
multiping <interval_secs> <host1> [host2] ...
```

Displays a column per host with a live scrolling ping history and a stats header showing median, average, p95 latency, and drop % over the last ~60 seconds. Timeouts and unreachable hosts are tracked separately and shown in red. Stats are recomputed only when new pings arrive to keep CPU usage low.

Requires `ping` (standard on macOS). Interval must be ≥ 0.2 seconds.

---

### `ai_limits`

Reports free-tier quota usage across developer services in a single dashboard.

```
ai_limits
```

Covers:

- **Claude** — 5-hour and 7-day rate limit windows with % used and time remaining
- **GitHub Actions** — monthly minutes used vs. included allowance
- **Render.com** — monthly build minutes used vs. free-tier allowance
- **Neon** — per-project compute (CU-hours), storage (MiB), and account-wide egress
- **Cloudflare** — Pages builds (monthly) and Workers requests (daily)

Each metric is shown as a progress bar with a traffic-light indicator (🟢🟠🔴) based on whether usage is ahead or behind the elapsed time in the billing period.

**Configuration:**

| Variable | How to provide |
|---|---|
| `GITHUB_ORG` | Set to your GitHub org or username (used for Actions billing API) |

**Credentials:**

| Service | How to provide |
|---|---|
| Claude | Read automatically from macOS keychain (Claude Code stores it there) |
| GitHub | Uses `gh` CLI — run `gh auth login` if not already authenticated |
| Neon | `NEON_API_KEY` env var, or `security add-generic-password -s "neon-api-key" -a "$USER" -w "<key>"` |
| Cloudflare | `CF_API_TOKEN` env var, or `security add-generic-password -s "cloudflare-api-token" -a "$USER" -w "<key>"` |
| Render | `RENDER_API_KEY` env var only |

---

### `ai_builds`

Displays the current status of CI/CD workflow runs, service deploys, and database endpoints across your infrastructure.

```
ai_builds [interval_mins]
```

Shows four sections:

- **Rebuilds** — last run of the sandbox rebuild workflow per repo
- **Delete merged branches** — last run of the branch cleanup workflow per repo
- **Checks (production / sandbox01)** — CI, CD, and database migration workflow status per repo; Render.com deploy status per service; Neon endpoint state (active/idle) per project branch

Each entry has a traffic-light dot: 🟢 passed/live/active · 🔵 in progress · 🟠 cancelled/idle · 🔴 failed · ⚪ unknown or no runs.

Pass an optional interval in minutes to keep the display auto-refreshing.

**Configuration:**

The repos and workflow files `ai_builds` queries are set via environment variables. Edit the defaults at the top of the script to match your project's workflow filenames.

| Variable | Default | Description |
|---|---|---|
| `GITHUB_ORG` | _(required)_ | GitHub org or username |
| `BACKEND_REPO` | `backend` | Name of the backend repo |
| `IOS_REPO` | `ios-app` | Name of the iOS app repo |

**Credentials:**

| Service | How to provide |
|---|---|
| GitHub | Uses `gh` CLI — run `gh auth login` if not already authenticated |
| Neon | `NEON_API_KEY` env var, or macOS keychain (see `ai_limits`) |
| Render | `RENDER_API_KEY` env var only |
