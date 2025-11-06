const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const MongoClient = require('mongodb').MongoClient;
const bcrypt = require('bcrypt');
const crypto = require('crypto'); // Node's built in crypto module. Will generate a secure token

// import the send email function
const { sendVerificationEmail } = require('./utility/sendEmail.js');
const { generateToken, generateVerificationCode } = require('./utility/authTokens.js');


const app = express();
app.use(cors());
app.use(bodyParser.json());

const url = 'mongodb+srv://TheBeast:1231ENGINEERING@wordplay2d.nhc27zd.mongodb.net/wordle_db?retryWrites=true&w=majority&tls=true';
const client = new MongoClient(url, {
  serverSelectionTimeoutMS: 10000,
  socketTimeoutMS: 45000,
  tls: true,
  tlsInsecure: false,
});

// Connect to MongoDB
let db;
client.connect()
  .then(() => {
    console.log('Connected to MongoDB');
    db = client.db('wordle_db');
  })
  .catch(err => {
    console.error('MongoDB connection error:', err);
  });

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

    // Check if email is verified
    if (user.email_verified === false) {
      return res.status(403).json({
        id: -1,
        email: user.email || '',
        firstName: '',
        lastName: '',
        error: 'Verification still needed. Please check your email to verify your account.'
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

// testing purposes
app.get('/health', (_req, res) => res.send('ok\n'));


app.post('/api/auth/verify-email-code', async (req, res) => {
  try {
    const { email, code } = req.body;

    if (!email || !code) {
      return res.status(400).json({ error: 'Email and code are required.' });
    }

    const users = db.collection('users');
    const authTokens = db.collection('auth_tokens');

    // 1) Find user
    const user = await users.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found.' });
    }

    if (user.email_verified) {
      return res.status(400).json({ error: 'Email is already verified.' });
    }

    // 2) Find latest verification code for this user
    const record = await authTokens.findOne(
      { user_id: user._id, type: 'email_verify_code' },
      { sort: { created_at: -1 } }
    );

    if (!record) {
      return res.status(400).json({ error: 'No verification code found. Please request a new one.' });
    }

    // 3) Check expiration
    const now = new Date();
    if (record.expires_at < now) {
      return res.status(400).json({ error: 'Verification code has expired. Please request a new one.' });
    }

    // 4) (Optional) check attempts limit
    if (record.attempts >= 5) {
      return res.status(429).json({ error: 'Too many incorrect attempts. Request a new code.' });
    }

    // 5) Compare code
    const match = await bcrypt.compare(code, record.token_hash);
    if (!match) {
      // Increment attempts
      await authTokens.updateOne(
        { _id: record._id },
        { $inc: { attempts: 1 } }
      );
      return res.status(400).json({ error: 'Invalid verification code.' });
    }

    // 6) Mark user as verified
    await users.updateOne(
      { _id: user._id },
      { $set: { email_verified: true } }
    );

    // 7) Cleanup codes for this user
    await authTokens.deleteMany({
      user_id: user._id,
      type: 'email_verify_code'
    });

    return res.json({
      success: true,
      message: 'Email successfully verified.'
    });

  } catch (err) {
    console.error('verify-email-code error: ', err);
    return res.status(500).json({ error: 'Server error occurred.' });
  }
});


// this inserts a new token everytime. MULTIPLE valid tokens can exist at once for the same user until they expire
app.post('/api/auth/resend-email-code', async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ error: 'Email is required.' });
    }

    const users = db.collection('users');
    const authTokens = db.collection('auth_tokens');

    const user = await users.findOne({ email });
    if (!user) {
      return res.status(404).json({ error: 'User not found.' });
    }

    if (user.email_verified) {
      return res.status(400).json({ error: 'Email already verified.' });
    }

    // (Optional) prevent spam: check last created_at, rate-limit, etc.
    const { code, codeHash, expiresAt } = await generateVerificationCode();

    await authTokens.insertOne({
      user_id: user._id,
      token_hash: codeHash,
      type: 'email_verify_code',
      expires_at: expiresAt,
      created_at: new Date(),
      attempts: 0
    });

    await sendVerificationEmail(email, code);

    return res.json({ success: true, message: 'Verification code resent.' });

  } catch (err) {
    console.error('resend-email-code error: ', err);
    return res.status(500).json({ error: 'Server error occurred.' });
  }
});


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

    const users = db.collection('users');

    // collection for tokens // grab info from DB. (we need a table for verificationTokens. this is the current psuedo-code for it...)
    const authTokens = db.collection('auth_tokens');

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
    // grab the user object ID and convert it to a string
    const userId = result.insertedId;

    // grab results from the token generation
    const {code, codeHash, expiresAt } = await generateVerificationCode();

    // store info into DB. (we need a table for verificationTokens. this is the current psuedo-code for it...)
    await authTokens.insertOne({
      user_id: userId,          // string or ObjectId, just be consistent
      token_hash: codeHash,    // hashed form
      expires_at: expiresAt,    // Date
      type: 'email_verify_code',      // optional: helps reuse this collection for reset-password later
      created_at: new Date(),
      attempts: 0
    });

    // send the email
    await sendVerificationEmail(email, code);

    // Successful registration
    const ret = {
      id: result.insertedId.toString(),
      email: email,
      firstName: firstName,
      lastName: lastName,
      error: 'Successfully registered! Please check your email for account verification\n'
    };

    return res.status(201).json(ret);

  } catch (error) {
    console.error('Registration error: ', JSON.stringify(error, null, 2));
    res.status(500).json({
      id: -1,
      email: '',
      firstName: '',
      lastName: '',
      verifyUrl: '',
      error: 'Server error occurred!\n'
    });
  }
});


