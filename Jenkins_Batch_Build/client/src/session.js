import { api } from './api.js';

const CREDS_KEY = 'jbb.credentials';
const JOBS_KEY = 'jbb.jobsByServer';

function readJson(storage, key, fallback) {
  try {
    const raw = storage.getItem(key);
    if (!raw) return fallback;
    return JSON.parse(raw);
  } catch {
    return fallback;
  }
}

/** One-time migrate sessionStorage → localStorage so existing logins survive. */
function migrateFromSession() {
  try {
    for (const key of [CREDS_KEY, JOBS_KEY]) {
      const fromSession = sessionStorage.getItem(key);
      if (fromSession && !localStorage.getItem(key)) {
        localStorage.setItem(key, fromSession);
      }
      sessionStorage.removeItem(key);
    }
  } catch {
    // ignore quota / private mode quirks
  }
}

migrateFromSession();

export function loadCredentials() {
  return readJson(localStorage, CREDS_KEY, {});
}

export function saveCredentials(map) {
  localStorage.setItem(CREDS_KEY, JSON.stringify(map));
}

export function setServerCredentials(serverId, credentials) {
  const map = loadCredentials();
  map[serverId] = {
    username: credentials.username,
    password: credentials.password,
  };
  saveCredentials(map);
  return map;
}

export function clearCredentials() {
  localStorage.removeItem(CREDS_KEY);
  localStorage.removeItem(JOBS_KEY);
}

export function clearServerCredentials(serverId) {
  const map = loadCredentials();
  delete map[serverId];
  saveCredentials(map);
  const jobs = loadJobsByServer();
  delete jobs[serverId];
  localStorage.setItem(JOBS_KEY, JSON.stringify(jobs));
}

export function loadJobsByServer() {
  return readJson(localStorage, JOBS_KEY, {});
}

export function saveJobsForServer(serverId, jobs) {
  const map = loadJobsByServer();
  map[serverId] = jobs;
  localStorage.setItem(JOBS_KEY, JSON.stringify(map));
  return map;
}

export function saveAllJobs(jobsByServer) {
  localStorage.setItem(JOBS_KEY, JSON.stringify(jobsByServer || {}));
}

export function hasAnyCredentials() {
  return Object.keys(loadCredentials()).length > 0;
}

export function credentialsByServer() {
  return loadCredentials();
}

/**
 * Reconnect every CI that has saved username/password.
 * Per-server timeout so one hung Jenkins cannot block the UI forever.
 */
export async function reconnectAllSaved() {
  const creds = loadCredentials();
  const serverIds = Object.keys(creds).filter(
    (id) => creds[id]?.username && creds[id]?.password,
  );

  if (!serverIds.length) {
    return { ok: [], failed: [], jobsByServer: loadJobsByServer() };
  }

  const ok = [];
  const failed = [];
  const jobsByServer = { ...loadJobsByServer() };
  const TIMEOUT_MS = 15000;

  await Promise.all(
    serverIds.map(async (serverId) => {
      try {
        const data = await Promise.race([
          api.connect(serverId, {
            username: creds[serverId].username,
            password: creds[serverId].password,
          }),
          new Promise((_, reject) => {
            setTimeout(
              () => reject(new Error(`Timeout connecting to ${serverId}`)),
              TIMEOUT_MS,
            );
          }),
        ]);
        jobsByServer[serverId] = data.jobs;
        ok.push({ serverId, jobCount: data.jobs.length });
      } catch (e) {
        failed.push({ serverId, error: e.message || 'Connect failed' });
      }
    }),
  );

  saveAllJobs(jobsByServer);
  return { ok, failed, jobsByServer };
}
