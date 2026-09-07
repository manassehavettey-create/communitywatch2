require('dotenv').config();
const express = require('express');
const cors = require('cors');
const nodemailer = require('nodemailer');
const db = require('./database');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const app = express();
app.use(express.json());
app.use(cors());

// --- TACTICAL LOGGING ---
app.use((req, res, next) => {
  console.log(`📡 [SIGNAL] ${req.method} ${req.url} from ${req.ip}`);
  next();
});

const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir);
app.use('/uploads', express.static(uploadsDir));

const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'TACTICAL_CW_V10_SECRET';
const MASTER_ADMIN_ID = process.env.MASTER_ADMIN_ID || 'ADMIN';
const MASTER_ADMIN_KEY = process.env.MASTER_ADMIN_KEY || 'Admin@123';
const SALT_ROUNDS = 12;

// --- MULTER CONFIG ---
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, 'uploads/'),
  filename: (req, file, cb) => cb(null, `${Date.now()}-${file.originalname}`)
});
const upload = multer({ storage });

// --- TACTICAL MIDDLEWARE ---
const verifyToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  if (!authHeader) return res.status(403).json({ status: 'ERROR', message: 'NO_TOKEN' });
  const token = authHeader.split(' ')[1];
  jwt.verify(token, JWT_SECRET, (err, decoded) => {
    if (err) return res.status(401).json({ status: 'ERROR', message: 'SESSION_EXPIRED' });
    req.user = decoded;
    next();
  });
};

// --- API ENDPOINTS ---

// Record App Event Helper
const recordEvent = (userId, actionType, details = "") => {
  db.run(`INSERT INTO app_events (user_id, action_type, details) VALUES (?, ?, ?)`, [userId, actionType, details]);
};

// 0. PING (For Debugging Connectivity)
app.get('/api/ping', (req, res) => {
  res.status(200).json({ status: 'ONLINE', timestamp: new Date().toISOString() });
});

// 1. REGISTER
app.post('/api/register', upload.single('face_center'), async (req, res) => {
  try {
    const { username, email, password, phone, region, firstName, lastName } = req.body;
    const hashedPassword = await bcrypt.hash(password, SALT_ROUNDS);
    const facePath = req.file ? `/uploads/${req.file.filename}` : null;

    const query = `INSERT INTO users (username, email, password, phone, region, face_image, joined_date) VALUES (?, ?, ?, ?, ?, ?, ?)`;
    const joinedDate = new Date().toISOString().split('T')[0];

    db.run(query, [username, email, hashedPassword, phone, region, facePath, joinedDate], (err) => {
      if (err) {
        console.error("❌ Register Error:", err.message);
        return res.status(400).json({ status: 'ERROR', message: 'EMAIL_OR_PHONE_TAKEN' });
      }
      recordEvent(email, 'REGISTRATION', `User ${username} joined the network.`);
      res.status(200).json({ status: 'SUCCESS' });
    });
  } catch (e) {
    res.status(500).json({ status: 'ERROR', message: 'ENROLLMENT_FAILED' });
  }
});

// 2. LOGIN
app.post('/api/login', async (req, res) => {
  const { email, password } = req.body;

  if (email === MASTER_ADMIN_ID && password === MASTER_ADMIN_KEY) {
    const token = jwt.sign({ email, is_admin: 1 }, JWT_SECRET, { expiresIn: '24h' });
    recordEvent(email, 'ADMIN_LOGIN', 'Master terminal access established.');
    return res.status(200).json({
        status: 'SUCCESS',
        token: token,
        user: { username: 'COMMANDER', email, is_admin: 1, reputation_score: 1000 }
    });
  }

  db.get(`SELECT * FROM users WHERE email = ?`, [email], async (err, user) => {
    if (err || !user) return res.status(401).json({ status: 'ERROR', message: 'UNIT_NOT_FOUND' });
    const match = await bcrypt.compare(password, user.password);
    if (!match) return res.status(401).json({ status: 'ERROR', message: 'DENIED' });

    const token = jwt.sign({ email: user.email, is_admin: user.is_admin }, JWT_SECRET, { expiresIn: '24h' });
    recordEvent(email, 'USER_LOGIN_ATTEMPT', 'Credentials verified, awaiting OTP.');
    res.status(200).json({ status: 'SUCCESS', token: token, user: user });
  });
});

