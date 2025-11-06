const bcrypt = require('bcrypt');

async function generateVerificationCode() {
  // 6-digit code: 100000–999999
  const code = (Math.floor(100000 + Math.random() * 900000)).toString();

  const codeHash = await bcrypt.hash(code, 10);
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

  return { code, codeHash, expiresAt };
}


module.exports = { generateVerificationCode };