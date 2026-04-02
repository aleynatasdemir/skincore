const API_BASE = '/api'

export function getToken() {
  return localStorage.getItem('admin_token')
}
export function setToken(t) {
  localStorage.setItem('admin_token', t)
}
export function getUser() {
  try { return JSON.parse(localStorage.getItem('admin_user')) } catch { return null }
}
export function setUser(u) {
  localStorage.setItem('admin_user', JSON.stringify(u))
}
export function clearAuth() {
  localStorage.removeItem('admin_token')
  localStorage.removeItem('admin_user')
}

export async function apiFetch(path, options = {}) {
  const token = getToken()
  const res = await fetch(API_BASE + path, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(options.headers || {}),
    },
  })

  // Fail-safe: if token is expired/invalid, force logout.
  if (res.status === 401) {
    clearAuth()
    if (typeof window !== 'undefined' && window.location.pathname !== '/login') {
      window.location.replace('/login')
    }
  }

  return res
}

export function timeAgo(dateStr) {
  const diff = Date.now() - new Date(dateStr).getTime()
  const m = Math.floor(diff / 60000)
  if (m < 1) return 'just now'
  if (m < 60) return `${m}m ago`
  const h = Math.floor(m / 60)
  if (h < 24) return `${h}h ago`
  return `${Math.floor(h / 24)}d ago`
}
