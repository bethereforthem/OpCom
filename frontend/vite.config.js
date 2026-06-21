import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
    plugins: [react(), tailwindcss()],
    server: {
        port: 5173,
        proxy: {
            '/auth':          { target: 'http://localhost:3000', changeOrigin: true },
            '/users':         { target: 'http://localhost:3000', changeOrigin: true },
            '/conversations': { target: 'http://localhost:3000', changeOrigin: true },
            '/media':         { target: 'http://localhost:3000', changeOrigin: true },
            '/calls':         { target: 'http://localhost:3000', changeOrigin: true },
            '/notifications': { target: 'http://localhost:3000', changeOrigin: true },
            '/search':        { target: 'http://localhost:3000', changeOrigin: true },
            '/api':           { target: 'http://localhost:3000', changeOrigin: true },
            '/socket.io':     { target: 'http://localhost:3000', changeOrigin: true, ws: true },
        },
    },
});
