// ─────────────────────────────────────────────────────────────────────────────
// Shekatel Coffee — Sync API server
// Serves the exe (Electron) and apk (Capacitor) clients over HTTPS.
// Writes bump a data_version that clients poll to refresh across devices.
// ─────────────────────────────────────────────────────────────────────────────
const express = require('express');
const cors = require('cors');
const config = require('./config');
const db = require('./db');
const schema = require('./schema');
const { monthExpr, INSERT_OR_REPLACE } = db;

const app = express();
app.use(cors());
app.use(express.json({ limit: '50mb' })); // logo uploads are base64

// Simple shared-secret gate (the clients send this key in a header).
function requireKey(req, res, next) {
  if (!req.get('x-app-key') || req.get('x-app-key') !== config.appKey) {
    return res.status(401).json({ error: 'Invalid app key' });
  }
  next();
}
app.use(requireKey);

const wrap = (fn) => (req, res) => {
  Promise.resolve(fn(req, res)).catch((e) => {
    console.error('[api]', e);
    res.status(500).json({ error: e.message });
  });
};
const ok = (res, data) => res.json(data);

// ── meta ──────────────────────────────────────────────────────────────────────
app.get('/api/meta/version', wrap(async (req, res) => {
  ok(res, { version: await schema.getVersion() });
}));

// ── auth ─────────────────────────────────────────────────────────────────────
app.post('/api/login', wrap(async (req, res) => {
  const { username, password } = req.body || {};
  const user = await db.get('SELECT * FROM users WHERE username = ? AND password = ?', [username, password]);
  ok(res, user || null);
}));

// ── products ─────────────────────────────────────────────────────────────────
app.get('/api/products', wrap(async (req, res) => {
  const { category } = req.query;
  if (category) ok(res, await db.all('SELECT * FROM products WHERE category = ?', [category]));
  else ok(res, await db.all('SELECT * FROM products'));
}));
app.get('/api/products/non-mix', wrap(async (req, res) => ok(res, await db.all('SELECT * FROM products WHERE is_mix = 0'))));
app.get('/api/products/mix', wrap(async (req, res) => ok(res, await db.all('SELECT * FROM products WHERE is_mix = 1'))));
app.post('/api/products/price', wrap(async (req, res) => {
  const { id, cost_price, sell_price } = req.body;
  await db.run('UPDATE products SET cost_price = ?, sell_price = ? WHERE id = ?', [cost_price, sell_price, id]);
  await schema.bumpVersion();
  ok(res, { success: true });
}));

// ── customers ────────────────────────────────────────────────────────────────
app.get('/api/customers', wrap(async (req, res) => ok(res, await db.all('SELECT * FROM customers ORDER BY id DESC'))));
app.post('/api/customers', wrap(async (req, res) => {
  const { name, phone, address } = req.body;
  await db.run('INSERT INTO customers (name, phone, address) VALUES (?, ?, ?)', [name, phone, address]);
  await schema.bumpVersion();
  ok(res, { success: true });
}));
app.put('/api/customers/:id', wrap(async (req, res) => {
  const { name, phone, address } = req.body;
  await db.run('UPDATE customers SET name = ?, phone = ?, address = ? WHERE id = ?', [name, phone, address, req.params.id]);
  await schema.bumpVersion();
  ok(res, { success: true });
}));
app.delete('/api/customers/:id', wrap(async (req, res) => {
  await db.run('DELETE FROM customers WHERE id = ?', [req.params.id]);
  await schema.bumpVersion();
  ok(res, { success: true });
}));

