// ─────────────────────────────────────────────────────────────────────────────
// Database adapter — two backends behind one tiny query API:
//   - "sqlite": built-in node:sqlite (offline development / testing)
//   - "mysql":  mysql2 pool (ArvanCloud Managed Database)
// Queries use `?` placeholders in both dialects.
// ─────────────────────────────────────────────────────────────────────────────
const fs = require('fs');
const path = require('path');
const config = require('./config');

const dialect = config.db.type; // 'sqlite' | 'mysql'

let db = null; // sqlite handle
let pool = null; // mysql pool

async function init() {
  if (dialect === 'mysql') {
    const mysql = require('mysql2/promise');
    pool = mysql.createPool({
      host: config.db.host,
      port: config.db.port || 3306,
      user: config.db.user,
      password: config.db.password,
      database: config.db.database,
      waitForConnections: true,
      connectionLimit: 10,
      // ArvanCloud uses its own CA — accept it without shipping the cert file.
      // For maximum security, download the CA from the dashboard and set
      // config.db.ca to the file path (or DB_CA env) instead.
      ssl: config.db.ssl
        ? { rejectUnauthorized: false, ca: config.db.ca ? fs.readFileSync(config.db.ca) : undefined }
        : undefined,
      timezone: 'Z',
      dateStrings: true,
    });
    await pool.query('SELECT 1'); // verify connectivity at startup
    console.log(`[db] connected to MySQL at ${config.db.host}:${config.db.port || 3306}/${config.db.database}`);
  } else {
    const { DatabaseSync } = require('node:sqlite');
    const file = path.resolve(__dirname, config.db.sqliteFile);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    db = new DatabaseSync(file);
    console.log(`[db] using SQLite file: ${file}`);
  }
}

async function run(sql, params = []) {
  if (dialect === 'mysql') {
    await pool.query(sql, params);
    return;
  }
  db.prepare(sql).run(...params);
}

async function get(sql, params = []) {
  if (dialect === 'mysql') {
    const [rows] = await pool.query(sql, params);
    return rows[0] || null;
  }
  return db.prepare(sql).get(...params) || null;
}

async function all(sql, params = []) {
  if (dialect === 'mysql') {
    const [rows] = await pool.query(sql, params);
    return rows;
  }
  return db.prepare(sql).all(...params);
}

// Dialect helpers
const AUTOINCREMENT = dialect === 'mysql' ? 'AUTO_INCREMENT' : 'AUTOINCREMENT';
// MySQL cannot use CURRENT_TIMESTAMP as a default on TEXT columns (it must be
// DATETIME/TIMESTAMP); SQLite can use a datetime expression on TEXT.
const NOW = dialect === 'mysql' ? 'CURRENT_TIMESTAMP' : "(datetime('now'))";
const DATETIME_COL = dialect === 'mysql' ? 'DATETIME' : 'TEXT';
// base64 logos exceed MySQL TEXT's 64KB limit → use MEDIUMTEXT there.
const LARGE_TEXT_COL = dialect === 'mysql' ? 'MEDIUMTEXT' : 'TEXT';
function monthExpr(col) {
  return dialect === 'mysql'
    ? `DATE_FORMAT(${col}, '%Y-%m')`
    : `strftime('%Y-%m', ${col})`;
}
const INSERT_OR_REPLACE = dialect === 'mysql' ? 'REPLACE INTO' : 'INSERT OR REPLACE INTO';

module.exports = { init, run, get, all, dialect, AUTOINCREMENT, NOW, DATETIME_COL, LARGE_TEXT_COL, monthExpr, INSERT_OR_REPLACE };
