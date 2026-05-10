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

const app = express();
const server = http.createServer(app);

// Trust the first proxy (Render/Railway terminate TLS upstream).
// Required so express-rate-limit sees the real client IP from X-Forwarded-For.
app.set('trust proxy', 1);

// Allowed CORS origins — comma-separated list in env (e.g. "https://admin.kebtang.com,https://kebtang.com").
// Empty by default: mobile clients don't send Origin and aren't affected; browsers from unlisted origins are blocked.
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map(o => o.trim())
  .filter(Boolean);

const corsOptions = {
  origin: (origin, cb) => {
    // Requests without an Origin header (mobile apps, curl, server-to-server) are allowed.
    if (!origin) return cb(null, true);
    if (ALLOWED_ORIGINS.includes(origin)) return cb(null, true);
    return cb(new Error('Origin not allowed by CORS'));
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE']
};

// Security Middlewares
app.use(helmet()); // Set security-related HTTP headers
app.use(cors(corsOptions));
app.use(bodyParser.json({ limit: '32kb' }));

const io = new Server(server, {
  cors: corsOptions
});

const PORT = process.env.PORT || 3000;

const requireEnv = (name, { minLength = 1 } = {}) => {
  const value = process.env[name];
  if (!value || value.length < minLength) {
    throw new Error(`${name} must be set and at least ${minLength} characters long.`);
  }
  return value;
};

const MONGODB_URI = requireEnv('MONGODB_URI');
const JWT_SECRET = requireEnv('JWT_SECRET', { minLength: 32 });
const DEFAULT_ADMIN_PASSWORD = process.env.DEFAULT_ADMIN_PASSWORD ?? null;

if (DEFAULT_ADMIN_PASSWORD && DEFAULT_ADMIN_PASSWORD.length < 12) {
  throw new Error('DEFAULT_ADMIN_PASSWORD must be at least 12 characters long.');
}

// Rate Limiting for Registration (Prevention of spam accounts)
const registerLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 5, // Limit each IP to 5 registrations per hour
  message: { error: 'สมัครสมาชิกบ่อยเกินไป กรุณาลองใหม่ในภายหลัง' }
});

// Login Brute-force Protection (3 attempts per 30 seconds)
const loginLimiter = rateLimit({
  windowMs: 30 * 1000, // 30 seconds window
  max: 3, // 3 failed attempts
  skipSuccessfulRequests: true, // Only count 4xx/5xx responses
  handler: (req, res) => {
    res.status(429).json({ 
      error: 'login_locked',
      message: 'ลองผิดเกิน 3 ครั้ง กรุณารอ 30 วินาทีก่อนลองใหม่' 
    });
  }
});

// Auth Middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) return res.status(401).json({ error: 'Access denied. Token missing.' });

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) return res.status(403).json({ error: 'Invalid or expired token.' });
    req.user = user;
    next();
  });
};

const isAdmin = (req, res, next) => {
  if (req.user && req.user.role === 'admin') {
    next();
  } else {
    res.status(403).json({ error: 'Access denied. Admin rights required.' });
  }
};

// Socket.IO Connection
io.on('connection', (socket) => {
  console.log('A user connected:', socket.id);
  socket.on('disconnect', () => {
    console.log('User disconnected:', socket.id);
  });
});

// Mongoose Schemas and Models
const userSchema = new mongoose.Schema({
  username: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  role: { type: String, enum: ['user', 'admin'], default: 'user' }
});

const transactionSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true },
  username: { type: String, required: true },
  title: { type: String, required: true },
  amount: { type: Number, required: true },
  date: { type: String, required: true },
  isIncome: { type: String, required: true },
  category: { type: String, default: '' },
  note: { type: String, default: '' }
});

const User = mongoose.model('User', userSchema);
const Transaction = mongoose.model('Transaction', transactionSchema);