// 2. SEND OTP
app.post('/api/send-otp', async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ status: 'ERROR', message: 'EMAIL_REQUIRED' });

  const code = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = Date.now() + 600000; // 10 minutes

  db.run(`REPLACE INTO otps (identifier, code, expires_at) VALUES (?, ?, ?)`, [email, code, expiresAt], async (err) => {
    if (err) {
      console.error("❌ DB Error storing OTP:", err.message);
      return res.status(500).json({ status: 'ERROR', message: 'DB_FAILURE' });
    }

    try {
      console.log(`📧 [SMTP] Attempting to send OTP to: ${email}...`);

      const transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: {
          user: process.env.EMAIL_USER,
          pass: process.env.EMAIL_PASS
        },
        tls: { rejectUnauthorized: false }
      });

      const mailOptions = {
        from: `"Sector Alpha Command" <${process.env.EMAIL_USER}>`,
        to: email,
        subject: '🔒 SECURE_IDENTITY_TOKEN',
        html: `<div style="background-color:#020617;color:white;padding:40px;font-family:monospace;border:1px solid #0A5CFF;">
                 <h2 style="color:#0A5CFF;">IDENTIFICATION_PROTOCOL_V10</h2>
                 <p>A request has been made to establish a secure link with this node.</p>
                 <div style="background-color:#0F172A;padding:20px;text-align:center;border-radius:8px;margin:30px 0;">
                   <span style="font-size:32px;font-weight:bold;letter-spacing:10px;color:#FB923C;">${code}</span>
                 </div>
                 <p style="color:#64748b;font-size:12px;">This token expires in 10 minutes.</p>
               </div>`
      };

      await transporter.sendMail(mailOptions);
      console.log(`✅ [SMTP] OTP successfully transmitted to ${email}`);
      res.status(200).json({ status: 'SUCCESS' });
    } catch (e) {
      console.error("❌ [SMTP] FAILED to send email:", e.message);
      res.status(500).json({ status: 'ERROR', message: 'MAIL_SERVER_REJECTED' });
    }
  });
});

// 3. VERIFY OTP
app.post('/api/verify-otp', (req, res) => {
  const { email, code } = req.body;
  db.get('SELECT * FROM otps WHERE identifier = ?', [email], (err, row) => {
    if (row && row.code === code.trim() && row.expires_at > Date.now()) {
      db.run(`DELETE FROM otps WHERE identifier = ?`, [email]);
      db.get('SELECT * FROM users WHERE email = ?', [email], (err, user) => {
        const isAdmin = user ? user.is_admin : 0;
        const token = jwt.sign({ email: email, is_admin: isAdmin }, JWT_SECRET, { expiresIn: '24h' });
        recordEvent(email, 'USER_LOGIN_SUCCESS', 'Identity verified via OTP.');
        res.status(200).json({ status: 'SUCCESS', token: token });
      });
    } else {
      recordEvent(email, 'LOGIN_FAILED', 'Invalid or expired OTP entered.');
      res.status(400).json({ status: 'ERROR', message: 'INVALID_TOKEN' });
    }
  });
});

// 4. LOGOUT
app.post('/api/logout', verifyToken, (req, res) => {
  recordEvent(req.user.email, 'LOGOUT', 'User disconnected session.');
  res.status(200).json({ status: 'SUCCESS' });
});

// 5. ADMIN EVENTS
app.get('/api/admin/events', verifyToken, (req, res) => {
  if (req.user.is_admin !== 1) return res.status(403).json({ status: 'ERROR', message: 'UNAUTHORIZED' });
  db.all(`SELECT * FROM app_events ORDER BY timestamp DESC LIMIT 100`, (err, rows) => {
    res.status(200).json({ status: 'SUCCESS', events: rows });
  });
});

// 6. INCIDENTS
app.get('/api/incidents', verifyToken, (req, res) => {
  const isAdmin = req.user.is_admin === 1;
  let query = isAdmin ? `SELECT * FROM incidents ORDER BY timestamp DESC` : `SELECT * FROM incidents WHERE reporter_id = ? ORDER BY timestamp DESC`;
  db.all(query, isAdmin ? [] : [req.user.email], (err, rows) => {
    res.status(200).json({ status: 'SUCCESS', incidents: rows });
  });
});

