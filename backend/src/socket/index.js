const { Server } = require('socket.io');
const { verifyToken } = require('../utils/jwt');
const supabase = require('../utils/supabase');
const messageHandler = require('./handlers/message');
const presenceHandler = require('./handlers/presence');
const callingHandler = require('./handlers/calling');
const { startPoller } = require('../jobs/poller');

// In-memory map of userId → Set of socketIds (supports multi-device)
const onlineUsers = new Map();

function initSocket(httpServer) {
    const io = new Server(httpServer, {
        cors: { origin: '*', methods: ['GET', 'POST'] },
        pingTimeout: 30000,
        pingInterval: 10000,
    });

    // ── Authentication middleware ──────────────────────────────
    io.use(async (socket, next) => {
        const token = socket.handshake.auth?.token;
        if (!token) return next(new Error('Missing token'));

        let payload;
        try {
            payload = verifyToken(token);
        } catch {
            return next(new Error('Invalid token'));
        }

        // Verify session is still active
        const { data: session } = await supabase
            .from('sessions')
            .select('id')
            .eq('jwt_jti', payload.jti)
            .gt('expires_at', new Date().toISOString())
            .single();

        if (!session) return next(new Error('Session expired'));

        // Attach user to socket
        const { data: user } = await supabase
            .from('users')
            .select('id, full_name, username, avatar_url, role_id')
            .eq('id', payload.sub)
            .eq('is_active', true)
            .eq('is_locked', false)
            .single();

        if (!user) return next(new Error('User not found'));

        socket.userId = user.id;
        socket.user = user;
        next();
    });

    // ── Connection ─────────────────────────────────────────────
    io.on('connection', async (socket) => {
        const { userId } = socket;

        // Track online presence
        if (!onlineUsers.has(userId)) onlineUsers.set(userId, new Set());
        onlineUsers.get(userId).add(socket.id);

        // Auto-join all conversation rooms this user belongs to
        const { data: memberships } = await supabase
            .from('conversation_members')
            .select('conversation_id')
            .eq('user_id', userId)
            .is('left_at', null);

        const rooms = memberships?.map(m => `conv:${m.conversation_id}`) ?? [];
        socket.join(rooms);

        // Notify contacts this user is now online
        presenceHandler.broadcastOnline(io, socket, onlineUsers);

        // Register event handlers
        messageHandler(io, socket, onlineUsers);
        callingHandler(io, socket, onlineUsers);

        // ── Disconnect ─────────────────────────────────────────
        socket.on('disconnect', () => {
            const sockets = onlineUsers.get(userId);
            if (sockets) {
                sockets.delete(socket.id);
                if (sockets.size === 0) {
                    onlineUsers.delete(userId);
                    presenceHandler.broadcastOffline(io, socket);
                }
            }
        });
    });

    startPoller(io, onlineUsers);

    return io;
}

module.exports = { initSocket, onlineUsers };
