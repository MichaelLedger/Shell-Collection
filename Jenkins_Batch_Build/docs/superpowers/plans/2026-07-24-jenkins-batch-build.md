# Jenkins Batch Build Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Local Confluence-styled wizard app that connects to three Jenkins CIs with personal credentials, builds named job packages, and Start/Stops them in parallel with live status.

**Architecture:** Vite + React SPA talks only to a local Express proxy. Express holds Jenkins base URLs, performs Basic-auth Jenkins API calls (with crumb), and persists packages in `data/packages.json`. Credentials live in browser `sessionStorage` and are sent per request.

**Tech Stack:** Node 20+, Express, Vite, React 18, React Router, framer-motion, concurrently, IBM Plex Sans (Google Fonts), native `fetch` / `undici`.

## Global Constraints

- Jenkins servers fixed: `ci-8` → `http://10.4.2.8:8080`, `ci-6` → `http://10.4.2.6:8080`, `ci-5` → `http://10.4.2.5:8080`
- Never persist passwords to disk; never log passwords
- v1: parallel start only; stop = abort running build; no build parameters UI
- Visual: Confluence palette `#0052CC` / `#36B37E` / `#DE350B` / `#172B4D` / `#DFE1E6` / `#F4F5F7`; font IBM Plex Sans
- Spec: `docs/superpowers/specs/2026-07-24-jenkins-batch-build-design.md`

## File map

| Path | Responsibility |
|---|---|
| `package.json` | Root scripts: `dev`, `server`, `client` |
| `server/index.js` | Express app entry, CORS, static in prod |
| `server/config.js` | Server id → baseUrl map |
| `server/jenkinsClient.js` | Crumb + Basic auth Jenkins HTTP helpers |
| `server/packagesStore.js` | Read/write `data/packages.json` |
| `server/routes/servers.js` | `GET /api/servers` |
| `server/routes/jenkins.js` | connect + jobs |
| `server/routes/packages.js` | CRUD + start/stop/status |
| `data/packages.json` | Package persistence |
| `client/` | Vite React app |
| `client/src/api.js` | API client |
| `client/src/session.js` | sessionStorage credentials + jobs cache |
| `client/src/App.jsx` | Routes |
| `client/src/pages/Wizard.jsx` | 3-step wizard |
| `client/src/pages/Packages.jsx` | Package cards + poll |
| `client/src/styles.css` | Confluence theme + animations |
| `README.md` | How to run |

---

### Task 1: Scaffold monorepo + Express health

**Files:**
- Create: `package.json`, `server/index.js`, `server/config.js`, `data/packages.json`, `data/.gitkeep`, `README.md`
- Modify: `.gitignore`

- [ ] **Step 1: Create root package.json and server entry**

```json
{
  "name": "jenkins-batch-build",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "concurrently -n server,client -c blue,green \"npm run server\" \"npm run client\"",
    "server": "node server/index.js",
    "client": "npm run dev --prefix client",
    "install:all": "npm install && npm install --prefix client"
  },
  "dependencies": {
    "cors": "^2.8.5",
    "express": "^4.21.2",
    "uuid": "^11.0.5"
  },
  "devDependencies": {
    "concurrently": "^9.1.2"
  }
}
```

`server/config.js` exports `SERVERS` array with `id`, `baseUrl`, `label` for ci-8/6/5.

`server/index.js` listens on `PORT` (default 3847), mounts `/api` routes later, `GET /api/health` → `{ ok: true }`.

- [ ] **Step 2: Install deps and verify health**

Run: `npm install && node server/index.js` (background), then `curl -s http://127.0.0.1:3847/api/health`  
Expected: `{"ok":true}`

- [ ] **Step 3: Commit**

```bash
git add package.json package-lock.json server data README.md .gitignore
git commit -m "chore: scaffold Express server and root scripts"
```

---

### Task 2: Jenkins client + connect/jobs routes

**Files:**
- Create: `server/jenkinsClient.js`, `server/routes/jenkins.js`, `server/routes/servers.js`
- Modify: `server/index.js`

**Interfaces:**
- Produces: `getServer(serverId)`, `jenkinsFetch(baseUrl, path, { username, password, method, body })`, `listJobs(creds)`, `triggerBuild`, `abortBuild`, `jobStatus`