// ── inventory ────────────────────────────────────────────────────────────────
app.get('/api/inventory', wrap(async (req, res) => {
  ok(res, await db.all(`SELECT i.*, p.name_fa, p.code, p.category, p.unit
    FROM inventory i JOIN products p ON i.product_id = p.id
    ORDER BY p.category, p.name_fa`));
}));
app.post('/api/inventory/input', wrap(async (req, res) => {
  const { product_id, quantity, operator } = req.body;
  const inv = await db.get('SELECT * FROM inventory WHERE product_id = ?', [product_id]);
  if (inv) await db.run('UPDATE inventory SET current_stock = current_stock + ?, total_input = total_input + ? WHERE product_id = ?', [quantity, quantity, product_id]);
  else await db.run('INSERT INTO inventory (product_id, current_stock, total_input, total_output) VALUES (?, ?, ?, 0)', [product_id, quantity, quantity]);
  await db.run('INSERT INTO inventory_log (product_id, type, quantity, description, operator) VALUES (?, ?, ?, ?, ?)', [product_id, 'Input', quantity, 'ورودی انبار', operator]);
  await schema.bumpVersion();
  ok(res, { success: true });
}));
app.post('/api/inventory/reset', wrap(async (req, res) => {
  await db.run('UPDATE inventory SET total_input = 0, total_output = 0');
  await schema.bumpVersion();
  ok(res, { success: true });
}));
app.post('/api/inventory/check', wrap(async (req, res) => {
  const { product_id, quantity } = req.body;
  const inv = await db.get('SELECT current_stock FROM inventory WHERE product_id = ?', [product_id]);
  ok(res, inv ? inv.current_stock >= quantity : false);
}));

// ── inventory log ────────────────────────────────────────────────────────────
app.get('/api/inventory-log', wrap(async (req, res) => {
  ok(res, await db.all(`SELECT il.*, p.name_fa, p.code
    FROM inventory_log il JOIN products p ON il.product_id = p.id
    ORDER BY il.created_at DESC`));
}));

// ── recipes ──────────────────────────────────────────────────────────────────
app.get('/api/recipes', wrap(async (req, res) => {
  ok(res, await db.all(`SELECT r.*, p.name_fa as mix_name, i.name_fa as ingredient_name, i.code as ingredient_code
    FROM recipes r JOIN products p ON r.mix_product_id = p.id JOIN products i ON r.ingredient_id = i.id
    ORDER BY r.mix_product_id, r.id`));
}));
app.post('/api/recipes', wrap(async (req, res) => {
  const { mix_product_id, ingredients } = req.body;
  await db.run('DELETE FROM recipes WHERE mix_product_id = ?', [mix_product_id]);
  for (const ing of ingredients) {
    await db.run('INSERT INTO recipes (mix_product_id, ingredient_id, percentage) VALUES (?, ?, ?)', [mix_product_id, ing.ingredient_id, ing.percentage]);
  }
  await schema.bumpVersion();
  ok(res, { success: true });
}));

// ── invoices ─────────────────────────────────────────────────────────────────
app.get('/api/invoices/next-number', wrap(async (req, res) => {
  const last = await db.get('SELECT invoice_number FROM invoices ORDER BY id DESC LIMIT 1');
  if (!last) return ok(res, 'INV-0001');
  const num = parseInt(String(last.invoice_number).split('-')[1], 10) + 1;
  ok(res, `INV-${String(num).padStart(4, '0')}`);
}));
app.post('/api/invoices', wrap(async (req, res) => {
  const d = req.body;
  const result = await db.run(`INSERT INTO invoices (invoice_number, customer_id, total_amount, total_cost, tax, status, operator, invoice_date)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [d.invoice_number, d.customer_id, d.total_amount, d.total_cost, d.tax, d.status || 'BEDEHKAR', d.operator, d.invoice_date]);
  const invoice = await db.get('SELECT id FROM invoices WHERE invoice_number = ?', [d.invoice_number]);
  const invoiceId = invoice.id;
  for (const item of d.items) {
    await db.run('INSERT INTO invoice_items (invoice_id, product_id, quantity, unit_price, cost_price) VALUES (?, ?, ?, ?, ?)',
      [invoiceId, item.product_id, item.quantity, item.unit_price, item.cost_price || 0]);
    await db.run('UPDATE inventory SET current_stock = current_stock - ?, total_output = total_output + ? WHERE product_id = ?',
      [item.quantity, item.quantity, item.product_id]);
    await db.run('INSERT INTO inventory_log (product_id, type, quantity, description, operator) VALUES (?, ?, ?, ?, ?)',
      [item.product_id, 'Output', item.quantity, `خروج فاکتور ${d.invoice_number}`, d.operator]);
  }
  const grossProfit = d.total_amount - d.total_cost;
  const netProfit = grossProfit - d.tax;
  await db.run(`INSERT INTO sales_log (invoice_id, customer_name, total_sale, total_cost, gross_profit, tax, net_profit, status, operator)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [invoiceId, d.customer_name, d.total_amount, d.total_cost, grossProfit, d.tax, netProfit, d.status || 'BEDEHKAR', d.operator]);
  await schema.bumpVersion();
  ok(res, { invoiceId, invoice_number: d.invoice_number });
}));
app.get('/api/invoices/:id', wrap(async (req, res) => {
  const invoice = await db.get('SELECT * FROM invoices WHERE id = ?', [req.params.id]);
  if (invoice) {
    invoice.items = await db.all(`SELECT ii.*, p.name_fa, p.code
      FROM invoice_items ii JOIN products p ON ii.product_id = p.id WHERE ii.invoice_id = ?`, [req.params.id]);
  }
  ok(res, invoice);
}));
app.put('/api/invoices/:id', wrap(async (req, res) => {
  const id = req.params.id;
  const data = req.body;
  if (data.items && data.items.length > 0) {
    await db.run('DELETE FROM invoice_items WHERE invoice_id = ?', [id]);
    for (const item of data.items) {
      await db.run('INSERT INTO invoice_items (invoice_id, product_id, quantity, unit_price, cost_price) VALUES (?, ?, ?, ?, ?)',
        [id, item.product_id, item.quantity, item.unit_price, item.cost_price || 0]);
    }
  }
  if (data.total_amount !== undefined) {
    await db.run('UPDATE invoices SET total_amount = ?, is_edited = 1, edited_at = CURRENT_TIMESTAMP WHERE id = ?', [data.total_amount, id]);
    await db.run('UPDATE sales_log SET total_sale = ?, is_edited = 1, edited_at = CURRENT_TIMESTAMP WHERE invoice_id = ?', [data.total_amount, id]);
  }
  await schema.bumpVersion();
  ok(res, { success: true });
}));

