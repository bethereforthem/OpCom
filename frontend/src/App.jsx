import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { SocketProvider } from './contexts/SocketContext';
import LoginPage from './pages/LoginPage';
import SignupPage from './pages/SignupPage';
import MfaPage from './pages/MfaPage';
import ChatPage from './pages/ChatPage';
import SettingsPage from './pages/SettingsPage';
import AdminLayout from './components/admin/AdminLayout';
import AdminDashboard from './pages/admin/AdminDashboard';
import AdminUsers from './pages/admin/AdminUsers';
import AdminDevices from './pages/admin/AdminDevices';
import AdminAlerts from './pages/admin/AdminAlerts';
import AdminAuditLogs from './pages/admin/AdminAuditLogs';

function Spinner() {
    return (
        <div className="min-h-screen flex items-center justify-center bg-gray-900">
            <div className="w-8 h-8 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin" />
        </div>
    );
}

function ProtectedRoute({ children }) {
    const { user, loading } = useAuth();
    if (loading) return <Spinner />;
    return user ? children : <Navigate to="/login" replace />;
}

function AdminRoute({ children }) {
    const { user, loading } = useAuth();
    if (loading) return <Spinner />;
    if (!user) return <Navigate to="/login" replace />;
    if (user.roles?.name !== 'admin') return <Navigate to="/" replace />;
    return children;
}

function PublicRoute({ children }) {
    const { user, loading } = useAuth();
    if (loading) return null;
    return user ? <Navigate to="/" replace /> : children;
}

export default function App() {
    return (
        <AuthProvider>
            <BrowserRouter>
                <Routes>
                    {/* Public */}
                    <Route path="/login"  element={<PublicRoute><LoginPage /></PublicRoute>} />
                    <Route path="/signup" element={<PublicRoute><SignupPage /></PublicRoute>} />
                    <Route path="/mfa"    element={<PublicRoute><MfaPage /></PublicRoute>} />

                    {/* Chat */}
                    <Route path="/" element={
                        <ProtectedRoute>
                            <SocketProvider><ChatPage /></SocketProvider>
                        </ProtectedRoute>
                    } />

                    <Route path="/settings" element={
                        <ProtectedRoute><SettingsPage /></ProtectedRoute>
                    } />

                    {/* Admin */}
                    <Route path="/admin" element={
                        <AdminRoute>
                            <AdminLayout><AdminDashboard /></AdminLayout>
                        </AdminRoute>
                    } />
                    <Route path="/admin/users" element={
                        <AdminRoute>
                            <AdminLayout><AdminUsers /></AdminLayout>
                        </AdminRoute>
                    } />
                    <Route path="/admin/devices" element={
                        <AdminRoute>
                            <AdminLayout><AdminDevices /></AdminLayout>
                        </AdminRoute>
                    } />
                    <Route path="/admin/alerts" element={
                        <AdminRoute>
                            <AdminLayout><AdminAlerts /></AdminLayout>
                        </AdminRoute>
                    } />
                    <Route path="/admin/audit" element={
                        <AdminRoute>
                            <AdminLayout><AdminAuditLogs /></AdminLayout>
                        </AdminRoute>
                    } />

                    <Route path="*" element={<Navigate to="/" replace />} />
                </Routes>
            </BrowserRouter>
        </AuthProvider>
    );
}
