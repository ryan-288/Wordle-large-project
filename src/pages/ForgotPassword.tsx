import type { FormEvent } from 'react'
import { useState } from 'react'

export default function ForgotPassword() {
  const [email, setEmail] = useState('')
  const [message, setMessage] = useState<string | null>(null)

  function onSubmit(e: FormEvent) {
    e.preventDefault()
    if (!email) {
      setMessage('Please enter your email')
      return
    }
    setMessage('If this email exists, a reset link has been sent (mock).')
  }

  return (
    <div className="row justify-content-center">
      <div className="col-12 col-sm-10 col-md-8 col-lg-6 col-xl-5" style={{ maxWidth: '800px' }}>
        <h2 className="mb-3">Forgot password</h2>
        {message && <div className="alert alert-info">{message}</div>}
        <form onSubmit={onSubmit} noValidate>
          <div className="mb-3">
            <label className="form-label">Email</label>
            <input type="email" className="form-control form-control-lg" value={email} onChange={e => setEmail(e.target.value)} />
          </div>
          <button type="submit" className="btn btn-primary btn-lg w-100">Send reset link</button>
        </form>
      </div>
    </div>
  )
}