app.post('/api/auth', async (req, res, next) => {


})

// Add these endpoints to your server.js file

const { ObjectId } = require('mongodb');

app.post('/api/game/start', async (req, res) => {
  try {
    const { userId, wordId, difficulty } = req.body;

    if (!userId) {
      return res.status(400).json({ error: 'User ID is required' });
    }

    // Validate difficulty if provided
    if (difficulty !== undefined && difficulty !== 'random' && 
        (difficulty < 1 || difficulty > 4)) {
      return res.status(400).json({ 
        error: 'Difficulty must be between 1-4 or "random"' 
      });
    }

    const games = db.collection('games');
    const wordBank = db.collection('word_bank');

    let targetWord;
    let wordLength;
    let wordDifficulty;

    // If wordId provided, use that word, otherwise get random word
    if (wordId) {
      const wordDoc = await wordBank.findOne({ _id: new ObjectId(wordId) });
      if (!wordDoc) {
        return res.status(404).json({ error: 'Word not found' });
      }
      targetWord = wordDoc.word.toUpperCase();
      wordLength = wordDoc.length;
      wordDifficulty = wordDoc.difficulty;
    } else {
      // Build query based on difficulty
      let query = {};
      
      if (difficulty && difficulty !== 'random') {
        query.difficulty = parseInt(difficulty);
      }

      // Get words matching the difficulty criteria
      const words = await wordBank.find(query).toArray();
      
      if (words.length === 0) {
        return res.status(404).json({ 
          error: `No words available for difficulty ${difficulty}` 
        });
      }
      
      const randomWord = words[Math.floor(Math.random() * words.length)];
      targetWord = randomWord.word.toUpperCase();
      wordLength = randomWord.length;
      wordDifficulty = randomWord.difficulty;
    }

    // Create new game document matching your schema
    const newGame = {
      word: targetWord,
      word_length: wordLength,
      guesses: [], // Array of strings only
      num_guesses: 0,
      user_id: new ObjectId(userId),
      active: true,
      created_at: new Date(),
      guessed_at: null
    };

    const result = await games.insertOne(newGame);

    res.status(201).json({
      gameId: result.insertedId.toString(),
      wordLength: wordLength,
      difficulty: wordDifficulty,
      maxGuesses: 6,
      message: 'Game started successfully'
    });

  } catch (error) {
    console.error('Start game error:', error);
    res.status(500).json({ error: 'Server error occurred' });
  }
});