// Initialize MongoDB database
mongoose.connect(MONGODB_URI)
  .then(async () => {
    console.log('Connected to the MongoDB database.');
    
    // Create or update admin only when an explicit password is configured.
    const adminUser = await User.findOne({ username: 'admin' });
    
    if (!adminUser) {
      if (!DEFAULT_ADMIN_PASSWORD) {
        throw new Error('DEFAULT_ADMIN_PASSWORD must be set before the initial admin user can be created.');
      }
      const hashedPassword = await bcrypt.hash(DEFAULT_ADMIN_PASSWORD, 10);
      await User.create({ username: 'admin', password: hashedPassword, role: 'admin' });
      console.log('Default admin created.');
    } else {
      // Backfill role for admin accounts created before the role field existed.
      if (adminUser.role !== 'admin') {
        adminUser.role = 'admin';
        await adminUser.save();
        console.log('Admin role backfilled.');
      }
      if (DEFAULT_ADMIN_PASSWORD) {
        let isMatch = false;
        try {
          isMatch = await bcrypt.compare(DEFAULT_ADMIN_PASSWORD, adminUser.password);
        } catch (e) { isMatch = false; }

        if (!isMatch) {
          const hashedPassword = await bcrypt.hash(DEFAULT_ADMIN_PASSWORD, 10);
          adminUser.password = hashedPassword;
          await adminUser.save();
          console.log('Admin password updated to match .env');
        }
      }
    }
  })
  .catch((err) => {
    console.error('Error connecting to MongoDB:', err.message);
  });

// --- Validation helpers ---
const isNonEmptyString = (v, max) =>
  typeof v === 'string' && v.length > 0 && v.length <= max;

const isOptionalString = (v, max) =>
  v === undefined || v === null || (typeof v === 'string' && v.length <= max);

const validateUsernameFormat = (v) =>
  typeof v === 'string' && /^[a-z0-9_]{3,30}$/.test(v);

const validateTransactionPayload = (body, { requireId }) => {
  const { id, title, amount, date, isIncome, category, note } = body || {};

  if (requireId && !isNonEmptyString(id, 100)) {
    return 'Invalid id (string, 1-100 chars required)';
  }
  if (!isNonEmptyString(title, 200)) {
    return 'Invalid title (string, 1-200 chars required)';
  }
  if (typeof amount !== 'number' || !Number.isFinite(amount) || amount < 0 || amount > 1e12) {
    return 'Invalid amount (finite number, 0 to 1e12)';
  }
  if (!isNonEmptyString(date, 64) || Number.isNaN(Date.parse(date))) {
    return 'Invalid date (parseable ISO date string required)';
  }
  if (typeof isIncome !== 'boolean') {
    return 'Invalid isIncome (boolean required)';
  }
  if (!isOptionalString(category, 100)) {
    return 'Invalid category (string, max 100 chars)';
  }
  if (!isOptionalString(note, 1000)) {
    return 'Invalid note (string, max 1000 chars)';
  }
  return null;
};

// API Routes

