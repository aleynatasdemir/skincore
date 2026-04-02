import { useEffect, useMemo, useState } from 'react'
import Layout from '../components/Layout'
import { apiFetch, timeAgo } from '../api'

const LIMIT = 30

export default function Notifications() {
  const [logs, setLogs] = useState([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [loading, setLoading] = useState(false)
  const [language, setLanguage] = useState('en')
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const [sending, setSending] = useState(false)
  const [drafts, setDrafts] = useState({
    tr: { title: '', body: '' },
    en: { title: '', body: '' },
  })
  const [form, setForm] = useState({
    audience: 'all_users',
    recipientUserId: '',
  })

  const activeDraft = drafts[language]

  useEffect(() => {
    loadLogs()
  }, [page])

  async function loadLogs() {
    setLoading(true)
    setError('')
    try {
      const res = await apiFetch(`/admin/notifications?page=${page}&limit=${LIMIT}`)
      const data = await res.json()
      if (!res.ok) throw new Error(data.message || 'Bildirim logları alınamadı.')
      setLogs(data.data || [])
      setTotal(data.total || 0)
    } catch (err) {
      setLogs([])
      setTotal(0)
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  async function sendNotification(e) {
    e.preventDefault()
    setError('')
    setSuccess('')

    const trReady = drafts.tr.title.trim() && drafts.tr.body.trim()
    const enReady = drafts.en.title.trim() && drafts.en.body.trim()

    if (!trReady && !enReady) {
      setError('TR veya EN için başlık + içerik gir.')
      return
    }

    if (form.audience === 'specific_user' && !form.recipientUserId.trim()) {
      setError('Specific User seçiliyse User ID zorunlu.')
      return
    }

    setSending(true)
    try {
      const res = await apiFetch('/admin/notifications/send', {
        method: 'POST',
        body: JSON.stringify({
          audience: form.audience,
          recipientUserId: form.audience === 'specific_user' ? form.recipientUserId.trim() : null,
          title: activeDraft.title.trim() || drafts.tr.title.trim() || drafts.en.title.trim(),
          body: activeDraft.body.trim() || drafts.tr.body.trim() || drafts.en.body.trim(),
          titleTr: drafts.tr.title.trim() || null,
          bodyTr: drafts.tr.body.trim() || null,
          titleEn: drafts.en.title.trim() || null,
          bodyEn: drafts.en.body.trim() || null,
        }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.message || 'Bildirim gönderilemedi.')

      setSuccess(data.message || 'Bildirim gönderildi.')
      setForm(prev => ({ ...prev, recipientUserId: '' }))
      setDrafts({
        tr: { title: '', body: '' },
        en: { title: '', body: '' },
      })
      await loadLogs()
    } catch (err) {
      setError(err.message)
    } finally {
      setSending(false)
    }
  }

  function exportCsv() {
    if (logs.length === 0) return

    const rows = [
      ['id', 'title', 'body', 'audience', 'recipientUserId', 'type', 'success', 'sentAt'],
      ...logs.map(log => [
        log.id,
        log.title,
        log.body,
        log.recipientUserId ? 'specific_user' : 'all_users',
        log.recipientUserId || '',
        log.type || '',
        String(log.success),
        new Date(log.sentAt).toISOString(),
      ]),
    ]

    const csv = rows
      .map(row =>
        row
          .map(cell => `"${String(cell).replaceAll('"', '""')}"`)
          .join(',')
      )
      .join('\n')

    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.setAttribute('download', `notification-logs-page-${page}.csv`)
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    URL.revokeObjectURL(url)
  }

  const pages = Math.max(1, Math.ceil(total / LIMIT))
  const successRate = useMemo(() => {
    if (logs.length === 0) return 0
    const ok = logs.filter(x => x.success).length
    return Math.round((ok / logs.length) * 1000) / 10
  }, [logs])

  return (
    <Layout>
      <div className="max-w-7xl mx-auto space-y-10">
        <div className="flex items-end justify-between">
          <div>
            <h1 className="font-headline text-3xl font-extrabold tracking-tight text-primary">Notification Center</h1>
            <p className="text-on-surface-variant text-sm mt-1">Configure and broadcast system-wide or targeted communications.</p>
          </div>
          <div className="flex gap-2">
            <span className="bg-tertiary-fixed text-on-secondary-fixed-variant px-3 py-1 rounded text-[10px] font-bold tracking-widest uppercase">
              Live System
            </span>
          </div>
        </div>

        <div className="grid grid-cols-12 gap-6 items-start">
          <div className="col-span-12 lg:col-span-7 bg-surface-container-lowest p-8 rounded-lg shadow-[0_12px_32px_-4px_rgba(25,28,30,0.08)]">
            <div className="flex items-center justify-between mb-8">
              <div className="flex items-center gap-3">
                <div className="w-1.5 h-6 bg-primary rounded-full" />
                <h2 className="font-headline text-lg font-bold">Compose Message</h2>
              </div>
              <div className="flex bg-surface-container-low p-1 rounded-md">
                <button
                  onClick={() => setLanguage('en')}
                  className={`px-4 py-1.5 text-xs font-bold rounded-sm ${language === 'en' ? 'bg-surface-container-lowest shadow-sm text-primary' : 'text-on-surface-variant'}`}
                >
                  EN
                </button>
                <button
                  onClick={() => setLanguage('tr')}
                  className={`px-4 py-1.5 text-xs font-bold rounded-sm ${language === 'tr' ? 'bg-surface-container-lowest shadow-sm text-primary' : 'text-on-surface-variant'}`}
                >
                  TR
                </button>
              </div>
            </div>

            <form className="space-y-6" onSubmit={sendNotification}>
              <div className="grid grid-cols-2 gap-6">
                <div className="space-y-2 col-span-2 md:col-span-1">
                  <label className="text-[11px] font-bold text-on-surface-variant uppercase tracking-wider">Recipient Scope</label>
                  <select
                    value={form.audience}
                    onChange={e => setForm(p => ({ ...p, audience: e.target.value }))}
                    className="w-full bg-surface-container-low border-none rounded-md px-4 py-3 text-sm font-medium focus:ring-1 focus:ring-primary-container transition-all"
                  >
                    <option value="all_users">All Users</option>
                    <option value="specific_user">Specific User ID</option>
                    <option value="admin_staff">Administrative Staff</option>
                  </select>
                </div>
                <div className="space-y-2 col-span-2 md:col-span-1">
                  <label className="text-[11px] font-bold text-on-surface-variant uppercase tracking-wider">Target User ID (Optional)</label>
                  <input
                    value={form.recipientUserId}
                    onChange={e => setForm(p => ({ ...p, recipientUserId: e.target.value }))}
                    className="w-full bg-surface-container-low border-none rounded-md px-4 py-3 text-sm font-medium focus:ring-1 focus:ring-primary-container transition-all"
                    placeholder="e.g. 67f53e..."
                    disabled={form.audience !== 'specific_user'}
                  />
                </div>
              </div>

              <div className="space-y-2">
                  <label className="text-[11px] font-bold text-on-surface-variant uppercase tracking-wider">Message Subject</label>
                  <input
                  value={activeDraft.title}
                  onChange={e => setDrafts(p => ({
                    ...p,
                    [language]: {
                      ...p[language],
                      title: e.target.value,
                    },
                  }))}
                  className="w-full bg-surface-container-low border-none rounded-md px-4 py-3 text-sm font-medium focus:ring-1 focus:ring-primary-container transition-all"
                  placeholder={language === 'tr' ? 'Sistem duyurusu başlığı (TR)' : 'System maintenance update (EN)'}
                />
              </div>

              <div className="space-y-2">
                <label className="text-[11px] font-bold text-on-surface-variant uppercase tracking-wider">Message Body</label>
                <textarea
                  value={activeDraft.body}
                  onChange={e => setDrafts(p => ({
                    ...p,
                    [language]: {
                      ...p[language],
                      body: e.target.value,
                    },
                  }))}
                  className="w-full bg-surface-container-low border-none rounded-md px-4 py-3 text-sm font-medium focus:ring-1 focus:ring-primary-container transition-all resize-none"
                  placeholder={language === 'tr' ? 'Bildirim içeriğini yaz...' : 'Enter your detailed announcement...'}
                  rows={6}
                />
              </div>

              {error && <p className="text-sm text-red-600">{error}</p>}
              {success && <p className="text-sm text-green-600">{success}</p>}

              <div className="pt-4 flex items-center justify-between">
                <div className="flex items-center gap-2 text-on-surface-variant">
                  <span className="material-symbols-outlined text-sm">info</span>
                  <span className="text-xs">{total.toLocaleString()} total log entry tracked.</span>
                </div>
                <button
                  type="submit"
                  disabled={sending}
                  className="bg-gradient-to-r from-primary to-primary-container text-white px-8 py-3 rounded-md font-bold text-sm flex items-center gap-2 shadow-lg hover:shadow-primary-container/20 transition-all active:scale-95 disabled:opacity-60"
                >
                  <span className="material-symbols-outlined text-lg">send</span>
                  {sending ? 'Sending...' : 'Send Notification'}
                </button>
              </div>
            </form>
          </div>

          <div className="col-span-12 lg:col-span-5 space-y-6">
            <div className="bg-surface-container-low p-8 rounded-lg border border-outline-variant/15">
              <h3 className="font-headline text-sm font-bold uppercase tracking-widest text-on-surface-variant mb-6">Live Preview</h3>
              <div className="bg-white rounded-xl overflow-hidden shadow-md border border-slate-100">
                <div className="bg-primary-container p-4 flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className="material-symbols-outlined text-white text-lg">campaign</span>
                    <span className="text-white text-xs font-bold uppercase tracking-tighter">System Alert</span>
                  </div>
                  <span className="text-slate-400 text-[10px]">Just now</span>
                </div>
                <div className="p-5">
                  <p className="font-headline font-bold text-slate-900 mb-2">{activeDraft.title || 'Subject Placeholder'}</p>
                  <p className={`text-sm leading-relaxed ${activeDraft.body ? 'text-slate-600' : 'text-slate-500 italic'}`}>
                    {activeDraft.body || 'The message body you type in the editor will appear here in real-time.'}
                  </p>
                </div>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="bg-surface-container-lowest p-6 rounded-lg border border-outline-variant/10 shadow-sm">
                <p className="text-[10px] font-bold text-on-surface-variant uppercase mb-1">Success Rate</p>
                <p className="text-2xl font-headline font-extrabold text-primary">{successRate}%</p>
                <div className="mt-2 w-full bg-surface-container-high h-1 rounded-full overflow-hidden">
                  <div className="bg-tertiary-fixed h-full" style={{ width: `${Math.max(5, successRate)}%` }} />
                </div>
              </div>
              <div className="bg-surface-container-lowest p-6 rounded-lg border border-outline-variant/10 shadow-sm">
                <p className="text-[10px] font-bold text-on-surface-variant uppercase mb-1">Total Sent</p>
                <p className="text-2xl font-headline font-extrabold text-primary">{logs.filter(x => x.success).length}</p>
                <p className="text-[10px] text-on-tertiary-container font-semibold mt-1">Current page</p>
              </div>
            </div>
          </div>

          <div className="col-span-12 bg-surface-container-lowest rounded-lg shadow-sm border border-outline-variant/10 overflow-hidden">
            <div className="px-8 py-6 flex items-center justify-between bg-surface-container-low/50">
              <h2 className="font-headline text-lg font-bold">Transmission History</h2>
              <button onClick={exportCsv} className="text-xs font-bold flex items-center gap-1 text-primary hover:underline">
                <span className="material-symbols-outlined text-sm">download</span>
                Export Logs
              </button>
            </div>

            {loading ? (
              <div className="px-8 py-16 text-center text-on-surface-variant">Loading...</div>
            ) : logs.length === 0 ? (
              <div className="px-8 py-16 text-center text-on-surface-variant">No notification logs yet.</div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-left border-collapse">
                  <thead>
                    <tr className="bg-surface-container-high/30">
                      <th className="px-8 py-4 text-[11px] font-bold text-on-surface-variant uppercase tracking-widest">ID</th>
                      <th className="px-8 py-4 text-[11px] font-bold text-on-surface-variant uppercase tracking-widest">Subject</th>
                      <th className="px-8 py-4 text-[11px] font-bold text-on-surface-variant uppercase tracking-widest">Audience</th>
                      <th className="px-8 py-4 text-[11px] font-bold text-on-surface-variant uppercase tracking-widest">Date Sent</th>
                      <th className="px-8 py-4 text-[11px] font-bold text-on-surface-variant uppercase tracking-widest">Status</th>
                      <th className="px-8 py-4 text-[11px] font-bold text-on-surface-variant uppercase tracking-widest">Action</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-surface-container">
                    {logs.map(log => (
                      <tr key={log.id} className="hover:bg-surface-container-high transition-colors group">
                        <td className="px-8 py-5 text-sm font-mono text-on-surface-variant">#{log.id.slice(-6)}</td>
                        <td className="px-8 py-5">
                          <p className="text-sm font-bold text-primary">{log.title}</p>
                          <p className="text-xs text-on-surface-variant truncate max-w-[340px]">{log.body}</p>
                        </td>
                        <td className="px-8 py-5">
                          <span className="bg-secondary-container text-on-secondary-container text-[10px] px-2 py-1 rounded font-bold uppercase">
                            {log.recipientUserId ? `USER ${log.recipientUserId.slice(-6)}` : 'ALL_USERS'}
                          </span>
                        </td>
                        <td className="px-8 py-5 text-sm text-on-surface-variant">
                          {new Date(log.sentAt).toLocaleString()} ({timeAgo(log.sentAt)})
                        </td>
                        <td className="px-8 py-5">
                          {log.success ? (
                            <div className="flex items-center gap-2">
                              <div className="w-2 h-2 rounded-full bg-tertiary-fixed shadow-[0_0_8px_#6ffbbe]" />
                              <span className="text-xs font-bold text-green-700">Completed</span>
                            </div>
                          ) : (
                            <div className="flex items-center gap-2">
                              <div className="w-2 h-2 rounded-full bg-error animate-pulse" />
                              <span className="text-xs font-bold text-error">Failed</span>
                            </div>
                          )}
                        </td>
                        <td className="px-8 py-5">
                          <button className="opacity-0 group-hover:opacity-100 transition-opacity p-2 hover:bg-white rounded-lg">
                            <span className="material-symbols-outlined text-on-surface-variant">more_vert</span>
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}

            <div className="px-8 py-4 flex justify-between items-center bg-surface-container-low/20">
              <span className="text-xs text-on-surface-variant font-medium">
                Showing {(page - 1) * LIMIT + 1} to {Math.min(page * LIMIT, total)} of {total} records
              </span>
              <div className="flex gap-2">
                <button
                  onClick={() => setPage(p => Math.max(1, p - 1))}
                  disabled={page === 1}
                  className="w-8 h-8 flex items-center justify-center rounded-md border border-outline-variant/30 text-on-surface-variant hover:bg-white disabled:opacity-40"
                >
                  <span className="material-symbols-outlined text-sm">chevron_left</span>
                </button>
                <button
                  onClick={() => setPage(p => Math.min(pages, p + 1))}
                  disabled={page === pages}
                  className="w-8 h-8 flex items-center justify-center rounded-md border border-outline-variant/30 text-on-surface-variant hover:bg-white disabled:opacity-40"
                >
                  <span className="material-symbols-outlined text-sm">chevron_right</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layout>
  )
}