// Submit a guess
// Submit a guess
app.post('/api/game/guess', async (req, res) => {
  try {
    const { gameId, guess } = req.body;

    if (!gameId || !guess) {
      return res.status(400).json({ error: 'Game ID and guess are required' });
    }

    const games = db.collection('games');
    const validWords = db.collection('valid_words');

    // Find the game
    const game = await games.findOne({ _id: new ObjectId(gameId) });

    if (!game) {
      return res.status(404).json({ error: 'Game not found' });
    }

    if (!game.active) {
      return res.status(400).json({
        error: 'Game is no longer active',
        active: false
      });
    }

    const guessUpper = guess.toUpperCase().trim();
    const targetWord = game.word;

    // Validate guess length
    if (guessUpper.length !== game.word_length) {
      return res.status(400).json({
        error: `Guess must be ${game.word_length} letters long`
      });
    }

    // Check if word is valid (exists in valid_words collection)
    const isValidWord = await validWords.findOne({
      word: guessUpper.toLowerCase()
    });

    if (!isValidWord) {
      return res.status(400).json({
        error: 'Not a valid word',
        isValid: false
      });
    }

    // Check if already guessed
    if (game.guesses.includes(guessUpper)) {
      return res.status(400).json({
        error: 'Word already guessed'
      });
    }

    // Calculate feedback for the guess
    const feedback = calculateFeedback(guessUpper, targetWord);

    // Check if game is won
    const isWin = feedback.every(f => f.status === 'correct');
    const newNumGuesses = game.num_guesses + 1;
    const maxGuesses = 6;
    const isGameOver = isWin || newNumGuesses >= maxGuesses;

    let updateData = {
      $push: { guesses: guessUpper },
      $inc: { num_guesses: 1 }
    };

    if (isGameOver) {
      updateData.$set = {
        active: false,
        guessed_at: new Date()
      };

      // Update user statistics if won
      if (isWin) {
        const timeElapsed = (new Date() - game.created_at) / 1000;
        await updateUserStats(db, game.user_id, timeElapsed, newNumGuesses);
      }
    }

    // Update game with new guess
    await games.updateOne(
      { _id: new ObjectId(gameId) },
      updateData
    );

    res.status(200).json({
      guess: guessUpper,
      feedback: feedback,
      isCorrect: isWin,
      gameOver: isGameOver,
      active: !isGameOver,
      guessesRemaining: maxGuesses - newNumGuesses,
      totalGuesses: newNumGuesses,
      revealWord: isGameOver && !isWin ? targetWord : null,
      allGuesses: game.guesses.concat([guessUpper])
    });

  } catch (error) {
    console.error('Guess error:', error);
    res.status(500).json({ error: 'Server error occurred' });
  }
});

// Get game state
app.get('/api/game/:gameId', async (req, res) => {
  try {
    const { gameId } = req.params;

    const games = db.collection('games');

    const game = await games.findOne({ _id: new ObjectId(gameId) });

    if (!game) {
      return res.status(404).json({ error: 'Game not found' });
    }

    const maxGuesses = 6;
    const isWon = game.guesses.length > 0 &&
                  game.guesses[game.guesses.length - 1] === game.word;

    // Calculate feedback for each guess
    const guessesWithFeedback = game.guesses.map(guess => ({
      word: guess,
      feedback: calculateFeedback(guess, game.word)
    }));

    res.status(200).json({
      gameId: game._id.toString(),
      word: !game.active ? game.word : null, // Only reveal if game is over
      wordLength: game.word_length,
      guesses: guessesWithFeedback, // Return guesses with calculated feedback
      numGuesses: game.num_guesses,
      active: game.active,
      maxGuesses: maxGuesses,
      guessesRemaining: maxGuesses - game.num_guesses,
      createdAt: game.created_at,
      guessedAt: game.guessed_at,
      status: !game.active ? (isWon ? 'won' : 'lost') : 'in_progress'
    });

  } catch (error) {
    console.error('Get game error:', error);
    res.status(500).json({ error: 'Server error occurred' });
  }
});

// Get user's game history
app.get('/api/game/history/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const { limit = 10, active } = req.query;

    const games = db.collection('games');

    let query = { user_id: new ObjectId(userId) };

    // Filter by active status if provided
    if (active !== undefined) {
      query.active = active === 'true';
    }

    const gameHistory = await games
      .find(query)
      .sort({ created_at: -1 })
      .limit(parseInt(limit))
      .toArray();

    const formattedHistory = gameHistory.map(game => {
      const isWon = game.guesses.length > 0 &&
                    game.guesses[game.guesses.length - 1].feedback.every(f => f.status === 'correct');

      return {
        gameId: game._id.toString(),
        word: !game.active ? game.word : null,
        wordLength: game.word_length,
        numGuesses: game.num_guesses,
        active: game.active,
        status: !game.active ? (isWon ? 'won' : 'lost') : 'in_progress',
        createdAt: game.created_at,
        guessedAt: game.guessed_at
      };
    });

    res.status(200).json({
      games: formattedHistory,
      count: formattedHistory.length
    });

  } catch (error) {
    console.error('Game history error:', error);
    res.status(500).json({ error: 'Server error occurred' });
  }
});

