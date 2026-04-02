import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { getToken, setToken, setUser } from '../api'

export default function Login() {
  const navigate = useNavigate()
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (getToken()) navigate('/')
  }, [])

  async function handleSubmit(e) {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: username, password }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.message || 'Login failed')
      if (!data.user?.isAdmin) throw new Error('Bu hesabın admin yetkisi yok.')
      setToken(data.accessToken)
      setUser(data.user)
      navigate('/')
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-slate-950 font-body flex items-center justify-center">
      <div className="w-full max-w-sm mx-auto px-6">
        <div className="text-center mb-10">
          <div className="w-12 h-12 bg-gradient-to-br from-white to-slate-400 rounded-lg mx-auto mb-4" />
          <h1 className="text-2xl font-extrabold text-white font-headline tracking-tight">SkinCore Admin</h1>
          <p className="text-slate-500 text-sm mt-1">Sign in to your admin console</p>
        </div>

        {error && (
          <div className="mb-4 px-4 py-3 rounded-lg bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-xs font-semibold text-slate-400 mb-1.5 uppercase tracking-widest">Username or Email</label>
            <input
              type="text" required value={username} onChange={e => setUsername(e.target.value)}
              placeholder="admin"
              className="w-full bg-slate-900 border border-slate-700 rounded-lg px-4 py-3 text-white text-sm placeholder-slate-600 focus:outline-none focus:ring-2 focus:ring-white/20 transition-all"
            />
          </div>
          <div>
            <label className="block text-xs font-semibold text-slate-400 mb-1.5 uppercase tracking-widest">Password</label>
            <input
              type="password" required value={password} onChange={e => setPassword(e.target.value)}
              placeholder="••••••••"
              className="w-full bg-slate-900 border border-slate-700 rounded-lg px-4 py-3 text-white text-sm placeholder-slate-600 focus:outline-none focus:ring-2 focus:ring-white/20 transition-all"
            />
          </div>
          <button
            type="submit" disabled={loading}
            className="w-full bg-white text-slate-900 font-bold rounded-lg py-3 text-sm font-headline hover:bg-slate-100 active:scale-95 transition-all mt-2 flex items-center justify-center gap-2 disabled:opacity-60"
          >
            {loading ? (
              <>
                <span className="material-symbols-outlined text-base animate-spin">progress_activity</span>
                Signing in...
              </>
            ) : 'Sign In'}
          </button>
        </form>
      </div>
    </div>
  )
}
