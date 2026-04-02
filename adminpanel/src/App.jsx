import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { useEffect, useState } from 'react'
import { apiFetch, clearAuth, getToken, setUser } from './api'
import Login from './pages/Login'
import Dashboard from './pages/Dashboard'
import Users from './pages/Users'
import Products from './pages/Products'
import Notifications from './pages/Notifications'
import Routines from './pages/Routines'

function FullPageLoader() {
  return (
    <div className="min-h-screen bg-surface flex items-center justify-center">
      <div className="flex items-center gap-2 text-on-surface-variant text-sm">
        <span className="material-symbols-outlined animate-spin text-base">progress_activity</span>
        Session checking...
      </div>
    </div>
  )
}

function PrivateRoute({ children, authStatus }) {
  if (authStatus === 'checking') return <FullPageLoader />
  return authStatus === 'authenticated' ? children : <Navigate to="/login" replace />
}

export default function App() {
  const [authStatus, setAuthStatus] = useState('checking')

  useEffect(() => {
    async function validateSession() {
      const token = getToken()
      if (!token) {
        setAuthStatus('unauthenticated')
        return
      }

      try {
        const res = await apiFetch('/admin-auth/me')
        if (!res.ok) throw new Error('Session invalid')
        const user = await res.json()
        setUser(user)
        setAuthStatus('authenticated')
      } catch {
        clearAuth()
        setAuthStatus('unauthenticated')
      }
    }

    validateSession()
  }, [])

  return (
    <BrowserRouter>
      <Routes>
        <Route
          path="/login"
          element={
            authStatus === 'checking'
              ? <FullPageLoader />
              : authStatus === 'authenticated'
                ? <Navigate to="/" replace />
                : <Login />
          }
        />
        <Route path="/" element={<PrivateRoute authStatus={authStatus}><Dashboard /></PrivateRoute>} />
        <Route path="/users" element={<PrivateRoute authStatus={authStatus}><Users /></PrivateRoute>} />
        <Route path="/products" element={<PrivateRoute authStatus={authStatus}><Products /></PrivateRoute>} />
        <Route path="/notifications" element={<PrivateRoute authStatus={authStatus}><Notifications /></PrivateRoute>} />
        <Route path="/routines" element={<PrivateRoute authStatus={authStatus}><Routines /></PrivateRoute>} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}
