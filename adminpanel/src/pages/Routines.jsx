import { Fragment, useEffect, useState } from 'react'
import Layout from '../components/Layout'
import { apiFetch, timeAgo } from '../api'

const LIMIT = 20

export default function Routines() {
  const [routines, setRoutines] = useState([])
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const [loading, setLoading] = useState(false)
  const [expandedId, setExpandedId] = useState(null)
  const [commentsByRoutine, setCommentsByRoutine] = useState({})
  const [commentsLoadingId, setCommentsLoadingId] = useState(null)
  const [error, setError] = useState('')

  useEffect(() => {
    loadRoutines()
  }, [page, search])

  async function loadRoutines() {
    setLoading(true)
    setError('')
    try {
      const q = new URLSearchParams({
        page: String(page),
        limit: String(LIMIT),
        ...(search ? { search } : {}),
      })
      const res = await apiFetch(`/admin/routines?${q}`)
      const data = await res.json()
      if (!res.ok) throw new Error(data.message || 'Rutinler alınamadı.')
      setRoutines(data.data || [])
    } catch (err) {
      setRoutines([])
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  async function deleteRoutine(id) {
    if (!confirm('Bu rutini ve tüm yorumlarını silmek istediğine emin misin?')) return
    try {
      const res = await apiFetch(`/admin/routines/${id}`, { method: 'DELETE' })
      const data = await res.json()
      if (!res.ok) throw new Error(data.message || 'Rutin silinemedi.')
      setExpandedId(null)
      setCommentsByRoutine(prev => {
        const next = { ...prev }
        delete next[id]
        return next
      })
      await loadRoutines()
    } catch (err) {
      setError(err.message)
    }
  }

  async function toggleComments(routineId) {
    if (expandedId === routineId) {
      setExpandedId(null)
      return
    }

    setExpandedId(routineId)
    if (commentsByRoutine[routineId]) return

    setCommentsLoadingId(routineId)
    try {
      const res = await apiFetch(`/admin/routines/${routineId}/comments`)
      const data = await res.json()
      if (!res.ok) throw new Error(data.message || 'Yorumlar alınamadı.')
      setCommentsByRoutine(prev => ({ ...prev, [routineId]: data.data || [] }))
    } catch (err) {
      setCommentsByRoutine(prev => ({ ...prev, [routineId]: [] }))
      setError(err.message)
    } finally {
      setCommentsLoadingId(null)
    }
  }

  async function deleteComment(routineId, commentId) {
    if (!confirm('Bu yorumu silmek istiyor musun?')) return

    try {
      const res = await apiFetch(`/admin/routines/${routineId}/comments/${commentId}`, { method: 'DELETE' })
      const data = await res.json()
      if (!res.ok) throw new Error(data.message || 'Yorum silinemedi.')

      setCommentsByRoutine(prev => ({
        ...prev,
        [routineId]: (prev[routineId] || []).filter(c => c.id !== commentId),
      }))

      setRoutines(prev =>
        prev.map(r =>
          r.id === routineId
            ? { ...r, commentCount: Math.max(0, (r.commentCount || 0) - 1) }
            : r
        )
      )
    } catch (err) {
      setError(err.message)
    }
  }

  return (
    <Layout>
      <div className="mb-8">
        <h2 className="text-3xl font-extrabold font-headline text-primary mb-2">Routines</h2>
        <p className="text-on-surface-variant">Manage all user-created routines and their comments.</p>
      </div>

      {error && (
        <div className="mb-4 px-4 py-3 rounded-lg bg-red-100 text-red-700 text-sm">{error}</div>
      )}

      <div className="bg-surface-container-lowest rounded-lg border border-outline-variant/15 overflow-hidden">
        <div className="p-5 border-b border-outline-variant/15">
          <div className="relative max-w-sm">
            <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-lg">search</span>
            <input
              value={search}
              onChange={e => {
                setSearch(e.target.value)
                setPage(1)
              }}
              className="w-full pl-10 pr-4 py-2 rounded-lg bg-surface-container-low border-none text-sm focus:outline-none focus:ring-2 focus:ring-slate-200"
              placeholder="Search by title or username..."
            />
          </div>
        </div>

        {loading ? (
          <div className="text-center py-16 text-on-surface-variant">Loading...</div>
        ) : routines.length === 0 ? (
          <div className="text-center py-16 text-on-surface-variant">No routines found.</div>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-surface-container-low">
              <tr>
                {['Routine', 'Author', 'Likes', 'Comments', 'Created', 'Actions'].map(h => (
                  <th key={h} className="text-left px-5 py-3 text-xs font-bold uppercase tracking-widest text-on-surface-variant">
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-outline-variant/10">
              {routines.map(r => {
                const isExpanded = expandedId === r.id
                const comments = commentsByRoutine[r.id] || []
                const isCommentLoading = commentsLoadingId === r.id

                return (
                  <Fragment key={r.id}>
                    <tr className="hover:bg-surface-container-low/50 transition-colors">
                      <td className="px-5 py-4 max-w-[260px]">
                        <p className="font-semibold truncate">{r.title}</p>
                        {r.description && <p className="text-xs text-on-surface-variant truncate">{r.description}</p>}
                      </td>
                      <td className="px-5 py-4 text-sm text-on-surface-variant">{r.userName}</td>
                      <td className="px-5 py-4">
                        <span className="flex items-center gap-1 text-xs">
                          <span className="material-symbols-outlined text-sm text-pink-400">favorite</span>
                          {r.likeCount}
                        </span>
                      </td>
                      <td className="px-5 py-4">
                        <button
                          onClick={() => toggleComments(r.id)}
                          className="flex items-center gap-1 text-xs font-semibold text-blue-700 hover:underline"
                        >
                          <span className="material-symbols-outlined text-sm text-blue-400">comment</span>
                          {r.commentCount} {isExpanded ? 'Hide' : 'View'}
                        </button>
                      </td>
                      <td className="px-5 py-4 text-xs text-on-surface-variant">{new Date(r.createdAt).toLocaleDateString()}</td>
                      <td className="px-5 py-4 flex items-center gap-2">
                        <button
                          onClick={() => toggleComments(r.id)}
                          className="px-3 py-1.5 rounded-lg text-xs font-semibold bg-blue-50 text-blue-700 hover:bg-blue-100 transition-all"
                        >
                          Comments
                        </button>
                        <button
                          onClick={() => deleteRoutine(r.id)}
                          className="px-3 py-1.5 rounded-lg text-xs font-semibold bg-red-50 text-red-600 hover:bg-red-100 transition-all"
                        >
                          Delete
                        </button>
                      </td>
                    </tr>

                    {isExpanded && (
                      <tr className="bg-surface-container-low/40">
                        <td colSpan={6} className="px-6 py-4">
                          {isCommentLoading ? (
                            <p className="text-sm text-on-surface-variant">Comments loading...</p>
                          ) : comments.length === 0 ? (
                            <p className="text-sm text-on-surface-variant">No comments for this routine.</p>
                          ) : (
                            <div className="space-y-3">
                              {comments.map(comment => (
                                <div key={comment.id} className="bg-white rounded-lg border border-outline-variant/15 p-3 flex items-start gap-3">
                                  <div className="w-8 h-8 rounded-full bg-slate-200 flex items-center justify-center text-xs font-bold text-slate-700 flex-shrink-0 overflow-hidden">
                                    {comment.userProfileImageUrl ? (
                                      <img src={comment.userProfileImageUrl} alt="" className="w-full h-full object-cover" />
                                    ) : (
                                      (comment.userName || '?').charAt(0).toUpperCase()
                                    )}
                                  </div>
                                  <div className="flex-1 min-w-0">
                                    <div className="flex items-center justify-between gap-2">
                                      <p className="text-sm font-semibold truncate">{comment.userName}</p>
                                      <p className="text-xs text-on-surface-variant flex-shrink-0">{timeAgo(comment.createdAt)}</p>
                                    </div>
                                    <p className="text-sm text-on-surface mt-1 whitespace-pre-wrap break-words">{comment.text}</p>
                                  </div>
                                  <button
                                    onClick={() => deleteComment(r.id, comment.id)}
                                    className="px-2.5 py-1.5 rounded-md text-xs font-semibold bg-red-50 text-red-600 hover:bg-red-100 transition-colors flex-shrink-0"
                                  >
                                    Delete
                                  </button>
                                </div>
                              ))}
                            </div>
                          )}
                        </td>
                      </tr>
                    )}
                  </Fragment>
                )
              })}
            </tbody>
          </table>
        )}
      </div>
    </Layout>
  )
}
