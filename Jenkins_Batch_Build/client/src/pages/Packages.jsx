import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import { api } from '../api.js';
import { credentialsByServer, hasAnyCredentials } from '../session.js';
import {
  ensureBrowserNotifyPermission,
  notifyPackageFinished,
  summarizeJobsBuilding,
} from '../notify.js';

function statusBadge(job) {
  if (!job?.ok && job?.error) return <span className="badge failed">error</span>;
  if (job?.building) return <span className="badge building">building</span>;
  if (job?.result === 'SUCCESS') return <span className="badge success">success</span>;
  if (job?.result === 'FAILURE') return <span className="badge failed">failed</span>;
  if (job?.result === 'ABORTED') return <span className="badge">aborted</span>;
  if (job?.result === 'UNSTABLE') return <span className="badge">unstable</span>;
  return <span className="badge">idle</span>;
}

function PackageCard({
  pkg,
  statusJobs,
  expanded,
  selected,
  onSelect,
  onToggle,
  onStart,
  onStop,
  onDelete,
  onSaveMeta,
  busy,
}) {
  const jobs = statusJobs || [];
  const buildingCount = jobs.filter((j) => j.building).length;
  const successCount = jobs.filter((j) => j.result === 'SUCCESS' && !j.building).length;
  const total = pkg.jobs.length;
  const progress =
    jobs.length > 0 ? Math.round(((successCount + (total - buildingCount - successCount > 0 ? 0 : 0)) / total) * 100) : 0;
  const anyBuilding = buildingCount > 0;
  const [editing, setEditing] = useState(false);
  const [editName, setEditName] = useState(pkg.name);
  const [editDesc, setEditDesc] = useState(pkg.description || '');

  const summary = useMemo(() => {
    if (!jobs.length) return `${total} jobs`;
    if (anyBuilding) return `${total} jobs · ${buildingCount} building`;
    const failed = jobs.filter((j) => j.result === 'FAILURE').length;
    if (failed) return `${total} jobs · ${failed} failed`;
    if (successCount === total) return `${total} jobs · all success`;
    return `${total} jobs`;
  }, [jobs, total, anyBuilding, buildingCount, successCount]);

  const startEdit = () => {
    setEditName(pkg.name);
    setEditDesc(pkg.description || '');
    setEditing(true);
  };

  const saveEdit = async () => {
    await onSaveMeta(pkg.id, {
      name: editName,
      description: editDesc,
    });
    setEditing(false);
  };

  return (
    <motion.div
      className={`package-card ${selected ? 'selected' : ''} ${anyBuilding ? 'building' : ''}`}
      layout
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ type: 'spring', stiffness: 320, damping: 28 }}
      onClick={() => onSelect(pkg.id)}
    >
      <div className="package-head">
        <div style={{ flex: 1, minWidth: 200 }}>
          {editing ? (
            <div>
              <div className="field">
                <label>Package name</label>
                <input
                  value={editName}
                  onChange={(e) => setEditName(e.target.value)}
                />
              </div>
              <div className="field">
                <label>Description</label>
                <textarea
                  rows={2}
                  value={editDesc}
                  onChange={(e) => setEditDesc(e.target.value)}
                  placeholder="Optional details…"
                />
              </div>
              <div style={{ display: 'flex', gap: 8 }}>
                <button
                  type="button"
                  className="btn btn-primary"
                  disabled={busy || !editName.trim()}
                  onClick={saveEdit}
                >
                  Save
                </button>
                <button
                  type="button"
                  className="btn btn-ghost"
                  onClick={() => setEditing(false)}
                >
                  Cancel
                </button>
              </div>
            </div>
          ) : (
            <>
              <div className="package-title-row">
                <h3>{pkg.name}</h3>
                {anyBuilding && <span className="badge building">Building</span>}
              </div>
              {pkg.description ? (
                <p className="meta" style={{ margin: '4px 0 6px', maxWidth: 560 }}>
                  {pkg.description}
                </p>
              ) : null}
              <div className="meta">{summary}</div>
            </>
          )}
        </div>
        {!editing && (
          <div className="package-actions">
            <button
              type="button"
              className="btn btn-primary"
              disabled={busy}
              onClick={() => onStart(pkg.id)}
            >
              ▶ Start
            </button>
            <button
              type="button"
              className="btn btn-danger"
              disabled={busy}
              onClick={() => onStop(pkg.id)}
            >
              ■ Stop
            </button>
            <button
              type="button"
              className="btn btn-subtle"
              disabled={busy}
              onClick={startEdit}
            >
              Rename
            </button>
            <button
              type="button"
              className="btn btn-ghost"
              onClick={() => onToggle(pkg.id)}
            >
              {expanded ? 'Hide' : 'Details'}
            </button>
            <button
              type="button"
              className="btn btn-ghost"
              disabled={busy}
              onClick={() => onDelete(pkg.id)}
            >
              Delete
            </button>
          </div>
        )}
      </div>

      <div className="progress-track">
        <div
          className={`progress-bar ${anyBuilding ? 'indeterminate' : ''}`}
          style={{ width: anyBuilding ? undefined : `${Math.max(progress, jobs.length ? 8 : 0)}%` }}
        />
      </div>

      {expanded && (
        <div className="job-status-list">
          {pkg.jobs.map((j) => {
            const st = jobs.find(
              (x) => x.serverId === j.serverId && x.jobName === j.jobName,
            );
            return (
              <div
                key={`${j.serverId}-${j.jobName}`}
                className="job-status-row"
              >
                <div>
                  {st?.building ? (
                    <span className="status-dot build" />
                  ) : st?.result === 'SUCCESS' ? (
                    <span className="status-dot ok" />
                  ) : st?.result === 'FAILURE' ? (
                    <span className="status-dot err" />
                  ) : (
                    <span className="status-dot" style={{ background: '#c1c7d0' }} />
                  )}
                  <strong>{j.jobName}</strong>
                  <span className="meta"> · {j.serverId}</span>
                  {st?.error && (
                    <div className="error-text" style={{ marginTop: 4 }}>
                      {st.error}
                    </div>
                  )}
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  {st?.buildNumber != null && (
                    <span className="meta">#{st.buildNumber}</span>
                  )}
                  {statusBadge(st)}
                  {st?.url && (
                    <a href={st.url} target="_blank" rel="noreferrer">
                      Open
                    </a>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </motion.div>
  );
}

export default function Packages({ pushToast, ciReady }) {
  const [packages, setPackages] = useState([]);
  const [statuses, setStatuses] = useState({});
  const [expanded, setExpanded] = useState({});
  const [selectedId, setSelectedId] = useState(null);
  const [busyId, setBusyId] = useState(null);
  const [loading, setLoading] = useState(true);
  const buildingRef = useRef({});
  const packagesRef = useRef([]);

  useEffect(() => {
    packagesRef.current = packages;
  }, [packages]);

  useEffect(() => {
    ensureBrowserNotifyPermission();
  }, []);

  const refreshList = useCallback(async () => {
    const data = await api.listPackages();
    setPackages(data.packages || []);
  }, []);

  useEffect(() => {
    refreshList()
      .catch((e) => pushToast(e.message, 'error'))
      .finally(() => setLoading(false));
  }, [refreshList, pushToast]);

  const handleJobsUpdate = useCallback(
    async (packageId, jobs) => {
      const building = summarizeJobsBuilding(jobs);
      const wasBuilding = Boolean(buildingRef.current[packageId]);

      if (wasBuilding && !building && jobs?.length) {
        const pkg = packagesRef.current.find((p) => p.id === packageId);
        const name = pkg?.name || 'Package';
        try {
          const note = await notifyPackageFinished({
            packageName: name,
            jobs,
          });
          pushToast(note.body, note.level === 'error' ? 'error' : 'success');
        } catch {
          // ignore notify errors
        }
      }

      buildingRef.current[packageId] = building;
    },
    [pushToast],
  );

  const pollOne = useCallback(
    async (id) => {
      const creds = credentialsByServer();
      if (!Object.keys(creds).length) return null;
      try {
        const data = await api.packageStatus(id, creds);
        setStatuses((prev) => ({ ...prev, [id]: data.jobs }));
        await handleJobsUpdate(id, data.jobs);
        return data.jobs;
      } catch {
        return null;
      }
    },
    [handleJobsUpdate],
  );

  useEffect(() => {
    if (!packages.length) return undefined;
    if (!hasAnyCredentials()) return undefined;
    if (!ciReady) return undefined;

    let cancelled = false;

    const tick = async () => {
      await Promise.all(packages.map((pkg) => pollOne(pkg.id)));
    };

    tick();
    const timer = setInterval(tick, 4000);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, [packages, pollOne, ciReady]);

  const ensureCreds = () => {
    if (!hasAnyCredentials()) {
      pushToast('Connect to CI servers first (New package → Connect)', 'error');
      return false;
    }
    return true;
  };

  const onStart = async (id) => {
    if (!ensureCreds()) return;
    setBusyId(id);
    try {
      const data = await api.startPackage(id, credentialsByServer());
      const failed = (data.results || []).filter((r) => !r.ok);
      if (failed.length) {
        const detail = failed
          .map((f) => `${f.jobName}: ${f.error || 'failed'}`)
          .join(' | ');
        pushToast(
          `Start failed (${failed.length}): ${detail}`,
          'error',
        );
      } else {
        pushToast('All jobs triggered', 'success');
      }
      setExpanded((prev) => ({ ...prev, [id]: true }));
      setSelectedId(id);
      buildingRef.current[id] = true;
      await pollOne(id);
    } catch (e) {
      pushToast(e.message, 'error');
    } finally {
      setBusyId(null);
    }
  };

  const onStop = async (id) => {
    if (!ensureCreds()) return;
    setBusyId(id);
    try {
      const data = await api.stopPackage(id, credentialsByServer());
      const failed = (data.results || []).filter((r) => !r.ok);
      if (failed.length) {
        pushToast(
          `Stop finished with ${failed.length} error(s)`,
          'error',
        );
      } else {
        pushToast('Abort requested for running builds', 'success');
      }
      await pollOne(id);
    } catch (e) {
      pushToast(e.message, 'error');
    } finally {
      setBusyId(null);
    }
  };

  const onDelete = async (id) => {
    if (!window.confirm('Delete this package?')) return;
    setBusyId(id);
    try {
      await api.deletePackage(id);
      setPackages((prev) => prev.filter((p) => p.id !== id));
      pushToast('Package deleted', 'success');
    } catch (e) {
      pushToast(e.message, 'error');
    } finally {
      setBusyId(null);
    }
  };

  const onSaveMeta = async (id, { name, description }) => {
    setBusyId(id);
    try {
      const updated = await api.updatePackage(id, { name, description });
      setPackages((prev) => prev.map((p) => (p.id === id ? updated : p)));
      pushToast('Package updated', 'success');
    } catch (e) {
      pushToast(e.message, 'error');
      throw e;
    } finally {
      setBusyId(null);
    }
  };

  return (
    <div>
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'flex-start',
          gap: 16,
          flexWrap: 'wrap',
          marginBottom: 8,
        }}
      >
        <div>
          <h1 className="page-title">Packages</h1>
          <p className="page-sub" style={{ marginBottom: 0 }}>
            Start or stop every job in a package across your three Jenkins CIs.
          </p>
        </div>
        <Link to="/wizard" className="btn btn-primary" style={{ textDecoration: 'none' }}>
          + New package
        </Link>
      </div>

      {!ciReady && hasAnyCredentials() && (
        <div className="card" style={{ marginBottom: 16, background: 'var(--primary-soft)' }}>
          Reconnecting saved CI logins…
        </div>
      )}

      {!hasAnyCredentials() && (
        <div className="card" style={{ marginBottom: 16, background: 'var(--primary-soft)' }}>
          No saved CI logins yet. Open <Link to="/wizard">New package</Link> and
          connect once — this browser will remember them for next time.
        </div>
      )}

      {loading ? (
        <p className="meta">Loading packages…</p>
      ) : packages.length === 0 ? (
        <div className="empty">
          <p>No packages yet.</p>
          <Link to="/wizard" className="btn btn-primary" style={{ textDecoration: 'none' }}>
            Create your first package
          </Link>
        </div>
      ) : (
        <div style={{ display: 'grid', gap: 14, marginTop: 20 }}>
          {packages.map((pkg, i) => (
            <motion.div
              key={pkg.id}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.05 }}
            >
              <PackageCard
                pkg={pkg}
                statusJobs={statuses[pkg.id]}
                expanded={Boolean(expanded[pkg.id])}
                selected={selectedId === pkg.id}
                onSelect={setSelectedId}
                onToggle={(id) =>
                  setExpanded((prev) => ({ ...prev, [id]: !prev[id] }))
                }
                onStart={onStart}
                onStop={onStop}
                onDelete={onDelete}
                onSaveMeta={onSaveMeta}
                busy={busyId === pkg.id}
              />
            </motion.div>
          ))}
        </div>
      )}
    </div>
  );
}
