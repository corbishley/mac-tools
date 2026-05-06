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

**Credentials:**

| Service | How to provide |
|---|---|
| Claude | Read automatically from macOS keychain (Claude Code stores it there) |
| GitHub | Uses `gh` CLI — run `gh auth login` if not already authenticated |
| Neon | `NEON_API_KEY` env var, or `security add-generic-password -s "neon-api-key" -a "$USER" -w "<key>"` |
| Cloudflare | `CF_API_TOKEN` env var, or `security add-generic-password -s "cloudflare-api-token" -a "$USER" -w "<key>"` |
| Render | `RENDER_API_KEY` env var only |
