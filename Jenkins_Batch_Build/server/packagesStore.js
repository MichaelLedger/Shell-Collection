import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import { v4 as uuidv4 } from 'uuid';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DATA_PATH = path.join(__dirname, '..', 'data', 'packages.json');

async function readStore() {
  try {
    const raw = await fs.readFile(DATA_PATH, 'utf8');
    const data = JSON.parse(raw);
    if (!Array.isArray(data.packages)) return { packages: [] };
    return data;
  } catch (e) {
    if (e.code === 'ENOENT') return { packages: [] };
    throw e;
  }
}

async function writeStore(store) {
  await fs.mkdir(path.dirname(DATA_PATH), { recursive: true });
  await fs.writeFile(DATA_PATH, JSON.stringify(store, null, 2) + '\n', 'utf8');
}

export async function listPackages() {
  const store = await readStore();
  return store.packages;
}

export async function getPackage(id) {
  const store = await readStore();
  return store.packages.find((p) => p.id === id) ?? null;
}

export async function createPackage({ name, description, jobs }) {
  const store = await readStore();
  const trimmed = String(name || '').trim();
  if (!trimmed) {
    const err = new Error('Package name is required');
    err.status = 400;
    throw err;
  }
  if (!Array.isArray(jobs) || jobs.length === 0) {
    const err = new Error('At least one job is required');
    err.status = 400;
    throw err;
  }
  if (store.packages.some((p) => p.name.toLowerCase() === trimmed.toLowerCase())) {
    const err = new Error('A package with this name already exists');
    err.status = 409;
    throw err;
  }

  const now = new Date().toISOString();
  const pkg = {
    id: uuidv4(),
    name: trimmed,
    description: String(description || '').trim(),
    jobs: jobs.map((j) => ({
      serverId: j.serverId,
      jobName: j.jobName,
    })),
    createdAt: now,
    updatedAt: now,
  };
  store.packages.unshift(pkg);
  await writeStore(store);
  return pkg;
}

export async function updatePackage(id, { name, description, jobs }) {
  const store = await readStore();
  const idx = store.packages.findIndex((p) => p.id === id);
  if (idx === -1) return null;

  if (name != null) {
    const trimmed = String(name).trim();
    if (!trimmed) {
      const err = new Error('Package name is required');
      err.status = 400;
      throw err;
    }
    if (
      store.packages.some(
        (p) => p.id !== id && p.name.toLowerCase() === trimmed.toLowerCase(),
      )
    ) {
      const err = new Error('A package with this name already exists');
      err.status = 409;
      throw err;
    }
    store.packages[idx].name = trimmed;
  }
  if (description != null) {
    store.packages[idx].description = String(description).trim();
  }
  if (jobs != null) {
    if (!Array.isArray(jobs) || jobs.length === 0) {
      const err = new Error('At least one job is required');
      err.status = 400;
      throw err;
    }
    store.packages[idx].jobs = jobs.map((j) => ({
      serverId: j.serverId,
      jobName: j.jobName,
    }));
  }
  store.packages[idx].updatedAt = new Date().toISOString();
  await writeStore(store);
  return store.packages[idx];
}

export async function deletePackage(id) {
  const store = await readStore();
  const before = store.packages.length;
  store.packages = store.packages.filter((p) => p.id !== id);
  if (store.packages.length === before) return false;
  await writeStore(store);
  return true;
}
