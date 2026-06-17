# macOS Widget Plan

Two native macOS desktop widgets (WidgetKit, requires macOS 14 Sonoma+) built from the bash scripts in `scripts/`.

---

## Repo structure (target state)

```
mac-tools/
├── scripts/
│   ├── ai_limits
│   ├── ai_builds
│   └── multiping
├── widgets/
│   ├── project.yml                    # xcodegen manifest — run to generate .xcodeproj
│   ├── MacToolsWidgets.xcodeproj/     # generated, gitignored
│   ├── App/
│   │   ├── MacToolsWidgetsApp.swift
│   │   ├── SettingsView.swift
│   │   └── Assets.xcassets/
│   ├── AILimitsWidget/
│   │   ├── AILimitsWidget.swift       # @main widget entry + config
│   │   ├── Provider.swift             # TimelineProvider, fetches all APIs
│   │   ├── Views/
│   │   │   ├── MediumView.swift       # Claude only
│   │   │   └── LargeView.swift        # all services
│   │   └── Assets.xcassets/
│   ├── AIBuildsWidget/
│   │   ├── AIBuildsWidget.swift       # @main widget entry
│   │   ├── Provider.swift
│   │   ├── Views/
│   │   │   └── WidgetView.swift       # medium + large
│   │   └── Assets.xcassets/
│   └── Shared/
│       ├── Models.swift               # all data models
│       ├── APIClient.swift            # all API networking
│       └── KeychainHelper.swift       # reads keychain entries
```

---

## Widget designs

### AILimitsWidget (from `scripts/ai_limits`)

Quota usage across all services — native SwiftUI progress bars + traffic light dots.

| Size | Content |
|---|---|
| Medium | Claude 5-hour + 7-day windows only |
| Large | Claude + GitHub Actions + Render + Neon + Cloudflare |

- Each row: coloured dot + label + `ProgressView` bar + percentage + reset countdown
- Traffic light logic: 🟢 on-track, 🟠 slightly ahead of time, 🔴 significantly ahead of time
- Refresh: every 1 minute (configurable)

### AIBuildsWidget (from `scripts/ai_builds`)

CI/CD and service status — coloured status dot grid.

| Size | Content |
|---|---|
| Medium | Production workflows only |
| Large | Production + sandbox |

- 🟢 success · 🔴 failure · 🔵 in-progress · 🟠 cancelled · ⚪ unknown/no runs
- Render deploy status + Neon endpoint state (active/idle)
- **Wake calls are omitted** — widget is read-only (keep using the bash script for that)

---

## Settings (entered once in host app, shared to both widgets via App Group)

| Setting | Default | Notes |
|---|---|---|
| `GITHUB_ORG` | — | required |
| `BACKEND_REPO` | `backend` | |
| `IOS_REPO` | `ios-app` | |
| `RENDER_API_KEY` | — | not in keychain |
| `REFRESH_MINS` | `1` | |

## Keychain keys (already configured by bash scripts — no changes needed)

| Secret | Keychain service string |
|---|---|
| Claude OAuth token | `Claude Code-credentials` (JSON → `.claudeAiOauth.accessToken`) |
| Neon API key | `neon-api-key` |
| Cloudflare API token | `cloudflare-api-token` |

The widget extension reads these via a Keychain sharing entitlement + App Group.

---

## API reference

### AILimitsWidget

| Service | Endpoint |
|---|---|
| Claude | `GET https://api.anthropic.com/api/oauth/usage` — Bearer token, header `anthropic-beta: oauth-2025-04-20` |
| GitHub Actions | `GET /orgs/{org}/settings/billing/usage?year={y}&month={m}` — paginated; filter `product == "actions"`; multipliers Ubuntu×1, Windows×2, macOS×10 |
| Render | `GET /v1/services?limit=100` → `GET /v1/services/{id}/deploys?limit=100` — sum build minutes this month |
| Neon | `GET /api/v2/projects?limit=100` (org fallback) → `GET /api/v2/projects/{id}/branches` for storage bytes |
| Cloudflare Pages | `GET /accounts/{id}/pages/projects` → deploys per project, count this month |
| Cloudflare Workers | GraphQL `workersInvocationsAdaptive` — today's request count |

### AIBuildsWidget

| Service | Endpoint |
|---|---|
| GitHub workflows | `GET /repos/{org}/{repo}/actions/workflows/{file}/runs?per_page=1` — one call per workflow |
| Render | `GET /v1/services/{id}/deploys?limit=1` — latest deploy status |
| Neon endpoints | `GET /api/v2/projects/{id}/endpoints` — filter `type == "read_write"`, report `current_state` |

---

## Build steps

### Prerequisites
```bash
xcodebuild -version   # need Xcode installed
sw_vers               # need macOS 14+
xcodegen --version    # install with: brew install xcodegen
```

### Steps
1. Move scripts: `git mv ai_limits ai_builds multiping scripts/`
2. Claude writes all Swift source files + `widgets/project.yml`
3. `cd widgets && xcodegen generate`
4. Open `widgets/MacToolsWidgets.xcodeproj` in Xcode
5. Build for My Mac (⌘B), run once to register the app
6. Right-click desktop → Edit Widgets → add AILimitsWidget / AIBuildsWidget
7. Open MacToolsWidgets app → fill in settings
8. `.gitignore` excludes `widgets/MacToolsWidgets.xcodeproj/`
