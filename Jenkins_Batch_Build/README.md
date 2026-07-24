# Jenkins Batch Build

Local control panel to pick jobs from three Jenkins CI servers, save them as named **packages**, and **Start / Stop** (abort) all jobs in a package in parallel — with live status.

## Requirements

- **Node.js 20+** (includes `npm`)
- Access to the company LAN so the three Jenkins machines are reachable
- Your personal Jenkins **username** + **password** or **API token** for each CI

Check Node:

```bash
node -v
npm -v
```

## Jenkins servers

Default CIs are seeded on first run (editable under **CI servers** in the app):

| ID | URL |
|---|---|
| `ci-8` | http://10.4.2.8:8080 |
| `ci-6` | http://10.4.2.6:8080 |
| `ci-5` | http://10.4.2.5:8080 |

You can **add / edit / delete** CI servers in the UI. They are stored in `data/servers.json`.

## First-time setup

From the project root (`Jenkins_Batch_Build`):

```bash
# 1) Install root + client dependencies
npm run install:all

# 2) Start API + UI together
npm run dev
```

Wait until the terminal shows both:

- `Jenkins Batch Build API on http://127.0.0.1:8089`
- `Local: http://localhost:8088/`

Then open the UI in your browser:

**http://localhost:8088**

Leave that terminal running while you use the tool. Stop with `Ctrl+C`.

## Start again later (already installed)

```bash
cd /path/to/Jenkins_Batch_Build
npm run dev
```

Open **http://localhost:8088** again.

## How to use

1. (Optional) Open **CI servers** to add/edit/delete Jenkins URLs and descriptions
2. Click **New package**
3. For each CI card, enter your **username** and **password / API token** → **Connect & load jobs**
4. Go **Next** → select jobs across the connected CIs
5. Name the package, add an optional **description** → **Save package**
6. On **Packages**, use **▶ Start** / **■ Stop**, or **Rename** to edit name/description
7. Click **Details** to see live per-job status (polls about every 4 seconds)

### Credentials

- Saved in this browser’s **localStorage** (username + password/API token)
- On reopen, the app **autofills** and **auto-reconnects** all saved CIs
- Use **Forget saved logins** on the Connect step to clear them
- **Never** written into `data/packages.json` (packages store job names only)

Only use this on your own machine / trusted browser — passwords stay in local browser storage.

## Useful URLs

| What | URL |
|---|---|
| Web UI | http://localhost:8088 |
| API health | http://127.0.0.1:8089/api/health |

## Optional: run API or UI alone

```bash
# API only (port 8089)
npm run server

# UI only (port 8088; still needs the API running)
npm run client
```

## Notes

- **Start** triggers all jobs in the package at once (parallel).
- **Stop** aborts the currently running build of each job (if any).
- Jobs with required parameters (no usable defaults) may still fail to start in v1.
- Saved packages live in `data/packages.json` (job names only — no passwords).
- When a started package finishes, this Mac gets a **Notification Center** alert (success / fail). Allow browser notifications if prompted.

## Troubleshooting

| Problem | What to try |
|---|---|
| Page won’t load | Confirm `npm run dev` is still running; open http://localhost:8088 |
| Connect fails | Check username/password; confirm you can open that Jenkins URL in a browser |
| Start fails | Re-connect in this tab; expand **Details** / toast for the Jenkins error |
| Port in use | Stop the other process using `8088` or `8089`, then run `npm run dev` again |
