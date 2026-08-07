// ─────────────────────────────────────────────────────────────────────────────
// Schema creation + seed data (identical defaults to the desktop app).
// ─────────────────────────────────────────────────────────────────────────────
const db = require('./db');
const { AUTOINCREMENT, NOW, INSERT_OR_REPLACE, DATETIME_COL, LARGE_TEXT_COL } = db;

const TABLES = {
  users: `CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY ${AUTOINCREMENT},
    name TEXT NOT NULL,
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'limited')`,

  products: `CREATE TABLE IF NOT EXISTS products (
    id INTEGER PRIMARY KEY ${AUTOINCREMENT},
    code TEXT UNIQUE NOT NULL,
    name_fa TEXT NOT NULL,
    category TEXT NOT NULL,
    unit TEXT NOT NULL DEFAULT 'kg',
    cost_price REAL DEFAULT 0,
    sell_price REAL DEFAULT 0,
    is_mix INTEGER DEFAULT 0)`,

  customers: `CREATE TABLE IF NOT EXISTS customers (
    id INTEGER PRIMARY KEY ${AUTOINCREMENT},
    name TEXT NOT NULL,
    phone TEXT,
    address TEXT,
    created_at ${DATETIME_COL} DEFAULT ${NOW})`,

  inventory: `CREATE TABLE IF NOT EXISTS inventory (
    id INTEGER PRIMARY KEY ${AUTOINCREMENT},
    product_id INTEGER UNIQUE NOT NULL,
    current_stock REAL DEFAULT 0,
    total_input REAL DEFAULT 0,
    total_output REAL DEFAULT 0)`,

  inventory_log: `CREATE TABLE IF NOT EXISTS inventory_log (
    id INTEGER PRIMARY KEY ${AUTOINCREMENT},
    product_id INTEGER NOT NULL,
    type TEXT NOT NULL,
    quantity REAL NOT NULL,
    description TEXT,
    operator TEXT,
    created_at ${DATETIME_COL} DEFAULT ${NOW})`,

  recipes: `CREATE TABLE IF NOT EXISTS recipes (
    id INTEGER PRIMARY KEY ${AUTOINCREMENT},
    mix_product_id INTEGER NOT NULL,
    ingredient_id INTEGER NOT NULL,
    percentage REAL NOT NULL)`,

  invoices: `CREATE TABLE IF NOT EXISTS invoices (
    id INTEGER PRIMARY KEY ${AUTOINCREMENT},
    invoice_number TEXT UNIQUE NOT NULL,
    customer_id INTEGER NOT NULL,
    total_amount REAL NOT NULL,
    total_cost REAL DEFAULT 0,
    tax REAL DEFAULT 0,
    status TEXT DEFAULT 'BEDEHKAR',
    operator TEXT NOT NULL,
    invoice_date TEXT NOT NULL,
    created_at ${DATETIME_COL} DEFAULT ${NOW},
    is_edited INTEGER DEFAULT 0,
    edited_at TEXT)`,

  invoice_items: `CREATE TABLE IF NOT EXISTS invoice_items (
    id INTEGER PRIMARY KEY ${AUTOINCREMENT},
    invoice_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity REAL NOT NULL,
    unit_price REAL NOT NULL,
    cost_price REAL DEFAULT 0)`,

  sales_log: `CREATE TABLE IF NOT EXISTS sales_log (
    id INTEGER PRIMARY KEY ${AUTOINCREMENT},
    invoice_id INTEGER NOT NULL,
    customer_name TEXT,
    total_sale REAL NOT NULL,
    total_cost REAL DEFAULT 0,
    gross_profit REAL DEFAULT 0,
    tax REAL DEFAULT 0,
    net_profit REAL DEFAULT 0,
    status TEXT DEFAULT 'BEDEHKAR',
    operator TEXT,
    created_at ${DATETIME_COL} DEFAULT ${NOW},
    is_edited INTEGER DEFAULT 0,
    edited_at TEXT)`,

  roasting_log: `CREATE TABLE IF NOT EXISTS roasting_log (
    id INTEGER PRIMARY KEY ${AUTOINCREMENT},
    green_bean_id INTEGER NOT NULL,
    roasted_bean_id INTEGER NOT NULL,
    input_weight REAL NOT NULL,
    output_weight REAL NOT NULL,
    weight_loss_percent REAL NOT NULL,
    created_at ${DATETIME_COL} DEFAULT ${NOW})`,

  expenses: `CREATE TABLE IF NOT EXISTS expenses (
    id INTEGER PRIMARY KEY ${AUTOINCREMENT},
    category TEXT NOT NULL,
    description TEXT NOT NULL,
    amount REAL NOT NULL,
    expense_date ${DATETIME_COL} DEFAULT ${NOW},
    created_at ${DATETIME_COL} DEFAULT ${NOW})`,

  settings: `CREATE TABLE IF NOT EXISTS settings (
    id INTEGER PRIMARY KEY ${AUTOINCREMENT},
    key TEXT UNIQUE NOT NULL,
    value TEXT)`,

  logo: `CREATE TABLE IF NOT EXISTS logo (
    id INTEGER PRIMARY KEY ${AUTOINCREMENT},
    data ${LARGE_TEXT_COL} NOT NULL)`,
};

