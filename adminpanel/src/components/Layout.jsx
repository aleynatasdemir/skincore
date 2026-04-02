import { NavLink, useNavigate } from 'react-router-dom'
import { clearAuth, getUser } from '../api'

const navItems = [
  { to: '/',              label: 'Dashboard',     icon: 'dashboard' },
  { to: '/users',         label: 'Users',         icon: 'group' },
  { to: '/products',      label: 'Products',      icon: 'inventory_2' },
  { to: '/notifications', label: 'Notifications', icon: 'notifications' },
  { to: '/routines',      label: 'Routines',      icon: 'settings_backup_restore' },
]

export default function Layout({ children }) {
  const navigate = useNavigate()
  const user = getUser()

  function logout() {
    clearAuth()
    navigate('/login')
  }

  return (
    <div className="bg-surface font-body text-on-surface min-h-screen">
      {/* Sidebar */}
      <aside className="h-screen w-64 fixed left-0 top-0 bg-slate-900 flex flex-col py-6 px-4 shadow-xl z-50"
        style={{ boxShadow: 'inset -1px 0 0 0 rgba(255,255,255,0.05)' }}>
        <div className="mb-10 px-2 flex items-center gap-3">
          <div className="w-8 h-8 bg-gradient-to-br from-white to-slate-400 rounded-sm flex-shrink-0" />
          <h1 className="text-base font-bold tracking-wider text-white uppercase font-headline">SkinCore Admin</h1>
        </div>

        <nav className="flex-1 space-y-1">
          {navItems.map(item => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.to === '/'}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 py-2.5 rounded-md transition-colors duration-200 ${
                  isActive
                    ? 'bg-slate-800 text-white font-semibold'
                    : 'text-slate-400 hover:text-white hover:bg-slate-800/50'
                }`
              }
            >
              <span className="material-symbols-outlined text-xl">{item.icon}</span>
              <span className="font-headline text-sm tracking-tight">{item.label}</span>
            </NavLink>
          ))}
        </nav>

        <div className="mt-auto pt-6 border-t border-slate-800">
          <div className="flex items-center gap-3 px-2">
            <div className="w-9 h-9 rounded-full bg-slate-700 flex items-center justify-center text-white font-bold text-sm flex-shrink-0">
              {(user?.fullName || user?.email || 'A').charAt(0).toUpperCase()}
            </div>
            <div className="overflow-hidden flex-1">
              <p className="text-white text-sm font-semibold truncate">{user?.fullName || 'Admin'}</p>
              <p className="text-slate-500 text-xs truncate">{user?.email || ''}</p>
            </div>
            <button onClick={logout} className="text-slate-500 hover:text-red-400 transition-colors" title="Logout">
              <span className="material-symbols-outlined text-lg">logout</span>
            </button>
          </div>
        </div>
      </aside>

      {/* Main */}
      <main className="pl-64 min-h-screen flex flex-col">
        <header className="fixed top-0 right-0 left-64 h-16 z-30 bg-white/80 backdrop-blur-md border-b border-slate-100 flex justify-between items-center px-8">
          <div className="flex items-center gap-4 flex-1">
            <div className="relative w-full max-w-md">
              <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-lg">search</span>
              <input className="w-full bg-surface-container-low border-none rounded-lg py-2 pl-10 pr-4 text-sm focus:ring-2 focus:ring-slate-200 transition-all outline-none" placeholder="Search..." type="text"/>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <span className="text-sm font-semibold text-slate-900 font-headline">{user?.fullName || 'Administrator'}</span>
            <div className="w-8 h-8 rounded-full bg-slate-900 flex items-center justify-center text-white font-bold text-xs">
              {(user?.fullName || user?.email || 'A').charAt(0).toUpperCase()}
            </div>
          </div>
        </header>

        <div className="mt-16 p-10 flex-1 bg-surface">
          {children}
        </div>
      </main>
    </div>
  )
}
