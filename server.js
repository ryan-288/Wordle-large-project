const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const MongoClient = require('mongodb').MongoClient;
const bcrypt = require('bcrypt');

const app = express();
app.use(cors());
app.use(bodyParser.json());

const url = 'mongodb+srv://TheBeast:1231ENGINEERING@wordplay2d.nhc27zd.mongodb.net/wordle_db?retryWrites=true&w=majority';
const client = new MongoClient(url);
client.connect();

app.post('/api/login', async (req, res, next) => {
  // incoming: username, password
  // outgoing: id, email, firstName, lastName, error

  try {
    const { username, password } = req.body;

    // Validate input
    if (!username || !password) {
      return res.status(400).json({
        id: -1,
        email: '',
        firstName: '',
        lastName: '',
        error: 'Username and password are required'
      });
    }

    const db = client.db('wordle_db');
    const user = await db.collection('users').findOne({ username: username });

    // User not found
    if (!user) {
      return res.status(401).json({
        id: -1,
        email: '',
        firstName: '',
        lastName: '',
        error: 'Invalid credentials'
      });
    }

    // Verify password using bcrypt
    const isMatch = await bcrypt.compare(password, user.password);

    if (!isMatch) {
      return res.status(401).json({
        id: -1,
        email: '',
        firstName: '',
        lastName: '',
        error: 'Invalid credentials'
      });
    }

    // Successful login
    const ret = {
      id: user._id.toString(),
      email: user.email || '',
      firstName: user.first_name || '',
      lastName: user.last_name || '',
      error: ''
    };

    res.status(200).json(ret);

  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      id: -1,
      email: '',
      firstName: '',
      lastName: '',
      error: 'Server error occurred'
    });
  }
});

app.get('/health', (_req, res) => res.send('ok\n'));


app.post('/api/register', async (req, res, next) => {
  // incoming: email, username, firstName, lastName, password
  // outgoing: id, email, firstName, lastName, error
  try {
    const { email, username, firstName, lastName, password } = req.body;

    // Validate input
    if (!email || !username || !firstName || !lastName || !password) {
      return res.status(400).json({
        id: -1,
        error: 'All fields are required'
      });
    }

    // Basic email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({
        id: -1,
        error: 'Invalid email format'
      });
    }

    // Password strength validation (minimum 6 characters)
    if (password.length < 6) {
      return res.status(400).json({
        id: -1,
        error: 'Password must be at least 6 characters long'
      });
    }

    const db = client.db('wordle_db');
    const users = db.collection('users');

    // Check if username already exists
    const existingUsername = await users.findOne({ username: username });
    if (existingUsername) {
      return res.status(409).json({
        id: -1,
        error: 'Username already exists'
      });
    }

    // Check if email already exists
    const existingEmail = await users.findOne({ email: email });
    if (existingEmail) {
      return res.status(409).json({
        id: -1,
        error: 'Email already exists'
      });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create new user document - EXACTLY matching createUser.js structure
    const newUser = {
      email: email,
      username: username,
      first_name: firstName,
      last_name: lastName,
      password: hashedPassword,
      email_verified: false,
      games_played: 0,
      games_won: 0,
      avg_time_per_win: parseFloat((0).toFixed(1)),
      average_guesses_per_win: parseFloat((0).toFixed(1)),
      words_created: 0,
      words_shared: 0
    };

    // Insert user into database
    const result = await users.insertOne(newUser);

    // Successful registration
    const ret = {
      id: result.insertedId.toString(),
      email: email,
      firstName: firstName,
      lastName: lastName,
      error: 'Successfully registered!\n'
    };

    res.status(201).json(ret);
  } catch (error) {
    console.error('Registration error: ', error);
    res.status(500).json({
      id: -1,
      email: '',
      firstName: '',
      lastName: '',
      error: 'Server error occurred!\n'
    });
  }
});


app.listen(5000, '0.0.0.0', () => {
  console.log('Server running on port 5000');
});
