# Watchlist Tracker

A personal TV series watchlist manager, replacing Google TV's watchlist. Built as both a personal tool and a portfolio project.

## Stack

- **Framework:** React 19 + TypeScript + Vite
- **Styling:** Tailwind CSS v4 + Shadcn/ui (new-york style)
- **Data fetching:** TanStack Query v5
- **Routing:** React Router v7
- **Backend:** Supabase (Auth + PostgreSQL + Row Level Security)
- **Hosting:** Vercel (SPA + serverless functions)
- **Metadata source:** TMDB API (proxied through serverless functions)

## Architecture

- The client NEVER calls the TMDB API directly. All TMDB requests go through Vercel serverless functions in `/api/` which hold the API key.
- The `/api/tmdb-show` function fetches show data from TMDB and upserts it into the Supabase `shows` table using the service-role key. This table is shared across all users.
- All user-specific data (watchlist items, season progress, episode progress) is accessed via the Supabase client with the anon key. RLS policies enforce that users can only access their own rows.
- TanStack Query manages all server state. Every data fetch goes through a custom hook in `src/hooks/`. No direct Supabase calls from components.
- Use optimistic updates for user actions (status changes, episode marking) via TanStack Query's `useMutation` with `onMutate`.

## Project Structure

```
api/                          → Vercel serverless functions (TMDB proxy)
src/
  components/
    ui/                       → Shadcn/ui components (do not manually edit)
    layout/                   → App shell, header, mobile nav
    auth/                     → Login form, auth guard
    search/                   → TMDB search dialog, result cards, add form
    watchlist/                → List view, show cards, filters, status badges
    show/                     → Show detail page components (header, seasons, episodes)
  hooks/                      → TanStack Query hooks (one per data domain)
  lib/
    supabase.ts               → Supabase client initialisation
    api.ts                    → Typed fetch wrappers for /api/* endpoints
    tmdb-images.ts            → TMDB image URL builder (never hardcode CDN URLs)
    constants.ts              → Status labels, colours, enums
    utils.ts                  → cn(), formatDate, general utilities
  types/
    database.ts               → Auto-generated Supabase types (npx supabase gen types)
    tmdb.ts                   → TMDB API response types
    index.ts                  → App-level derived types
  routes/                     → One file per route
  app.tsx                     → Router + QueryClientProvider setup
  main.tsx                    → Entry point
  index.css                   → Tailwind directives
supabase/
  migrations/                 → SQL migration files
```

## Conventions

- **Path alias:** `@` → `src/` (configured in tsconfig and vite.config)
- **Components:** Functional components only. Use named exports except for route components (default export).
- **Hooks:** All Supabase/API data access goes through custom hooks in `src/hooks/`. Components never call `supabase.from(...)` directly.
- **Types:** Regenerate `src/types/database.ts` after any schema change: `npx supabase gen types typescript --project-id <id> > src/types/database.ts`
- **Images:** Always use the `tmdbImageUrl()` helper from `src/lib/tmdb-images.ts`. Never hardcode `https://image.tmdb.org/...` in components.
- **Env vars:** Client-side vars are prefixed `VITE_`. Secrets (TMDB key, Supabase service-role key) live only in `/api/` serverless functions and the Vercel dashboard.
- **Error handling:** All mutations should have `onError` handlers that show a toast via Shadcn's toast/sonner component. Never silently swallow errors.

## Database

The database has these core tables (see `supabase/migrations/` for full schema):

- `shows` — cached TMDB metadata, keyed by `tmdb_id` (integer PK). Shared across users.
- `watchlist_items` — a user's relationship to a show (status, note, priority, rating). Unique on `(user_id, tmdb_id)`.
- `season_progress` — per-season tracking (watched episodes, status, rating, dates). Unique on `(watchlist_item_id, season_number)`.
- `episode_progress` — per-episode tracking (watched, watched_at, notes). Phase 2 feature.
- `profiles` — extends `auth.users` with display name. Auto-created via trigger on signup.

Status enum values: `want_to_watch`, `watching`, `finished`, `dropped`, `on_hold`.
Season status enum values: `not_started`, `watching`, `finished`.

## Implementation Phases

This project is built in 20 incremental steps across 3 phases. Each step should be completed, tested, and committed before moving to the next. The full plan is in `watchlist-tracker-plan.md`.

- **Phase 1 (Steps 1–9):** MVP — scaffolding, auth, schema, TMDB proxy, search, list view, status management, show detail with season progress, polish.
- **Phase 2 (Steps 10–16):** Episode tracking, watch dates, runtime calculator, personal ratings, notes, priority ordering, binge detector.
- **Phase 3 (Steps 17–20):** Rewatch tracking, stats dashboard, mobile polish, recommendations.

## Do NOT

- Do not install additional UI component libraries (MUI, Chakra, Ant Design, etc.). Use Shadcn/ui.
- Do not call TMDB directly from client code.
- Do not skip RLS policies on any new table.
- Do not use `localStorage` for data that should persist across devices — that's what Supabase is for.
- Do not build features from future steps unless explicitly asked. Stay on the current step.
