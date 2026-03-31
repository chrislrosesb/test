# CLAUDE.md — Personal Website Decision Log

This file tracks architectural decisions, design choices, and rules Claude must follow.

---

## Project Overview

A personal website with multiple pages and a Supabase-backed reading list:
- `index.html` — Homepage
- `about.html` — About page
- `contact.html` — Contact page
- `uses.html` — My Gear page
- `reading-list.html` — Public reading list with admin CRUD, bookmarklet, compact/grid view
- `admin.html` — Admin panel for managing gear
- `styles.css` — Shared stylesheet
- `reading-list.js` — Reading list logic (Supabase, filters, search, view modes)
- `uses.js` — Uses page dynamic content
- `admin.js` — Admin panel logic

**Primary URL:** `https://chrislrose.aseva.ai` — canonical domain.
**Mirror:** GitHub Pages at `https://chrislrosesb.github.io/test/` — NOT the primary site.
**Reading list primary URL:** `https://chrislrose.aseva.ai/reading-list.html` — hardcoded in `reading-list.js` as `PRIMARY_URL`.

---

## Design Decisions

### Color palette
- Background: `#ffffff` | Alt background: `#f8f9fa`
- Text: `#1a1a2e` | Muted: `#6c757d`
- Accent: `#4f46e5` (indigo) | Hover: `#818cf8`

### Typography + Layout
- Font: Inter (Google Fonts). Headings use `clamp()` + letter-spacing `-0.02em`.
- Max content width: `900px`. CSS Grid for cards/two-column layouts. Sticky frosted-glass nav.

### JavaScript
Vanilla JS, no frameworks, no build step. Supabase JS v2 SDK loaded from CDN.

---

## Cache Busting — ALWAYS DO THIS

Every commit that changes JS or CSS must bust the browser cache via:

1. **`?v=TIMESTAMP` on all `<script>`/`<link>` tags** in HTML files.
2. **Git pre-commit hook** (`.git/hooks/pre-commit`) — auto-replaces all `?v=[0-9]+` with the current Unix timestamp. Never remove this hook.
3. **No-cache meta tags** in every HTML file (immediately after `<meta charset="UTF-8" />`):
   ```html
   <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
   <meta http-equiv="Pragma" content="no-cache" />
   <meta http-equiv="Expires" content="0" />
   ```

**Rules:** Never manually edit `?v=` numbers. New JS/CSS refs need `?v=1`. New HTML pages need the three no-cache tags.

---

## Deployment & Server Constraints

- **Deploy:** `git push` to `main` — no build step. Primary site auto-deploys.
- **No PHP** — `.php` files are served as downloads. Use `.html` + JS + third-party services.
- **Instagram/Threads images** hotlink-block via Referer. Route through `wsrv.nl` proxy — see `proxyImage()` in `reading-list.js`.
- **OG images must be PNG, 1200×630** — iMessage doesn't render SVG.
- **`c.html`** — static collection share handler (OG tags + JS redirect). Collection share URLs use `c.html?id=`.

---

## Reading List — Data Model & Key Features

### Link fields
`url`, `title`, `description`, `image`, `favicon`, `domain`, `category` (single), `tags` (comma-separated), `stars` (1–5), `note` (personal, public), `status` (`to-read`/`to-try`/`to-share`/`done`/null), `read` (bool, synced with status), `private`, `saved_at`.

### Supabase tables
- `links` — all saved links
- `categories` — `name` + `sort_order`
- `collections` — legacy one-time shares (`id`, `recipient`, `message`, `link_ids[]`, `created_at`)
- `subtasks` — (`id` UUID, `link_id`, `text`, `is_done`, `created_at`); `on delete cascade` from links
- `recipients` — persistent share recipients (`id` UUID, `name`, `slug` unique, `created_at`)
- `recipient_batches` — (`id`, `recipient_id` FK, `link_ids[]`, `note`, `enriched_message`, `created_at`)

All tables: RLS enabled. Public SELECT, authenticated INSERT/UPDATE/DELETE.

### Curate (persistent recipients)
Recipients have permanent URLs (`reading-list.html?recipient=<slug>`). Each curate creates a batch. Website renders all batches as a living feed; latest batch gets a "NEW" ribbon. Legacy `?collection=` URLs unchanged.

