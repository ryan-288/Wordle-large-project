import type { FormEvent } from 'react'
import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'

export default function Register() {
  const navigate = useNavigate()
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [message, setMessage] = useState<string | null>(null)

  function onSubmit(e: FormEvent) {
    e.preventDefault()
    if (!name || !email || !password) {
      setMessage('Please fill out all fields')
      return
    }
    if (password !== confirm) {
      setMessage('Passwords do not match')
      return
    }
    setMessage('Registered (mock). Please verify your email.')
    setTimeout(() => navigate('/verify'), 700)
  }

  return (
    <div className="row justify-content-center">
      <div className="col-12 col-sm-10 col-md-8 col-lg-6 col-xl-5" style={{ maxWidth: '800px' }}>
        <h2 className="mb-3">Create account</h2>
        {message && <div className="alert alert-info">{message}</div>}
        <form onSubmit={onSubmit} noValidate>
          <div className="mb-3">
            <label className="form-label">Name</label>
            <input className="form-control form-control-lg" value={name} onChange={e => setName(e.target.value)} />
          </div>
          <div className="mb-3">
            <label className="form-label">Email</label>
            <input type="email" className="form-control form-control-lg" value={email} onChange={e => setEmail(e.target.value)} />
          </div>
          <div className="mb-3">
            <label className="form-label">Password</label>
            <input type="password" className="form-control form-control-lg" value={password} onChange={e => setPassword(e.target.value)} />
          </div>
          <div className="mb-3">
            <label className="form-label">Confirm Password</label>
            <input type="password" className="form-control form-control-lg" value={confirm} onChange={e => setConfirm(e.target.value)} />
          </div>
          <button type="submit" className="btn btn-primary btn-lg w-100">Register</button>
        </form>
        <div className="mt-3">
          <Link to="/login">Already have an account? Login</Link>
        </div>
      </div>
    </div>
  )
}


