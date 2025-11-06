const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(process.env.SENDGRID_API_KEY); // we will need to sign up for this service // hopefully its free :p

async function sendVerificationEmail(toEmail, code) {
  const msg = {
    to: toEmail,
    from: 'ranko830@gmail.com',
    subject: 'Verify your Wordplay account!',
    text: `Your verification code is ${code}. It expires in 10 minutes.`,
    html: `
      <p>Thanks for trying our small app!</p>
      <p>Use this 6-digit code to verify your account -> <strong>${code}</strong>.</p>
      <p>This code will expire in 10 minutes.</p>
    `
  };

  await sgMail.send(msg);
}

module.exports = { sendVerificationEmail };