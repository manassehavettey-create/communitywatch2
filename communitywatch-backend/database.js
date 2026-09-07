const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const dbPath = path.resolve(__dirname, 'communitywatch.db');
const db = new sqlite3.Database(dbPath);

db.serialize(() => {
  console.log("🛠️  [DATABASE] Initializing Tactical Core V10.7...");

  // 0. OTP TABLE
  db.run(`CREATE TABLE IF NOT EXISTS otps (
    identifier TEXT PRIMARY KEY,
    code TEXT NOT NULL,
    expires_at INTEGER NOT NULL
  )`);

  db.all(`PRAGMA table_info(otps)`, (err, columns = []) => {
    if (err) return console.error('OTP schema check failed:', err.message);
    const existingColumns = new Set(columns.map((column) => column.name));
    const migrations = [
      ['identifier', 'TEXT'],
      ['code', 'TEXT'],
      ['expires_at', 'INTEGER'],
    ];
    migrations.forEach(([name, type]) => {
      if (!existingColumns.has(name)) {
        db.run(`ALTER TABLE otps ADD COLUMN ${name} ${type}`, (migrationError) => {
          if (migrationError) console.error(`OTP migration failed for ${name}:`, migrationError.message);
        });
      }
    });
  });

  // 1. USERS TABLE
  db.run(`CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT,
    email TEXT UNIQUE NOT NULL,
    password TEXT,
    phone TEXT UNIQUE,
    region TEXT,
    is_admin INTEGER DEFAULT 0,
    reputation_score INTEGER DEFAULT 100,
    is_verified INTEGER DEFAULT 0,
    is_frozen INTEGER DEFAULT 0,
    lat REAL DEFAULT 5.6037,
    lng REAL DEFAULT -0.1870,
    face_image TEXT,
    last_seen TEXT,
    joined_date TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);

  // 2. INCIDENTS TABLE
  db.run(`CREATE TABLE IF NOT EXISTS incidents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT, description TEXT, location TEXT, timestamp TEXT, severity TEXT,
    is_resolved INTEGER DEFAULT 0, lat REAL, lng REAL, reporter_name TEXT,
    reporter_id TEXT, attachments TEXT
  )`);

  // 3. APP EVENTS (LOGS)
  db.run(`CREATE TABLE IF NOT EXISTS app_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT,
    action_type TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    details TEXT
  )`, () => {
    // Migration: Add details column if it doesn't exist in old DB versions
    db.run(`ALTER TABLE app_events ADD COLUMN details TEXT`, (err) => {
        if (err) {
            // Error usually means column already exists, ignore
        } else {
            console.log("🛠️ [DATABASE] Migrated app_events: added 'details' column.");
        }
    });
  });

  // 4. MESSAGES TABLE
  db.run(`CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sender TEXT,
    recipient TEXT,
    content TEXT,
    timestamp TEXT,
    is_admin_reply INTEGER DEFAULT 0,
    is_read INTEGER DEFAULT 0,
    is_edited INTEGER DEFAULT 0
  )`);

  console.log("✅ [DATABASE] All tables ready.");
});

module.exports = db;
