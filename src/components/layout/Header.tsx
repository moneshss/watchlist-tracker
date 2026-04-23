import { Tv } from 'lucide-react'

export function Header() {
  return (
    <header className="border-b bg-background">
      <div className="container mx-auto flex h-14 items-center gap-2 px-4">
        <Tv className="h-5 w-5" />
        <span className="font-semibold">Watchlist Tracker</span>
      </div>
    </header>
  )
}
