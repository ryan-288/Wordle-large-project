// sendEmail.js
const dotenv = require('dotenv');
dotenv.config();

const sgMail = require('@sendgrid/mail');

if (!process.env.SENDGRID_API_KEY) {
  console.error('ERROR: SENDGRID_API_KEY not set. Run `source ./sendgrid.env` first or set the env var.');
  process.exit(1);
}
sgMail.setApiKey(process.env.SENDGRID_API_KEY);

// simple CLI: node sendEmail.js recipient@example.com "https://.../verify?token=abc"
async function main() {
  const argv = process.argv.slice(2);
  const to = argv[0];
  const verifyUrl = argv[1];

  if (!to || !verifyUrl) {
    console.error('Usage: node sendEmail.js recipient@example.com "https://your-site/verify?token=..."');
    process.exit(1);
  }

  const msg = {
    to,
    from: 'ranko830@gmail.com', // replace with your verified sender
    subject: 'Please verify your email',
    text: `Welcome! Click to verify: ${verifyUrl}`,
    html: `
      <p>Welcome!</p>
      <p>Click the button below to verify your email address:</p>
      <p><a href="${verifyUrl}" style="padding:10px 14px; background:#1a73e8; color:white; text-decoration:none; border-radius:4px;">Verify email</a></p>
      <p>If that doesn't work, paste this link into your browser:</p>
      <p>${verifyUrl}</p>
    `
  };

  try {
    const response = await sgMail.send(msg);
    console.log('Email queued/sent. SendGrid response status:', response[0].statusCode);
  } catch (err) {
    console.error('Send failed:', err.response ? err.response.body : err.message);
    process.exit(2);
  }
}

main();
