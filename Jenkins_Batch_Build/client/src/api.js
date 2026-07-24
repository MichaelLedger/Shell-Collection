async function request(path, options = {}) {
  const res = await fetch(path, {
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
    ...options,
  });

  let data = null;
  const text = await res.text();
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = { error: text };
    }
  }

  if (!res.ok) {
    const err = new Error(data?.error || `Request failed (${res.status})`);
    err.status = res.status;
    err.data = data;
    throw err;
  }
  return data;
}

export const api = {
  getServers: () => request('/api/servers'),
  createServer: (payload) =>
    request('/api/servers', {
      method: 'POST',
      body: JSON.stringify(payload),
    }),
  updateServer: (id, payload) =>
    request(`/api/servers/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(payload),
    }),
  deleteServer: (id) =>
    request(`/api/servers/${id}`, { method: 'DELETE' }),
  connect: (serverId, credentials) =>
    request(`/api/jenkins/${serverId}/connect`, {
      method: 'POST',
      body: JSON.stringify(credentials),
    }),
  listPackages: () => request('/api/packages'),
  createPackage: (payload) =>
    request('/api/packages', {
      method: 'POST',
      body: JSON.stringify(payload),
    }),
  updatePackage: (id, payload) =>
    request(`/api/packages/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(payload),
    }),
  deletePackage: (id) =>
    request(`/api/packages/${id}`, { method: 'DELETE' }),
  startPackage: (id, credentialsByServer) =>
    request(`/api/packages/${id}/start`, {
      method: 'POST',
      body: JSON.stringify({ credentialsByServer }),
    }),
  stopPackage: (id, credentialsByServer) =>
    request(`/api/packages/${id}/stop`, {
      method: 'POST',
      body: JSON.stringify({ credentialsByServer }),
    }),
  packageStatus: (id, credentialsByServer) =>
    request(`/api/packages/${id}/status`, {
      method: 'POST',
      body: JSON.stringify({ credentialsByServer }),
    }),
  notify: (payload) =>
    request('/api/notify', {
      method: 'POST',
      body: JSON.stringify(payload),
    }),
};