### Admin
FAB button (bottom-right). Login adds `admin-mode` class to `<body>`. Shows edit/delete/status controls on cards.

### iOS Shortcut
Receive Share Sheet → Get URLs → open `reading-list.html?add=URL`. Must be logged into admin mode on first device use.

### OG / Social Previews
All pages have OG + Twitter Card meta tags. `og-image.png` + `og-reading-list.png` are 1200×630 PNG.

---

## iOS App — Procrastinate

**Intent:** The app is the private intelligence layer — AI-powered tools to actually process and act on saved articles. Website is the public face.

- SwiftUI, iOS 26 target, Liquid Glass design language
- Same Supabase backend as website (shared data)
- On-device AI via `FoundationModels` framework (iOS 26+)
- No Share Extension (avoids $99/yr dev account)
- Saving stays via iOS Shortcut/bookmarklet
- App lives in `/ios/ReadingList/`
- Mac Catalyst enabled (`SUPPORTS_MACCATALYST = YES`; `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO`)

### Architecture
- **`@Observable` + `@MainActor`** throughout — `LibraryViewModel` is the single source of truth
- **`SupabaseClient.shared`** — raw URLSession + JSONDecoder, no SDK
- **`SubtaskStore.shared`** — Supabase-backed subtasks (syncs across devices)
- **`ArticleFullTextStore`** — SwiftData on-device only, never goes to Supabase
- Tabs: **Read → Do → Library → Discover** (default: Read)
- iPhone: `TabView`. iPad/Mac: `NavigationSplitView` (`IPadNavigationView`)

### Navigation & UI Layout

#### iPhone
| Location | Contents |
|---|---|
| Tab bar | Read · Do · Library · Discover |
| Top-left (all tabs) | Hamburger menu (≡) |
| Top-right (all tabs) | Grid/List toggle · Search · Enrich ✦ (conditional, iOS 26+) |
| Hamburger menu | **Intelligence:** Today's Reading, Library Insights, Notes Review, Knowledge Synthesis, Sources · **Filter:** Category submenu, Tags (opens tag cloud sheet), Sort · **Actions:** Curate Collection · **Account:** Profile · Clear All Filters (when active) |
| Discover tab | Hub: Library Insights · Notes Review · Knowledge Synthesis · Sources |

#### iPad / Mac (NavigationSplitView)
| Location | Contents |
|---|---|
| Sidebar — Reading | Read · Do · Library |
| Sidebar — Discover | Sources · Insights · Notes Review · Knowledge Synthesis · Search |
| Sidebar — Other | Profile · Stats (Read/Do/Done counts) |
| Card grid toolbar | Left: filter menu · Right: list toggle, Enrich ✦ (conditional) |
| Article list toolbar (no article open) | Left: filter menu · Right: card toggle, Enrich ✦ (conditional) |
| Article list toolbar (article open) | Left: filter menu only — reader owns the right side |
| Reader toolbar | Done ✓ · Info ⓘ (toggles metadata/reader swap) · Share ↗ (Copy URL, Open in Safari) · Fullscreen ↔ |
| Filter menu (both views) | Category submenu · Tags (opens tag cloud sheet) · Sort · Curate Collection · Clear All Filters (when active) |

**Key design rule:** When an article is open in split view, the list panel shows only its filter menu. The reader panel owns all article-level actions. No button appears twice.

**Info mode:** Tapping ⓘ in the reader toolbar swaps the web view for `ArticleDetailView` (full metadata). Tap again to return to web view. Controlled by `isInfoMode` state in `IPadReadingPane`.

**Enrich All:** Only visible as a `✦ sparkles` toolbar button when `vm.unenrichedLinks.count > 0 && !vm.isEnrichingAll` (iOS 26+ only). Not shown in any menu.