// Get active game for user (if any)
app.get('/api/game/active/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const games = db.collection('games');

    const activeGame = await games.findOne({
      user_id: new ObjectId(userId),
      active: true
    });

    if (!activeGame) {
      return res.status(404).json({
        error: 'No active game found',
        hasActiveGame: false
      });
    }

    res.status(200).json({
      hasActiveGame: true,
      gameId: activeGame._id.toString(),
      wordLength: activeGame.word_length,
      numGuesses: activeGame.num_guesses,
      guesses: activeGame.guesses,
      createdAt: activeGame.created_at
    });

  } catch (error) {
    console.error('Get active game error:', error);
    res.status(500).json({ error: 'Server error occurred' });
  }
});

// Helper function to calculate feedback for a guess
function calculateFeedback(guess, target) {
  const feedback = [];
  const targetLetters = target.split('');
  const guessLetters = guess.split('');
  const usedIndices = new Set();

  // First pass: mark correct positions (green)
  for (let i = 0; i < guessLetters.length; i++) {
    if (guessLetters[i] === targetLetters[i]) {
      feedback[i] = {
        letter: guessLetters[i],
        status: 'correct', // Green - correct letter in correct position
        position: i
      };
      usedIndices.add(i);
    }
  }

  // Second pass: mark present but wrong position (yellow) and absent (gray)
  for (let i = 0; i < guessLetters.length; i++) {
    if (feedback[i]) continue; // Skip already marked correct

    let found = false;
    for (let j = 0; j < targetLetters.length; j++) {
      if (!usedIndices.has(j) && guessLetters[i] === targetLetters[j]) {
        feedback[i] = {
          letter: guessLetters[i],
          status: 'present', // Yellow - correct letter, wrong position
          position: i
        };
        usedIndices.add(j);
        found = true;
        break;
      }
    }

    if (!found) {
      feedback[i] = {
        letter: guessLetters[i],
        status: 'absent', // Gray - letter not in word
        position: i
      };
    }
  }

  return feedback;
}

// Helper function to update user statistics
async function updateUserStats(db, userId, timeElapsed, guessCount) {
  const users = db.collection('users');
  const user = await users.findOne({ _id: userId });

  if (!user) return;

  const newGamesPlayed = user.games_played + 1;
  const newGamesWon = user.games_won + 1;

  // Calculate new average time per win
  const totalTime = (user.avg_time_per_win * user.games_won) + timeElapsed;
  const newAvgTime = parseFloat((totalTime / newGamesWon).toFixed(1));

  // Calculate new average guesses per win
  const totalGuesses = (user.average_guesses_per_win * user.games_won) + guessCount;
  const newAvgGuesses = parseFloat((totalGuesses / newGamesWon).toFixed(1));

  await users.updateOne(
    { _id: userId },
    {
      $set: {
        games_played: newGamesPlayed,
        games_won: newGamesWon,
        avg_time_per_win: newAvgTime,
        average_guesses_per_win: newAvgGuesses
      }
    }
  );
}

// Check if a word is valid (exists in valid_words)
app.post('/api/word/validate', async (req, res) => {
  try {
    const { word } = req.body;

    if (!word) {
      return res.status(400).json({ error: 'Word is required' });
    }

    const validWords = db.collection('valid_words');

    const wordDoc = await validWords.findOne({
      word: word.toLowerCase().trim()
    });

    res.status(200).json({
      word: word,
      isValid: !!wordDoc
    });

  } catch (error) {
    console.error('Validate word error:', error);
    res.status(500).json({ error: 'Server error occurred' });
  }
});

// Get user statistics
app.get('/api/user/stats/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const users = db.collection('users');

    const user = await users.findOne({ _id: new ObjectId(userId) });

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.status(200).json({
      gamesPlayed: user.games_played || 0,
      gamesWon: user.games_won || 0,
      winRate: user.games_played > 0
        ? parseFloat(((user.games_won / user.games_played) * 100).toFixed(1))
        : 0,
      avgTimePerWin: user.avg_time_per_win || 0,
      averageGuessesPerWin: user.average_guesses_per_win || 0,
      wordsCreated: user.words_created || 0,
      wordsShared: user.words_shared || 0
    });

  } catch (error) {
    console.error('Get stats error:', error);
    res.status(500).json({ error: 'Server error occurred' });
  }
});


