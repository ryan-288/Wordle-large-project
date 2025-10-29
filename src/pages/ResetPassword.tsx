import type { FormEvent } from 'react'
import { useState } from 'react'

export default function ResetPassword() {
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [message, setMessage] = useState<string | null>(null)

  function onSubmit(e: FormEvent) {
    e.preventDefault()
    if (!password || !confirm) {
      setMessage('Please enter and confirm your new password')
      return
    }
    if (password !== confirm) {
      setMessage('Passwords do not match')
      return
    }
    setMessage('Password updated (mock). You can now login.')
  }

  return (
    <div className="row justify-content-center">
      <div className="col-12 col-sm-10 col-md-8 col-lg-6 col-xl-5" style={{ maxWidth: '800px' }}>
        <h2 className="mb-3">Reset password</h2>
        {message && <div className="alert alert-info">{message}</div>}
        <form onSubmit={onSubmit} noValidate>
          <div className="mb-3">
            <label className="form-label">New password</label>
            <input type="password" className="form-control form-control-lg" value={password} onChange={e => setPassword(e.target.value)} />
          </div>
          <div className="mb-3">
            <label className="form-label">Confirm password</label>
            <input type="password" className="form-control form-control-lg" value={confirm} onChange={e => setConfirm(e.target.value)} />
          </div>
          <button type="submit" className="btn btn-primary btn-lg w-100">Update password</button>
        </form>
      </div>
    </div>
  )
}


