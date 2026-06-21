const { io } = require('socket.io-client');
const TOKEN = process.argv[2];
const CONV_ID = process.argv[3];
const REPLY_TO_ID = process.argv[4];

const sock = io('http://localhost:3000', { auth: { token: TOKEN }, transports: ['websocket'] });
sock.on('connect_error', e => console.log('connect_error', e.message));

setTimeout(() => {
    sock.timeout(5000).emit('send_message', {
        conversation_id: CONV_ID, type: 'text', content: 'Reply attempt 2', reply_to_id: REPLY_TO_ID,
    }, (err, ack) => {
        console.log('err:', err);
        console.log('ack:', JSON.stringify(ack, null, 2));

        // Now test edit on the resulting message
        if (ack?.ok) {
            sock.timeout(5000).emit('edit_message', { message_id: ack.message.id, content: 'Reply attempt 2 EDITED' }, (err2, ack2) => {
                console.log('edit err:', err2);
                console.log('edit ack:', JSON.stringify(ack2, null, 2));
                process.exit(0);
            });
        } else {
            process.exit(0);
        }
    });
}, 1500);
