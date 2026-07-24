import { useCallback, useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { api } from '../api.js';
import { clearServerCredentials } from '../session.js';

const emptyForm = { label: '', baseUrl: '', description: '' };

export default function Servers({ pushToast }) {
  const [servers, setServers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState(emptyForm);
  const [editingId, setEditingId] = useState(null);
  const [editForm, setEditForm] = useState(emptyForm);
  const [busy, setBusy] = useState(null);

  const refresh = useCallback(async () => {
    const data = await api.getServers();
    setServers(data.servers || []);
  }, []);

  useEffect(() => {
    refresh()
      .catch((e) => pushToast(e.message, 'error'))
      .finally(() => setLoading(false));
  }, [refresh, pushToast]);

  const onAdd = async (e) => {
    e.preventDefault();
    setBusy('add');
    try {
      await api.createServer(form);
      setForm(emptyForm);
      await refresh();
      pushToast('CI server added', 'success');
    } catch (err) {
      pushToast(err.message, 'error');
    } finally {
      setBusy(null);
    }
  };

  const startEdit = (server) => {
    setEditingId(server.id);
    setEditForm({
      label: server.label || '',
      baseUrl: server.baseUrl || '',
      description: server.description || '',
    });
  };

  const onSaveEdit = async (id) => {
    setBusy(id);
    try {
      await api.updateServer(id, editForm);
      setEditingId(null);
      await refresh();
      pushToast('CI server updated', 'success');
    } catch (err) {
      pushToast(err.message, 'error');
    } finally {
      setBusy(null);
    }
  };

  const onDelete = async (server) => {
    if (
      !window.confirm(
        `Delete CI “${server.label}”? Saved login for this server will be cleared.`,
      )
    ) {
      return;
    }
    setBusy(server.id);
    try {
      await api.deleteServer(server.id);
      clearServerCredentials(server.id);
      await refresh();
      pushToast('CI server deleted', 'success');
    } catch (err) {
      pushToast(err.message, 'error');
    } finally {
      setBusy(null);
    }
  };

  return (
    <div>
      <h1 className="page-title">CI servers</h1>
      <p className="page-sub">
        Add or remove Jenkins instances used by the wizard and packages.
      </p>

      <form className="card" onSubmit={onAdd} style={{ marginBottom: 20 }}>
        <h3 style={{ margin: '0 0 12px', fontSize: 15 }}>Add CI server</h3>
        <div className="field">
          <label htmlFor="new-label">Display name</label>
          <input
            id="new-label"
            value={form.label}
            placeholder="e.g. CI · 10.4.2.8"
            onChange={(e) => setForm((f) => ({ ...f, label: e.target.value }))}
          />
        </div>
        <div className="field">
          <label htmlFor="new-url">Jenkins URL</label>
          <input
            id="new-url"
            required
            value={form.baseUrl}
            placeholder="http://10.4.2.8:8080"
            onChange={(e) => setForm((f) => ({ ...f, baseUrl: e.target.value }))}
          />
        </div>
        <div className="field">
          <label htmlFor="new-desc">Description</label>
          <textarea
            id="new-desc"
            rows={2}
            value={form.description}
            placeholder="Optional notes about this CI (team, region, purpose…)"
            onChange={(e) =>
              setForm((f) => ({ ...f, description: e.target.value }))
            }
          />
        </div>
        <button
          type="submit"
          className="btn btn-primary"
          disabled={busy === 'add' || !form.baseUrl.trim()}
        >
          {busy === 'add' ? 'Adding…' : '+ Add server'}
        </button>
      </form>

      {loading ? (
        <p className="meta">Loading…</p>
      ) : servers.length === 0 ? (
        <div className="empty">No CI servers yet. Add one above.</div>
      ) : (
        <div style={{ display: 'grid', gap: 12 }}>
          {servers.map((server, i) => (
            <motion.div
              key={server.id}
              className="card"
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.04 }}
            >
              {editingId === server.id ? (
                <div>
                  <div className="field">
                    <label>Display name</label>
                    <input
                      value={editForm.label}
                      onChange={(e) =>
                        setEditForm((f) => ({ ...f, label: e.target.value }))
                      }
                    />
                  </div>
                  <div className="field">
                    <label>Jenkins URL</label>
                    <input
                      value={editForm.baseUrl}
                      onChange={(e) =>
                        setEditForm((f) => ({ ...f, baseUrl: e.target.value }))
                      }
                    />
                  </div>
                  <div className="field">
                    <label>Description</label>
                    <textarea
                      rows={2}
                      value={editForm.description}
                      onChange={(e) =>
                        setEditForm((f) => ({
                          ...f,
                          description: e.target.value,
                        }))
                      }
                    />
                  </div>
                  <div style={{ display: 'flex', gap: 8 }}>
                    <button
                      type="button"
                      className="btn btn-primary"
                      disabled={busy === server.id}
                      onClick={() => onSaveEdit(server.id)}
                    >
                      Save
                    </button>
                    <button
                      type="button"
                      className="btn btn-ghost"
                      onClick={() => setEditingId(null)}
                    >
                      Cancel
                    </button>
                  </div>
                </div>
              ) : (
                <div className="package-head">
                  <div>
                    <h3 style={{ margin: '0 0 4px', fontSize: 16 }}>
                      {server.label}
                    </h3>
                    <div className="ci-url" style={{ marginBottom: 6 }}>
                      {server.baseUrl}
                    </div>
                    {server.description ? (
                      <p className="meta" style={{ margin: 0, maxWidth: 640 }}>
                        {server.description}
                      </p>
                    ) : (
                      <p className="meta" style={{ margin: 0, fontStyle: 'italic' }}>
                        No description
                      </p>
                    )}
                    <div className="meta" style={{ marginTop: 6 }}>
                      id: {server.id}
                    </div>
                  </div>
                  <div className="package-actions">
                    <button
                      type="button"
                      className="btn btn-subtle"
                      onClick={() => startEdit(server)}
                    >
                      Edit
                    </button>
                    <button
                      type="button"
                      className="btn btn-ghost"
                      disabled={busy === server.id}
                      onClick={() => onDelete(server)}
                    >
                      Delete
                    </button>
                  </div>
                </div>
              )}
            </motion.div>
          ))}
        </div>
      )}
    </div>
  );
}