// Add these endpoints to your server.js file
// Make sure ObjectId is imported at the top

// ============= FRIENDS APIS =============

// Search users by username (for adding friends)
app.get('/api/users/search', async (req, res) => {
  try {
    const { query, currentUserId } = req.query;

    if (!query || query.trim().length === 0) {
      return res.status(400).json({ error: 'Search query is required' });
    }

    if (!currentUserId) {
      return res.status(400).json({ error: 'Current user ID is required' });
    }

    const db = client.db('wordle_db');
    const users = db.collection('users');

    // Search for users by username (case-insensitive, partial match)
    // Exclude the current user from results
    const searchResults = await users
      .find({
        username: { $regex: query.trim(), $options: 'i' },
        _id: { $ne: new ObjectId(currentUserId) }
      })
      .limit(10)
      .toArray();

    const formattedResults = searchResults.map(user => ({
      id: user._id.toString(),
      username: user.username,
      firstName: user.first_name,
      lastName: user.last_name,
      gamesPlayed: user.games_played || 0,
      gamesWon: user.games_won || 0
    }));

    res.status(200).json({
      users: formattedResults,
      count: formattedResults.length
    });

  } catch (error) {
    console.error('Search users error:', error);
    res.status(500).json({ error: 'Server error occurred' });
  }
});

// Send friend request
app.post('/api/friends/request', async (req, res) => {
  try {
    const { userId, friendId } = req.body;

    if (!userId || !friendId) {
      return res.status(400).json({ error: 'User ID and Friend ID are required' });
    }

    if (userId === friendId) {
      return res.status(400).json({ error: 'Cannot add yourself as a friend' });
    }

    const db = client.db('wordle_db');
    const users = db.collection('users');

    // Check if both users exist
    const [user, friend] = await Promise.all([
      users.findOne({ _id: new ObjectId(userId) }),
      users.findOne({ _id: new ObjectId(friendId) })
    ]);

    if (!user || !friend) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Check if already friends
    const userFriends = user.friends || [];
    if (userFriends.some(f => f.toString() === friendId)) {
      return res.status(400).json({ error: 'Already friends with this user' });
    }

    // Add friend to both users' friend lists
    await users.updateOne(
      { _id: new ObjectId(userId) },
      { $addToSet: { friends: new ObjectId(friendId) } }
    );

    await users.updateOne(
      { _id: new ObjectId(friendId) },
      { $addToSet: { friends: new ObjectId(userId) } }
    );

    res.status(200).json({
      message: 'Friend added successfully',
      friendId: friendId
    });

  } catch (error) {
    console.error('Add friend error:', error);
    res.status(500).json({ error: 'Server error occurred' });
  }
});

// Get user's friends list with their stats
app.get('/api/friends/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const db = client.db('wordle_db');
    const users = db.collection('users');

    const user = await users.findOne({ _id: new ObjectId(userId) });

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const friendIds = user.friends || [];

    if (friendIds.length === 0) {
      return res.status(200).json({
        friends: [],
        count: 0
      });
    }

    // Get all friends' data (only their stats, not their friends)
    const friends = await users
      .find({ _id: { $in: friendIds } })
      .project({
        username: 1,
        first_name: 1,
        last_name: 1,
        games_played: 1,
        games_won: 1,
        avg_time_per_win: 1,
        average_guesses_per_win: 1
        // Explicitly exclude friends array - don't show friends' friends
      })
      .toArray();

    const formattedFriends = friends.map(friend => ({
      id: friend._id.toString(),
      username: friend.username,
      firstName: friend.first_name,
      lastName: friend.last_name,
      gamesPlayed: friend.games_played || 0,
      gamesWon: friend.games_won || 0,
      winRate: friend.games_played > 0
        ? parseFloat(((friend.games_won / friend.games_played) * 100).toFixed(1))
        : 0,
      avgTimePerWin: friend.avg_time_per_win || 0,
      averageGuessesPerWin: friend.average_guesses_per_win || 0
    }));

    res.status(200).json({
      friends: formattedFriends,
      count: formattedFriends.length
    });

  } catch (error) {
    console.error('Get friends error:', error);
    res.status(500).json({ error: 'Server error occurred' });
  }
});


