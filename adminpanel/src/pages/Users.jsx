import { useEffect, useMemo, useState } from 'react'
import Layout from '../components/Layout'
import { apiFetch } from '../api'

const LIMIT = 20

function roleLabel(user) {
  return user.isAdmin ? 'Admin' : 'User'
}

export default function Users() {
  const [users, setUsers] = useState([])
  const [total, setTotal] = useState(0)
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const [statusFilter, setStatusFilter] = useState('all')
  const [roleFilter, setRoleFilter] = useState('all')
  const [sortBy, setSortBy] = useState('recent')
  const [loading, setLoading] = useState(false)
  const [actionLoadingId, setActionLoadingId] = useState(null)
  const [error, setError] = useState('')

  useEffect(() => {
    loadUsers()
  }, [page, search, statusFilter])

  async function loadUsers() {
    setLoading(true)
    setError('')
    try {
      const query = new URLSearchParams({
        page: String(page),
        limit: String(LIMIT),
        ...(search ? { search } : {}),
        ...(statusFilter !== 'all' ? { status: statusFilter } : {}),
      })
      const res = await apiFetch(`/admin/users?${query}`)
      const data = await res.json()
      if (!res.ok) throw new Error(data.message || 'Kullanıcılar alınamadı.')
      setUsers(data.data || [])
      setTotal(data.total || 0)
    } catch (err) {
      setUsers([])
      setTotal(0)
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  async function banUser(user) {
    const reason = prompt(`"${user.email}" kullanıcısı için ban nedeni (opsiyonel):`) || ''
    setActionLoadingId(user.id)
    try {
      const res = await apiFetch(`/admin/users/${user.id}/ban`, {
        method: 'PUT',
        body: JSON.stringify({ reason }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.message || 'Ban işlemi başarısız.')
      await loadUsers()
    } catch (err) {
      setError(err.message)
    } finally {
      setActionLoadingId(null)
    }
  }

  async function unbanUser(user) {
    setActionLoadingId(user.id)
    try {
      const res = await apiFetch(`/admin/users/${user.id}/unban`, { method: 'PUT' })
      const data = await res.json()
      if (!res.ok) throw new Error(data.message || 'Unban işlemi başarısız.')
      await loadUsers()
    } catch (err) {
      setError(err.message)
    } finally {
      setActionLoadingId(null)
    }
  }

  const visibleUsers = useMemo(() => {
    let list = [...users]

    if (roleFilter === 'admin') list = list.filter(u => u.isAdmin)
    if (roleFilter === 'user') list = list.filter(u => !u.isAdmin)

    if (sortBy === 'recent') {
      list.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
    } else if (sortBy === 'oldest') {
      list.sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime())
    } else if (sortBy === 'name') {
      list.sort((a, b) => (a.fullName || a.email).localeCompare(b.fullName || b.email))
    }

    return list
  }, [users, roleFilter, sortBy])

  const pages = Math.max(1, Math.ceil(total / LIMIT))
  const showingFrom = total === 0 ? 0 : (page - 1) * LIMIT + 1
  const showingTo = Math.min(page * LIMIT, total)

  return (
    <Layout>
      <div className="max-w-7xl mx-auto">
        <div className="mb-10 flex justify-between items-end gap-4">
          <div>
            <h1 className="font-headline text-4xl font-extrabold tracking-tight text-primary mb-2 uppercase">Users</h1>
            <p className="text-on-surface-variant">Manage administrative access and platform permissions.</p>
          </div>
          <button
            disabled
            className="px-6 py-2.5 bg-tertiary text-on-tertiary rounded-md font-headline font-semibold text-sm shadow-md opacity-40 cursor-not-allowed flex items-center gap-2"
            title="Bu aksiyon henüz bağlı değil."
          >
            <span className="material-symbols-outlined text-sm">person_add</span>
            Provision User
          </button>
        </div>

        <div className="mb-6 flex flex-wrap gap-4 items-center justify-between">
          <div className="flex gap-2">
            {[
              { id: 'all', label: 'All Users' },
              { id: 'active', label: 'Active' },
              { id: 'banned', label: 'Banned' },
            ].map(tab => (
              <button
                key={tab.id}
                onClick={() => {
                  setStatusFilter(tab.id)
                  setPage(1)
                }}
                className={`px-4 py-2 text-xs font-bold uppercase tracking-widest rounded-md transition-colors ${
                  statusFilter === tab.id
                    ? 'bg-slate-900 text-white'
                    : 'bg-surface-container-low text-on-surface-variant hover:bg-surface-container-high'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>

          <div className="flex items-center gap-3">
            <div className="relative w-72">
              <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-sm">search</span>
              <input
                value={search}
                onChange={e => {
                  setSearch(e.target.value)
                  setPage(1)
                }}
                className="w-full bg-surface-container-low border-none rounded-lg pl-10 pr-4 py-2 text-sm font-medium focus:ring-2 focus:ring-slate-200"
                placeholder="Search user..."
              />
            </div>

            <select
              value={roleFilter}
              onChange={e => setRoleFilter(e.target.value)}
              className="bg-surface-container-low border-none rounded-lg px-3 py-2 text-sm font-semibold focus:ring-2 focus:ring-slate-200"
            >
              <option value="all">All Roles</option>
              <option value="admin">Admin</option>
              <option value="user">User</option>
            </select>

            <select
              value={sortBy}
              onChange={e => setSortBy(e.target.value)}
              className="bg-surface-container-low border-none rounded-lg px-3 py-2 text-sm font-semibold focus:ring-2 focus:ring-slate-200"
            >
              <option value="recent">Recent First</option>
              <option value="oldest">Oldest First</option>
              <option value="name">Name A-Z</option>
            </select>
          </div>
        </div>

        {error && (
          <div className="mb-4 px-4 py-3 rounded-md bg-red-100 text-red-700 text-sm">{error}</div>
        )}

        <div className="bg-surface-container-lowest rounded-xl shadow-sm border border-outline-variant/15 overflow-hidden">
          {loading ? (
            <div className="px-6 py-16 text-center text-on-surface-variant">Loading users...</div>
          ) : visibleUsers.length === 0 ? (
            <div className="px-6 py-16 text-center text-on-surface-variant">No users found.</div>
          ) : (
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="bg-surface-container-low">
                  <th className="px-6 py-4 text-xs font-extrabold uppercase tracking-widest text-on-surface-variant">Username</th>
                  <th className="px-6 py-4 text-xs font-extrabold uppercase tracking-widest text-on-surface-variant">Email</th>
                  <th className="px-6 py-4 text-xs font-extrabold uppercase tracking-widest text-on-surface-variant">Registration Date</th>
                  <th className="px-6 py-4 text-xs font-extrabold uppercase tracking-widest text-on-surface-variant">Role</th>
                  <th className="px-6 py-4 text-xs font-extrabold uppercase tracking-widest text-on-surface-variant">Status</th>
                  <th className="px-6 py-4 text-xs font-extrabold uppercase tracking-widest text-on-surface-variant text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {visibleUsers.map(user => (
                  <tr key={user.id} className="group hover:bg-surface-container-high transition-colors duration-150">
                    <td className="px-6 py-5">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-lg bg-primary-fixed flex items-center justify-center text-on-primary-fixed font-bold text-sm">
                          {(user.fullName || user.email).charAt(0).toUpperCase()}
                        </div>
                        <div>
                          <p className="font-headline font-bold text-slate-900">{user.fullName || 'Unnamed User'}</p>
                          {user.username && <p className="text-xs text-on-surface-variant">@{user.username}</p>}
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-5 text-sm text-on-surface-variant font-medium">{user.email}</td>
                    <td className="px-6 py-5 text-sm text-on-surface-variant">{new Date(user.createdAt).toLocaleDateString()}</td>
                    <td className="px-6 py-5">
                      <span className="px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider bg-secondary-container text-on-secondary-container rounded-sm">
                        {roleLabel(user)}
                      </span>
                    </td>
                    <td className="px-6 py-5">
                      {user.isBanned ? (
                        <div className="flex items-center gap-2">
                          <div className="w-2 h-2 rounded-full bg-error" />
                          <span className="text-sm font-semibold text-error">Banned</span>
                        </div>
                      ) : (
                        <div className="flex items-center gap-2">
                          <div className="w-2 h-2 rounded-full bg-tertiary-fixed-dim" />
                          <span className="text-sm font-semibold text-green-700">Active</span>
                        </div>
                      )}
                    </td>
                    <td className="px-6 py-5 text-right">
                      <div className="flex justify-end items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                        {user.isBanned ? (
                          <button
                            onClick={() => unbanUser(user)}
                            disabled={actionLoadingId === user.id}
                            className="p-2 text-on-tertiary-container hover:bg-tertiary-fixed/30 rounded-lg transition-colors flex items-center gap-1 text-xs font-bold uppercase disabled:opacity-50"
                            title="Unban User"
                          >
                            <span className="material-symbols-outlined text-lg">check_circle</span>
                            Unban
                          </button>
                        ) : (
                          <button
                            onClick={() => banUser(user)}
                            disabled={actionLoadingId === user.id}
                            className="p-2 text-error hover:bg-error-container/30 rounded-lg transition-colors flex items-center gap-1 text-xs font-bold uppercase disabled:opacity-50"
                            title="Ban User"
                          >
                            <span className="material-symbols-outlined text-lg">block</span>
                            Ban
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}

          <div className="px-6 py-5 bg-surface-container-low flex justify-between items-center border-t border-outline-variant/15">
            <span className="text-xs font-bold uppercase tracking-widest text-on-surface-variant">
              Showing {showingFrom} to {showingTo} of {total} users
            </span>
            <div className="flex items-center gap-1">
              <button
                onClick={() => setPage(p => Math.max(1, p - 1))}
                disabled={page === 1}
                className="w-8 h-8 flex items-center justify-center rounded-md text-on-surface-variant hover:bg-surface-container-high transition-colors disabled:opacity-40"
              >
                <span className="material-symbols-outlined text-lg">chevron_left</span>
              </button>
              <span className="px-2 text-xs font-bold text-on-surface-variant">{page} / {pages}</span>
              <button
                onClick={() => setPage(p => Math.min(pages, p + 1))}
                disabled={page === pages}
                className="w-8 h-8 flex items-center justify-center rounded-md text-on-surface-variant hover:bg-surface-container-high transition-colors disabled:opacity-40"
              >
                <span className="material-symbols-outlined text-lg">chevron_right</span>
              </button>
            </div>
          </div>
        </div>

        <div className="mt-10 grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="bg-surface-container-lowest p-6 rounded-xl border border-outline-variant/15 shadow-sm">
            <div className="flex items-center justify-between mb-4">
              <span className="text-[10px] font-extrabold uppercase tracking-widest text-on-surface-variant">Active Users</span>
              <span className="material-symbols-outlined text-on-tertiary-container">shield_with_heart</span>
            </div>
            <p className="text-3xl font-headline font-extrabold text-primary tracking-tighter">
              {users.filter(u => !u.isBanned).length}
            </p>
            <p className="text-[11px] text-on-surface-variant mt-2">Current page active user count.</p>
          </div>

          <div className="bg-primary-container p-6 rounded-xl shadow-md flex flex-col justify-between">
            <div>
              <span className="text-[10px] font-extrabold uppercase tracking-widest text-on-primary-container">Security Status</span>
              <h3 className="text-white font-headline font-bold mt-1">Advanced Protection Active</h3>
            </div>
            <div className="mt-6 flex gap-2">
              <div className="flex-1 h-1 bg-white/10 rounded-full overflow-hidden">
                <div className="h-full bg-tertiary-fixed w-3/4" />
              </div>
            </div>
            <span className="text-[10px] text-on-primary-container mt-2">Threat level: Minimal</span>
          </div>

          <div className="bg-tertiary-fixed p-6 rounded-xl border border-outline-variant/15 shadow-sm">
            <div className="flex items-center justify-between mb-4">
              <span className="text-[10px] font-extrabold uppercase tracking-widest text-on-tertiary-fixed-variant">Banned Users</span>
              <span className="material-symbols-outlined text-on-tertiary-fixed-variant">pending_actions</span>
            </div>
            <p className="text-3xl font-headline font-extrabold text-on-tertiary-fixed tracking-tighter">
              {users.filter(u => u.isBanned).length}
            </p>
            <button
              onClick={() => {
                setStatusFilter('banned')
                setPage(1)
              }}
              className="mt-4 w-full py-2 bg-on-tertiary-fixed text-tertiary-fixed text-[10px] font-bold uppercase tracking-widest rounded-md"
            >
              Review Queue
            </button>
          </div>
        </div>
      </div>
    </Layout>
  )
}

