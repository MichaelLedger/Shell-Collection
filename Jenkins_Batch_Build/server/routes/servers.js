import { Router } from 'express';
import {
  listServers,
  createServer,
  updateServer,
  deleteServer,
} from '../serversStore.js';

export const serversRouter = Router();

serversRouter.get('/', async (_req, res, next) => {
  try {
    const servers = await listServers();
    res.json({ servers });
  } catch (err) {
    next(err);
  }
});

serversRouter.post('/', async (req, res, next) => {
  try {
    const server = await createServer({
      baseUrl: req.body?.baseUrl,
      label: req.body?.label,
      description: req.body?.description,
    });
    res.status(201).json(server);
  } catch (err) {
    next(err);
  }
});

serversRouter.patch('/:id', async (req, res, next) => {
  try {
    const server = await updateServer(req.params.id, {
      baseUrl: req.body?.baseUrl,
      label: req.body?.label,
      description: req.body?.description,
    });
    if (!server) {
      res.status(404).json({ error: 'Server not found' });
      return;
    }
    res.json(server);
  } catch (err) {
    next(err);
  }
});

serversRouter.delete('/:id', async (req, res, next) => {
  try {
    const ok = await deleteServer(req.params.id);
    if (!ok) {
      res.status(404).json({ error: 'Server not found' });
      return;
    }
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});
