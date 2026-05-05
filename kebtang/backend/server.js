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

// Security Middlewares
app.use(helmet()); // Set security-related HTTP headers
app.use(cors({
  origin: '*', // In production, replace with specific domain
  methods: ['GET', 'POST', 'PUT', 'DELETE']
}));
app.use(bodyParser.json());

const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE']
  }
});

const PORT = process.env.PORT || 3000;
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/kebtang';
const JWT_SECRET = process.env.JWT_SECRET || 'fallback_secret_for_dev_only';

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
  if (req.user && req.user.username === 'admin') {
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
  password: { type: String, required: true }
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
    
    // Create or Update default admin
    const adminUser = await User.findOne({ username: 'admin' });
    const defaultPass = process.env.DEFAULT_ADMIN_PASSWORD || 'admin12345678';
    
    if (!adminUser) {
      const hashedPassword = await bcrypt.hash(defaultPass, 10);
      await User.create({ username: 'admin', password: hashedPassword });
      console.log('Default admin created.');
    } else {
      // Force sync password with .env if it doesn't match
      let isMatch = false;
      try {
        isMatch = await bcrypt.compare(defaultPass, adminUser.password);
      } catch (e) { isMatch = false; }

      if (!isMatch && adminUser.password !== defaultPass) {
        const hashedPassword = await bcrypt.hash(defaultPass, 10);
        adminUser.password = hashedPassword;
        await adminUser.save();
        console.log('Admin password updated to match .env');
      }
    }
  })
  .catch((err) => {
    console.error('Error connecting to MongoDB:', err.message);
  });

// API Routes

// --- Auth Routes ---
app.post('/api/register', registerLimiter, async (req, res) => {
  const { username: rawUsername, password } = req.body;
  const username = rawUsername ? rawUsername.toLowerCase() : '';
  
  if (!username || !password || password.length < 8) {
    return res.status(400).json({ error: 'Username and password (min 8 chars) required' });
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

    // Fallback: Check if it's an old plaintext password
    if (!isMatch && user.password === password) {
      // Migrate to hashed password
      const newHash = await bcrypt.hash(password, 10);
      user.password = newHash;
      await user.save();
      isMatch = true;
      console.log(`User ${username} migrated to hashed password.`);
    }

    if (isMatch) {
      const token = jwt.sign(
        { id: user._id, username: user.username },
        JWT_SECRET,
        { expiresIn: '7d' }
      );
      res.json({ message: 'Login successful', username: user.username, token });
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
  if (req.user.username !== username && req.user.username !== 'admin') {
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
  const { id, title, amount, date, isIncome, category, note } = req.body;
  
  if (req.user.username !== username && req.user.username !== 'admin') {
    return res.status(403).json({ error: 'Unauthorized access.' });
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
  
  if (req.user.username !== username && req.user.username !== 'admin') {
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
  const { title, amount, date, isIncome, category, note } = req.body;
  
  if (req.user.username !== username && req.user.username !== 'admin') {
    return res.status(403).json({ error: 'Unauthorized access.' });
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
  const { title, amount, date, isIncome, category, note } = req.body;
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
    const users = await User.find({}, { username: 1, _id: 0 }); // Don't send hashed passwords
    res.json(users);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/admin/users/:username', authenticateToken, isAdmin, async (req, res) => {
  const { username } = req.params;
  if (username === 'admin') {
    return res.status(403).json({ error: 'Cannot delete admin account' });
  }
  
  try {
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
