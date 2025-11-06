const { MongoClient } = require('mongodb');
const bcrypt = require('bcrypt'); // npm i bcrypt

const uri = 'mongodb+srv://TheBeast:1231ENGINEERING@wordplay2d.nhc27zd.mongodb.net/wordle_db?retryWrites=true&w=majority'; // e.g. "mongodb+srv://..."
const client = new MongoClient(uri);

async function createUser() {
  try {
    await client.connect();
    const db = client.db('wordle_db'); // your database name
    const users = db.collection('users');

    // Generate a random suffix to make each user unique
    const randomNum = Math.floor(Math.random() * 10000);

    const hashedPassword = await bcrypt.hash('password123', 10);

    const newUser = {
      email: `testuser${randomNum}@example.com`,
      username: `testplayer${randomNum}`,
      first_name: 'Test',
      last_name: 'Player',
      password: hashedPassword,
      email_verified: false,
      games_played: Math.floor(Math.random() * 10),
      games_won: Math.floor(Math.random() * 5),
      avg_time_per_win: parseFloat((Math.random() * 100).toFixed(1)),
      average_guesses_per_win: parseFloat((Math.random() * 6).toFixed(1)),
      words_created: Math.floor(Math.random() * 10),
      words_shared: Math.floor(Math.random() * 5),
    };

    const result = await users.insertOne(newUser);
    console.log('✅ New user created with ID:', result.insertedId);
    console.log(newUser);
  } catch (err) {
    console.error('Error creating user:', err);
  } finally {
    await client.close();
  }
}

createUser();

