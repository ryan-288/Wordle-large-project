import { render, screen } from '@testing-library/react'
import { BrowserRouter } from 'react-router-dom'
import App from '../App'

describe('App', () => {
  it('renders navbar links', () => {
    render(
      <BrowserRouter>
        <App />
      </BrowserRouter>
    )
    expect(screen.getByText(/MERN Demo/i)).toBeInTheDocument()
    expect(screen.getAllByRole('link', { name: /Login/i }).length).toBeGreaterThanOrEqual(1)
    expect(screen.getAllByRole('link', { name: /Register/i }).length).toBeGreaterThanOrEqual(1)
  })
})


