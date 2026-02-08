# Bingeable iOS App — MVP Specification

## Overview

**Bingeable** is an iOS application built with **Swift** and **SwiftUI** that helps users **discover TV shows that are ready to be binged** and **track shows they are waiting to become bingeable**.

The MVP prioritizes:
- Fast initial delivery
- Clean, understandable architecture
- Clear separation of MVP vs post‑MVP scope
- Low operational cost (3rd‑party APIs, minimal backend)

---

## Core Value Proposition

> Help users quickly discover and track TV shows that are *ready to binge*, without having to manually research airing schedules or completion status.

Success for the MVP is defined as:
- Users discovering bingeable shows
- Users adding shows to their Library
- Users returning to check bingeable status

---

## Target User

- Consumer-facing app
- Users who watch TV series regularly
- Frequency: multiple times per week
- Session length: 30 seconds to 5 minutes

---

## MVP Scope

### Included
- Discover shows (Trending + Popular)
- Search shows
- Show detail view with bingeable status
- Watch providers (streaming only, region-based)
- Library with shelves (Waiting / Watching / Finished)
- Anonymous usage
- Email/password accounts (optional)
- Local caching for usability

### Explicitly Excluded (Non‑Goals)
- Push notifications
- Episode-by-episode progress tracking
- Personal recommendations
- Social features
- Showing a specific "bingeable on" date

---

## Definition of “Bingeable” (MVP Logic)

A show is considered **Ready to Binge** if **either**:
- The show status is `Ended`, OR
- There is **no next episode scheduled** (`next_episode_to_air == nil`) and at least one episode has aired

If insufficient data exists:
- Bingeable state = `TBD`

No estimated dates are shown in MVP.

---

## Third‑Party APIs

### Primary
- **TMDB (The Movie Database)**
  - Trending TV
  - Popular TV
  - Search TV
  - TV Details (status, air dates)
  - Watch Providers (region-based)

### Region Handling
- Watch providers are fetched using the **device’s region**

---

## Authentication

### Supported (MVP)
- Anonymous (guest) usage
- Email/password authentication

### Behavior
- Users can use the app fully as a guest
- Authenticated users sync their Library

---

## Offline Behavior

- App requires internet for discovery/search
- Cached data allows:
  - Viewing previously loaded show details
  - Viewing and managing the Library

---

## Navigation Model

**Tab-based navigation**

Tabs:
1. Discover
2. Search
3. Library
4. Settings

---

## Screens & Responsibilities

### Auth / Entry
- **LaunchGateView**
  - Determines auth state
- **SignInView**
- **SignUpView**

### Discover
- **DiscoverView**
  - Trending & Popular lists
  - Optional filter: Ready to Binge
- **ShowDetailView**
  - Show metadata
  - Bingeable badge
  - Watch providers
  - Add / Move / Remove from Library

### Search
- **SearchView**
  - Search input
  - Results list
- **ShowDetailView** (shared)

### Library
- **LibraryView**
  - Shelves:
    - Waiting
    - Watching
    - Finished
- **LibraryEditSheet** (optional)

### Settings
- **SettingsView**
  - Account status
  - Region display
  - Clear cache
  - Sign out

---

## Data Models (Domain)

```swift
struct Show {
  let id: Int
  let name: String
  let posterPath: String?
  let overview: String
  let genres: [Genre]
  let status: ShowStatus?
  let lastAirDate: Date?
  let nextEpisodeAirDate: Date?
}

enum BingeableState {
  case ready
  case notYet
  case tbd
}

enum LibraryShelf {
  case waiting
  case watching
  case finished
}

struct TrackedShow {
  let id: Int
  var shelf: LibraryShelf
  var addedAt: Date
  var updatedAt: Date
}
```

---

## Architecture

### Pattern
- **SwiftUI + MVVM**
- Feature-based folder organization

### State Management
- `@StateObject` ViewModels
- Shared session state via `SessionManager`

### Concurrency
- `async/await`
- Simple request caching/coalescing

---

## Persistence Strategy

### Local
- **SwiftData** (recommended)
  - Tracked shows
  - Cached show metadata
- HTTP caching via `URLCache`

### Remote (for signed-in users)
- **Firebase Auth**
  - Anonymous
  - Email/password
- **Firestore**
  - `users/{uid}/library/{showId}`

### Sync Rules (MVP)
- Local-first
- Write-through when authenticated
- Last-write-wins using `updatedAt`

---

## Project Structure (Xcode)

```
Bingeable/
  App/
  Features/
    Discover/
    Search/
    Library/
    ShowDetail/
    Settings/
    Auth/
  Domain/
    Models/
    Logic/
  Data/
    Network/
    Persistence/
    Repositories/
  Shared/
    UIComponents/
    Utilities/
```

---

## Implementation Roadmap

1. TMDB client + endpoints
2. Bingeable evaluation logic + tests
3. Local Library persistence
4. Core UI (tabs + lists + detail)
5. Auth + Library sync
6. Polish (filters, empty states, caching)

---

## Post‑MVP Ideas (Not Implemented)

- Push notifications when a show becomes bingeable
- Estimated bingeable dates
- Episode progress tracking
- Personalized recommendations
- Social sharing

---

## Summary

This MVP is intentionally conservative in scope, prioritizing **correctness**, **clarity**, and **speed to ship**, while leaving clear extension points for future growth.

