# Jenkins Batch Build — Design Spec

**Date:** 2026-07-24  
**Status:** Approved for planning (pending user review of this doc)

## Goal

A local web app to authenticate to three Jenkins CI servers with the user’s own credentials, pick jobs across those servers, save them as named **packages**, and Start/Stop (abort) all jobs in a package in parallel — with live build status and a Confluence-like UI.

## Decisions (locked)

| Topic | Choice |
|---|---|
| Stack | Vite + React SPA + Express proxy |
| Layout | Guided wizard (Connect → Pick jobs → Name package), then Packages home |
| Visual style | Classic Confluence / Atlassian (blue `#0052CC`, light gray canvas, crisp cards) |
| Auth | Per-user username + password/API token entered in UI for each CI |
| Start | Fire all package jobs in parallel |
| Stop | Abort currently running build of each job in the package |
| Status | Live poll (~4s) while package is active / page visible |
| Parameters | Out of scope for v1 |
| Sequential runs | Out of scope for v1 |
| Disable-job as Stop | Out of scope for v1 |

## Architecture

```
Browser (React)
  │  sessionStorage: { serverId → { username, password } }
  │  Authorization / body forwarded per request
  ▼
Express (localhost)
  │  proxies Jenkins API with Basic auth
  │  CRUD packages → data/packages.json
  ▼
Jenkins ×3
  http://10.4.2.8:8080
  http://10.4.2.6:8080
  http://10.4.2.5:8080
```

- Browser never calls Jenkins directly (avoids CORS; keeps a single auth path).
- Express never persists user passwords to disk.
- Packages store only job references (`serverId` + `jobName`), never credentials.

## Jenkins servers (config)

Fixed in app config (editable later if needed):

| serverId | baseUrl | label |
|---|---|---|
| `ci-8` | `http://10.4.2.8:8080` | CI · 10.4.2.8 |
| `ci-6` | `http://10.4.2.6:8080` | CI · 10.4.2.6 |
| `ci-5` | `http://10.4.2.5:8080` | CI · 10.4.2.5 |

## User flows

### 1. Connect (wizard step 1)

1. Show three CI cards with prefilled base URLs.
2. User enters username + password/API token per CI.
3. User clicks **Connect & load jobs** on a card (or Connect all).
4. Frontend `POST /api/jenkins/:serverId/connect` with credentials.
5. On success: mark CI connected, cache job list in memory; store credentials in `sessionStorage`.
6. **Continue** enabled when ≥1 CI is connected.

### 2. Pick jobs (wizard step 2)

1. Show connected CIs as columns/sections with searchable checklists.
2. User multi-selects jobs across servers.
3. Selection count shown; **Next** requires ≥1 job.

### 3. Name & save package (wizard step 3)

1. User enters package name (required, unique among existing packages).
2. Review selected job list.
3. `POST /api/packages` → persist; navigate to Packages home.

### 4. Packages home

1. List package cards with name, job count, aggregate health.
2. Per card: **Start**, **Stop**, expand for per-job live status, delete.
3. **+ New package** re-enters wizard (skip Connect if session still has valid creds/jobs).
4. While any package has a building job (or after Start until settled), poll `GET /api/packages/:id/status` ~every 4s.

## Data model

### Package (`data/packages.json`)

```json
{
  "packages": [
    {
      "id": "uuid",
      "name": "Nightly Suite",
      "jobs": [
        { "serverId": "ci-8", "jobName": "build-ios" }
      ],
      "createdAt": "2026-07-24T05:00:00.000Z",
      "updatedAt": "2026-07-24T05:00:00.000Z"
    }
  ]
}
```

### Session credentials (browser only)

```json
{
  "ci-8": { "username": "...", "password": "..." }
}
```

### Job list (in-memory / React state after connect)

```json
{
  "serverId": "ci-8",
  "jobs": [
    { "name": "build-ios", "url": "...", "color": "blue" }
  ]
}
```

## API

