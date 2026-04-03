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
- **`ArticleFullTextStore`** — SwiftData on-device only for `rawText`; `digest` field is synced to Supabase `links.digest` column on save
- Tabs: **Read → Do → Library → Discover** (default: Read)
- iPhone: `TabView`. iPad/Mac: `NavigationSplitView` (`IPadNavigationView`)

### Navigation & UI Layout

#### iPhone
| Location | Contents |
|---|---|
| Tab bar | Read · Do · Library · Discover |
| Top-left (all tabs) | Hamburger menu (≡) |
| Top-right (all tabs) | Grid/List toggle · Search · Enrich ✦ (conditional, iOS 26+) |
| Hamburger menu | **Intelligence:** Today's Reading, Audio Briefing, Library Insights, Notes Review, Knowledge Synthesis, Sources · **Filter:** Category submenu, Tags (opens tag cloud sheet), Sort · **Actions:** Curate Collection · **Account:** Profile · Clear All Filters (when active) |
| Discover tab | Hub: Library Insights · Notes Review · Knowledge Synthesis · Sources |

#### iPad / Mac (NavigationSplitView)
| Location | Contents |
|---|---|
| Sidebar — Reading | Read · Do · Library |
| Sidebar — Discover | Sources · Insights · Notes Review · Knowledge Synthesis · Audio Briefing · Search |
| Sidebar — Other | Profile · Stats (Read/Do/Done counts) |
| Card grid toolbar | Left: filter menu · Right: list toggle, Enrich ✦ (conditional) |
| Article list toolbar (no article open) | Left: filter menu · Right: card toggle, Enrich ✦ (conditional) |
| Article list toolbar (article open) | Left: filter menu only — reader owns the right side |
| Reader toolbar | Done ✓ · Info ⓘ (toggles metadata/reader swap) · Share ↗ (Copy URL, Open in Safari) · Fullscreen ↔ |
| Filter menu (both views) | Category submenu · Tags (opens tag cloud sheet) · Sort · Curate Collection · Clear All Filters (when active) |

**Key design rule:** When an article is open in split view, the list panel shows only its filter menu. The reader panel owns all article-level actions. No button appears twice.

**Info mode:** Tapping ⓘ in the reader toolbar swaps the web view for `ArticleDetailView` (full metadata). Tap again to return to web view. Controlled by `isInfoMode` state in `IPadReadingPane`.

**Reader toolbar (updated):** Done ✓ · Reader/Web toggle (doc.text ↔ globe) · Info ⓘ · Fullscreen ↔ · Share ↗ menu (Reflect, Typography when in reader mode, Copy URL, Open in Safari)

**Enrich All:** Only visible as a `✦ sparkles` toolbar button when `vm.unenrichedLinks.count > 0 && !vm.isEnrichingAll` (iOS 26+ only). Not shown in any menu.

### CRITICAL: iPhone ≠ iPad — Always update BOTH

The iPhone and iPad use **completely separate view hierarchies**. Features added to one do NOT appear on the other.

| Feature area | iPhone file | iPad file |
|---|---|---|
| Article reading | `ArticleReaderContainer.swift` | `IPadNavigationView.swift` → `IPadReadingPane` |
| Reader toolbar buttons | `ArticleReaderContainer` toolbar | `IPadReadingPane.readerTrailingButtons()` |
| Reader content (web/reader mode) | `isReaderMode` in `ArticleReaderContainer` | `isReaderMode` in `IPadReadingPane` |
| Library list/grid | `LibraryView.swift` | `IPadCardGrid` / `IPadArticleList` in `IPadNavigationView.swift` |
| Hamburger menu items | `LibraryView` menu | iPad sidebar items in `IPadNavigationView` |
| Sheets from reading | `.sheet` on `ArticleReaderContainer` | `.sheet` on `IPadReadingPane` body |

**Rule:** Any time you add a button, sheet, state variable, or feature to the article reader or library on iPhone, immediately check whether `IPadReadingPane` and/or `IPadCardGrid`/`IPadArticleList` need the same change. They usually do.

