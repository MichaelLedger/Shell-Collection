import { Router } from 'express';
import { notifyLocal } from '../notify.js';

export const notifyRouter = Router();

notifyRouter.post('/', async (req, res, next) => {
  try {
    const title = String(req.body?.title || 'Jenkins Batch Build').slice(0, 80);
    const body = String(req.body?.body || '').slice(0, 240);
    const sound = req.body?.sound;
    const result = await notifyLocal({ title, body, sound });
    res.json(result);
  } catch (err) {
    next(err);
  }
});
