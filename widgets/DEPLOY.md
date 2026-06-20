# Deploying MacToolsWidgets

Step-by-step guide to building and installing the widgets on a Mac from scratch.

---

## Prerequisites

Install these once if you don't have them:

```bash
# Xcode (required — install from App Store or developer.apple.com)
xcodebuild -version   # should print "Xcode 15" or later

# xcodegen (generates the Xcode project from project.yml)
brew install xcodegen
```

macOS 14 Sonoma or later is required for WidgetKit on macOS.

---

## 1. Pull the latest code

```bash
cd ~/git/corbishley/mac-tools
git pull
```

---

## 2. Generate the Xcode project

The `.xcodeproj` is not committed — you must generate it each time you pull changes.

```bash
cd widgets
xcodegen generate
```

You should see `Generating plists...` and `Creating project...` with no errors.

---

## 3. Open in Xcode and set your signing team

```bash
open MacToolsWidgets.xcodeproj
```

In Xcode:

1. Click the **MacToolsWidgets** project in the left sidebar (the blue icon at the very top)
2. Select the **MacToolsWidgets** target → **Signing & Capabilities**
3. Under **Team**, select your personal Apple ID
4. Repeat for the **AILimitsWidget** and **AIBuildsWidget** targets

> If you see "No account found", go to **Xcode → Settings → Accounts** and add your Apple ID.

---

## 4. Build and run

1. Make sure the scheme selector at the top of Xcode shows **MacToolsWidgets** and **My Mac**
2. Press **⌘R** to build and run
3. The MacToolsWidgets settings app will open — this is normal

---

## 5. Add the widgets to your desktop

1. Right-click anywhere on the macOS desktop
2. Click **Edit Widgets**
3. Search for **AIBuildsWidget** or **AILimitsWidget**
4. Drag them onto your desktop

---

## 6. Configure settings

Open the **MacToolsWidgets** app (it appears in your Dock when running, or find it in Spotlight).

Fill in:

| Field | What to enter |
|---|---|
| GitHub Token | A GitHub personal access token with `repo` and `read:org` scopes |
| GitHub Org | `shoesthatfit-me` |
| Backend Repo | `backend` |
| iOS Repo | `ios-app` |
| Render API Key | Your Render.com API key (from render.com → Account Settings → API Keys) |
| Refresh (mins) | `1` |

Click **Save**. The widgets will refresh within a minute.

---

## 7. Keychain secrets (one-time setup)

The Neon API key is read from the macOS keychain. If the widget shows no Neon data:

```bash
security add-generic-password -s "neon-api-key" -a "$USER" -w "<your-neon-api-key>"
```

The Claude token is read automatically from the keychain entry Claude Code creates — no action needed.

---

## Rebuilding after code changes

Any time you pull new changes:

```bash
cd ~/git/corbishley/mac-tools/widgets
xcodegen generate
```

Then in Xcode press **⌘R**. The widgets update automatically once the new build is running.
