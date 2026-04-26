import type { ReactNode } from 'react'
import { Navigate } from 'react-router-dom'
import { useAuth } from '@/hooks/use-auth'

export function AuthGuard({ children }: { children: ReactNode }) {
  const { user, loading } = useAuth()

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <span className="text-muted-foreground text-sm">Loading…</span>
      </div>
    )
  }

  if (!user) return <Navigate to="/login" replace />

  return <>{children}</>
}
