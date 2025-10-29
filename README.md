# Wordle Large Project - Frontend

React + TypeScript frontend for the Wordle MERN stack project.

## Tech Stack

- **React 19** - UI framework
- **TypeScript** - Type safety
- **Vite** - Build tool and dev server
- **React Router** - Client-side routing
- **Bootstrap 5** - UI styling

## Features

- Authentication pages (Login, Register, Forgot Password, Reset Password)
- Email verification notice page
- Responsive design with Bootstrap
- TypeScript for type safety
- Unit tests with Vitest and React Testing Library

## Getting Started

### Installation

```bash
npm install
```

### Development

```bash
npm run dev
```

The app will be available at `http://localhost:5173`

### Build

```bash
npm run build
```

### Testing

```bash
npm test
```

## Project Structure

```
web/
├── src/
│   ├── pages/          # Page components (Login, Register, etc.)
│   ├── App.tsx         # Main app component with routing
│   ├── main.tsx        # Entry point
│   └── __tests__/      # Test files
├── public/             # Static assets
└── index.html          # HTML template
```

## Note

This is a frontend-only implementation. API integration is not included.
