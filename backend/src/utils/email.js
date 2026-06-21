const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT, 10),
    secure: false,
    auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
    },
});

// Kept in one place per language so a native-speaker review pass (especially
// for `rw`) can audit/replace this text without touching any other code.
const EMAIL_TEMPLATES = {
    en: (fullName, otpCode, minutes) => ({
        subject: 'OpCom — Your verification code',
        text: `Hello ${fullName},\n\nYour one-time verification code is: ${otpCode}\n\nThis code expires in ${minutes} minutes.\n\nDo not share this code with anyone.`,
        html: `
            <p>Hello <strong>${fullName}</strong>,</p>
            <p>Your OpCom verification code is:</p>
            <h1 style="letter-spacing:8px;font-family:monospace;">${otpCode}</h1>
            <p>This code expires in <strong>${minutes} minutes</strong>.</p>
            <p style="color:#888;">Do not share this code with anyone.</p>
        `,
    }),
    fr: (fullName, otpCode, minutes) => ({
        subject: 'OpCom — Votre code de vérification',
        text: `Bonjour ${fullName},\n\nVotre code de vérification à usage unique est : ${otpCode}\n\nCe code expire dans ${minutes} minutes.\n\nNe partagez ce code avec personne.`,
        html: `
            <p>Bonjour <strong>${fullName}</strong>,</p>
            <p>Votre code de vérification OpCom est :</p>
            <h1 style="letter-spacing:8px;font-family:monospace;">${otpCode}</h1>
            <p>Ce code expire dans <strong>${minutes} minutes</strong>.</p>
            <p style="color:#888;">Ne partagez ce code avec personne.</p>
        `,
    }),
    rw: (fullName, otpCode, minutes) => ({
        subject: 'OpCom — Kode yawe yo kwemeza',
        text: `Muraho ${fullName},\n\nKode yawe yo kwemeza ni: ${otpCode}\n\nKode iyi izarangira mu minota ${minutes}.\n\nNtukabwire uyu kode undi muntu.`,
        html: `
            <p>Muraho <strong>${fullName}</strong>,</p>
            <p>Kode yawe yo kwemeza kuri OpCom ni:</p>
            <h1 style="letter-spacing:8px;font-family:monospace;">${otpCode}</h1>
            <p>Iyi kode izarangira mu <strong>minota ${minutes}</strong>.</p>
            <p style="color:#888;">Ntukabwire uyu kode undi muntu.</p>
        `,
    }),
};

async function sendOtpEmail(toEmail, otpCode, fullName, locale = 'en') {
    const minutes = process.env.OTP_EXPIRES_MINUTES || 10;
    const build = EMAIL_TEMPLATES[locale] ?? EMAIL_TEMPLATES.en;
    const { subject, text, html } = build(fullName, otpCode, minutes);

    await transporter.sendMail({
        from: process.env.EMAIL_FROM,
        to: toEmail,
        subject, text, html,
    });
}

module.exports = { sendOtpEmail };
