require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const bodyParser = require('body-parser');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const sanitize = require('mongo-sanitize');

const app = express();
const server = http.createServer(app);

// Trust proxy for rate limiting
app.set('trust proxy', 1);

const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || '').split(',').map(o => o.trim()).filter(Boolean);
const corsOptions = {
  origin: (origin, cb) => {
    if (!origin || ALLOWED_ORIGINS.includes(origin)) return cb(null, true);
    return cb(null, true); 
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE']
};

app.use(helmet()); 
app.use(cors(corsOptions));
app.use(bodyParser.json({ limit: '32kb' }));

// NoSQL Injection Protection
app.use((req, res, next) => {
  req.body = sanitize(req.body);
  req.query = sanitize(req.query);
  req.params = sanitize(req.params);
  next();
});

app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.originalUrl} ${res.statusCode} - ${Date.now() - start}ms`);
  });
  next();
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'OK', uptime: process.uptime() });
});

const io = new Server(server, { cors: corsOptions });
const PORT = process.env.PORT || 3000;

const requireEnv = (name, { minLength = 1 } = {}) => {
  const value = process.env[name];
  if (!value || value.length < minLength) throw new Error(`${name} must be set.`);
  return value;
};

const MONGODB_URI = requireEnv('MONGODB_URI');
const JWT_SECRET = requireEnv('JWT_SECRET', { minLength: 32 });
const DEFAULT_ADMIN_PASSWORD = process.env.DEFAULT_ADMIN_PASSWORD ?? null;

const registerLimiter = rateLimit({ windowMs: 60 * 60 * 1000, max: 5 });
const loginLimiter = rateLimit({
  windowMs: 30 * 1000, max: 3, skipSuccessfulRequests: true,
  handler: (req, res) => res.status(429).json({ error: 'login_locked' })
});

const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Token missing.' });
  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) return res.status(403).json({ error: 'Invalid token.' });
    req.user = user;
    next();
  });
};

const isAdmin = (req, res, next) => {
  if (req.user && req.user.role === 'admin') next();
  else res.status(403).json({ error: 'Admin rights required.' });
};

const userSchema = new mongoose.Schema({
  username: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  role: { type: String, enum: ['user', 'admin'], default: 'user' },
  lastRecurringSync: { type: String, default: '' },
  displayName: { type: String, default: '' },
  avatarColor: { type: String, default: '0xFF4CAF50' }, // Default Green
  avatarIcon: { type: String, default: 'person' },
  categories: {
    income: { type: [String], default: ['salary', 'freelance', 'bonus', 'investment', 'other'] },
    expense: { type: [String], default: ['food', 'travel', 'shopping', 'bill', 'entertainment', 'health', 'other'] }
  }
});

const transactionSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true },
  username: { type: String, required: true },
  title: { type: String, required: true },
  amount: { type: Number, required: true },
  date: { type: String, required: true },
  isIncome: { type: String, required: true },
  category: { type: String, default: '' },
  note: { type: String, default: '' },
  isRecurring: { type: Boolean, default: false },
  frequency: { type: String, enum: ['none', 'daily', 'weekly', 'monthly', 'yearly'], default: 'none' }
});

const User = mongoose.model('User', userSchema);
const Transaction = mongoose.model('Transaction', transactionSchema);

mongoose.connect(MONGODB_URI).then(async () => {
  const adminUser = await User.findOne({ username: 'admin' });
  if (!adminUser && DEFAULT_ADMIN_PASSWORD) {
    const hashedPassword = await bcrypt.hash(DEFAULT_ADMIN_PASSWORD, 10);
    await User.create({ username: 'admin', password: hashedPassword, role: 'admin' });
  }
});

// --- API Routes ---

app.post('/api/register', registerLimiter, async (req, res) => {
  const { username, password } = req.body;
  try {
    const existingUser = await User.findOne({ username: username.toLowerCase() });
    if (existingUser) return res.status(409).json({ error: 'Username exists' });
    const hashedPassword = await bcrypt.hash(password, 10);
    await User.create({ username: username.toLowerCase(), password: hashedPassword });
    res.json({ message: 'Success' });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.post('/api/login', loginLimiter, async (req, res) => {
  const { username, password } = req.body;
  try {
    const user = await User.findOne({ username: username.toLowerCase() });
    if (!user || !(await bcrypt.compare(password, user.password))) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    const token = jwt.sign({ id: user._id, username: user.username, role: user.role }, JWT_SECRET, { expiresIn: '1d' });
    res.json({ username: user.username, role: user.role, token });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.get('/api/user/profile', authenticateToken, async (req, res) => {
  try {
    const user = await User.findOne({ username: req.user.username }, { password: 0 });
    res.json(user);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.get('/api/user/categories', authenticateToken, async (req, res) => {
  try {
    const user = await User.findOne({ username: req.user.username }, { categories: 1 });
    res.json(user.categories);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.put('/api/user/categories', authenticateToken, async (req, res) => {
  const { income, expense } = req.body;
  try {
    const update = {};
    if (income) update['categories.income'] = income;
    if (expense) update['categories.expense'] = expense;
    await User.updateOne({ username: req.user.username }, { $set: update });
    res.json({ message: 'Success' });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.put('/api/user/profile', authenticateToken, async (req, res) => {
  const { displayName, avatarColor, avatarIcon } = req.body;
  try {
    const update = {};
    if (displayName !== undefined) update.displayName = displayName.trim();
    if (avatarColor !== undefined) update.avatarColor = avatarColor;
    if (avatarIcon !== undefined) update.avatarIcon = avatarIcon;
    
    await User.updateOne({ username: req.user.username }, { $set: update });
    res.json({ message: 'Success' });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.put('/api/user/password', authenticateToken, async (req, res) => {
  const { oldPassword, newPassword } = req.body;
  try {
    const user = await User.findOne({ username: req.user.username });
    if (!user || !(await bcrypt.compare(oldPassword, user.password))) {
      return res.status(401).json({ error: 'Wrong password' });
    }
    user.password = await bcrypt.hash(newPassword, 10);
    await user.save();
    res.json({ message: 'Success' });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.delete('/api/user', authenticateToken, async (req, res) => {
  try {
    await Transaction.deleteMany({ username: req.user.username });
    await User.deleteOne({ username: req.user.username });
    res.json({ message: 'Deleted' });
  } catch (err) { res.status(500).json({ error: err.message }); }
});
const processRecurringTransactions = async (username) => {
  const now = new Date();
  const todayStr = now.toISOString().split('T')[0];

  try {
    const user = await User.findOne({ username });
    if (!user) return;

    // If already synced today, skip
    if (user.lastRecurringSync === todayStr) return;

    const lastSync = user.lastRecurringSync ? new Date(user.lastRecurringSync) : new Date(2020, 0, 1);
    const recurringTemplates = await Transaction.find({ username, isRecurring: true });

    let generatedCount = 0;
    for (const template of recurringTemplates) {
      let nextDate = new Date(template.date);
      // We start checking from the day after the original transaction or last sync
      const startDate = lastSync > nextDate ? lastSync : nextDate;

      let currentCheck = new Date(startDate);
      currentCheck.setHours(0,0,0,0);
      now.setHours(0,0,0,0);

      while (true) {
        // Advance currentCheck based on frequency
        if (template.frequency === 'daily') currentCheck.setDate(currentCheck.getDate() + 1);
        else if (template.frequency === 'weekly') currentCheck.setDate(currentCheck.getDate() + 7);
        else if (template.frequency === 'monthly') currentCheck.setMonth(currentCheck.getMonth() + 1);
        else if (template.frequency === 'yearly') currentCheck.setFullYear(currentCheck.getFullYear() + 1);
        else break;

        if (currentCheck > now) break;

        // Generate instance
        const newId = `${template.id}_${currentCheck.getTime()}`;
        // Check if already exists (to be safe)
        const exists = await Transaction.findOne({ id: newId });
        if (!exists) {
          await Transaction.create({
            id: newId,
            username: template.username,
            title: template.title,
            amount: template.amount,
            date: currentCheck.toISOString(),
            isIncome: template.isIncome,
            category: template.category,
            note: `[Recurring] ${template.note}`,
            isRecurring: false,
            frequency: 'none'
          });
          generatedCount++;
        }
      }
    }

    user.lastRecurringSync = todayStr;
    await user.save();

    if (generatedCount > 0) {
      io.emit('data_changed');
      console.log(`[Recurring] Generated ${generatedCount} items for ${username}`);
    }
  } catch (err) {
    console.error(`[Recurring] Error for ${username}:`, err);
  }
};

// --- Transaction Routes --- (SERVER-SIDE FILTERING & PAGINATION)
app.get('/api/transactions/:username', authenticateToken, async (req, res) => {
  const { username } = req.params;

  // Security check: User can only access their own data unless admin
  if (req.user.username !== username && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Unauthorized access to user data.' });
  }

  // Auto-process recurring items before fetching
  await processRecurringTransactions(username);

  const page = parseInt(req.query.page) || 1;
...

  const limit = parseInt(req.query.limit) || 50;
  const skip = (page - 1) * limit;
  const search = req.query.search || '';
  const isIncome = req.query.isIncome; 
  const category = req.query.category;
  const startDate = req.query.startDate;
  const endDate = req.query.endDate;

  if (req.user.username !== username && req.user.role !== 'admin') return res.status(403).json({ error: 'Forbidden' });

  try {
    const query = { username };
    if (search) {
      query.$or = [{ title: { $regex: search, $options: 'i' } }, { category: { $regex: search, $options: 'i' } }, { note: { $regex: search, $options: 'i' } }];
    }
    if (isIncome !== undefined) query.isIncome = isIncome === 'true' ? 'รายรับ' : 'รายจ่าย';
    if (category) query.category = category;
    if (startDate || endDate) {
      query.date = {};
      if (startDate) query.date.$gte = startDate;
      if (endDate) query.date.$lte = endDate;
    }

    const totalCount = await Transaction.countDocuments(query);
    const rows = await Transaction.find(query).sort({ date: -1 }).skip(skip).limit(limit);

    const allStats = await Transaction.aggregate([
      { $match: { username } }, 
      { $group: {
        _id: null,
        totalIncome: { $sum: { $cond: [{ $or: [{ $eq: ["$isIncome", "รายรับ"] }, { $eq: ["$isIncome", "true"] }, { $eq: ["$isIncome", true] }] }, "$amount", 0] } },
        totalExpense: { $sum: { $cond: [{ $or: [{ $eq: ["$isIncome", "รายรับ"] }, { $eq: ["$isIncome", "true"] }, { $eq: ["$isIncome", true] }] }, 0, "$amount"] } }
      }}
    ]);

    const stats = allStats[0] || { totalIncome: 0, totalExpense: 0 };

    // Calculate 7-day Spending Trend (Ending Today)
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 6);
    sevenDaysAgo.setHours(0,0,0,0);

    const trendStats = await Transaction.aggregate([
      { $match: { 
        username, 
        isIncome: { $in: ["รายจ่าย", "false", false] },
        date: { $gte: sevenDaysAgo.toISOString() }
      }},
      { $group: {
        _id: { $substr: ["$date", 0, 10] },
        amount: { $sum: "$amount" }
      }},
      { $sort: { _id: 1 } }
    ]);

    // Fill missing days with 0
    const trend = [];
    for (let i = 0; i < 7; i++) {
      const d = new Date(sevenDaysAgo);
      d.setDate(d.getDate() + i);
      const dateStr = d.toISOString().split('T')[0];
      const match = trendStats.find(t => t._id === dateStr);
      trend.push(match ? match.amount : 0);
    }

    // Calculate 6-Month Spending Trend
    const sixMonthsAgo = new Date();
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 5);
    sixMonthsAgo.setDate(1);
    sixMonthsAgo.setHours(0,0,0,0);

    const monthlyStats = await Transaction.aggregate([
      { $match: { 
        username, 
        isIncome: { $in: ["รายจ่าย", "false", false] },
        date: { $gte: sixMonthsAgo.toISOString() }
      }},
      { $group: {
        _id: { $substr: ["$date", 0, 7] }, // YYYY-MM
        amount: { $sum: "$amount" }
      }},
      { $sort: { _id: 1 } }
    ]);

    // Fill missing months with 0
    const mTrend = [];
    for (let i = 0; i < 6; i++) {
      const d = new Date(sixMonthsAgo);
      d.setMonth(d.getMonth() + i);
      const monthStr = d.toISOString().split('T')[0].substring(0, 7);
      const match = monthlyStats.find(t => t._id === monthStr);
      mTrend.push({
        month: monthStr,
        amount: match ? match.amount : 0
      });
    }

    res.json({
      transactions: rows.map(r => ({ id: r.id, title: r.title, amount: r.amount, date: r.date, isIncome: r.isIncome === 'รายรับ' || r.isIncome === true, category: r.category, note: r.note, isRecurring: r.isRecurring || false, frequency: r.frequency || 'none' })),
      metadata: { 
        total: totalCount, page, limit, hasMore: skip + rows.length < totalCount,
        summary: {
          income: stats.totalIncome,
          expense: stats.totalExpense,
          balance: stats.totalIncome - stats.totalExpense,
          trend: trend,
          monthlyTrend: mTrend
        }
      }
    });

  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.post('/api/transactions/:username', authenticateToken, async (req, res) => {
  const { id, title, amount, date, isIncome, category, note, isRecurring, frequency } = req.body;
  try {
    await Transaction.create({ 
      id, username: req.params.username, title, amount, date, 
      isIncome: isIncome ? 'รายรับ' : 'รายจ่าย', category, note,
      isRecurring: isRecurring || false, frequency: frequency || 'none'
    });
    io.emit('data_changed');
    res.status(201).json({ message: 'Created' });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.delete('/api/transactions/:username/:id', authenticateToken, async (req, res) => {
  try {
    await Transaction.deleteOne({ id: req.params.id, username: req.params.username });
    io.emit('data_changed');
    res.json({ message: 'Deleted' });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.put('/api/transactions/:username/:id', authenticateToken, async (req, res) => {
  const { title, amount, date, isIncome, category, note, isRecurring, frequency } = req.body;
  try {
    await Transaction.updateOne({ id: req.params.id, username: req.params.username }, { 
      $set: { title, amount, date, isIncome: isIncome ? 'รายรับ' : 'รายจ่าย', category, note, isRecurring, frequency } 
    });
    io.emit('data_changed');
    res.json({ message: 'Updated' });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// --- Admin Routes --- (SERVER-SIDE FILTERING & PAGINATION)
app.get('/api/admin/stats', authenticateToken, isAdmin, async (req, res) => {
  try {
    const totalUsers = await User.countDocuments();
    const totalTransactions = await Transaction.countDocuments();
    
    const allStats = await Transaction.aggregate([
      { $group: {
        _id: null,
        totalIncome: { $sum: { $cond: [{ $or: [{ $eq: ["$isIncome", "รายรับ"] }, { $eq: ["$isIncome", "true"] }, { $eq: ["$isIncome", true] }] }, "$amount", 0] } },
        totalExpense: { $sum: { $cond: [{ $or: [{ $eq: ["$isIncome", "รายรับ"] }, { $eq: ["$isIncome", "true"] }, { $eq: ["$isIncome", true] }] }, 0, "$amount"] } }
      }}
    ]);

    const stats = allStats[0] || { totalIncome: 0, totalExpense: 0 };
    
    res.json({
      totalUsers,
      totalTransactions,
      totalIncome: stats.totalIncome,
      totalExpense: stats.totalExpense,
      totalBalance: stats.totalIncome - stats.totalExpense
    });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.get('/api/admin/transactions', authenticateToken, isAdmin, async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 100;
  const skip = (page - 1) * limit;
  const search = req.query.search || '';
  const isIncome = req.query.isIncome;
  const username = req.query.username;

  try {
    const query = {};
    if (search) {
      query.$or = [{ title: { $regex: search, $options: 'i' } }, { username: { $regex: search, $options: 'i' } }, { category: { $regex: search, $options: 'i' } }, { note: { $regex: search, $options: 'i' } }];
    }
    if (isIncome !== undefined) query.isIncome = isIncome === 'true' ? 'รายรับ' : 'รายจ่าย';
    if (username) query.username = username;

    const totalCount = await Transaction.countDocuments(query);
    const rows = await Transaction.find(query).sort({ date: -1 }).skip(skip).limit(limit);

    res.json({
      transactions: rows.map(r => ({ 
        id: r.id, username: r.username, title: r.title, amount: r.amount, date: r.date,
        isIncome: r.isIncome === 'รายรับ' || r.isIncome === true,
        category: r.category, note: r.note,
        isRecurring: r.isRecurring || false, frequency: r.frequency || 'none'
      })),
      metadata: { total: totalCount, page, limit, hasMore: skip + rows.length < totalCount }
    });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.get('/api/admin/users', authenticateToken, isAdmin, async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 50;
  const skip = (page - 1) * limit;
  const search = req.query.search || '';
  try {
    const query = search ? { username: { $regex: search, $options: 'i' } } : {};
    const totalCount = await User.countDocuments(query);
    const users = await User.find(query, { username: 1, role: 1, _id: 0 }).skip(skip).limit(limit);
    res.json({ users, metadata: { total: totalCount, page, limit, hasMore: skip + users.length < totalCount } });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.put('/api/admin/users/:username/role', authenticateToken, isAdmin, async (req, res) => {
  const { role } = req.body;
  if (!['user', 'admin'].includes(role)) return res.status(400).json({ error: 'Invalid role' });
  try {
    if (req.params.username === 'admin' && role !== 'admin') return res.status(403).json({ error: 'Cannot demote primary admin' });
    await User.updateOne({ username: req.params.username }, { $set: { role } });
    res.json({ message: 'Role updated' });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.delete('/api/admin/users/:username', authenticateToken, isAdmin, async (req, res) => {
  try {
    if (req.params.username === 'admin') return res.status(403).json({ error: 'Cannot delete primary admin' });
    await Transaction.deleteMany({ username: req.params.username });
    await User.deleteOne({ username: req.params.username });
    io.emit('data_changed');
    res.json({ message: 'Deleted' });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.delete('/api/admin/transactions/:id', authenticateToken, isAdmin, async (req, res) => {
  try {
    await Transaction.deleteOne({ id: req.params.id });
    io.emit('data_changed');
    res.json({ message: 'Deleted' });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.put('/api/admin/transactions/:id', authenticateToken, isAdmin, async (req, res) => {
  const { title, amount, date, isIncome, category, note, isRecurring, frequency } = req.body;
  try {
    await Transaction.updateOne({ id: req.params.id }, { 
      $set: { title, amount, date, isIncome: isIncome ? 'รายรับ' : 'รายจ่าย', category, note, isRecurring, frequency } 
    });
    io.emit('data_changed');
    res.json({ message: 'Updated' });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

server.listen(PORT, '0.0.0.0', () => console.log(`Running on ${PORT}`));
