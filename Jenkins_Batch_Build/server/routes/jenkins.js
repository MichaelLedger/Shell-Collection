import { Router } from 'express';
import { listJobs, requireServer } from '../jenkinsClient.js';

export const jenkinsRouter = Router();

function readCredentials(req) {
  const username = req.body?.username ?? req.body?.credentials?.username;
  const password = req.body?.password ?? req.body?.credentials?.password;
  if (!username || !password) {
    const err = new Error('username and password are required');
    err.status = 400;
    throw err;
  }
  return { username, password };
}

jenkinsRouter.post('/:serverId/connect', async (req, res, next) => {
  try {
    const server = await requireServer(req.params.serverId);
    const { username, password } = readCredentials(req);
    const jobs = await listJobs({
      baseUrl: server.baseUrl,
      username,
      password,
    });
    res.json({
      serverId: server.id,
      baseUrl: server.baseUrl,
      label: server.label,
      jobs,
    });
  } catch (err) {
    next(err);
  }
});

jenkinsRouter.post('/:serverId/jobs', async (req, res, next) => {
  try {
    const server = await requireServer(req.params.serverId);
    const { username, password } = readCredentials(req);
    const jobs = await listJobs({
      baseUrl: server.baseUrl,
      username,
      password,
    });
    res.json({ serverId: server.id, jobs });
  } catch (err) {
    next(err);
  }
});
