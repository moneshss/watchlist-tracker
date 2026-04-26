import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { Toaster } from '@/components/ui/sonner'
import { AuthProvider } from '@/components/auth/AuthProvider'
import { AuthGuard } from '@/components/auth/AuthGuard'
import { Header } from '@/components/layout/Header'
import LoginPage from '@/routes/login'

const queryClient = new QueryClient()

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <AuthProvider>
          <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route
              path="/*"
              element={
                <AuthGuard>
                  <div className="min-h-screen bg-background">
                    <Header />
                    <main className="container mx-auto px-4 py-8">
                      <Routes>
                        <Route
                          path="/"
                          element={
                            <p className="text-center text-muted-foreground">
                              Your watchlist will appear here.
                            </p>
                          }
                        />
                      </Routes>
                    </main>
                  </div>
                </AuthGuard>
              }
            />
          </Routes>
          <Toaster />
        </AuthProvider>
      </BrowserRouter>
    </QueryClientProvider>
  )
}
