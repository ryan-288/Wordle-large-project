# Wordle Flutter Mobile App

Flutter Android app that uses the same API as the web application.

## Setup

1. **Install Flutter:**
   - Download Flutter SDK from https://flutter.dev
   - Add Flutter to your PATH
   - Run `flutter doctor` to check setup

2. **Install dependencies:**
```bash
cd mobile
flutter pub get
```

3. **Update API URL** (if needed):
   - Edit `lib/services/api.dart`
   - Change `API_BASE_URL` if your server IP is different

4. **Run the app:**
```bash
flutter run
```

Or for Android specifically:
```bash
flutter run -d android
```

## Features

- Login and Register screens
- Wordle game with same logic as web version
- Uses same API endpoints as web app (`http://129.212.184.28:5000/api`)
- Email verification check
- SharedPreferences for user data persistence

## API Endpoints Used

- `POST /api/login` - User login
- `POST /api/register` - User registration
- `POST /api/game/start` - Start new game
- `POST /api/game/guess` - Submit guess
- `GET /api/game/:gameId` - Get game state
- `GET /api/game/active/:userId` - Get active game
- `POST /api/word/validate` - Validate word
- `GET /api/user/stats/:userId` - Get user stats

