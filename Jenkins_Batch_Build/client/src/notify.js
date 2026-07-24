import { api } from './api.js';

let permissionAsked = false;

/** Ask once for browser Notification permission (also shows in macOS Notification Center). */
export async function ensureBrowserNotifyPermission() {
  if (typeof window === 'undefined' || !('Notification' in window)) {
    return 'unsupported';
  }
  if (Notification.permission === 'granted') return 'granted';
  if (Notification.permission === 'denied') return 'denied';
  if (permissionAsked) return Notification.permission;
  permissionAsked = true;
  try {
    return await Notification.requestPermission();
  } catch {
    return Notification.permission;
  }
}

function showBrowserNotification(title, body) {
  if (typeof window === 'undefined' || !('Notification' in window)) return;
  if (Notification.permission !== 'granted') return;
  try {
    const n = new Notification(title, {
      body,
      silent: false,
      tag: `jbb-${title}-${body}`.slice(0, 64),
    });
    n.onclick = () => {
      window.focus();
      n.close();
    };
  } catch {
    // ignore
  }
}

/**
 * Fire macOS system notification via local API + browser Notification fallback.
 */
export async function notifyPackageFinished({ packageName, jobs }) {
  const list = jobs || [];
  const success = list.filter((j) => j.result === 'SUCCESS').length;
  const failed = list.filter((j) => j.result === 'FAILURE').length;
  const aborted = list.filter((j) => j.result === 'ABORTED').length;
  const unstable = list.filter((j) => j.result === 'UNSTABLE').length;
  const total = list.length;

  let level = 'success';
  let body;
  if (failed > 0) {
    level = 'error';
    body = `${failed} failed · ${success} success` +
      (aborted ? ` · ${aborted} aborted` : '') +
      ` (${total} jobs)`;
  } else if (aborted > 0 || unstable > 0) {
    level = 'warning';
    body = `${success} success` +
      (unstable ? ` · ${unstable} unstable` : '') +
      (aborted ? ` · ${aborted} aborted` : '') +
      ` (${total} jobs)`;
  } else if (success === total && total > 0) {
    body = `All ${total} jobs succeeded`;
  } else {
    body = `${total} jobs finished`;
  }

  const title = `${packageName} · finished`;
  const sound = level === 'error' ? 'Basso' : level === 'warning' ? 'Sosumi' : 'Glass';

  showBrowserNotification(title, body);

  try {
    await api.notify({ title, body, sound });
  } catch (e) {
    console.warn('macOS notify API failed', e.message);
  }

  return { title, body, level };
}

export function summarizeJobsBuilding(jobs) {
  return (jobs || []).some((j) => j.building);
}