// ── sales log ────────────────────────────────────────────────────────────────
app.get('/api/sales-log', wrap(async (req, res) => ok(res, await db.all('SELECT * FROM sales_log ORDER BY created_at DESC'))));
app.post('/api/sales-log/:id/status', wrap(async (req, res) => {
  const { status } = req.body;
  await db.run('UPDATE sales_log SET status = ? WHERE id = ?', [status, req.params.id]);
  await db.run('UPDATE invoices SET status = ? WHERE id = (SELECT invoice_id FROM sales_log WHERE id = ?)', [status, req.params.id]);
  await schema.bumpVersion();
  ok(res, { success: true });
}));

// ── roasting ─────────────────────────────────────────────────────────────────
app.post('/api/roasting', wrap(async (req, res) => {
  const d = req.body;
  const lossPercent = (1 - d.output_weight / d.input_weight) * 100;
  await db.run('INSERT INTO roasting_log (green_bean_id, roasted_bean_id, input_weight, output_weight, weight_loss_percent) VALUES (?, ?, ?, ?, ?)',
    [d.green_bean_id, d.roasted_bean_id, d.input_weight, d.output_weight, lossPercent]);
  await db.run('UPDATE inventory SET current_stock = current_stock - ?, total_output = total_output + ? WHERE product_id = ?',
    [d.input_weight, d.input_weight, d.green_bean_id]);
  await db.run('INSERT INTO inventory_log (product_id, type, quantity, description, operator) VALUES (?, ?, ?, ?, ?)',
    [d.green_bean_id, 'Output', d.input_weight, 'خروج برای روست', d.operator]);
  const inv = await db.get('SELECT * FROM inventory WHERE product_id = ?', [d.roasted_bean_id]);
  if (inv) await db.run('UPDATE inventory SET current_stock = current_stock + ?, total_input = total_input + ? WHERE product_id = ?',
    [d.output_weight, d.output_weight, d.roasted_bean_id]);
  else await db.run('INSERT INTO inventory (product_id, current_stock, total_input, total_output) VALUES (?, ?, ?, 0)',
    [d.roasted_bean_id, d.output_weight, d.output_weight]);
  await db.run('INSERT INTO inventory_log (product_id, type, quantity, description, operator) VALUES (?, ?, ?, ?, ?)',
    [d.roasted_bean_id, 'Input', d.output_weight, 'ورودی از روست', d.operator]);
  await schema.bumpVersion();
  ok(res, { success: true });
}));
app.get('/api/roasting-log', wrap(async (req, res) => {
  ok(res, await db.all(`SELECT rl.*, g.name_fa as green_name, r.name_fa as roasted_name
    FROM roasting_log rl JOIN products g ON rl.green_bean_id = g.id JOIN products r ON rl.roasted_bean_id = r.id
    ORDER BY rl.created_at DESC`));
}));