app.post('/api/incidents', verifyToken, (req, res) => {
  const { type, description, location, timestamp, severity, lat, lng, reporter_name } = req.body;
  db.run(`INSERT INTO incidents (type, description, location, timestamp, severity, lat, lng, reporter_name, reporter_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [type, description, location, timestamp, severity, lat, lng, reporter_name, req.user.email], (err) => {
    recordEvent(req.user.email, 'REPORT_SUBMITTED', `Incident type: ${type} at ${location}`);
    res.status(200).json({ status: 'SUCCESS' });
  });
});

// 7. NODES
app.get('/api/nodes', verifyToken, (req, res) => {
    db.all(`SELECT username, email, is_admin, lat, lng, phone, region FROM users`, (err, rows) => {
      res.status(200).json({ status: 'SUCCESS', nodes: rows });
    });
});

// 8. MESSAGES
app.get('/api/messages', verifyToken, (req, res) => {
  const { unit } = req.query;
  const isAdmin = req.user.is_admin === 1;

  let query = isAdmin ? `SELECT * FROM messages ORDER BY timestamp DESC` : `SELECT * FROM messages WHERE sender = ? OR recipient = ? ORDER BY timestamp ASC`;
  let params = isAdmin ? [] : [req.user.email, req.user.email];

  if (isAdmin && unit) {
    query = `SELECT * FROM messages WHERE sender = ? OR recipient = ? ORDER BY timestamp ASC`;
    params = [unit, unit];
  }

  db.all(query, params, (err, rows) => {
    res.status(200).json({ status: 'SUCCESS', messages: rows });
  });
});

app.post('/api/messages', verifyToken, (req, res) => {
  const { sender, recipient, content, timestamp, is_admin_reply } = req.body;
  // Use email as unique identifier for storage to survive name changes
  db.run(`INSERT INTO messages (sender, recipient, content, timestamp, is_admin_reply) VALUES (?, ?, ?, ?, ?)`,
    [sender, recipient, content, timestamp, is_admin_reply], (err) => {
    res.status(200).json({ status: 'SUCCESS' });
  });
});

app.post('/api/messages/edit', verifyToken, (req, res) => {
  const { id, content } = req.body;
  db.run(`UPDATE messages SET content = ?, is_edited = 1 WHERE id = ? AND sender = ?`, [content, id, req.user.email], (err) => {
    if (err) return res.status(500).json({ status: 'ERROR' });
    res.status(200).json({ status: 'SUCCESS' });
  });
});

// 9. UPDATE LOCATION
app.post('/api/update-location', verifyToken, (req, res) => {
  const { lat, lng } = req.body;
  db.run(`UPDATE users SET lat = ?, lng = ?, last_seen = CURRENT_TIMESTAMP WHERE email = ?`, [lat, lng, req.user.email], (err) => {
    res.status(200).json({ status: 'SUCCESS' });
  });
});

// 9. BIOMETRIC VERIFY (REGISTRATION & AUTH)
app.post('/api/biometric-verify', (req, res) => {
  // TACTICAL: Removed verifyToken to allow biometric sync during enrollment
  console.log(`👤 [BIOMETRICS] Syncing unit visage data...`);
  res.status(200).json({ status: 'SUCCESS' });
});

// 10. FORGOT PASSWORD
app.post('/api/forgot-password', (req, res) => {
  const { phone } = req.body;
  db.get(`SELECT email FROM users WHERE phone = ?`, [phone], (err, user) => {
    if (user) {
      recordEvent(user.email, 'FORGOT_PASSWORD_REQUEST', `Initiated via phone: ${phone}`);
      res.status(200).json({ status: 'SUCCESS', identifier: user.email });
    } else {
      res.status(404).json({ status: 'ERROR', message: 'PHONE_NOT_RECOGNIZED' });
    }
  });
});

// 11. RESET PASSWORD
app.post('/api/reset-password', async (req, res) => {
  const { identifier, newPassword } = req.body;
  const hashedPassword = await bcrypt.hash(newPassword, SALT_ROUNDS);
  db.run(`UPDATE users SET password = ? WHERE email = ?`, [hashedPassword, identifier], (err) => {
    if (err) return res.status(500).json({ status: 'ERROR' });
    recordEvent(identifier, 'PASSWORD_RESET_SUCCESS', 'Security key updated.');
    res.status(200).json({ status: 'SUCCESS' });
  });
});

// 12. UPDATE PROFILE
app.post('/api/update-profile', verifyToken, async (req, res) => {
  const { username, first_name, middle_name, last_name, phone, region, blood_group, emergency_contact } = req.body;
  const email = req.user.email;

  const query = `UPDATE users SET
    username = ?,
    first_name = ?,
    middle_name = ?,
    last_name = ?,
    phone = ?,
    region = ?,
    blood_group = ?,
    emergency_contact = ?
    WHERE email = ?`;

  db.run(query, [username, first_name, middle_name, last_name, phone, region, blood_group, emergency_contact, email], (err) => {
    if (err) {
      console.error("❌ Update Profile Error:", err.message);
      return res.status(400).json({ status: 'ERROR', message: 'UPDATE_FAILED' });
    }
    recordEvent(email, 'PROFILE_UPDATED', `User ${username} updated their dossier.`);
    res.status(200).json({ status: 'SUCCESS' });
  });
});

// 13. MASTER PURGE (DEVELOPMENT ONLY)
app.get('/api/debug/purge-all', (req, res) => {
  db.serialize(() => {
    db.run(`DELETE FROM users`);
    db.run(`DELETE FROM incidents`);
    db.run(`DELETE FROM app_events`);
    db.run(`DELETE FROM otps`);
  });
  console.log("⚠️ [SYSTEM] MASTER PURGE EXECUTED. ALL NODES DELETED.");
  res.send("SYSTEM_PURGED_SUCCESSFULLY");
});

// --- ERROR HANDLER ---
app.use((err, req, res, next) => {
  console.error("💥 [ERROR]", err);
  res.status(500).json({ status: 'ERROR', message: 'SERVER_CRASH' });
});

const os = require('os');
const networkInterfaces = os.networkInterfaces();
const localIPs = [];

Object.keys(networkInterfaces).forEach((ifname) => {
  networkInterfaces[ifname].forEach((iface) => {
    if ('IPv4' !== iface.family || iface.internal !== false) return;
    localIPs.push(iface.address);
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 SECURITY_CORE_V10.7 ONLINE`);
  console.log(`📡 LISTENING ON PORT: ${PORT} (ALL INTERFACES)`);
  console.log(`🔗 DETECTED LOCAL IPs: ${localIPs.join(', ')}`);
  console.log(`📝 USE ONE OF THESE IN lib/core/services/auth_service.dart`);
});
