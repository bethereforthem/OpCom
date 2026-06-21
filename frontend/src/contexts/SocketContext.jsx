import { createContext, useContext, useEffect, useRef, useState } from 'react';
import { io } from 'socket.io-client';
import { useAuth } from './AuthContext';

const SocketContext = createContext(null);

export function SocketProvider({ children }) {
    const { token } = useAuth();
    const socketRef = useRef(null);
    const [connected, setConnected] = useState(false);

    // Message listeners registered by ChatPage
    const listenersRef = useRef({});

    useEffect(() => {
        if (!token) {
            socketRef.current?.disconnect();
            socketRef.current = null;
            setConnected(false);
            return;
        }

        const socket = io('/', {
            auth: { token },
            transports: ['websocket', 'polling'],
        });

        socket.on('connect',    () => setConnected(true));
        socket.on('disconnect', () => setConnected(false));

        // Forward events to registered listeners
        const events = [
            'new_message', 'message_delivered', 'message_read_receipt',
            'message_deleted', 'message_edited', 'message_reaction_updated',
            'mention_received', 'disappearing_settings_updated',
            'user_typing', 'user_stopped_typing',
            'presence_update', 'contacts_online',
            'incoming_call', 'call_offer_received', 'call_answered',
            'ice_candidate', 'call_rejected', 'call_ended', 'call_missed', 'call_busy',
        ];

        events.forEach(evt => {
            socket.on(evt, data => {
                listenersRef.current[evt]?.forEach(fn => fn(data));
            });
        });

        socketRef.current = socket;

        return () => {
            socket.disconnect();
            socketRef.current = null;
        };
    }, [token]);

    function on(event, fn) {
        if (!listenersRef.current[event]) listenersRef.current[event] = new Set();
        listenersRef.current[event].add(fn);
        return () => listenersRef.current[event]?.delete(fn);
    }

    function emit(event, data, ack) {
        return socketRef.current?.emit(event, data, ack);
    }

    return (
        <SocketContext.Provider value={{ connected, on, emit, socket: socketRef }}>
            {children}
        </SocketContext.Provider>
    );
}

export const useSocket = () => useContext(SocketContext);
