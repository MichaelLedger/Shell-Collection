import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import { v4 as uuidv4 } from 'uuid';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DATA_PATH = path.join(__dirname, '..', 'data', 'servers.json');

export const DEFAULT_SERVERS = [
  {
    id: 'ci-8',
    baseUrl: 'http://10.4.2.8:8080',
    label: 'CI · 10.4.2.8',
    description: 'Jenkins CI on 10.4.2.8',
  },
  {
    id: 'ci-6',
    baseUrl: 'http://10.4.2.6:8080',
    label: 'CI · 10.4.2.6',
    description: 'Jenkins CI on 10.4.2.6',
  },
  {
    id: 'ci-5',
    baseUrl: 'http://10.4.2.5:8080',
    label: 'CI · 10.4.2.5',
    description: 'Jenkins CI on 10.4.2.5',
  },
];

function normalizeBaseUrl(url) {
  const trimmed = String(url || '').trim().replace(/\/+$/, '');
  if (!trimmed) return '';
  try {
    const u = new URL(trimmed);
    if (!/^https?:$/.test(u.protocol)) {
      throw new Error('URL must start with http:// or https://');
    }
    return u.origin + (u.pathname === '/' ? '' : u.pathname.replace(/\/+$/, ''));
  } catch (e) {
    if (e.message.includes('http')) throw e;
    const err = new Error('Invalid Jenkins URL');
    err.status = 400;
    throw err;
  }
}

function publicServer(s) {
  return {
    id: s.id,
    baseUrl: s.baseUrl,
    label: s.label,
    description: s.description || '',
  };
}

async function readStore() {
  try {
    const raw = await fs.readFile(DATA_PATH, 'utf8');
    const data = JSON.parse(raw);
    if (!Array.isArray(data.servers)) {
      return { servers: DEFAULT_SERVERS.map((s) => ({ ...s })) };
    }
    return {
      servers: data.servers.map((s) => ({
        id: s.id,
        baseUrl: s.baseUrl,
        label: s.label,
        description: s.description || '',
      })),
    };
  } catch (e) {
    if (e.code === 'ENOENT') {
      const store = { servers: DEFAULT_SERVERS.map((s) => ({ ...s })) };
      await writeStore(store);
      return store;
    }
    throw e;
  }
}

async function writeStore(store) {
  await fs.mkdir(path.dirname(DATA_PATH), { recursive: true });
  await fs.writeFile(DATA_PATH, JSON.stringify(store, null, 2) + '\n', 'utf8');
}

export async function listServers() {
  const store = await readStore();
  return store.servers.map(publicServer);
}

export async function getServer(serverId) {
  const store = await readStore();
  const found = store.servers.find((s) => s.id === serverId);
  return found ? publicServer(found) : null;
}

export async function createServer({ baseUrl, label, description }) {
  const store = await readStore();
  const url = normalizeBaseUrl(baseUrl);
  if (!url) {
    const err = new Error('Jenkins URL is required');
    err.status = 400;
    throw err;
  }
  const name = String(label || '').trim() || url;
  const desc = String(description || '').trim();

  if (store.servers.some((s) => s.baseUrl === url)) {
    const err = new Error('A CI server with this URL already exists');
    err.status = 409;
    throw err;
  }

  const server = {
    id: `ci-${uuidv4().slice(0, 8)}`,
    baseUrl: url,
    label: name,
    description: desc,
  };
  store.servers.push(server);
  await writeStore(store);
  return publicServer(server);
}

export async function updateServer(id, { baseUrl, label, description }) {
  const store = await readStore();
  const idx = store.servers.findIndex((s) => s.id === id);
  if (idx === -1) return null;

  if (baseUrl != null) {
    const url = normalizeBaseUrl(baseUrl);
    if (!url) {
      const err = new Error('Jenkins URL is required');
      err.status = 400;
      throw err;
    }
    if (store.servers.some((s) => s.id !== id && s.baseUrl === url)) {
      const err = new Error('A CI server with this URL already exists');
      err.status = 409;
      throw err;
    }
    store.servers[idx].baseUrl = url;
  }
  if (label != null) {
    const name = String(label).trim();
    if (!name) {
      const err = new Error('Label is required');
      err.status = 400;
      throw err;
    }
    store.servers[idx].label = name;
  }
  if (description != null) {
    store.servers[idx].description = String(description).trim();
  }

  await writeStore(store);
  return publicServer(store.servers[idx]);
}

export async function deleteServer(id) {
  const store = await readStore();
  const before = store.servers.length;
  store.servers = store.servers.filter((s) => s.id !== id);
  if (store.servers.length === before) return false;
  await writeStore(store);
  return true;
}
