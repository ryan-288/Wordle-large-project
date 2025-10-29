import { Link } from 'react-router-dom'

export default function VerifyNotice() {
  return (
    <div className="row justify-content-center">
      <div className="col-12 col-lg-10 col-xxl-8">
        <div className="p-4 bg-light border rounded">
          <h2 className="mb-2">Email verification required</h2>
          <p className="mb-3">
            Please check your email and click the verification link to activate your account.
          </p>
          <div className="d-flex gap-3">
            <Link to="/register" className="btn btn-primary btn-lg">Register</Link>
            <Link to="/login" className="btn btn-outline-secondary btn-lg">Login</Link>
            <Link to="/forgot-password" className="btn btn-link btn-lg">Forgot password</Link>
          </div>
        </div>
      </div>
    </div>
  )
}


