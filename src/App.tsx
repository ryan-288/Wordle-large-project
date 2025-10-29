import { Link, NavLink, Route, Routes } from 'react-router-dom'
import './App.css'

import Login from './pages/Login'
import Register from './pages/Register'
import VerifyNotice from './pages/VerifyNotice'
import ForgotPassword from './pages/ForgotPassword'
import ResetPassword from './pages/ResetPassword'

function App() {
  return (
    <div className="d-flex flex-column min-vh-100">
      <nav className="navbar navbar-expand-lg navbar-dark bg-dark">
        <div className="container-fluid">
          <Link to="/" className="navbar-brand">MERN Demo</Link>
          <button className="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarsExample" aria-controls="navbarsExample" aria-expanded="false" aria-label="Toggle navigation">
            <span className="navbar-toggler-icon"></span>
          </button>
          <div className="collapse navbar-collapse" id="navbarsExample">
            <ul className="navbar-nav ms-auto mb-2 mb-lg-0">
              <li className="nav-item"><NavLink to="/login" className="nav-link">Login</NavLink></li>
              <li className="nav-item"><NavLink to="/register" className="nav-link">Register</NavLink></li>
            </ul>
          </div>
        </div>
      </nav>

      <main className="flex-fill py-4">
        <div className="container-fluid px-4">
          <Routes>
            <Route path="/" element={<VerifyNotice />} />
            <Route path="/login" element={<Login />} />
            <Route path="/register" element={<Register />} />
            <Route path="/verify" element={<VerifyNotice />} />
            <Route path="/forgot-password" element={<ForgotPassword />} />
            <Route path="/reset-password" element={<ResetPassword />} />
          </Routes>
        </div>
      </main>

      <footer className="bg-light py-3 mt-auto">
        <div className="container small text-muted"></div>
      </footer>
    </div>
  )
}

export default App
