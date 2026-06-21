const Minio = require('minio');

const client = new Minio.Client({
    endPoint:  process.env.MINIO_ENDPOINT  || 'localhost',
    port:      parseInt(process.env.MINIO_PORT, 10) || 9000,
    useSSL:    process.env.MINIO_USE_SSL === 'true',
    accessKey: process.env.MINIO_ACCESS_KEY,
    secretKey: process.env.MINIO_SECRET_KEY,
});

const BUCKET = process.env.MINIO_BUCKET || 'opcom-media';

// Called once at server startup — creates the bucket if it doesn't exist
async function ensureBucket() {
    const exists = await client.bucketExists(BUCKET);
    if (!exists) {
        await client.makeBucket(BUCKET, process.env.MINIO_REGION || 'us-east-1');
        console.log(`MinIO: bucket "${BUCKET}" created`);
    } else {
        console.log(`MinIO: bucket "${BUCKET}" ready`);
    }
}

// Upload a Buffer to MinIO, returns the object key
async function uploadFile({ buffer, objectKey, mimeType, size }) {
    await client.putObject(BUCKET, objectKey, buffer, size, {
        'Content-Type': mimeType,
    });
    return objectKey;
}

// Generate a time-limited presigned download URL (default 1 hour)
async function presignedUrl(objectKey, expirySeconds = 3600) {
    return client.presignedGetObject(BUCKET, objectKey, expirySeconds);
}

// Permanently delete a file from MinIO
async function deleteFile(objectKey) {
    await client.removeObject(BUCKET, objectKey);
}

module.exports = { client, BUCKET, ensureBucket, uploadFile, presignedUrl, deleteFile };
