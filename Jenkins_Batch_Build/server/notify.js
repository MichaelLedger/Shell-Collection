import { execFile } from 'child_process';
import { promisify } from 'util';

const execFileAsync = promisify(execFile);

function escapeAppleScript(str) {
  return String(str ?? '')
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .slice(0, 180);
}

/**
 * Show a macOS Notification Center banner on this machine.
 * No-op (ok:false) on non-macOS hosts.
 */
export async function notifyLocal({ title, body, sound = 'Glass' }) {
  if (process.platform !== 'darwin') {
    return { ok: false, reason: 'Notifications are only sent on macOS' };
  }

  const safeTitle = escapeAppleScript(title || 'Jenkins Batch Build');
  const safeBody = escapeAppleScript(body || '');
  const safeSound = escapeAppleScript(sound || 'Glass');

  const script = `display notification "${safeBody}" with title "${safeTitle}" sound name "${safeSound}"`;

  try {
    await execFileAsync('osascript', ['-e', script], { timeout: 5000 });
    return { ok: true };
  } catch (e) {
    console.warn('[notify] osascript failed', e.message);
    const err = new Error(`macOS notification failed: ${e.message}`);
    err.status = 500;
    throw err;
  }
}
