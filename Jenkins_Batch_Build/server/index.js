import express from 'express';
import cors from 'cors';
import { serversRouter } from './routes/servers.js';
import { jenkinsRouter } from './routes/jenkins.js';
import { packagesRouter } from './routes/packages.js';
import { notifyRouter } from './routes/notify.js';

const app = express();
const PORT = Number(process.env.PORT) || 8089;

app.use(cors());
app.use(express.json({ limit: '1mb' }));

app.get('/api/health', (_req, res) => {
  res.json({ ok: true });
});

app.use('/api/servers', serversRouter);
app.use('/api/jenkins', jenkinsRouter);
app.use('/api/packages', packagesRouter);
app.use('/api/notify', notifyRouter);

app.use((err, _req, res, _next) => {
  const status = err.status || 500;
  res.status(status).json({
    error: err.message || 'Internal server error',
    details: err.details ?? undefined,
  });
});

app.listen(PORT, () => {
  console.log(`Jenkins Batch Build API on http://127.0.0.1:${PORT}`);
});