// ── expenses ─────────────────────────────────────────────────────────────────
app.get('/api/expenses', wrap(async (req, res) => ok(res, await db.all('SELECT * FROM expenses ORDER BY created_at DESC'))));
app.post('/api/expenses', wrap(async (req, res) => {
  const { category, description, amount, expense_date } = req.body;
  await db.run('INSERT INTO expenses (category, description, amount, expense_date) VALUES (?, ?, ?, ?)', [category, description, amount, expense_date]);
  await schema.bumpVersion();
  ok(res, { success: true });
}));
app.delete('/api/expenses/:id', wrap(async (req, res) => {
  await db.run('DELETE FROM expenses WHERE id = ?', [req.params.id]);
  await schema.bumpVersion();
  ok(res, { success: true });
}));

// ── settings / logo ──────────────────────────────────────────────────────────
app.get('/api/settings', wrap(async (req, res) => {
  const rows = await db.all('SELECT * FROM settings');
  const settings = {};
  for (const row of rows) settings[row.key] = row.value;
  ok(res, settings);
}));
app.put('/api/settings/:key', wrap(async (req, res) => {
  await db.run(`${INSERT_OR_REPLACE} settings (key, value) VALUES (?, ?)`, [req.params.key, req.body.value]);
  await schema.bumpVersion();
  ok(res, { success: true });
}));
app.get('/api/logo', wrap(async (req, res) => {
  const row = await db.get('SELECT data FROM logo ORDER BY id DESC LIMIT 1');
  ok(res, row ? row.data : null);
}));
app.post('/api/logo', wrap(async (req, res) => {
  await db.run('INSERT INTO logo (data) VALUES (?)', [req.body.data]);
  await schema.bumpVersion();
  ok(res, { success: true });
}));

// ── dashboard ────────────────────────────────────────────────────────────────
app.get('/api/dashboard', wrap(async (req, res) => {
  const one = (sql, p = []) => db.get(sql, p);
  const totalSales = (await one('SELECT COALESCE(SUM(total_sale), 0) as total FROM sales_log')).total;
  const totalCost = (await one('SELECT COALESCE(SUM(total_cost), 0) as total FROM sales_log')).total;
  const totalTax = (await one('SELECT COALESCE(SUM(tax), 0) as total FROM sales_log')).total;
  const totalExpenses = (await one('SELECT COALESCE(SUM(amount), 0) as total FROM expenses')).total;
  const totalProfit = (await one('SELECT COALESCE(SUM(net_profit), 0) as total FROM sales_log')).total;
  const invoiceCount = (await one('SELECT COUNT(*) as count FROM invoices')).count;
  const customerCount = (await one('SELECT COUNT(*) as count FROM customers')).count;
  const topProducts = await db.all(`SELECT p.name_fa, SUM(ii.quantity) as total_qty, SUM(ii.quantity * ii.unit_price) as total_revenue
    FROM invoice_items ii JOIN products p ON ii.product_id = p.id
    GROUP BY ii.product_id ORDER BY total_revenue DESC LIMIT 10`);
  const monthlyProfit = await db.all(`SELECT ${monthExpr('created_at')} as month, SUM(net_profit) as profit, SUM(total_sale) as sales
    FROM sales_log GROUP BY ${monthExpr('created_at')} ORDER BY month`);
  const lowStock = await db.all(`SELECT i.*, p.name_fa, p.code FROM inventory i JOIN products p ON i.product_id = p.id
    WHERE i.current_stock < 1 ORDER BY i.current_stock ASC`);
  ok(res, {
    totalSales, totalCost, totalTax, totalExpenses, totalProfit,
    netProfit: totalProfit - totalTax - totalExpenses,
    invoiceCount, customerCount, topProducts, monthlyProfit, lowStock,
  });
}));

// ── boot ─────────────────────────────────────────────────────────────────────
const PORT = process.env.PORT || config.port;

async function boot() {
  await db.init();
  await schema.ensureSchema();
  await schema.seedIfEmpty();

  if (process.argv.includes('--seed-only')) {
    console.log('Seed complete.');
    process.exit(0);
  }

  app.listen(PORT, () => {
    console.log(`[server] Shekatel sync API listening on port ${PORT} (db: ${db.dialect})`);
  });
}

boot().catch((e) => {
  console.error('Startup failed:', e);
  process.exit(1);
});