**Checklist when adding a reader feature:**
1. Add to `ArticleReaderContainer` toolbar/menu (iPhone)
2. Add matching state var to `IPadReadingPane`
3. Add button to `IPadReadingPane.readerTrailingButtons()` or the share overflow `Menu`
4. Wire any new sheets on the `IPadReadingPane` body (`.sheet` / `.fullScreenCover`)
5. If the feature needs AppStorage settings (e.g. font, theme), add them to both structs

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
│   ├── Digest/      DigestView, PodcastDigestView
│   ├── Insights/    LibraryInsightsView
│   ├── Notes/       NotesReviewView
│   ├── Knowledge/   KnowledgeSynthesisView
│   ├── Sources/     SourcesView
│   ├── Discover/    DiscoverView (hub), DiscoverSimilarView (from Notes Review)
│   ├── Profile/     ProfileView
│   ├── Auth/        SignInView
│   └── iPad/        IPadNavigationView (IPadReadingPane, IPadCardGrid, IPadArticleList)
├── Helpers/         ArticleExtractor, ArticleDigestEngine, PodcastDigestEngine,
│                    DigestNotificationManager, CachedAsyncImage, StatusHelpers,
│                    BounceStyle (+Haptics), Color+Hex
└── Supabase/        SupabaseClient.swift, NewsAPIConfig.swift (Discover Similar)
```

### AI Features Summary
| Feature | Entry Point | AI Engine | Context Source |
|---------|-------------|-----------|----------------|
| Daily Digest | Hamburger → "Today's Reading" | FoundationModels (iOS 26+) | `todaysSavedContext` — last 24h articles |
| Audio Briefing | Hamburger or iPad sidebar | **Gemini 2.5 Flash** (script) + **Gemini TTS** (audio) | `podcastContext` — last 7 days, up to 50 articles |
| Library Insights | Hamburger or Discover tab | FoundationModels (iOS 26+) | `libraryStatsContext` — aggregate stats only (no per-article content) |
| Notes Review | Hamburger or Discover tab | FoundationModels (iOS 26+) | `notesContext()` — articles with notes, date-filtered |
| Knowledge Synthesis | Hamburger or Discover tab | FoundationModels (iOS 26+) | Top 12 scored articles from full library |
| Discover Similar | From Notes Review recap | NewsAPI + FoundationModels | Article titles + themes |
| Enrich All | Sparkles ✦ toolbar (iOS 26+) | FoundationModels (iOS 26+) | Single article OG metadata |
| Curate AI Summary | Curate Collection sheet | FoundationModels (iOS 26+) | Selected article digests/summaries |

### CRITICAL: AI Context Priority Order — Apply to ALL features

**Every AI feature that builds per-article context MUST follow this priority chain:**

```swift
// 1. On-device full digest (richest — from deep save on this device)
if let ft = ArticleFullTextStore.shared.fetch(linkId: link.id), !ft.digest.isEmpty {
    use ft.digest
// 2. Supabase-synced digest (from deep save on another device)
} else if let d = link.digest, !d.isEmpty {
    use d
// 3. Short Supabase summary (from Enrich All)
} else if let s = link.summary, !s.isEmpty {
    use s
}
// 4. Note — ALWAYS append if present (highest personal signal, never omit)
if let note = link.note, !note.isEmpty { always include }
```

**Rule:** Any time you change what data is fed to one AI feature, update ALL AI features that build per-article context. The four that share this pattern are:
- `LibraryViewModel.todaysSavedContext` → Daily Digest
- `LibraryViewModel.notesContext()` → Notes Review
- `LibraryViewModel.podcastContext` → Audio Briefing
- `KnowledgeSynthesisView.buildContext()` → Knowledge Synthesis

Library Insights uses aggregate stats only (`libraryStatsContext`) — no per-article context needed there.

### Full Text / Digest Pipeline — CRITICAL to understand

There are **three enrichment levels**:

**Level 1 — "Enrich All" ✦ (Supabase fields, lightweight)**
- Triggered by: ✦ sparkles toolbar button on any article without a summary/note
- What it does: Uses `EnrichEngine` → FoundationModels → writes `summary` (2-3 sentences), `tags`, `category`, `status` back to Supabase
- What it does NOT do: Never fetches full article text. Never touches `ArticleFullTextStore`.
- Source material: Only the article's existing `title`, `description`, `url` (OG metadata)

**Level 2 — "Save Full Text" / Deep Save (triggers cross-device digest sync)**
- Triggered by exactly THREE things in `ArticleDetailView.performDeepSave()`:
  1. User taps "Save Full Text" button in the Full Text section of detail view
  2. User rates an article **5 stars** (auto-triggers if not already saved)
  3. User saves a **note** for the first time (auto-triggers if not already saved)
- What it does: `ArticleExtractor` fetches full page text via hidden WKWebView → `ArticleDigestEngine` generates a rich 150-200 word digest → saved to `ArticleFullTextStore` (SwiftData local) AND digest PATCHed to `links.digest` in Supabase
- Result: `ArticleFullText` with `rawText` (up to 15K chars, local only) + `digest` (150-200 words, also in Supabase)

**Level 3 — Supabase digest (cross-device)**
- The `digest` field on the `Link` model (Supabase `links.digest` column) is populated automatically when any device performs a deep save
- Available to all devices on next fetch — no action needed on the receiving device
- `ArticleDetailView` shows a teal "Digest synced from another device" indicator when `link.digest` is set but no local `ArticleFullText` exists

**Best AI source articles:** Articles where `ArticleFullTextStore.shared.fetch(linkId:) != nil` OR `link.digest != nil` — these have real 150-200 word digests. Articles with only a Supabase `summary` give the LLM much less to work with.

### AI Rule — FoundationModels vs External APIs
**Most AI features use FoundationModels** (`LanguageModelSession`, iOS 26+). Always gate with `if #available(iOS 26, *)` and provide a graceful fallback. Never dump raw data sets — always pre-aggregate context.

**Audio Briefing is the exception:** Uses **Gemini 2.5 Flash** (script generation, free tier) + **Gemini 2.5 Flash TTS** (audio synthesis, free preview tier). API key stored in `AppStorage("geminiAPIKey")`, entered in Profile → AI Services. No iOS version gate needed — works on any iOS version with internet. Never use paid external APIs for other features.

### FoundationModels Context Window Limits
The on-device model has a small context window (~4K tokens total including prompt + response). Hard limits enforced in each feature:
- `todaysSavedContext`: 20 articles max with digests/summaries
- `notesContext`: 20 articles max
- Podcast uses Gemini (1M token context) — no limit needed
- `@Guide` macro requires `description:` named label — `@Guide(description: "...")` not `@Guide("...")`
- `session.respond(to:generating:)` returns `Response<T>` — access value via `.content`, not directly
- `@Generable` structs must be defined at file scope (not nested), inside `#if canImport(FoundationModels)`

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

*Last updated: 2026-04-02 by Claude Code*