// ============= SIMPLE MESSAGING APIS =============

// Send a message to a friend
app.post('/api/messages/send', async (req, res) => {
  try {
    const { senderId, recipientId, message } = req.body;

    if (!senderId || !recipientId || !message) {
      return res.status(400).json({ 
        error: 'Sender ID, recipient ID, and message are required' 
      });
    }

    if (senderId === recipientId) {
      return res.status(400).json({ 
        error: 'Cannot send message to yourself' 
      });
    }

    // Trim message and check it's not empty
    const trimmedMessage = message.trim();
    if (trimmedMessage.length === 0) {
      return res.status(400).json({ 
        error: 'Message cannot be empty' 
      });
    }

    const users = db.collection('users');
    const messages = db.collection('messages');

    // Verify both users exist
    const [sender, recipient] = await Promise.all([
      users.findOne({ _id: new ObjectId(senderId) }),
      users.findOne({ _id: new ObjectId(recipientId) })
    ]);

    if (!sender || !recipient) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Optional: Check if they are friends
    const senderFriends = sender.friends || [];
    const isFriend = senderFriends.some(f => f.toString() === recipientId);
    
    if (!isFriend) {
      return res.status(403).json({ 
        error: 'You can only message friends' 
      });
    }

    // Create message document
    const newMessage = {
      sender_id: new ObjectId(senderId),
      recipient_id: new ObjectId(recipientId),
      message: trimmedMessage,
      created_at: new Date()
    };

    const result = await messages.insertOne(newMessage);

    res.status(201).json({
      messageId: result.insertedId.toString(),
      message: 'Message sent successfully',
      sentAt: newMessage.created_at
    });

  } catch (error) {
    console.error('Send message error:', error);
    res.status(500).json({ error: 'Server error occurred' });
  }
});

// Get conversation between two users
app.get('/api/messages/conversation/:userId/:friendId', async (req, res) => {
  try {
    const { userId, friendId } = req.params;
    const { limit = 50 } = req.query;

    const messages = db.collection('messages');
    const users = db.collection('users');

    // Get all messages between these two users
    const conversation = await messages
      .find({
        $or: [
          { sender_id: new ObjectId(userId), recipient_id: new ObjectId(friendId) },
          { sender_id: new ObjectId(friendId), recipient_id: new ObjectId(userId) }
        ]
      })
      .sort({ created_at: 1 }) // Oldest first
      .limit(parseInt(limit))
      .toArray();

    // Get user details for display
    const [user, friend] = await Promise.all([
      users.findOne({ _id: new ObjectId(userId) }),
      users.findOne({ _id: new ObjectId(friendId) })
    ]);

    if (!user || !friend) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Format messages with sender info
    const formattedMessages = conversation.map(msg => ({
      messageId: msg._id.toString(),
      senderId: msg.sender_id.toString(),
      senderUsername: msg.sender_id.toString() === userId ? user.username : friend.username,
      recipientId: msg.recipient_id.toString(),
      message: msg.message,
      sentAt: msg.created_at,
      isMine: msg.sender_id.toString() === userId
    }));

    res.status(200).json({
      userId: userId,
      friendId: friendId,
      friendUsername: friend.username,
      friendName: `${friend.first_name} ${friend.last_name}`,
      messages: formattedMessages,
      count: formattedMessages.length
    });

  } catch (error) {
    console.error('Get conversation error:', error);
    res.status(500).json({ error: 'Server error occurred' });
  }
});

