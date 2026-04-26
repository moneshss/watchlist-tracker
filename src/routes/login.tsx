import { useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '@/hooks/use-auth'
import { LoginForm } from '@/components/auth/LoginForm'
import { Tv } from 'lucide-react'

export default function LoginPage() {
  const { user, loading } = useAuth()
  const navigate = useNavigate()

  useEffect(() => {
    if (!loading && user) navigate('/', { replace: true })
  }, [user, loading, navigate])

  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-6 bg-background px-4">
      <div className="flex items-center gap-2">
        <Tv className="h-6 w-6" />
        <span className="text-xl font-semibold">Watchlist Tracker</span>
      </div>
      <LoginForm />
    </div>
  )
}
