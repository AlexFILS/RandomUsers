# RandomUsers

A SwiftUI app that browses profiles from the [Random User Generator API](https://randomuser.me), built with modern Swift Concurrency (`async`/`await`, `@Observable`).

## Features

### User list

The home screen loads a paginated list of users. Scrolling near the end of the loaded list prefetches the next page automatically; a failed page fetch surfaces an inline retry control instead of losing the pages already loaded, and a failed *initial* load shows a full-screen error with retry.

### Search

Tapping the search icon reveals a search bar over the list. Typing debounces into a search over the users loaded so far (pagination is paused while a search is active and resumes when the search is cleared), showing either matching results or a "no matches" state.

### User details

Selecting a user pushes a details screen with their full profile — personal info (gender, date of birth, nationality, ID), contact info, address, and account info — grouped into sections.

## Architecture: MVVM + Coordinators

- **View** — SwiftUI views (`UsersView`, `UserDetailsView`) are dumb renderers of a view model's state. They forward user intents (button taps, selection, search text changes) to the view model and never make navigation or networking decisions themselves.
- **ViewModel** — `@Observable` classes (`UsersViewModel`, `UserDetailsViewModel`) own screen state and business logic (pagination, search, error presentation) behind small, enum-shaped state (`Content`, `Overlay`, `Footer`) so the view has no branching logic to get wrong. View models never import SwiftUI and never navigate directly — they report a user's intent (e.g. "user selected") via an injected closure.
- **Coordinator** — Navigation lives outside the view model, in a coordinator tree:
  - `AppCoordinator` is the root; it owns the app's composed dependencies and the top-level flows (currently a single `UsersFlowCoordinator`).
  - `UsersFlowCoordinator` owns the `NavigationPath` for the Users flow, builds each screen's view model, and decides what to push/pop in response to the closures those view models call (e.g. `onSelectUser`, `onBack`). A shared `Coordinator` protocol tracks parent/child ownership so `AppCoordinator` can hold and swap flows without knowing their concrete types.

This keeps navigation, state, and rendering as three separate concerns: a view model can be unit-tested with no navigation stack in sight, and a coordinator can be tested/swapped without touching view rendering.

## Dependency injection

There is no DI framework or service locator — dependencies are passed explicitly through initializers (constructor injection), composed once at the top and threaded down:

1. **`AppDependencies`** is the composition root's payload: every shared, protocol-typed service a coordinator needs (`ServiceProtocol` for networking, `SearchableCollectionProtocol` for search). `AppDependencies.production()` builds the real implementations (`NetworkingClient`, `SearchService`); a `#if DEBUG` `develop()` variant swaps in stubs for previews/local runs.
2. It's built once in `RandomUsersApp` and passed into `AppCoordinator`, which passes the relevant pieces into `UsersFlowCoordinator`, which injects them into each view model it creates (`UsersViewModel`, `UserDetailsViewModel`).
3. View models depend on protocols (`ServiceProtocol`, `SearchableCollectionProtocol`), never concrete types — production code and tests each supply their own conformance, so a view model can be tested with a stub service and no network access.

The same pattern extends to the local Swift packages: `Networking` exposes a concrete `NetworkingClient` with no app-specific protocol of its own — the app defines `ServiceProtocol` and adapts `NetworkingClient` to it (see [`Packages/Networking/README.md`](Packages/Networking/README.md)), keeping the app layer decoupled from the networking implementation.

## Project structure

```
RandomUsers/
├── Main/                    # App entry point
├── Navigation/              # Coordinator protocol + AppCoordinator + per-flow coordinators
├── Dependency/              # AppDependencies (composition root) + protocol abstractions
├── Features/
│   ├── UsersScreen/         # List screen: model, view, view model, pagination fetcher
│   └── UserDetailsScreen/   # Details screen: view, view model
├── Common/                  # Reusable, feature-agnostic building blocks
│   ├── Pagination/          # Generic Paginator + PaginatedCollectionLoader
│   ├── Search/               # Generic SearchController + SearchCoordinator
│   ├── Presentation/         # Status/error presentation helpers
│   └── ReusableViews/        # Shared SwiftUI components
└── Resources/                # Theme, localized strings

Packages/
├── Networking/               # Local SPM package: URLSession-based networking client
└── UIComponents/             # Local SPM package: shared UI components (e.g. StatusView)
```

## Testing

`RandomUsersTests` covers view models, pagination, and search in isolation using stub services (`Doubles/`) rather than a live network — a direct benefit of injecting protocols instead of concrete types.