// Get all conversations for a user (list of friends they've messaged with)
app.get('/api/messages/conversations/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const messages = db.collection('messages');
    const users = db.collection('users');

    // Get all messages where user is sender or recipient
    const allMessages = await messages
      .find({
        $or: [
          { sender_id: new ObjectId(userId) },
          { recipient_id: new ObjectId(userId) }
        ]
      })
      .sort({ created_at: -1 })
      .toArray();

    if (allMessages.length === 0) {
      return res.status(200).json({
        conversations: [],
        count: 0
      });
    }

    // Group by conversation partner
    const conversationMap = new Map();

    for (const msg of allMessages) {
      const partnerId = msg.sender_id.toString() === userId 
        ? msg.recipient_id.toString() 
        : msg.sender_id.toString();

      if (!conversationMap.has(partnerId)) {
        conversationMap.set(partnerId, {
          partnerId: partnerId,
          lastMessage: msg.message,
          lastMessageAt: msg.created_at,
          lastMessageSenderId: msg.sender_id.toString()
        });
      }
    }

    // Get user details for each conversation partner
    const partnerIds = Array.from(conversationMap.keys()).map(id => new ObjectId(id));
    const partners = await users.find({ _id: { $in: partnerIds } }).toArray();

    const conversations = partners.map(partner => {
      const conv = conversationMap.get(partner._id.toString());
      return {
        friendId: partner._id.toString(),
        friendUsername: partner.username,
        friendName: `${partner.first_name} ${partner.last_name}`,
        lastMessage: conv.lastMessage,
        lastMessageAt: conv.lastMessageAt,
        lastMessageFromMe: conv.lastMessageSenderId === userId
      };
    });

    // Sort by most recent message
    conversations.sort((a, b) => b.lastMessageAt - a.lastMessageAt);

    res.status(200).json({
      conversations: conversations,
      count: conversations.length
    });

  } catch (error) {
    console.error('Get conversations error:', error);
    res.status(500).json({ error: 'Server error occurred' });
  }
});


// Remove a friend
app.delete('/api/friends/remove', async (req, res) => {
  try {
    const { userId, friendId } = req.body;

    if (!userId || !friendId) {
      return res.status(400).json({ error: 'User ID and Friend ID are required' });
    }

    const db = client.db('wordle_db');
    const users = db.collection('users');

    // Remove friend from both users' friend lists
    await users.updateOne(
      { _id: new ObjectId(userId) },
      { $pull: { friends: new ObjectId(friendId) } }
    );

    await users.updateOne(
      { _id: new ObjectId(friendId) },
      { $pull: { friends: new ObjectId(userId) } }
    );

    res.status(200).json({
      message: 'Friend removed successfully'
    });

  } catch (error) {
    console.error('Remove friend error:', error);
    res.status(500).json({ error: 'Server error occurred' });
  }
});

// ============= STATISTICS APIS =============

// Get detailed user statistics
app.get('/api/stats/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const db = client.db('wordle_db');
    const users = db.collection('users');
    const games = db.collection('games');

    const user = await users.findOne({ _id: new ObjectId(userId) });

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Get all user's games
    const allGames = await games
      .find({ user_id: new ObjectId(userId) })
      .sort({ created_at: -1 })
      .toArray();

    // Calculate statistics
    const totalGames = allGames.length;
    const completedGames = allGames.filter(g => !g.active);
    const wonGames = completedGames.filter(g =>
      g.guesses.length > 0 && g.guesses[g.guesses.length - 1] === g.word
    );
    const lostGames = completedGames.filter(g =>
      g.guesses.length === 6 && g.guesses[g.guesses.length - 1] !== g.word
    );

    // Calculate win streak
    let currentStreak = 0;
    let maxStreak = 0;
    let tempStreak = 0;

    for (let i = 0; i < completedGames.length; i++) {
      const game = completedGames[i];
      const isWin = game.guesses.length > 0 &&
                    game.guesses[game.guesses.length - 1] === game.word;

      if (isWin) {
        tempStreak++;
        if (i === 0) currentStreak = tempStreak;
        maxStreak = Math.max(maxStreak, tempStreak);
      } else {
        tempStreak = 0;
      }
    }

    // Calculate guess distribution (how many games won in X guesses)
    const guessDistribution = [0, 0, 0, 0, 0, 0]; // index 0 = 1 guess, index 5 = 6 guesses
    wonGames.forEach(game => {
      const numGuesses = game.num_guesses;
      if (numGuesses >= 1 && numGuesses <= 6) {
        guessDistribution[numGuesses - 1]++;
      }
    });

    res.status(200).json({
      user: {
        id: user._id.toString(),
        username: user.username,
        firstName: user.first_name,
        lastName: user.last_name
      },
      statistics: {
        gamesPlayed: totalGames,
        gamesWon: wonGames.length,
        gamesLost: lostGames.length,
        activeGames: allGames.filter(g => g.active).length,
        winRate: totalGames > 0
          ? parseFloat(((wonGames.length / totalGames) * 100).toFixed(1))
          : 0,
        currentStreak: currentStreak,
        maxStreak: maxStreak,
        avgTimePerWin: user.avg_time_per_win || 0,
        averageGuessesPerWin: user.average_guesses_per_win || 0,
        guessDistribution: guessDistribution,
        wordsCreated: user.words_created || 0,
        wordsShared: user.words_shared || 0
      }
    });

  } catch (error) {
    console.error('Get user stats error:', error);
    res.status(500).json({ error: 'Server error occurred' });
  }
});

