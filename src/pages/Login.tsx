import type { FormEvent } from 'react'
import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'

export default function Login() {
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [message, setMessage] = useState<string | null>(null)

  function onSubmit(e: FormEvent) {
    e.preventDefault()
    if (!email || !password) {
      setMessage('Please enter email and password')
      return
    }
    setMessage('Logged in (mock). Redirecting...')
    setTimeout(() => navigate('/verify'), 500)
  }

  return (
    <div className="row justify-content-center">
      <div className="col-12 col-sm-10 col-md-8 col-lg-6 col-xl-5" style={{ maxWidth: '800px' }}>
        <h2 className="mb-3">Login</h2>
        {message && <div className="alert alert-info">{message}</div>}
        <form onSubmit={onSubmit} noValidate>
          <div className="mb-3">
            <label className="form-label">Email</label>
            <input type="email" className="form-control form-control-lg" value={email} onChange={e => setEmail(e.target.value)} required />
          </div>
          <div className="mb-3">
            <label className="form-label">Password</label>
            <input type="password" className="form-control form-control-lg" value={password} onChange={e => setPassword(e.target.value)} required />
          </div>
          <button type="submit" className="btn btn-primary btn-lg w-100">Login</button>
        </form>
        <div className="mt-3 d-flex justify-content-between">
          <Link to="/forgot-password">Forgot password?</Link>
          <Link to="/register">Create account</Link>
        </div>
      </div>
    </div>
  )
}


