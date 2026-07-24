import { getServer } from './serversStore.js';

function basicAuthHeader(username, password) {
  const token = Buffer.from(`${username}:${password}`, 'utf8').toString('base64');
  return `Basic ${token}`;
}

function parseSetCookie(headers) {
  // Node fetch: getSetCookie() when available; otherwise single set-cookie header
  if (typeof headers.getSetCookie === 'function') {
    return headers.getSetCookie();
  }
  const raw = headers.get('set-cookie');
  return raw ? [raw] : [];
}

function cookieHeaderFromSetCookie(setCookieValues) {
  if (!setCookieValues?.length) return null;
  return setCookieValues
    .map((c) => c.split(';')[0].trim())
    .filter(Boolean)
    .join('; ');
}

async function fetchCrumb(baseUrl, authHeader) {
  try {
    const res = await fetch(`${baseUrl}/crumbIssuer/api/json`, {
      headers: { Authorization: authHeader },
    });
    if (!res.ok) return null;
    const data = await res.json();
    if (data?.crumb && data?.crumbRequestField) {
      return {
        field: data.crumbRequestField,
        crumb: data.crumb,
        cookie: cookieHeaderFromSetCookie(parseSetCookie(res.headers)),
      };
    }
  } catch {
    // CSRF crumb optional
  }
  return null;
}

/**
 * @param {string} baseUrl
 * @param {string} path - absolute path starting with /
 * @param {{ username: string, password: string, method?: string, body?: string|undefined, headers?: Record<string,string> }} opts
 */
export async function jenkinsFetch(baseUrl, path, opts) {
  const { username, password, method = 'GET', body, headers = {} } = opts;
  const authHeader = basicAuthHeader(username, password);
  const crumb = method !== 'GET' ? await fetchCrumb(baseUrl, authHeader) : null;

  const reqHeaders = {
    Authorization: authHeader,
    ...headers,
  };
  if (crumb) {
    reqHeaders[crumb.field] = crumb.crumb;
    if (crumb.cookie) {
      reqHeaders.Cookie = crumb.cookie;
    }
  }
  if (body !== undefined && body !== null && !reqHeaders['Content-Type']) {
    reqHeaders['Content-Type'] = 'application/x-www-form-urlencoded';
  }

  const res = await fetch(`${baseUrl}${path}`, {
    method,
    headers: reqHeaders,
    body: body === undefined ? undefined : body,
    redirect: 'manual',
  });

  return res;
}

function isRedirectOrOk(res) {
  return res.ok || res.status === 201 || res.status === 302 || res.status === 303;
}

function flattenJobs(jobs, prefix = '') {
  const out = [];
  for (const job of jobs || []) {
    const name = prefix ? `${prefix}/${job.name}` : job.name;
    const isFolder =
      typeof job._class === 'string' &&
      (job._class.includes('Folder') || job._class.includes('OrganizationFolder'));

    if (isFolder && Array.isArray(job.jobs)) {
      out.push(...flattenJobs(job.jobs, name));
    } else if (!isFolder) {
      out.push({
        name,
        url: job.url,
        color: job.color || 'notbuilt',
      });
    }
  }
  return out;
}

export async function listJobs({ baseUrl, username, password }) {
  const tree =
    'jobs[name,url,color,_class,jobs[name,url,color,_class,jobs[name,url,color,_class]]]';
  const res = await jenkinsFetch(baseUrl, `/api/json?tree=${encodeURIComponent(tree)}`, {
    username,
    password,
  });

  if (res.status === 401 || res.status === 403) {
    const err = new Error('Authentication failed');
    err.status = res.status;
    throw err;
  }
  if (!res.ok) {
    const err = new Error(`Jenkins list jobs failed (${res.status})`);
    err.status = res.status;
    throw err;
  }

  const data = await res.json();
  return flattenJobs(data.jobs || []);
}

function encodeJobPath(jobName) {
  return jobName
    .split('/')
    .map((seg) => encodeURIComponent(seg))
    .join('/job/');
}

async function readErrorSnippet(res) {
  const text = await res.text().catch(() => '');
  return text.replace(/\s+/g, ' ').trim().slice(0, 240);
}