// Get leaderboard (top players by wins)
app.get('/api/stats/leaderboard', async (req, res) => {
  try {
    const { limit = 10, sortBy = 'wins' } = req.query;

    const db = client.db('wordle_db');
    const users = db.collection('users');

    let sortCriteria;
    switch (sortBy) {
      case 'wins':
        sortCriteria = { games_won: -1 };
        break;
      case 'winRate':
        sortCriteria = { games_won: -1, games_played: 1 };
        break;
      case 'avgGuesses':
        sortCriteria = { average_guesses_per_win: 1 };
        break;
      default:
        sortCriteria = { games_won: -1 };
    }

    const topUsers = await users
      .find({ games_played: { $gt: 0 } }) // Only users who have played
      .sort(sortCriteria)
      .limit(parseInt(limit))
      .toArray();

    const leaderboard = topUsers.map((user, index) => ({
      rank: index + 1,
      id: user._id.toString(),
      username: user.username,
      firstName: user.first_name,
      lastName: user.last_name,
      gamesPlayed: user.games_played || 0,
      gamesWon: user.games_won || 0,
      winRate: user.games_played > 0
        ? parseFloat(((user.games_won / user.games_played) * 100).toFixed(1))
        : 0,
      avgTimePerWin: user.avg_time_per_win || 0,
      averageGuessesPerWin: user.average_guesses_per_win || 0
    }));

    res.status(200).json({
      leaderboard: leaderboard,
      count: leaderboard.length
    });

  } catch (error) {
    console.error('Get leaderboard error:', error);
    res.status(500).json({ error: 'Server error occurred' });
  }
});

// Compare stats with a friend
app.get('/api/stats/compare/:userId/:friendId', async (req, res) => {
  try {
    const { userId, friendId } = req.params;

    const db = client.db('wordle_db');
    const users = db.collection('users');

    const [user, friend] = await Promise.all([
      users.findOne({ _id: new ObjectId(userId) }),
      users.findOne({ _id: new ObjectId(friendId) })
    ]);

    if (!user || !friend) {
      return res.status(404).json({ error: 'User not found' });
    }

    const formatUserStats = (u) => ({
      id: u._id.toString(),
      username: u.username,
      firstName: u.first_name,
      lastName: u.last_name,
      gamesPlayed: u.games_played || 0,
      gamesWon: u.games_won || 0,
      winRate: u.games_played > 0
        ? parseFloat(((u.games_won / u.games_played) * 100).toFixed(1))
        : 0,
      avgTimePerWin: u.avg_time_per_win || 0,
      averageGuessesPerWin: u.average_guesses_per_win || 0
    });

    res.status(200).json({
      user: formatUserStats(user),
      friend: formatUserStats(friend),
      comparison: {
        gamesPlayedDiff: user.games_played - friend.games_played,
        gamesWonDiff: user.games_won - friend.games_won,
        betterWinRate: user.games_won / (user.games_played || 1) >
                       friend.games_won / (friend.games_played || 1) ? 'user' : 'friend',
        betterAvgGuesses: (user.average_guesses_per_win || 999) <
                          (friend.average_guesses_per_win || 999) ? 'user' : 'friend'
      }
    });

  } catch (error) {
    console.error('Compare stats error:', error);
    res.status(500).json({ error: 'Server error occurred' });
  }
});

app.post('/api/searchcards', async (req, res, next) => {
  // incoming: userId, search
  // outgoing: results[], error

  var error = '';

  const { userId, search } = req.body;

  var _search = search.trim();

  const results = await db.collection('word_bank').find({"word":{$regex:_search+'.*', $options:'i'}}).toArray();

  var _ret = [];
  for( var i=0; i<results.length; i++ )
  {
    _ret.push( results[i].word );
  }

  var ret = {results:_ret, error:error};
  res.status(200).json(ret);
});

app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'Origin, X-Requested-With, Content-Type, Accept, Authorization'
  );
  res.setHeader(
    'Access-Control-Allow-Methods',
    'GET, POST, PATCH, DELETE, OPTIONS'
  );
  next();
});

app.listen(5000, '0.0.0.0', () => {
  console.log('Server running on port 5000');
});