### Key File Structure
```
ios/ReadingList/ReadingList/
├── ContentView.swift
├── Models/          Link, Category, Recipient, Subtask, ArticleFullText(Store)
├── ViewModels/      LibraryViewModel.swift
├── Views/
│   ├── Library/     LibraryView, ArticleCardView, ArticleRowView, TagCloudView,
│   │                TaskRowView, SubtaskEditorView, CurateSheetView, Filter*
│   ├── Detail/      ArticleDetailView, EnrichSheetView (dead code)
│   ├── Reader/      ArticleReaderContainer, WebReaderView, FinishedReadingSheet
│   ├── Search/      SearchView
│   ├── Digest/      DigestView
│   ├── Insights/    LibraryInsightsView
│   ├── Notes/       NotesReviewView
│   ├── Knowledge/   KnowledgeSynthesisView
│   ├── Sources/     SourcesView
│   ├── Discover/    DiscoverView (hub), DiscoverSimilarView (from Notes Review)
│   ├── Profile/     ProfileView
│   ├── Auth/        SignInView
│   └── iPad/        IPadNavigationView (IPadReadingPane, IPadCardGrid, IPadArticleList)
├── Helpers/         ArticleExtractor, ArticleDigestEngine, DigestNotificationManager,
│                    CachedAsyncImage, StatusHelpers, BounceStyle (+Haptics), Color+Hex
└── Supabase/        SupabaseClient.swift, NewsAPIConfig.swift (Discover Similar)
```

### AI Features Summary
| Feature | Entry Point | AI Context Used |
|---------|-------------|-----------------|
| Daily Digest | Hamburger menu → "Today's Reading" | Last 24h articles + digests/summaries |
| Library Insights | Hamburger menu or Discover tab | Pre-aggregated stats only |
| Notes Review | Hamburger menu or Discover tab | Notes + titles + digests |
| Knowledge Synthesis | Hamburger menu or Discover tab | Top 12 relevant articles |
| Discover Similar | From Notes Review recap | NewsAPI + AI curation |
| Enrich All | Sparkles ✦ toolbar button (when unenriched articles exist, iOS 26+) | Single article metadata |
| Curate AI Summary | Curate Collection (hamburger/filter menu) | Article digests/summaries |

**Full text context pattern:** `if let ft = ArticleFullTextStore.shared.fetch(linkId: link.id), !ft.digest.isEmpty { use digest } else { use summary/note }`

### AI Rule — ALWAYS USE FOUNDATION MODELS
**Never use external AI APIs (Claude API, OpenAI, etc.) in the iOS app.** All generative AI uses `LanguageModelSession` from `FoundationModels`. Always gate with `if #available(iOS 26, *)` and provide a graceful fallback. Never dump raw data sets — always pre-aggregate context.

### Known Issues / Gotchas
- **`Link` name conflict:** Clashes with `SwiftUI.Link<Label>` in SourceKit single-file analysis → shows IDE errors but builds fine. Do not rename the model.
- **Mac Catalyst SourceKit warnings:** `topBarLeading`, `topBarTrailing`, `navigationBarTitleDisplayMode` show "unavailable in macOS" — false positives, fully supported via Catalyst. Ignore.
- **PBXFileSystemSynchronizedRootGroup:** New `.swift` files in the correct folder are auto-included — no need to edit `project.pbxproj`.
- **iOS 26 Form buttons:** Must use `.buttonStyle(.plain)` on Cancel/Save buttons inside `Form`/`List` sections or they won't fire reliably. Use `@FocusState` to dismiss `TextEditor` focus before saving.
- **`ArticleDetailView` is Form-based** (not ScrollView): title, status/category, stars, tags, AI summary, note. Tap-to-edit inline pattern throughout.
- **`EnrichSheetView` is dead code:** Not presented by any view. Single-article enrich needs re-wiring.
- **Subtask sync:** `subtasks` table must exist in Supabase with RLS policies allowing public CRUD.
- **`recipients` / `recipient_batches` tables** must be created manually in Supabase SQL editor if not done yet. If `createRecipient` or `createBatch` fails, check Xcode console for ❌ error lines.
- **Mac app distribution:** Without $99/yr Apple Developer account, build from Xcode + copy to `/Applications` manually. Free certs expire every 7 days.
- **NewsAPI key** in `NewsAPIConfig.swift` is hardcoded in source (free tier, 100 req/day). Low risk but visible in public repo.

*Last updated: 2026-03-30 by Claude Code*
