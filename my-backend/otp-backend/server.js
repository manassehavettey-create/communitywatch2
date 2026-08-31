const express = require('express');
const { Resend } = require('resend');

const app = express();
app.use(express.json());

// Replace with your actual Resend API Key from https://resend.com
const resend = new Resend('YOUR_RESEND_API_KEY');
const otpStore = new Map();

// 1. Send OTP Endpoint
app.post('/api/send-otp', async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ message: 'Email required' });

  const code = Math.floor(100000 + Math.random() * 900000).toString();
  otpStore.set(email, { code, expiresAt: Date.now() + 5 * 60 * 1000 });

  try {
    await resend.emails.send({
      from: 'Auth <onboarding@resend.dev>',
      to: email,
      subject: 'Your Verification Code',
      html: '<p>Your code is: <strong>' + code + '</strong>. It expires in 5 minutes.</p>'
    });
    res.json({ message: 'OTP sent successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 2. Verify OTP Endpoint
app.post('/api/verify-otp', (req, res) => {
  const { email, code } = req.body;
  const record = otpStore.get(email);

  if (!record) return res.status(400).json({ message: 'No OTP requested' });
  if (Date.now() > record.expiresAt) return res.status(400).json({ message: 'Code expired' });
  if (record.code !== code) return res.status(400).json({ message: 'Invalid code' });

  otpStore.delete(email);
  res.json({ message: 'Verification successful', status: 'SUCCESS' });
});

app.listen(3000, () => console.log('Server running on port 3000'));