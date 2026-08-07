// ─────────────────────────────────────────────────────────────────────────────
// Server configuration — THE DATABASE KEY LIVES HERE (server-side only).
// The clients (exe/apk) never need the database credentials; they only call
// this server over HTTPS.
//
// Create `config.json` next to this file (see config.example.json):
// {
//   "port": 3000,
//   "appKey": "change-me",          // shared secret the clients send
//   "db": {
//     "type": "sqlite",             // "sqlite" (offline dev) | "mysql" (ArvanCloud)
//     "sqliteFile": "./data/shekatel.db",
//     "host": "", "port": 3306, "user": "", "password": "", "database": "",
//     "ssl": true
//   }
// }
// ─────────────────────────────────────────────────────────────────────────────
const fs = require('fs');
const path = require('path');

const CONFIG_PATH = process.env.SHEKATEL_CONFIG || path.join(__dirname, 'config.json');

let config = {};
if (fs.existsSync(CONFIG_PATH)) {
  try {
    config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
  } catch (e) {
    console.error('Could not parse ' + CONFIG_PATH, e.message);
  }
} else {
  console.warn('config.json not found — using defaults (SQLite dev mode). Copy config.example.json to config.json and fill in your ArvanCloud database key when ready.');
}

config.port = Number(process.env.PORT) || config.port || 3000;
config.appKey = process.env.APP_KEY || config.appKey || 'change-me';
config.db = config.db || {};
config.db.type = process.env.DB_TYPE || config.db.type || 'sqlite';
config.db.host = process.env.DB_HOST || config.db.host || '';
config.db.port = Number(process.env.DB_PORT) || config.db.port || 3306;
config.db.user = process.env.DB_USER || config.db.user || '';
config.db.password = process.env.DB_PASSWORD || config.db.password || '';
config.db.database = process.env.DB_NAME || config.db.database || '';
config.db.ca = process.env.DB_CA || config.db.ca || '';
config.db.sqliteFile = config.db.sqliteFile || './data/shekatel.db';

module.exports = config;