export async function triggerBuild({ baseUrl, username, password, jobName }) {
  const jobPath = encodeJobPath(jobName);

  // Prefer /build; parameterized jobs often need /buildWithParameters (defaults apply).
  let res = await jenkinsFetch(baseUrl, `/job/${jobPath}/build`, {
    username,
    password,
    method: 'POST',
  });

  if (res.status === 400 || res.status === 405) {
    const firstSnippet = await readErrorSnippet(res);
    console.warn(
      `[jenkins] ${baseUrl} job=${jobName} /build → ${res.status}; trying buildWithParameters`,
      firstSnippet,
    );
    res = await jenkinsFetch(baseUrl, `/job/${jobPath}/buildWithParameters`, {
      username,
      password,
      method: 'POST',
    });
  }

  if (res.status === 401 || res.status === 403) {
    const snippet = await readErrorSnippet(res);
    console.warn(`[jenkins] start auth fail ${baseUrl} job=${jobName}`, res.status, snippet);
    const err = new Error(
      `Authentication failed (${res.status})${snippet ? `: ${snippet}` : ''}`,
    );
    err.status = res.status;
    throw err;
  }

  if (isRedirectOrOk(res)) {
    console.log(`[jenkins] started ${baseUrl} job=${jobName} status=${res.status}`);
    return { ok: true, status: res.status };
  }

  const snippet = await readErrorSnippet(res);
  console.warn(`[jenkins] start failed ${baseUrl} job=${jobName}`, res.status, snippet);
  const err = new Error(
    `Failed to start ${jobName} (HTTP ${res.status})${snippet ? `: ${snippet}` : ''}`,
  );
  err.status = res.status;
  throw err;
}

export async function abortBuild({ baseUrl, username, password, jobName }) {
  const infoPath = `/job/${encodeJobPath(jobName)}/api/json?tree=lastBuild[number,building]`;
  const infoRes = await jenkinsFetch(baseUrl, infoPath, { username, password });
  if (infoRes.status === 401 || infoRes.status === 403) {
    const err = new Error('Authentication failed');
    err.status = infoRes.status;
    throw err;
  }
  if (!infoRes.ok) {
    const err = new Error(`Failed to query ${jobName} (${infoRes.status})`);
    err.status = infoRes.status;
    throw err;
  }
  const info = await infoRes.json();
  const last = info.lastBuild;
  if (!last?.number) {
    return { ok: true, skipped: true, reason: 'No builds' };
  }
  if (!last.building) {
    return { ok: true, skipped: true, reason: 'Not building' };
  }

  const stopPath = `/job/${encodeJobPath(jobName)}/${last.number}/stop`;
  let res = await jenkinsFetch(baseUrl, stopPath, {
    username,
    password,
    method: 'POST',
  });

  if (!isRedirectOrOk(res)) {
    const killPath = `/job/${encodeJobPath(jobName)}/${last.number}/kill`;
    res = await jenkinsFetch(baseUrl, killPath, {
      username,
      password,
      method: 'POST',
    });
  }

  if (!isRedirectOrOk(res)) {
    const snippet = await readErrorSnippet(res);
    const err = new Error(
      `Failed to abort ${jobName} #${last.number} (HTTP ${res.status})${snippet ? `: ${snippet}` : ''}`,
    );
    err.status = res.status;
    throw err;
  }
  return { ok: true, buildNumber: last.number };
}

export async function jobStatus({ baseUrl, username, password, jobName }) {
  const path = `/job/${encodeJobPath(jobName)}/api/json?tree=color,url,lastBuild[number,result,building,url]`;
  const res = await jenkinsFetch(baseUrl, path, { username, password });
  if (res.status === 401 || res.status === 403) {
    const err = new Error('Authentication failed');
    err.status = res.status;
    throw err;
  }
  if (!res.ok) {
    const err = new Error(`Failed to get status for ${jobName} (${res.status})`);
    err.status = res.status;
    throw err;
  }
  const data = await res.json();
  const last = data.lastBuild;
  return {
    jobName,
    color: data.color || 'notbuilt',
    url: data.url,
    building: Boolean(last?.building),
    result: last?.result ?? null,
    buildNumber: last?.number ?? null,
    buildUrl: last?.url ?? null,
  };
}

export async function requireServer(serverId) {
  const server = await getServer(serverId);
  if (!server) {
    const err = new Error(`Unknown server: ${serverId}`);
    err.status = 404;
    throw err;
  }
  return server;
}