// --- Auth Routes ---
app.post('/api/register', registerLimiter, async (req, res) => {
  const { username: rawUsername, password } = req.body || {};
  const username = typeof rawUsername === 'string' ? rawUsername.toLowerCase() : '';

  if (!validateUsernameFormat(username)) {
    return res.status(400).json({ error: 'Invalid username (3-30 chars, lowercase letters/digits/underscore only)' });
  }
  if (typeof password !== 'string' || password.length < 8 || password.length > 200) {
    return res.status(400).json({ error: 'Invalid password (8-200 chars required)' });
  }
  
  try {
    const existingUser = await User.findOne({ username });
    if (existingUser) {
      return res.status(409).json({ error: 'Username already exists' });
    }
    
    const hashedPassword = await bcrypt.hash(password, 10);
    await User.create({ username, password: hashedPassword });
    
    io.emit('data_changed'); 
    res.status(201).json({ message: 'User registered successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/login', loginLimiter, async (req, res) => {
  const { username: rawUsername, password } = req.body;
  const username = rawUsername ? rawUsername.toLowerCase() : '';
  
  try {
    const user = await User.findOne({ username });
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    let isMatch = false;
    try {
      isMatch = await bcrypt.compare(password, user.password);
    } catch (e) {
      isMatch = false;
    }

    if (isMatch) {
      const token = jwt.sign(
        { id: user._id, username: user.username, role: user.role || 'user' },
        JWT_SECRET,
        { expiresIn: '1d' }
      );
      res.json({ message: 'Login successful', username: user.username, role: user.role || 'user', token });
    } else {
      res.status(401).json({ error: 'Invalid credentials' });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- Transaction Routes --- (Protected by JWT)
app.get('/api/transactions/:username', authenticateToken, async (req, res) => {
  const { username } = req.params;
  
  // Security check: User can only access their own data unless admin
  if (req.user.username !== username && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Unauthorized access to user data.' });
  }
  
  try {
    const rows = await Transaction.find({ username }).sort({ date: -1 });
    const transactions = rows.map(row => ({
      id: row.id,
      username: row.username,
      title: row.title,
      amount: row.amount,
      date: row.date,
      isIncome: row.isIncome === 'รายรับ' || row.isIncome === '1' || row.isIncome === true,
      category: row.category || '',
      note: row.note || '' 
    }));
    res.json(transactions);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/transactions/:username', authenticateToken, async (req, res) => {
  const { username } = req.params;
  const { id, title, amount, date, isIncome, category, note } = req.body || {};

  if (req.user.username !== username && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Unauthorized access.' });
  }

  const validationError = validateTransactionPayload(req.body, { requireId: true });
  if (validationError) {
    return res.status(400).json({ error: validationError });
  }

  try {
    const newTx = new Transaction({
      id,
      username,
      title,
      amount,
      date,
      isIncome: isIncome ? 'รายรับ' : 'รายจ่าย',
      category: category || '',
      note: note || ''
    });
    
    await newTx.save();
    io.emit('data_changed'); 
    res.status(201).json({ message: 'Transaction added successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/transactions/:username/:id', authenticateToken, async (req, res) => {
  const { username, id } = req.params;
  
  if (req.user.username !== username && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Unauthorized access.' });
  }

  try {
    const result = await Transaction.deleteOne({ id, username });
    if (result.deletedCount > 0) {
      io.emit('data_changed');
      res.json({ message: 'Transaction deleted successfully' });
    } else {
      res.status(404).json({ error: 'Transaction not found' });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/transactions/:username/:id', authenticateToken, async (req, res) => {
  const { username, id } = req.params;
  const { title, amount, date, isIncome, category, note } = req.body || {};

  if (req.user.username !== username && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Unauthorized access.' });
  }

  const validationError = validateTransactionPayload(req.body, { requireId: false });
  if (validationError) {
    return res.status(400).json({ error: validationError });
  }

  try {
    const result = await Transaction.updateOne(
      { username, id },
      { 
        $set: { 
          title, 
          amount, 
          date, 
          isIncome: isIncome ? 'รายรับ' : 'รายจ่าย', 
          category, 
          note 
        } 
      }
    );
    
    io.emit('data_changed'); 
    res.json({ message: 'Transaction updated successfully', modifiedCount: result.modifiedCount });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- Admin Routes --- (Protected by JWT + Admin check)
app.get('/api/admin/transactions', authenticateToken, isAdmin, async (req, res) => {
  try {
    const rows = await Transaction.find().sort({ date: -1 });
    const transactions = rows.map(row => ({
      id: row.id,
      username: row.username,
      title: row.title,
      amount: row.amount,
      date: row.date,
      isIncome: row.isIncome === 'รายรับ' || row.isIncome === '1' || row.isIncome === true,
      category: row.category || '',
      note: row.note || ''
    }));
    res.json(transactions);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/admin/transactions/:id', authenticateToken, isAdmin, async (req, res) => {
  const { id } = req.params;
  try {
    const result = await Transaction.deleteOne({ id });
    io.emit('data_changed');
    res.json({ message: 'Transaction deleted successfully', deletedCount: result.deletedCount });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/admin/transactions/:id', authenticateToken, isAdmin, async (req, res) => {
  const { id } = req.params;
  const { title, amount, date, isIncome, category, note } = req.body || {};

  const validationError = validateTransactionPayload(req.body, { requireId: false });
  if (validationError) {
    return res.status(400).json({ error: validationError });
  }

  try {
    const result = await Transaction.updateOne(
      { id },
      { 
        $set: {
          title, amount, date, 
          isIncome: isIncome ? 'รายรับ' : 'รายจ่าย',
          category: category || '',
          note: note || ''
        }
      }
    );
    io.emit('data_changed');
    res.json({ message: 'Transaction updated by admin', modifiedCount: result.modifiedCount });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/admin/users', authenticateToken, isAdmin, async (req, res) => {
  try {
    const users = await User.find({}, { username: 1, role: 1, _id: 0 }); // Don't send hashed passwords
    res.json(users);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/admin/users/:username', authenticateToken, isAdmin, async (req, res) => {
  const { username } = req.params;

  try {
    const target = await User.findOne({ username });
    if (!target) {
      return res.status(404).json({ error: 'User not found' });
    }
    if (target.role === 'admin') {
      return res.status(403).json({ error: 'Cannot delete an admin account' });
    }

    await Transaction.deleteMany({ username });
    const result = await User.deleteOne({ username });
    io.emit('data_changed');
    res.json({ message: 'User deleted successfully', deletedCount: result.deletedCount });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Start the server
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running on port ${PORT}`);
});
