require('dotenv').config();

const http = require('http');
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const rateLimit = require('express-rate-limit');

const authRouter = require('./routes/auth');
const usersRouter = require('./routes/users');
const conversationsRouter = require('./routes/conversations');
const messagesRouter = require('./routes/messages');
const scheduledMessagesRouter = require('./routes/scheduledMessages');
const mediaRouter = require('./routes/media');
const callsRouter = require('./routes/calls');
const adminRouter = require('./routes/admin');
const notificationsRouter = require('./routes/notifications');
const searchRouter = require('./routes/search');
const { initSocket } = require('./socket');
const { ensureBucket } = require('./utils/minio');

const app = express();
const httpServer = http.createServer(app);

// Attach Socket.io to the same HTTP server
const io = initSocket(httpServer);
app.set('io', io);

// Ensure MinIO bucket exists on startup
ensureBucket().catch(err => console.warn('MinIO not reachable at startup:', err.message));

// Security headers
app.use(helmet());

// Allow cross-origin requests (Flutter web build, mobile, etc. don't share
// origin with this API the way the Vite-proxied React app does)
app.use(cors());

// Parse JSON bodies
app.use(express.json());

// Trust proxy (for correct IP behind reverse proxy / nginx)
app.set('trust proxy', 1);

// Rate limiting — 100 requests per 15 minutes per IP
app.use(rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 100,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Too many requests, please try again later.' },
}));

// Tighter rate limit on login — 10 attempts per 15 minutes per IP
app.use('/auth/login', rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 10,
    message: { error: 'Too many login attempts, please try again later.' },
}));

// Tighter rate limit on signup — 5 accounts per 15 minutes per IP
app.use('/auth/signup', rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 5,
    message: { error: 'Too many signup attempts, please try again later.' },
}));

// REST routes
app.use('/auth', authRouter);
app.use('/users', usersRouter);
app.use('/conversations', conversationsRouter);
app.use('/conversations/:id/messages', messagesRouter);
app.use('/conversations/:id/scheduled-messages', scheduledMessagesRouter);
app.use('/media', mediaRouter);
app.use('/calls', callsRouter);
app.use('/api/admin', adminRouter);
app.use('/notifications', notificationsRouter);
app.use('/search', searchRouter);

// Health check
app.get('/health', (req, res) => res.json({ status: 'ok' }));

// 404 handler
app.use((req, res) => res.status(404).json({ error: 'Not found' }));

// Global error handler
app.use((err, req, res, next) => {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
});

const PORT = process.env.PORT || 3000;
httpServer.listen(PORT, () => {
    console.log(`OpCom backend running on port ${PORT} (HTTP + WebSocket)`);
});
