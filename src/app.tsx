import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { Header } from '@/components/layout/Header'

const queryClient = new QueryClient()

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
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
      </BrowserRouter>
    </QueryClientProvider>
  )
}
