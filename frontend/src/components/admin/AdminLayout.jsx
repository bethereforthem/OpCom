import { NavLink, useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../../contexts/AuthContext';

export default function AdminLayout({ children }) {
    const { t }             = useTranslation();
    const { user, logout } = useAuth();
    const navigate         = useNavigate();

    const NAV = [
        { to: '/admin',         label: t('admin.layout.nav.dashboard'), exact: true,
          icon: 'M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6' },
        { to: '/admin/users',   label: t('admin.layout.nav.users'),
          icon: 'M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z' },
        { to: '/admin/devices', label: t('admin.layout.nav.devices'),
          icon: 'M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z' },
        { to: '/admin/alerts',  label: t('admin.layout.nav.alerts'),
          icon: 'M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z' },
        { to: '/admin/audit',   label: t('admin.layout.nav.auditLogs'),
          icon: 'M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2' },
    ];

    return (
        <div className="h-full flex flex-col">
            {/* Top bar */}
            <header className="flex items-center justify-between px-6 py-3 bg-gray-800 border-b border-gray-700 flex-shrink-0">
                <div className="flex items-center gap-3">
                    <div className="w-7 h-7 rounded-lg bg-red-600 flex items-center justify-center">
                        <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                        </svg>
                    </div>
                    <span className="font-bold text-white">{t('admin.layout.title')}</span>
                </div>
                <div className="flex items-center gap-4">
                    <button onClick={() => navigate('/')}
                        className="text-sm text-gray-400 hover:text-white transition-colors">
                        {t('admin.layout.backToChat')}
                    </button>
                    <span className="text-sm text-gray-300">{user?.username}</span>
                    <button onClick={logout} className="text-sm text-gray-500 hover:text-red-400 transition-colors">
                        {t('common.signOut')}
                    </button>
                </div>
            </header>

            <div className="flex flex-1 min-h-0">
                {/* Sidebar */}
                <nav className="w-56 bg-gray-800 border-r border-gray-700 flex-shrink-0 py-4">
                    {NAV.map(item => (
                        <NavLink key={item.to} to={item.to} end={item.exact}
                            className={({ isActive }) =>
                                `flex items-center gap-3 px-4 py-2.5 text-sm transition-colors
                                 ${isActive ? 'bg-gray-700 text-white font-medium' : 'text-gray-400 hover:text-white hover:bg-gray-700/50'}`
                            }>
                            <svg className="w-4 h-4 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d={item.icon} />
                            </svg>
                            {item.label}
                        </NavLink>
                    ))}
                </nav>

                {/* Content */}
                <main className="flex-1 overflow-y-auto bg-gray-900 p-6">
                    {children}
                </main>
            </div>
        </div>
    );
}