- [ ] **Step 1: Implement jenkinsClient**

- Basic auth header from username/password
- GET crumb from `/crumbIssuer/api/json` (ignore 404)
- `listJobs`: `/api/json?tree=jobs[name,url,color]`
- Nested folders: flatten one level optional — v1 flat jobs only from root `jobs` array (skip folders or recurse `jobs` if `_class` contains Folder)
- Recurse folders so nested jobs are discoverable: if job has `jobs`, walk recursively with path `folder/job`

- [ ] **Step 2: Routes**

- `GET /api/servers` → SERVERS without secrets
- `POST /api/jenkins/:serverId/connect` body `{ username, password }` → list jobs or 401
- `POST /api/jenkins/:serverId/jobs` body credentials → refresh (use POST so password not in query)

- [ ] **Step 3: Manual smoke** (optional if Jenkins unreachable — unit-test client with mock later)

- [ ] **Step 4: Commit**

```bash
git commit -m "feat: Jenkins connect and job listing proxy"
```

---

### Task 3: Packages store + CRUD + start/stop/status

**Files:**
- Create: `server/packagesStore.js`, `server/routes/packages.js`
- Modify: `server/index.js`

- [ ] **Step 1: packagesStore** — load/save JSON; create/update/delete; duplicate name rejection

- [ ] **Step 2: packages routes**

- CRUD as spec
- `POST /:id/start` body `{ credentialsByServer }` → Promise.allSettled triggerBuild per job
- `POST /:id/stop` → abort each
- `POST /:id/status` body `{ credentialsByServer }` → per-job status (POST so creds in body; also accept GET with header later — use POST `/status` for consistency)

Note: Spec said GET status; use `POST /api/packages/:id/status` with credentials in body to avoid putting secrets in query strings. Document in README.

- [ ] **Step 3: Commit**

```bash
git commit -m "feat: package CRUD and parallel start/stop/status"
```

---

### Task 4: Vite React client shell + theme

**Files:**
- Create: `client/` via Vite React template, `client/src/styles.css`, `client/src/api.js`, `client/src/session.js`, `client/src/App.jsx`, `client/src/main.jsx`

- [ ] **Step 1: Scaffold client** `npm create vite@latest client -- --template react`
- [ ] **Step 2: Add react-router-dom, framer-motion; proxy `/api` → `http://127.0.0.1:3847` in `vite.config.js`
- [ ] **Step 3: Confluence CSS variables + IBM Plex Sans + App shell with nav
- [ ] **Step 4: Commit** `feat: React client shell with Confluence theme`

---

### Task 5: Wizard pages (Connect → Pick → Name)

**Files:**
- Create: `client/src/pages/Wizard.jsx`, `client/src/components/Stepper.jsx`, `ConnectStep.jsx`, `PickJobsStep.jsx`, `NamePackageStep.jsx`

- [ ] **Step 1: Implement 3 steps with framer-motion transitions**
- [ ] **Step 2: session.js save/load credentials + jobs**
- [ ] **Step 3: Commit** `feat: guided wizard for connect, pick, save package`

---

### Task 6: Packages home + live polling

**Files:**
- Create: `client/src/pages/Packages.jsx`, `client/src/components/PackageCard.jsx`

- [ ] **Step 1: List packages, Start/Stop/Delete, expand job status**
- [ ] **Step 2: Poll status every 4s when any job building or after start until idle**
- [ ] **Step 3: Commit** `feat: packages home with live status polling`

---

### Task 7: README polish + end-to-end verify

- [ ] **Step 1: README with install, `npm run install:all`, `npm run dev`, open `http://localhost:5173`**
- [ ] **Step 2: Verify server health + client builds**
- [ ] **Step 3: Final commit** `docs: README for local Batch Build app`

---

## Spec coverage check

| Spec item | Task |
|---|---|
| Wizard layout B | 5 |
| Confluence style A | 4 |
| Per-user creds UI | 5 |
| Parallel start / abort stop | 3, 6 |
| Live status | 6 |
| No params v1 | 3 (trigger `/build` only) |
| packages.json | 3 |