async function ensureSchema() {
  for (const ddl of Object.values(TABLES)) await db.run(ddl);

  // sync version counter — bumped on every write so clients know to refresh
  await db.run(`CREATE TABLE IF NOT EXISTS meta (
    id INTEGER PRIMARY KEY ${AUTOINCREMENT},
    key TEXT UNIQUE NOT NULL,
    value TEXT)`);
  const v = await db.get("SELECT value FROM meta WHERE key = 'data_version'");
  if (!v) await db.run(`${INSERT_OR_REPLACE} meta (key, value) VALUES ('data_version', '0')`);
}

async function seedIfEmpty() {
  const seeded = await db.get('SELECT COUNT(*) AS c FROM users');
  if (seeded.c === 0) {
    const users = [
      ['بهنام محمدی', 'behnam', '0092455', 'admin'],
      ['علی اسدی', 'ali', '0099455', 'sales'],
      ['سعید', 'saeed', '0097485', 'marketing'],
    ];
    for (const [name, username, password, role] of users) {
      await db.run('INSERT INTO users (name, username, password, role) VALUES (?, ?, ?, ?)', [name, username, password, role]);
    }
  }

  const products = await db.get('SELECT COUNT(*) AS c FROM products');
  if (products.c === 0) {
    const seed = (code, name, category, isMix) =>
      db.run("INSERT INTO products (code, name_fa, category, unit, cost_price, sell_price, is_mix) VALUES (?, ?, ?, 'kg', 0, 0, ?)", [code, name, category, isMix]);

    const mixes = [
      ['MIX-R100', 'میکس 100 درصد ربوستا شکاتل'], ['MIX-R90', 'میکس 90/10 ربوستا شکاتل'],
      ['MIX-R80', 'میکس 80/20 ربوستا شکاتل'], ['MIX-R70', 'میکس 70/30 ربوستا شکاتل'],
      ['MIX-R60', 'میکس 60/40 ربوستا شکاتل'], ['MIX-5050', 'میکس 50/50 شکاتل'],
      ['MIX-A100', 'میکس 100 درصد عربیکا شکاتل'], ['MIX-A90', 'میکس 90/10 عربیکا شکاتل'],
      ['MIX-A80', 'میکس 80/20 عربیکا شکاتل'], ['MIX-A70', 'میکس 70/30 عربیکا شکاتل'],
      ['MIX-A60', 'میکس 60/40 عربیکا شکاتل'],
    ];
    for (const [code, name] of mixes) await seed(code, name, 'mix', 1);

    const powders = [
      ['PWR-HCH', 'هات چاکلت'], ['PWR-CAP', 'کاپوچینو'], ['PWR-KRK', 'چای کرک'],
      ['PWR-MSL', 'چای ماسالا'], ['PWR-MSRD', 'چای ماسلا رژیمی'], ['PWR-KRKR', 'چای کرک رژیمی'],
      ['PWR-HCHR', 'هات چاکلت رژیمی'], ['PWR-WCH', 'وایت چاکلت'], ['PWR-COC', 'پودر کاکائو'],
      ['PWR-FOAM', 'فومر'], ['PWR-CAPR', 'کاپوچینو رژیمی'], ['PWR-CM', 'کافی میت'],
      ['PWR-SUG', 'شکر'],
    ];
    for (const [code, name] of powders) await seed(code, name, 'pwr', 0);

    const greens = [
      ['GRN-VNM', 'دان سبز ویتنام'], ['GRN-EK', 'دان سبز اندونزی ek'],
      ['GRN-AP1', 'دان سبز اندونزی ap1'], ['GRN-BRZ', 'دان سبز برزیل ریو'],
      ['GRN-UGA', 'دان سبز اوگاندا'], ['GRN-CHAA', 'دان سبز چری aa'],
      ['GRN-IND', 'دان سبز PB هند'], ['GRN-COL', 'دان سبز کلمبیا'],
    ];
    for (const [code, name] of greens) await seed(code, name, 'grn', 0);

    const roasted = [
      ['RST-COL', 'دان رست شده کلمبیا'], ['RST-AP1', 'دان رست شده اندونزی AP1'],
      ['RST-EK', 'دان رست اندونزی EK'], ['RST-VNM', 'دان رست شده ویتنام'],
      ['RST-CHAA', 'دان رست شده چری AA'], ['RST-BRZ', 'دان رست شده برزیل ریو'],
      ['RST-UGA', 'دان رست شده اوگاندا'], ['RST-IND', 'دان رست شده PB هند'],
    ];
    for (const [code, name] of roasted) await seed(code, name, 'rst', 0);

    const instants = [
      ['GRN-GOLD-IND', 'گلد هند'], ['GRN-GOLD-ECU', 'گلد اکوادور'], ['GRN-GOLD-BRZ', 'گلد برزیل'],
      ['INST-ESP-IND', 'اسپرسو فوری هند'], ['INST-ESP-CLS', 'اسپرسو کلاسیک'],
    ];
    for (const [code, name] of instants) await seed(code, name, 'inst', 0);

    const nonMix = await db.all('SELECT id FROM products WHERE is_mix = 0');
    for (const p of nonMix) {
      await db.run('INSERT INTO inventory (product_id, current_stock, total_input, total_output) VALUES (?, 0, 0, 0)', [p.id]);
    }
  }

  const settings = await db.get('SELECT COUNT(*) AS c FROM settings');
  if (settings.c === 0) {
    const defaults = [
      ['company_name', 'شکاتل کافی'], ['company_phone', ''], ['company_address', ''],
      ['invoice_footer', ''], ['logo_path', ''], ['show_stamps', '1'],
      ['show_buyer_stamp', '1'], ['show_issuer_stamp', '1'],
      ['bank_name', ''], ['bank_account_number', ''], ['bank_account_holder', ''],
      ['bank_card_number', ''], ['bank_sheba', ''],
    ];
    for (const [k, v] of defaults) {
      await db.run(`${INSERT_OR_REPLACE} settings (key, value) VALUES (?, ?)`, [k, v]);
    }
  }

  // seed a data_version bump so the very first sync is detectable
  const v = await db.get("SELECT value FROM meta WHERE key = 'data_version'");
  if (v && v.value === '0') await bumpVersion();
}

async function bumpVersion() {
  // implicit numeric coercion works in both SQLite and MySQL (CAST(... AS INTEGER)
  // is not a valid MySQL target type)
  await db.run("UPDATE meta SET value = value + 1 WHERE key = 'data_version'");
}

async function getVersion() {
  const v = await db.get("SELECT value FROM meta WHERE key = 'data_version'");
  return v ? Number(v.value) : 0;
}

module.exports = { ensureSchema, seedIfEmpty, bumpVersion, getVersion };
