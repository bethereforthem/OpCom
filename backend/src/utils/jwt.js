const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');

function signToken(payload) {
    const jti = uuidv4();
    const token = jwt.sign(
        { ...payload, jti },
        process.env.JWT_SECRET,
        { expiresIn: process.env.JWT_EXPIRES_IN || '8h' }
    );
    return { token, jti };
}

function verifyToken(token) {
    return jwt.verify(token, process.env.JWT_SECRET);
}

module.exports = { signToken, verifyToken };
