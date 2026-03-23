// mock_server/server.js
// Run with: node server.js
// Requires: npm install express cors body-parser uuid

const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(cors());
app.use(bodyParser.json());

// ── In-memory store ───────────────────────────────────────────────────────────
const db = {
  products: new Map(),
  sales: new Map(),
  stockMovements: new Map(),
};

// Seed some test products
const seedProducts = [
  { id: uuidv4(), name: 'White Bread', nameSetswana: 'Borotho', category: 'Food', price: 12.50, quantity: 50, sku: 'BRD001' },
  { id: uuidv4(), name: 'Coca-Cola 340ml', nameSetswana: 'Kokokola', category: 'Drinks', price: 10.00, quantity: 24, sku: 'CCL340' },
  { id: uuidv4(), name: 'Simba Chips', nameSetswana: 'Dikaka', category: 'Snacks', price: 5.00, quantity: 30, sku: 'SIM001' },
  { id: uuidv4(), name: 'Sunlight Soap', nameSetswana: 'Sesepa', category: 'Household', price: 8.00, quantity: 15, sku: 'SUN001' },
  { id: uuidv4(), name: 'Airtime Orange BWP10', nameSetswana: 'Airtime', category: 'Airtime', price: 10.00, quantity: 100, sku: 'AIR010' },
];
seedProducts.forEach(p => db.products.set(p.id, { ...p, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() }));

// ── Middleware ─────────────────────────────────────────────────────────────────
const logger = (req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
};
app.use(logger);

// Simulate network latency
app.use((req, res, next) => setTimeout(next, Math.random() * 300 + 100));

// ── Products ──────────────────────────────────────────────────────────────────

app.get('/api/products', (req, res) => {
  res.json({ data: [...db.products.values()], total: db.products.size });
});

app.get('/api/products/:id', (req, res) => {
  const product = db.products.get(req.params.id);
  if (!product) return res.status(404).json({ error: 'Not found' });
  res.json(product);
});

app.post('/api/products', (req, res) => {
  const product = { ...req.body, updatedAt: new Date().toISOString() };
  
  // Simulate conflict: if SKU already exists (10% chance for demo)
  if (Math.random() < 0.05) {
    return res.status(409).json({
      error: 'Conflict',
      message: 'Product with this SKU already exists',
      serverVersion: product
    });
  }
  
  db.products.set(product.id, product);
  console.log(`  Created product: ${product.name}`);
  res.status(201).json(product);
});

app.put('/api/products/:id', (req, res) => {
  if (!db.products.has(req.params.id)) {
    return res.status(404).json({ error: 'Not found' });
  }
  const updated = { ...req.body, id: req.params.id, updatedAt: new Date().toISOString() };
  db.products.set(req.params.id, updated);
  res.json(updated);
});

app.delete('/api/products/:id', (req, res) => {
  if (!db.products.has(req.params.id)) {
    return res.status(404).json({ error: 'Not found' });
  }
  db.products.delete(req.params.id);
  res.status(204).send();
});

// ── Sales ─────────────────────────────────────────────────────────────────────

app.get('/api/sales', (req, res) => {
  let sales = [...db.sales.values()];
  if (req.query.from) sales = sales.filter(s => s.soldAt >= req.query.from);
  if (req.query.to) sales = sales.filter(s => s.soldAt <= req.query.to);
  sales.sort((a, b) => new Date(b.soldAt) - new Date(a.soldAt));
  res.json({ data: sales, total: sales.length });
});

app.post('/api/sales', (req, res) => {
  const sale = { ...req.body, syncedAt: new Date().toISOString() };
  db.sales.set(sale.id, sale);
  
  // Update inventory
  const product = db.products.get(sale.productId);
  if (product) {
    product.quantity = Math.max(0, product.quantity - (sale.quantitySold || 1));
    product.updatedAt = new Date().toISOString();
  }
  
  console.log(`  Sale: ${sale.productName} × ${sale.quantitySold} = BWP ${sale.totalAmount}`);
  res.status(201).json(sale);
});

// Force-create sale (conflict override from mobile)
app.post('/api/sales/force', (req, res) => {
  const sale = { ...req.body, forceSynced: true, syncedAt: new Date().toISOString() };
  db.sales.set(sale.id, sale);
  console.log(`  FORCE sale: ${sale.id}`);
  res.status(201).json(sale);
});

// ── Stock movements ───────────────────────────────────────────────────────────

app.post('/api/stock_movements', (req, res) => {
  const movement = { ...req.body, syncedAt: new Date().toISOString() };
  db.stockMovements.set(movement.id, movement);
  res.status(201).json(movement);
});

// ── Orange Money mock ─────────────────────────────────────────────────────────

app.post('/api/payments/orange-money', (req, res) => {
  const { amount, phoneNumber, reference } = req.body;
  
  // Validate phone (Botswana format: 267XXXXXXXX)
  if (!phoneNumber || !phoneNumber.startsWith('267')) {
    return res.status(400).json({
      status: 'failed',
      error: 'Invalid Botswana phone number (must start with 267)'
    });
  }
  
  // 90% success rate
  const success = Math.random() > 0.1;
  
  if (success) {
    const receipt = `OM${Date.now().toString().slice(-8)}`;
    console.log(`  Orange Money: BWP ${amount} → ${phoneNumber} ✓ [${receipt}]`);
    return res.json({
      status: 'success',
      transactionId: reference,
      receiptNumber: receipt,
      timestamp: new Date().toISOString(),
      amount,
      currency: 'BWP',
      phoneNumber,
    });
  }
  
  console.log(`  Orange Money: BWP ${amount} → ${phoneNumber} ✗`);
  res.status(402).json({
    status: 'failed',
    transactionId: reference,
    error: 'Insufficient balance',
    errorCode: 'INSUFFICIENT_FUNDS'
  });
});

app.post('/api/payments/myzaka', (req, res) => {
  const { amount, phoneNumber, reference } = req.body;
  const success = Math.random() > 0.08;
  const receipt = `MZ${Date.now().toString().slice(-8)}`;
  
  console.log(`  MyZaka: BWP ${amount} → ${phoneNumber} ${success ? '✓' : '✗'}`);
  
  if (success) {
    return res.json({
      status: 'success',
      transactionId: reference,
      receiptNumber: receipt,
      amount,
      currency: 'BWP',
    });
  }
  res.status(402).json({ status: 'failed', error: 'Transaction declined' });
});

// ── Sync health ───────────────────────────────────────────────────────────────

app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    products: db.products.size,
    sales: db.sales.size,
  });
});

app.get('/api/sync/status', (req, res) => {
  res.json({
    serverTime: new Date().toISOString(),
    version: '1.0.0',
    features: ['products', 'sales', 'stock_movements', 'orange_money', 'myzaka']
  });
});

// ── Start ─────────────────────────────────────────────────────────────────────

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`\n🛒 SpazaStock mock server running on http://localhost:${PORT}`);
  console.log(`   Products: ${db.products.size} seeded`);
  console.log(`   Endpoints:`);
  console.log(`   GET  /api/products`);
  console.log(`   POST /api/products`);
  console.log(`   POST /api/sales`);
  console.log(`   POST /api/payments/orange-money`);
  console.log(`   POST /api/payments/myzaka`);
  console.log(`   GET  /api/health\n`);
});

module.exports = app;
