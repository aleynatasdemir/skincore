import { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import Layout from '../components/Layout'
import { apiFetch, timeAgo } from '../api'

const typeColor = t => ({ like: 'bg-pink-100 text-pink-600', comment: 'bg-blue-100 text-blue-600', broadcast: 'bg-purple-100 text-purple-600' }[t] || 'bg-slate-100 text-slate-600')

export default function Dashboard() {
  const [stats, setStats] = useState({ users: '—', routines: '—', notifs: '—', pending: '—' })
  const [notifLogs, setNotifLogs] = useState([])
  const [pendingReqs, setPendingReqs] = useState([])
  const [broadcast, setBroadcast] = useState({ open: false, title: '', body: '', loading: false, error: '', success: '' })

  useEffect(() => { loadAll() }, [])

  async function loadAll() {
    try {
      const [uRes, rRes, nRes, pRes] = await Promise.all([
        apiFetch('/admin/users?limit=1'),
        apiFetch('/admin/routines?limit=1'),
        apiFetch('/admin/notifications?limit=5'),
        apiFetch('/admin/product-requests?status=pending&limit=4'),
      ])
      if (uRes?.ok) { const d = await uRes.json(); setStats(s => ({ ...s, users: d.total?.toLocaleString() ?? '—' })) }
      if (rRes?.ok) { const d = await rRes.json(); setStats(s => ({ ...s, routines: (d.data?.length ?? 0).toLocaleString() })) }
      if (nRes?.ok) { const d = await nRes.json(); setStats(s => ({ ...s, notifs: d.total?.toLocaleString() ?? '—' })); setNotifLogs(d.data || []) }
      if (pRes?.ok) { const d = await pRes.json(); setStats(s => ({ ...s, pending: d.data?.length ?? 0 })); setPendingReqs(d.data || []) }
    } catch {}
  }

  async function sendBroadcast() {
    if (!broadcast.title.trim() || !broadcast.body.trim()) return setBroadcast(b => ({ ...b, error: 'Title and message required.' }))
    setBroadcast(b => ({ ...b, loading: true, error: '', success: '' }))
    try {
      const res = await apiFetch('/admin/notifications/broadcast', { method: 'POST', body: JSON.stringify({ title: broadcast.title, body: broadcast.body }) })
      const data = await res.json()
      if (!res.ok) throw new Error(data.message)
      setBroadcast(b => ({ ...b, success: data.message, loading: false }))
      setTimeout(() => setBroadcast({ open: false, title: '', body: '', loading: false, error: '', success: '' }), 2000)
      loadAll()
    } catch (e) { setBroadcast(b => ({ ...b, error: e.message, loading: false })) }
  }

  const StatCard = ({ id, icon, label, value, badge, badgeColor }) => (
    <div className="bg-surface-container-lowest p-6 rounded-lg border border-outline-variant/15 hover:border-outline-variant/50 transition-all">
      <div className="flex justify-between items-start mb-4">
        <div className="p-2 bg-primary-container/10 rounded-lg">
          <span className="material-symbols-outlined text-primary-container">{icon}</span>
        </div>
        <span className={`${badgeColor} px-2 py-0.5 rounded-sm text-[10px] font-bold`}>{badge}</span>
      </div>
      <p className="text-xs font-bold uppercase tracking-widest text-on-surface-variant mb-1">{label}</p>
      <h3 className="text-2xl font-extrabold font-headline text-primary">{value}</h3>
    </div>
  )

  return (
    <Layout>
      <div className="mb-10">
        <h2 className="text-3xl font-extrabold tracking-tight font-headline text-primary mb-2">Executive Overview</h2>
        <p className="text-on-surface-variant">Real-time product management and operational metrics.</p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-10">
        <StatCard icon="group" label="Total Users" value={stats.users} badge="Active" badgeColor="bg-tertiary-fixed text-on-tertiary-container" />
        <StatCard icon="settings_backup_restore" label="Routines" value={stats.routines} badge="Total" badgeColor="bg-tertiary-fixed text-on-tertiary-container" />
        <StatCard icon="notifications" label="Notifications Sent" value={stats.notifs} badge="Logs" badgeColor="bg-error-container text-on-error-container" />
        <StatCard icon="inventory_2" label="Pending Products" value={stats.pending} badge="Review" badgeColor="bg-secondary-fixed text-on-secondary-fixed-variant" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Notification Logs */}
        <div className="lg:col-span-2 bg-surface-container-lowest p-8 rounded-lg border border-outline-variant/15">
          <div className="flex justify-between items-end mb-6">
            <div>
              <h4 className="text-lg font-bold font-headline mb-1">Recent Notifications</h4>
              <p className="text-on-surface-variant text-sm">Latest sent push notifications.</p>
            </div>
            <Link to="/notifications" className="text-xs font-bold text-primary-container hover:underline">View All</Link>
          </div>
          {notifLogs.length === 0 ? (
            <div className="text-center py-10 text-on-surface-variant text-sm">No notifications yet.</div>
          ) : (
            <div className="space-y-2">
              {notifLogs.map(n => (
                <div key={n.id} className="flex items-start gap-3 p-3 rounded-lg bg-surface-container-low">
                  <div className={`w-2 h-2 mt-1.5 rounded-full flex-shrink-0 ${n.success ? 'bg-green-400' : 'bg-red-400'}`} />
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold truncate">{n.title}</p>
                    <p className="text-xs text-on-surface-variant truncate">{n.body}</p>
                  </div>
                  <div className="text-right flex-shrink-0">
                    <span className={`text-[10px] font-bold uppercase px-1.5 py-0.5 rounded ${typeColor(n.type)}`}>{n.type}</span>
                    <p className="text-[10px] text-on-surface-variant mt-1">{timeAgo(n.sentAt)}</p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Right column */}
        <div className="space-y-6">
          <div className="bg-surface-container-lowest p-6 rounded-lg border border-outline-variant/15">
            <h4 className="text-sm font-bold font-headline mb-4 uppercase tracking-widest text-on-surface-variant">Quick Actions</h4>
            <div className="space-y-3">
              {[
                { to: '/users', icon: 'group', label: 'Manage Users' },
                { to: '/products', icon: 'inventory_2', label: 'Product Requests' },
                { to: '/routines', icon: 'settings_backup_restore', label: 'Routines' },
              ].map(a => (
                <Link key={a.to} to={a.to} className="flex items-center gap-3 w-full p-3 rounded-lg bg-surface-container-low hover:bg-surface-container-high transition-all">
                  <span className="material-symbols-outlined text-primary-container">{a.icon}</span>
                  <span className="text-sm font-semibold">{a.label}</span>
                </Link>
              ))}
              <button onClick={() => setBroadcast(b => ({ ...b, open: true }))}
                className="flex items-center gap-3 w-full p-3 rounded-lg bg-surface-container-low hover:bg-surface-container-high transition-all text-left">
                <span className="material-symbols-outlined text-primary-container">send</span>
                <span className="text-sm font-semibold">Broadcast Notification</span>
              </button>
            </div>
          </div>

          <div className="bg-surface-container-lowest p-6 rounded-lg border border-outline-variant/15">
            <div className="flex justify-between items-center mb-4">
              <h4 className="text-sm font-bold font-headline uppercase tracking-widest text-on-surface-variant">Pending Requests</h4>
              <Link to="/products" className="text-xs font-bold text-primary-container hover:underline">View All</Link>
            </div>
            {pendingReqs.length === 0 ? (
              <p className="text-sm text-on-surface-variant text-center py-2">No pending requests.</p>
            ) : (
              <div className="space-y-3">
                {pendingReqs.map(r => (
                  <div key={r.id} className="flex items-center gap-3">
                    {r.frontImageUrl
                      ? <img src={r.frontImageUrl} className="w-10 h-10 rounded-lg object-cover bg-slate-100 flex-shrink-0" alt=""/>
                      : <div className="w-10 h-10 rounded-lg bg-slate-100 flex items-center justify-center flex-shrink-0"><span className="material-symbols-outlined text-slate-400 text-sm">image</span></div>
                    }
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-semibold truncate">{r.productName || r.brandName}</p>
                      <p className="text-xs text-on-surface-variant truncate">{r.brandName}</p>
                    </div>
                    <Link to="/products" className="text-xs font-bold text-primary-container hover:underline flex-shrink-0">Review</Link>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Broadcast Modal */}
      {broadcast.open && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-white rounded-xl shadow-xl w-full max-w-md mx-4 p-8">
            <h3 className="text-lg font-bold font-headline mb-1">Broadcast Notification</h3>
            <p className="text-sm text-on-surface-variant mb-6">Send a push notification to all users.</p>
            <div className="space-y-4">
              <div>
                <label className="block text-xs font-bold uppercase tracking-widest text-on-surface-variant mb-1.5">Title</label>
                <input value={broadcast.title} onChange={e => setBroadcast(b => ({ ...b, title: e.target.value }))}
                  className="w-full border border-outline-variant rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-slate-300" placeholder="Notification title"/>
              </div>
              <div>
                <label className="block text-xs font-bold uppercase tracking-widest text-on-surface-variant mb-1.5">Message</label>
                <textarea value={broadcast.body} onChange={e => setBroadcast(b => ({ ...b, body: e.target.value }))}
                  rows={3} className="w-full border border-outline-variant rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-slate-300 resize-none" placeholder="Notification message..."/>
              </div>
            </div>
            {broadcast.error && <p className="mt-3 text-sm text-red-500">{broadcast.error}</p>}
            {broadcast.success && <p className="mt-3 text-sm text-green-600 font-semibold">{broadcast.success}</p>}
            <div className="flex gap-3 mt-6">
              <button onClick={() => setBroadcast({ open: false, title: '', body: '', loading: false, error: '', success: '' })}
                className="flex-1 py-2.5 rounded-lg border border-outline-variant text-sm font-semibold hover:bg-surface-container-low transition-all">Cancel</button>
              <button onClick={sendBroadcast} disabled={broadcast.loading}
                className="flex-1 py-2.5 rounded-lg bg-slate-900 text-white text-sm font-semibold hover:bg-slate-700 transition-all disabled:opacity-60">
                {broadcast.loading ? 'Sending...' : 'Send to All'}
              </button>
            </div>
          </div>
        </div>
      )}
    </Layout>
  )
}
