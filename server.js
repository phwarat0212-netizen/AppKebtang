const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const bodyParser = require('body-parser');
const cors = require('cors');
const path = require('path');
const http = require('http');
const { Server } = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE']
  }
});

const PORT = 3000;

app.use(cors());
app.use(bodyParser.json());

// Socket.IO Connection
io.on('connection', (socket) => {
  console.log('A user connected:', socket.id);
  socket.on('disconnect', () => {
    console.log('User disconnected:', socket.id);
  });
});

// Initialize SQLite database
const fs = require('fs');
const dataDir = path.resolve(__dirname, '.data');
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir);
}
const dbPath = path.resolve(dataDir, 'database.db');

const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('Error opening database', err.message);
  } else {
    console.log('Connected to the SQLite database.');
    
    // Create Users table
    db.run(`CREATE TABLE IF NOT EXISTS users (
      username TEXT PRIMARY KEY,
      password TEXT NOT NULL
    )`, () => {
      // Create default admin if not exists
      db.run(`INSERT OR IGNORE INTO users (username, password) VALUES (?, ?)`, ['admin', '1234']);
    });

    // Create Transactions table
    db.run(`CREATE TABLE IF NOT EXISTS transactions (
      id TEXT PRIMARY KEY,
      username TEXT NOT NULL,
      title TEXT NOT NULL,
      amount REAL NOT NULL,
      date TEXT NOT NULL,
      isIncome TEXT NOT NULL,
      category TEXT
    )`, () => {
      // Upgrade existing table to add category if it's missing
      db.run(`ALTER TABLE transactions ADD COLUMN category TEXT DEFAULT ''`, (err) => {
        // Ignore error if column already exists
      });
      // Upgrade existing data to text
      db.run(`UPDATE transactions SET isIncome = 'รายรับ' WHERE isIncome = '1'`);
      db.run(`UPDATE transactions SET isIncome = 'รายจ่าย' WHERE isIncome = '0'`);
    });
  }
});

// API Routes

// --- Auth Routes ---
app.post('/api/register', (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) {
    return res.status(400).json({ error: 'Username and password required' });
  }
  const sql = 'INSERT INTO users (username, password) VALUES (?, ?)';
  db.run(sql, [username, password], function(err) {
    if (err) {
      if (err.message.includes('UNIQUE constraint failed')) {
        return res.status(409).json({ error: 'Username already exists' });
      }
      return res.status(500).json({ error: err.message });
    }
    io.emit('data_changed'); // Notify real-time update
    res.status(201).json({ message: 'User registered successfully' });
  });
});

app.post('/api/login', (req, res) => {
  const { username, password } = req.body;
  const sql = 'SELECT * FROM users WHERE username = ? AND password = ?';
  db.get(sql, [username, password], (err, row) => {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    if (row) {
      res.json({ message: 'Login successful', username: row.username });
    } else {
      res.status(401).json({ error: 'Invalid credentials' });
    }
  });
});

// --- Transaction Routes ---
app.get('/api/transactions/:username', (req, res) => {
  const { username } = req.params;
  const sql = 'SELECT * FROM transactions WHERE username = ? ORDER BY date DESC';
  db.all(sql, [username], (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    // Convert isIncome back to boolean and ensure category is a string
    const transactions = rows.map(row => ({
      ...row,
      isIncome: row.isIncome === 'รายรับ' || row.isIncome === 1 || row.isIncome === '1',
      category: row.category || ''
    }));
    res.json(transactions);
  });
});

// 2. Add a new transaction
app.post('/api/transactions/:username', (req, res) => {
  const { username } = req.params;
  const { id, title, amount, date, isIncome, category } = req.body;
  const sql = 'INSERT INTO transactions (id, username, title, amount, date, isIncome, category) VALUES (?, ?, ?, ?, ?, ?, ?)';
  const params = [id, username, title, amount, date, isIncome ? 'รายรับ' : 'รายจ่าย', category || ''];
  db.run(sql, params, function(err) {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    io.emit('data_changed'); // Notify real-time update
    res.status(201).json({ message: 'Transaction added successfully' });
  });
});

// 3. Delete a transaction
app.delete('/api/transactions/:username/:id', (req, res) => {
  const { username, id } = req.params;
  const sql = 'DELETE FROM transactions WHERE username = ? AND id = ?';
  db.run(sql, [username, id], function(err) {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    io.emit('data_changed'); // Notify real-time update
    res.json({ message: 'Transaction deleted successfully', changes: this.changes });
  });
});

// 4. Admin: Get ALL transactions
app.get('/api/admin/transactions', (req, res) => {
  const sql = 'SELECT * FROM transactions ORDER BY date DESC';
  db.all(sql, [], (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    const transactions = rows.map(row => ({
      ...row,
      isIncome: row.isIncome === 'รายรับ' || row.isIncome === 1 || row.isIncome === '1',
      category: row.category || ''
    }));
    res.json(transactions);
  });
});

// 5. Admin: Delete a transaction
app.delete('/api/admin/transactions/:id', (req, res) => {
  const { id } = req.params;
  const sql = 'DELETE FROM transactions WHERE id = ?';
  db.run(sql, [id], function(err) {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    io.emit('data_changed'); // Notify real-time update
    res.json({ message: 'Transaction deleted successfully', changes: this.changes });
  });
});

// 6. Admin: Edit a transaction
app.put('/api/admin/transactions/:id', (req, res) => {
  const { id } = req.params;
  const { title, amount, date, isIncome, category } = req.body;
  const sql = 'UPDATE transactions SET title = ?, amount = ?, date = ?, isIncome = ?, category = ? WHERE id = ?';
  const params = [title, amount, date, isIncome ? 'รายรับ' : 'รายจ่าย', category || '', id];
  db.run(sql, params, function(err) {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    io.emit('data_changed'); // Notify real-time update
    res.json({ message: 'Transaction updated successfully', changes: this.changes });
  });
});

// 7. Admin: Get ALL users
app.get('/api/admin/users', (req, res) => {
  const sql = 'SELECT username, password FROM users';
  db.all(sql, [], (err, rows) => {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    res.json(rows);
  });
});

// 8. Admin: Delete a user (and their transactions)
app.delete('/api/admin/users/:username', (req, res) => {
  const { username } = req.params;
  if (username === 'admin') {
    return res.status(403).json({ error: 'Cannot delete admin account' });
  }
  
  db.serialize(() => {
    db.run('DELETE FROM transactions WHERE username = ?', [username]);
    db.run('DELETE FROM users WHERE username = ?', [username], function(err) {
      if (err) {
        return res.status(500).json({ error: err.message });
      }
      io.emit('data_changed'); // Notify real-time update
      res.json({ message: 'User deleted successfully', changes: this.changes });
    });
  });
});

// Start the server
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
