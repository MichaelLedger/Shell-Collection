import { useEffect, useMemo, useState } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { useNavigate } from 'react-router-dom';
import { api } from '../api.js';
import {
  clearCredentials,
  loadCredentials,
  loadJobsByServer,
  reconnectAllSaved,
  saveJobsForServer,
  setServerCredentials,
} from '../session.js';
import Stepper from '../components/Stepper.jsx';

const stepMotion = {
  initial: { opacity: 0, x: 24 },
  animate: { opacity: 1, x: 0 },
  exit: { opacity: 0, x: -24 },
  transition: { duration: 0.22 },
};

function ConnectStep({
  servers,
  connected,
  forms,
  setForms,
  onConnect,
  onConnectAll,
  onForget,
  busy,
  reconnecting,
}) {
  const hasSaved = servers.some((s) => forms[s.id]?.username && forms[s.id]?.password);

  return (
    <div>
      <h1 className="page-title">Connect CI servers</h1>
      <p className="page-sub">
        Logins are remembered in this browser. Next time you open the app they
        autofill and reconnect automatically.
      </p>
      {hasSaved && (
        <div style={{ display: 'flex', gap: 8, marginBottom: 14, flexWrap: 'wrap' }}>
          <button
            type="button"
            className="btn btn-subtle"
            disabled={Boolean(busy) || reconnecting}
            onClick={onConnectAll}
          >
            {reconnecting ? 'Reconnecting…' : 'Reconnect all saved'}
          </button>
          <button
            type="button"
            className="btn btn-ghost"
            disabled={Boolean(busy) || reconnecting}
            onClick={onForget}
          >
            Forget saved logins
          </button>
        </div>
      )}
      <div className="grid-3">
        {servers.map((server) => {
          const isConnected = Boolean(connected[server.id]);
          const form = forms[server.id] || { username: '', password: '' };
          const state = connected[server.id];
          return (
            <div
              key={server.id}
              className={`ci-card ${isConnected ? 'connected' : ''}`}
            >
              <h3>
                {isConnected && <span className="status-dot ok" />}
                {server.label}
              </h3>
              <div className="ci-url">{server.baseUrl}</div>
              {server.description ? (
                <p className="meta" style={{ margin: '0 0 10px' }}>
                  {server.description}
                </p>
              ) : null}
              <div className="field">
                <label htmlFor={`${server.id}-user`}>Username</label>
                <input
                  id={`${server.id}-user`}
                  autoComplete="username"
                  value={form.username}
                  onChange={(e) =>
                    setForms((prev) => ({
                      ...prev,
                      [server.id]: { ...form, username: e.target.value },
                    }))
                  }
                />
              </div>
              <div className="field">
                <label htmlFor={`${server.id}-pass`}>Password / API token</label>
                <input
                  id={`${server.id}-pass`}
                  type="password"
                  autoComplete="current-password"
                  value={form.password}
                  onChange={(e) =>
                    setForms((prev) => ({
                      ...prev,
                      [server.id]: { ...form, password: e.target.value },
                    }))
                  }
                />
              </div>
              <button
                type="button"
                className="btn btn-primary"
                disabled={
                  busy === server.id || !form.username || !form.password
                }
                onClick={() => onConnect(server.id)}
              >
                {busy === server.id
                  ? 'Connecting…'
                  : isConnected
                    ? 'Reconnect'
                    : 'Connect & load jobs'}
              </button>
              {state?.error && <p className="error-text">{state.error}</p>}
              {isConnected && !state?.error && (
                <p className="success-text">
                  Connected · {state.jobCount} jobs loaded
                </p>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

function PickJobsStep({ jobsByServer, servers, selected, setSelected, search, setSearch }) {
  const connectedServers = servers.filter((s) => jobsByServer[s.id]?.length);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    const out = {};
    for (const s of connectedServers) {
      const jobs = jobsByServer[s.id] || [];
      out[s.id] = q
        ? jobs.filter((j) => j.name.toLowerCase().includes(q))
        : jobs;
    }
    return out;
  }, [connectedServers, jobsByServer, search]);

  const keyOf = (serverId, jobName) => `${serverId}::${jobName}`;

  const toggle = (serverId, jobName) => {
    const key = keyOf(serverId, jobName);
    setSelected((prev) => {
      const next = { ...prev };
      if (next[key]) delete next[key];
      else next[key] = { serverId, jobName };
      return next;
    });
  };

  const count = Object.keys(selected).length;

  return (
    <div>
      <h1 className="page-title">Pick jobs</h1>
      <p className="page-sub">
        Select jobs across connected CIs. {count} selected.
      </p>
      <input
        className="search-input"
        placeholder="Search jobs…"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
      />
      <div className="grid-3">
        {connectedServers.map((server) => (
          <div key={server.id} className="job-column">
            <h3>
              {server.label} · {(jobsByServer[server.id] || []).length}
            </h3>
            <div className="job-list">
              {(filtered[server.id] || []).map((job) => {
                const key = keyOf(server.id, job.name);
                const checked = Boolean(selected[key]);
                return (
                  <label
                    key={key}
                    className={`job-item ${checked ? 'selected' : ''}`}
                  >
                    <input
                      type="checkbox"
                      checked={checked}
                      onChange={() => toggle(server.id, job.name)}
                    />
                    <span>{job.name}</span>
                  </label>
                );
              })}
              {(filtered[server.id] || []).length === 0 && (
                <div className="meta">No jobs match</div>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function NamePackageStep({ name, setName, description, setDescription, selectedJobs, error }) {
  return (
    <div>
      <h1 className="page-title">Name your package</h1>
      <p className="page-sub">Add a name and optional description, then save.</p>
      <div className="card" style={{ maxWidth: 520 }}>
        <div className="field">
          <label htmlFor="pkg-name">Package name</label>
          <input
            id="pkg-name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="e.g. Nightly Suite"
          />
        </div>
        <div className="field">
          <label htmlFor="pkg-desc">Description</label>
          <textarea
            id="pkg-desc"
            rows={3}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="What this package is for (region, release, owners…)"
          />
        </div>
        {error && <p className="error-text">{error}</p>}
        <div style={{ fontWeight: 600, marginBottom: 8 }}>
          Jobs in this package ({selectedJobs.length})
        </div>
        <ul style={{ margin: 0, paddingLeft: 18, color: 'var(--text-subtle)' }}>
          {selectedJobs.map((j) => (
            <li key={`${j.serverId}-${j.jobName}`}>
              {j.serverId} / {j.jobName}
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}

function applyJobsToConnected(jobsMap) {
  const next = {};
  for (const [serverId, jobs] of Object.entries(jobsMap || {})) {
    if (jobs?.length) next[serverId] = { jobCount: jobs.length };
  }
  return next;
}

export default function Wizard({ pushToast, ciReady }) {
  const navigate = useNavigate();
  const [step, setStep] = useState(1);
  const [servers, setServers] = useState([]);
  const [forms, setForms] = useState({});
  const [connected, setConnected] = useState(() =>
    applyJobsToConnected(loadJobsByServer()),
  );
  const [jobsByServer, setJobsByServer] = useState(loadJobsByServer);
  const [busy, setBusy] = useState(null);
  const [reconnecting, setReconnecting] = useState(false);
  const [selected, setSelected] = useState({});
  const [search, setSearch] = useState('');
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [saveError, setSaveError] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    api.getServers().then((data) => {
      setServers(data.servers || []);
      const creds = loadCredentials();
      const initialForms = {};
      for (const s of data.servers || []) {
        initialForms[s.id] = {
          username: creds[s.id]?.username || '',
          password: creds[s.id]?.password || '',
        };
      }
      setForms(initialForms);
    }).catch((e) => pushToast(e.message, 'error'));
  }, [pushToast]);

  // Sync after App-level auto-reconnect finishes
  useEffect(() => {
    if (!ciReady) return;
    const jobs = loadJobsByServer();
    setJobsByServer(jobs);
    setConnected((prev) => ({ ...prev, ...applyJobsToConnected(jobs) }));
  }, [ciReady]);

  const connectedCount = Object.keys(connected).filter(
    (id) => connected[id] && !connected[id].error,
  ).length;

  const selectedJobs = Object.values(selected);

  const onConnect = async (serverId) => {
    const form = forms[serverId];
    setBusy(serverId);
    setConnected((prev) => ({ ...prev, [serverId]: { ...(prev[serverId] || {}), error: null } }));
    try {
      const data = await api.connect(serverId, {
        username: form.username,
        password: form.password,
      });
      setServerCredentials(serverId, form);
      saveJobsForServer(serverId, data.jobs);
      setJobsByServer((prev) => ({ ...prev, [serverId]: data.jobs }));
      setConnected((prev) => ({
        ...prev,
        [serverId]: { jobCount: data.jobs.length },
      }));
      pushToast(`Loaded ${data.jobs.length} jobs from ${serverId}`, 'success');
    } catch (e) {
      setConnected((prev) => ({
        ...prev,
        [serverId]: { error: e.message },
      }));
      pushToast(e.message, 'error');
    } finally {
      setBusy(null);
    }
  };

  const onConnectAll = async () => {
    // Persist current form values first
    for (const [serverId, form] of Object.entries(forms)) {
      if (form?.username && form?.password) {
        setServerCredentials(serverId, form);
      }
    }
    setReconnecting(true);
    try {
      const { ok, failed, jobsByServer: jobs } = await reconnectAllSaved();
      setJobsByServer(jobs);
      setConnected(applyJobsToConnected(jobs));
      for (const f of failed) {
        setConnected((prev) => ({
          ...prev,
          [f.serverId]: { error: f.error },
        }));
      }
      if (ok.length) {
        pushToast(`Reconnected ${ok.length} CI(s)`, 'success');
      }
      if (failed.length) {
        pushToast(
          `Failed: ${failed.map((f) => f.serverId).join(', ')}`,
          'error',
        );
      }
    } finally {
      setReconnecting(false);
    }
  };

  const onForget = () => {
    if (!window.confirm('Remove all saved usernames and passwords from this browser?')) {
      return;
    }
    clearCredentials();
    setForms((prev) => {
      const blank = {};
      for (const id of Object.keys(prev)) {
        blank[id] = { username: '', password: '' };
      }
      return blank;
    });
    setConnected({});
    setJobsByServer({});
    pushToast('Saved logins cleared');
  };

  const savePackage = async () => {
    setSaveError('');
    setSaving(true);
    try {
      await api.createPackage({
        name,
        description,
        jobs: selectedJobs,
      });
      pushToast(`Package “${name.trim()}” saved`, 'success');
      navigate('/');
    } catch (e) {
      setSaveError(e.message);
      pushToast(e.message, 'error');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div>
      <Stepper step={step} />
      <AnimatePresence mode="wait">
        <motion.div key={step} {...stepMotion}>
          {step === 1 && (
            <ConnectStep
              servers={servers}
              connected={connected}
              forms={forms}
              setForms={setForms}
              onConnect={onConnect}
              onConnectAll={onConnectAll}
              onForget={onForget}
              busy={busy}
              reconnecting={reconnecting || !ciReady}
            />
          )}
          {step === 2 && (
            <PickJobsStep
              jobsByServer={jobsByServer}
              servers={servers}
              selected={selected}
              setSelected={setSelected}
              search={search}
              setSearch={setSearch}
            />
          )}
          {step === 3 && (
            <NamePackageStep
              name={name}
              setName={setName}
              description={description}
              setDescription={setDescription}
              selectedJobs={selectedJobs}
              error={saveError}
            />
          )}
        </motion.div>
      </AnimatePresence>

      <div className="wizard-actions">
        <button
          type="button"
          className="btn btn-ghost"
          disabled={step === 1}
          onClick={() => setStep((s) => Math.max(1, s - 1))}
        >
          Back
        </button>
        {step < 3 ? (
          <button
            type="button"
            className="btn btn-primary"
            disabled={
              (step === 1 && connectedCount < 1) ||
              (step === 2 && selectedJobs.length < 1)
            }
            onClick={() => setStep((s) => s + 1)}
          >
            Next →
          </button>
        ) : (
          <button
            type="button"
            className="btn btn-primary"
            disabled={!name.trim() || saving}
            onClick={savePackage}
            style={{ background: 'var(--success)' }}
          >
            {saving ? 'Saving…' : 'Save package'}
          </button>
        )}
      </div>
    </div>
  );
}
