import { Router } from 'express';
import {
  listPackages,
  getPackage,
  createPackage,
  updatePackage,
  deletePackage,
} from '../packagesStore.js';
import {
  requireServer,
  triggerBuild,
  abortBuild,
  jobStatus,
} from '../jenkinsClient.js';

export const packagesRouter = Router();

function credsFor(credentialsByServer, serverId) {
  const c = credentialsByServer?.[serverId];
  if (!c?.username || !c?.password) {
    const err = new Error(`Missing credentials for ${serverId}`);
    err.status = 400;
    throw err;
  }
  return c;
}

packagesRouter.get('/', async (_req, res, next) => {
  try {
    const packages = await listPackages();
    res.json({ packages });
  } catch (err) {
    next(err);
  }
});

packagesRouter.post('/', async (req, res, next) => {
  try {
    const pkg = await createPackage({
      name: req.body?.name,
      description: req.body?.description,
      jobs: req.body?.jobs,
    });
    res.status(201).json(pkg);
  } catch (err) {
    next(err);
  }
});

packagesRouter.patch('/:id', async (req, res, next) => {
  try {
    const pkg = await updatePackage(req.params.id, {
      name: req.body?.name,
      description: req.body?.description,
      jobs: req.body?.jobs,
    });
    if (!pkg) {
      res.status(404).json({ error: 'Package not found' });
      return;
    }
    res.json(pkg);
  } catch (err) {
    next(err);
  }
});

packagesRouter.delete('/:id', async (req, res, next) => {
  try {
    const ok = await deletePackage(req.params.id);
    if (!ok) {
      res.status(404).json({ error: 'Package not found' });
      return;
    }
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

packagesRouter.post('/:id/start', async (req, res, next) => {
  try {
    const pkg = await getPackage(req.params.id);
    if (!pkg) {
      res.status(404).json({ error: 'Package not found' });
      return;
    }
    const credentialsByServer = req.body?.credentialsByServer || {};
    const results = await Promise.all(
      pkg.jobs.map(async (job) => {
        try {
          const server = await requireServer(job.serverId);
          const creds = credsFor(credentialsByServer, job.serverId);
          await triggerBuild({
            baseUrl: server.baseUrl,
            username: creds.username,
            password: creds.password,
            jobName: job.jobName,
          });
          return { serverId: job.serverId, jobName: job.jobName, ok: true };
        } catch (e) {
          return {
            serverId: job.serverId,
            jobName: job.jobName,
            ok: false,
            error: e.message,
          };
        }
      }),
    );
    res.json({ packageId: pkg.id, results });
  } catch (err) {
    next(err);
  }
});

packagesRouter.post('/:id/stop', async (req, res, next) => {
  try {
    const pkg = await getPackage(req.params.id);
    if (!pkg) {
      res.status(404).json({ error: 'Package not found' });
      return;
    }
    const credentialsByServer = req.body?.credentialsByServer || {};
    const results = await Promise.all(
      pkg.jobs.map(async (job) => {
        try {
          const server = await requireServer(job.serverId);
          const creds = credsFor(credentialsByServer, job.serverId);
          const outcome = await abortBuild({
            baseUrl: server.baseUrl,
            username: creds.username,
            password: creds.password,
            jobName: job.jobName,
          });
          return { serverId: job.serverId, jobName: job.jobName, ok: true, ...outcome };
        } catch (e) {
          return {
            serverId: job.serverId,
            jobName: job.jobName,
            ok: false,
            error: e.message,
          };
        }
      }),
    );
    res.json({ packageId: pkg.id, results });
  } catch (err) {
    next(err);
  }
});

packagesRouter.post('/:id/status', async (req, res, next) => {
  try {
    const pkg = await getPackage(req.params.id);
    if (!pkg) {
      res.status(404).json({ error: 'Package not found' });
      return;
    }
    const credentialsByServer = req.body?.credentialsByServer || {};
    const jobs = await Promise.all(
      pkg.jobs.map(async (job) => {
        try {
          const server = await requireServer(job.serverId);
          const creds = credsFor(credentialsByServer, job.serverId);
          const status = await jobStatus({
            baseUrl: server.baseUrl,
            username: creds.username,
            password: creds.password,
            jobName: job.jobName,
          });
          return { serverId: job.serverId, ok: true, ...status };
        } catch (e) {
          return {
            serverId: job.serverId,
            jobName: job.jobName,
            ok: false,
            error: e.message,
            building: false,
            result: null,
            color: 'unknown',
          };
        }
      }),
    );
    res.json({ packageId: pkg.id, jobs });
  } catch (err) {
    next(err);
  }
});
