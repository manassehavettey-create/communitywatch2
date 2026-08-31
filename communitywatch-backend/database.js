const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('./communitywatch.db');

db.serialize(() => {
  // 1. Table to store OTP requests and expiration times
  db.run(`
    CREATE TABLE IF NOT EXISTS otps (
      email TEXT PRIMARY KEY,
      code TEXT NOT NULL,
      expires_at INTEGER NOT NULL
    )
  `);

  // 2. Table to store registered users
  db.run(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT UNIQUE NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);
});

module.exports = db;