All mutating Jenkins calls require credentials in the request body (or `X-Jenkins-Auth` header as base64 `user:pass` per server). Preferred: JSON body field `credentials: { username, password }` scoped to the target `serverId`, and for package start/stop/status a map `credentialsByServer: { "ci-8": { username, password }, ... }`.

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/servers` | List configured servers |
| `POST` | `/api/jenkins/:serverId/connect` | Validate auth; return job list |
| `GET` | `/api/jenkins/:serverId/jobs` | Refresh jobs (creds required) |
| `GET` | `/api/packages` | List packages |
| `POST` | `/api/packages` | Create package `{ name, jobs }` |
| `PATCH` | `/api/packages/:id` | Rename / replace jobs |
| `DELETE` | `/api/packages/:id` | Delete package |
| `POST` | `/api/packages/:id/start` | Parallel `build` / `buildWithParameters` skip — use standard build trigger only |
| `POST` | `/api/packages/:id/stop` | Parallel abort of last/current build |
| `GET` | `/api/packages/:id/status` | Per-job status snapshot |

### Jenkins operations (server-side)

- **List jobs:** `GET {base}/api/json?tree=jobs[name,url,color]`
- **Start:** `POST {base}/job/{name}/build` (with crumb if CSRF enabled)
- **Stop/abort:** resolve last build number via job API, then `POST .../job/{name}/{n}/stop` (and `/kill` fallback if needed)
- **Status:** job `color` + `lastBuild[number,result,building,url]`
- **CSRF:** fetch crumb from `/crumbIssuer/api/json` when present; attach to POSTs

### Response shapes (illustrative)

**Status**
```json
{
  "packageId": "...",
  "jobs": [
    {
      "serverId": "ci-8",
      "jobName": "build-ios",
      "building": true,
      "result": null,
      "buildNumber": 42,
      "color": "blue_anime",
      "url": "http://10.4.2.8:8080/job/build-ios/"
    }
  ]
}
```

**Start/Stop** return per-job success/failure so the UI can show partial failures without failing the whole package silently.

## UI / visual

- Classic Conlassian palette: primary `#0052CC`, success `#36B37E`, danger `#DE350B`, text `#172B4D`, borders `#DFE1E6`, canvas `#F4F5F7`.
- Typography: clean sans (e.g. Inter is avoided per product preference — use **Atlassian-like Charlie Text / Noto Sans** or system stack with clear hierarchy). Prefer **IBM Plex Sans** or **Source Sans 3** as expressive but Confluence-adjacent.
- Wizard stepper, focus rings, subtle card shadows (low elevation, not glassmorphism).
- Motion: stepper transitions, package card mount stagger, Start pulse while building, progress bar on package card. Keep motion purposeful (2–3 patterns), not decorative noise.
- Accessibility: keyboardable checkboxes, clear disabled states when not connected.

## Error handling

- Connect 401/403 → inline error on that CI card; do not mark connected.
- Network / Jenkins down → toast + card error; allow retry.
- Start/Stop partial failure → list which jobs failed; others still proceed.
- Missing session creds on Start → prompt to reconnect that CI.
- Duplicate package name → validation error before save.
- Parameterized-only jobs that refuse `/build` → show clear per-job error (v1: no parameter UI).

## Project structure (planned)

```
/
  client/          # Vite + React
  server/          # Express
  data/packages.json
  docs/superpowers/specs/
  README.md
```

Single `npm` workspace or root scripts: `dev` runs API + Vite concurrently.

## Security notes

- Local LAN tool; no multi-tenant auth for the web app itself.
- Credentials in `sessionStorage` clear when the tab session ends.
- Do not log passwords.
- `.gitignore`: `data/` optional backup, `.env`, `.superpowers/`, `node_modules/`.

## Out of scope (v1)

- Build parameters UI
- Sequential / ordered execution
- Disabling jobs as Stop
- User accounts / multi-user sharing of packages with shared secrets
- Editing Jenkins job config
- HTTPS / reverse proxy deployment (local `localhost` is enough)

## Success criteria

1. User can connect to all three CIs with personal credentials and see jobs.
2. User can create a named package mixing jobs from multiple CIs.
3. Start triggers all package jobs in parallel; Stop aborts running builds.
4. Package UI shows live per-job status while builds run.
5. UI is Confluence-like, clear, and easy to operate via the wizard.
