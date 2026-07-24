import { NavLink, Route, Routes } from 'react-router-dom';
import { useCallback, useEffect, useState } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import BrandLogo from './components/BrandLogo.jsx';
import Wizard from './pages/Wizard.jsx';
import Packages from './pages/Packages.jsx';
import Servers from './pages/Servers.jsx';
import { hasAnyCredentials, reconnectAllSaved } from './session.js';
import { makeId } from './id.js';

function ToastStack({ toasts, onDismiss }) {
  return (
    <div className="toast-stack">
      <AnimatePresence>
        {toasts.map((t) => (
          <motion.div
            key={t.id}
            className={`toast ${t.type || ''}`}
            initial={{ opacity: 0, y: 16, x: 8 }}
            animate={{ opacity: 1, y: 0, x: 0 }}
            exit={{ opacity: 0, x: 24 }}
            onClick={() => onDismiss(t.id)}
            role="status"
          >
            {t.message}
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  );
}

export default function App() {
  const [toasts, setToasts] = useState([]);
  const [ciReady, setCiReady] = useState(!hasAnyCredentials());

  const pushToast = useCallback((message, type = '') => {
    const id = makeId();
    setToasts((prev) => [...prev, { id, message, type }]);
    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
    }, 4200);
  }, []);

  const dismissToast = useCallback((id) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  useEffect(() => {
    let cancelled = false;

    (async () => {
      if (!hasAnyCredentials()) {
        setCiReady(true);
        return;
      }

      // Don't block the UI forever — show packages while reconnect runs
      setCiReady(true);
      pushToast('Reconnecting saved CI logins…');
      try {
        const { ok, failed } = await reconnectAllSaved();
        if (cancelled) return;
        if (ok.length) {
          pushToast(
            `Reconnected ${ok.length} CI${ok.length > 1 ? 's' : ''}`,
            'success',
          );
        }
        if (failed.length) {
          pushToast(
            `Reconnect failed: ${failed.map((f) => f.serverId).join(', ')}`,
            'error',
          );
        }
      } catch (e) {
        if (!cancelled) {
          pushToast(e.message || 'Reconnect failed', 'error');
        }
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [pushToast]);

  return (
    <div className="app-shell">
      <header className="topbar">
        <NavLink to="/" className="brand">
          <BrandLogo />
          <span className="brand-title">Jenkins Batch Build</span>
        </NavLink>
        <nav className="topnav">
          <NavLink to="/" end>
            Packages
          </NavLink>
          <NavLink to="/wizard">New package</NavLink>
          <NavLink to="/servers">CI servers</NavLink>
        </nav>
      </header>
      <main className="main">
        <Routes>
          <Route
            path="/"
            element={<Packages pushToast={pushToast} ciReady={ciReady} />}
          />
          <Route
            path="/wizard"
            element={<Wizard pushToast={pushToast} ciReady={ciReady} />}
          />
          <Route
            path="/servers"
            element={<Servers pushToast={pushToast} />}
          />
        </Routes>
      </main>
      <ToastStack toasts={toasts} onDismiss={dismissToast} />
    </div>
  );
}
