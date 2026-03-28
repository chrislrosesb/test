# CLAUDE.md — Personal Website Decision Log

This file tracks architectural decisions, design choices, and customization notes.

---

## Project Overview

A personal website with multiple pages and a Supabase-backed reading list:
- `index.html` — Homepage
- `about.html` — About page
- `contact.html` — Contact page
- `uses.html` — My Gear page (hardware, software, tools)
- `reading-list.html` — Public reading list with admin CRUD, bookmarklet, compact/grid view
- `admin.html` — Admin panel for managing gear (uses.html content)
- `styles.css` — Shared stylesheet
- `reading-list.js` — Reading list logic (Supabase, filters, search, view modes)
- `uses.js` — Uses page dynamic content (gear cards)
- `admin.js` — Admin panel logic

**Primary URL:** `https://chrislrose.aseva.ai` — this is the canonical domain.
**Hosting:** Company-managed hosting environment. Also mirrored to GitHub Pages (`https://chrislrosesb.github.io/test/`) but that is NOT the primary site.
**Reading list primary URL:** `https://chrislrose.aseva.ai/reading-list.html` — hardcoded in `reading-list.js` as `PRIMARY_URL` so bookmarklets always point here regardless of which mirror you're viewing from.

---

## Design Decisions

### Color palette
- Background: `#ffffff` (white)
- Alternate background: `#f8f9fa` (light gray, used for section banding)
- Text: `#1a1a2e` (near-black with a subtle blue tint)
- Muted text: `#6c757d` (gray, used for `<p>` tags)
- Accent: `#4f46e5` (indigo) — used for links, buttons, tags, icons
- Accent light: `#818cf8` — hover states

**Rationale:** Indigo accent is distinctive but professional; avoids the overused
blue/teal of many developer portfolios.

### Typography
- Font: [Inter](https://rsms.me/inter/) loaded from Google Fonts
- Headings use `clamp()` for fluid sizing across viewport widths
- Letter-spacing `-0.02em` on headings for a tighter, modern feel

### Layout
- Max content width: `900px` centered — wide enough to breathe, narrow enough to
  read comfortably
- CSS Grid for card grids and two-column layouts (`about`, `contact`)
- Sticky frosted-glass nav (`backdrop-filter: blur`)

### JavaScript
The site uses vanilla JS (no frameworks, no build step). `reading-list.js`,
`uses.js`, and `admin.js` handle dynamic content. The Supabase JS v2 SDK is
loaded from CDN.

---

## Cache Busting — ALWAYS DO THIS

**Every commit that changes JS or CSS must bust the browser cache.** This is handled automatically but requires two things to be in place:

### How it works

1. **`?v=TIMESTAMP` on all JS/CSS `<script>`/`<link>` tags in HTML files** — when the version changes, browsers fetch a fresh copy instead of using cached files.

2. **Git pre-commit hook** (`.git/hooks/pre-commit`) — automatically replaces all `?v=[0-9]+` occurrences in every `*.html` file with the current Unix timestamp on every commit. This runs without any manual steps.

3. **No-cache meta tags in every HTML file** — HTML files themselves can be cached by browsers, which would prevent them from seeing the new `?v=` timestamp. All HTML pages include:
   ```html
   <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
   <meta http-equiv="Pragma" content="no-cache" />
   <meta http-equiv="Expires" content="0" />
   ```

### Rules
- **Never manually edit `?v=` numbers** — the pre-commit hook handles it.
- **If adding a new JS or CSS file reference to any HTML page**, make sure it has `?v=1` on the `src`/`href` so the hook can find and update it on the next commit.
- **If adding a new HTML page**, add the three no-cache meta tags immediately after `<meta charset="UTF-8" />`.
- **Never remove the pre-commit hook** at `.git/hooks/pre-commit`.

---

## Reading List — Key Features

### Share / Collections
The "Curate" button in the filter bar enters selection mode. You pick links, optionally add a recipient name and message, then click "Create share link." This saves a `collections` record in Supabase containing the selected link IDs and generates a URL (`?collection=abc123`) you can send to anyone. Recipients see a collection banner at the top with the recipient name, message, and article count.

The copy (🔗) button on each card copies that single link's URL to clipboard.

### Link data model
Each link has: `url`, `title`, `description`, `image`, `favicon`, `domain`, `category` (single, from dropdown), `tags` (freeform comma-separated text), `stars` (1–5), `note` (personal note, visible to visitors), `status` (`to-read` / `to-try` / `to-share` / `done` / null), `read` (boolean kept in sync with status for backwards compat), `private`, `saved_at`.

### Supabase tables
- `links` — all saved links
- `categories` — managed list with `name` + `sort_order`
- `collections` — shared curated link bundles (`id`, `recipient`, `message`, `link_ids[]`, `created_at`)
- `subtasks` — subtasks for Do-tab items (`id` UUID, `link_id`, `text`, `is_done`, `created_at`); has `on delete cascade` from links

### Admin
Admin access is via a FAB button (bottom-right). Logging in activates `admin-mode` class on `<body>`, which shows edit/delete/status buttons on cards. Admin can add, edit, delete links and manage categories.

---

## Deployment

- **Primary host:** `https://chrislrose.aseva.ai` — company-managed hosting, auto-deploys from `main`
- **Mirror:** GitHub Pages at `https://chrislrosesb.github.io/test/` (also auto-deploys from `main`)
- **Deploy process:** `git push` to `main` — no build step, files are served directly
- **Important:** Always use the primary domain (`chrislrose.aseva.ai`) in any hardcoded URLs (bookmarklets, share links, etc.)
- **PHP does NOT run on this server** — `.php` files are served as static file downloads. Do not create `.php` files. Use `.html` + JS for dynamic behaviour, and third-party services for anything requiring server-side logic.

## Server Constraints & Workarounds

- **No PHP:** `c.php` was replaced with `c.html` (static OG tags + JS redirect). Collection share URLs use `c.html?id=`.
- **Image hotlinking:** Instagram/Threads CDN (`cdninstagram.com`, `fbcdn.net`) blocks browser requests via Referer checking. Fixed by routing those image URLs through `wsrv.nl` — a free image proxy that fetches server-side. See `proxyImage()` in `reading-list.js`.
- **OG images must be PNG, 1200×630** — iMessage doesn't render SVG, and square images leave a white bar. Both `og-image.png` and `og-reading-list.png` are 1200×630.

---

## File Structure

```
/
├── index.html          # Homepage
├── about.html          # About page
├── contact.html        # Contact page
├── uses.html           # My Gear page
├── reading-list.html   # Reading list (public + admin)
├── admin.html          # Gear admin panel
├── styles.css          # Shared CSS
├── reading-list.js     # Reading list logic
├── uses.js             # Uses page logic
├── admin.js            # Admin panel logic
├── c.html              # Collection share handler (OG tags + JS redirect)
├── og-image.png        # Main site OG image (1200×630)
├── og-reading-list.png # Reading list OG image (1200×630)
└── CLAUDE.md           # This file — decision log

.git/hooks/pre-commit   # Auto-updates ?v= cache busters on every commit
```

---

---

## iOS App Project — Core Intent

**The deeper intent of the app is making the saved library actually useful, not just a graveyard of bookmarks.** The website is the public face (anyone can browse). The iOS app is the private intelligence layer — AI-powered tools to help you actually process and act on what you've saved.

A native iOS reading list app (app name: **Procrastinate**). Full brief is in **`ios-app-brief.md`** (root of this repo) — read it before starting iOS work.

Key points:
- SwiftUI, iOS 26 target, Liquid Glass design language
- Same Supabase backend as the website (shared data)
- On-device AI via Foundation Models (`FoundationModels` framework, iOS 26+)
- No Share Extension (deliberately skipped — avoid $99/year dev account requirement)
- Saving articles stays via existing iOS Shortcut/bookmarklet flow
- App lives in `/ios/ReadingList/` subfolder of this repo
- Mac Catalyst enabled (`SUPPORTS_MACCATALYST = YES`); `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO`

### iOS App Architecture

- **`@Observable` + `@MainActor`** throughout — `LibraryViewModel` is the single source of truth
- **`SupabaseClient.shared`** — raw URLSession + JSONDecoder, no SDK
- **`SubtaskStore.shared`** — `@Observable` singleton, Supabase-backed (was UserDefaults, migrated to Supabase `subtasks` table for cross-device sync)
- Tabs (in order): **Read → Do → Library → Search** — defaults to Read tab on launch
- `TabView(selection: $selectedTab)` with `@State private var selectedTab = "read"` in ContentView

### iOS App File Structure (key files)

```
ios/ReadingList/ReadingList/
├── ContentView.swift               # TabView, tab order, default tab
├── Models/
│   ├── Link.swift                  # Core data model (NOT SwiftUI.Link — naming conflict in IDE, builds fine)
│   ├── Category.swift
│   └── Subtask.swift               # Subtask model + SubtaskStore (Supabase-backed, syncs across devices)
├── ViewModels/
│   └── LibraryViewModel.swift      # All data, filters, AI search, enrich all
├── Views/
│   ├── Detail/
│   │   ├── ArticleDetailView.swift # Editable title, category, tags inline
│   │   └── EnrichSheetView.swift   # AI enrichment sheet + EnrichEngine
│   ├── Library/
│   │   ├── LibraryView.swift       # Main library, tag cloud button, filters, toolbar menu
│   │   ├── TagCloudView.swift      # Full-screen weighted tag cloud, tap to filter
│   │   ├── TaskRowView.swift       # Do-tab rows with inline subtask expand/collapse
│   │   └── SubtaskEditorView.swift # Half-sheet subtask manager
│   ├── Digest/
│   │   └── DigestView.swift        # Today's Reading — last-24h articles + AI narrative
│   ├── Insights/
│   │   └── LibraryInsightsView.swift # Library stats grid + AI narrative + action items
│   ├── Notes/
│   │   └── NotesReviewView.swift   # Notes Review — date picker, AI recap, action items → subtasks
│   ├── iPad/
│   │   └── IPadNavigationView.swift # iPad/Mac: NavigationSplitView, sidebar includes Insights + Notes Review
│   └── ...
└── Supabase/
    └── SupabaseClient.swift
```

### iOS App — Features Implemented

**Daily Digest (`DigestView`)**
- Accessible from toolbar Menu → "Today's Reading"
- Shows only articles saved in the **last 24 hours**
- "Generate Today's Summary" button → Foundation Models produces 3–4 sentence narrative: themes, what to read first, quick observation about the mix
- Article cards below the AI summary; tap to open full reader
- Graceful `ContentUnavailableView` fallback if no articles today or iOS < 26

**Library Insights (`LibraryInsightsView`)**
- Accessible from toolbar Menu → "Library Insights" (iPhone) and sidebar under Discover (iPad/Mac)
- Always-visible stats grid: status counts (to-read / to-do / done / unsorted), top 3 categories, top 5 tag pills — no AI required
- "Generate Insights" button → Foundation Models produces 2–3 paragraph narrative on reading habits + exactly 3 action items
- `libraryStatsContext` computed property on `LibraryViewModel` builds pre-aggregated stats string (top-10 tags, top-6 categories, top-5 domains, counts) — never dumps raw links to the model
- AI section shows generated-at timestamp and refresh button

**Notes Review (`NotesReviewView`)**
- Accessible from toolbar Menu → "Notes Review" (iPhone) and sidebar under Discover (iPad/Mac)
- **Purpose:** recall what you were thinking when you wrote notes on articles during a time period
- **Quick date picker:** 7 Days / 30 Days / 3 Months / This Month — plus a **Custom** option that reveals animated From/To `DatePicker` fields with no lower bound (can go back years, e.g. Q1 2025)
- Filters by `savedAt` date (not note-written date — no timestamp for that); only articles with non-empty, non-whitespace notes appear
- "Analyse Notes" → Foundation Models reads each note + article title + AI summary for context, returns:
  - **Recap** (2–3 paragraphs, journal-entry tone, references actual notes)
  - **Action Items** (up to 5, prefixed with `[N]` to identify source article)
- **Add to Do** button per action item: auto-attaches text as subtask on the source article, moves article to Do tab if not already there, button hides after use
- Article list uses `NoteReviewCardView` — note-first design: compact title/domain header + full note text as body (no line limit, scrollable)
- Switching date range or regenerating resets all added-item state
- Key bug fix: whitespace-only notes (e.g. `" "`) are trimmed before emptiness check so they never appear

**Knowledge Synthesis (`KnowledgeSynthesisView`)**
- Entry: toolbar Menu → "Knowledge Synthesis" (iPhone), sidebar under Discover (iPad/Mac)
- User types a natural language question ("What do I know about LLMs?")
- Scores entire library for relevance — prefers articles with full text digests, then summary+note
- Top 12 passed to Foundation Models, returns three labelled sections: **SYNTHESIS** (2-3 para briefing), **GAPS** (what's missing from your understanding), **NEXT STEP** (one concrete action)
- Sources list below shows which articles were used; tapping opens the reader; "Full text" badge shown on deep-saved articles
- Idle state shows example queries you can tap to run immediately

**Full Text Save (`ArticleFullTextStore`, `ArticleExtractor`, `ArticleDigestEngine`)**
- Stores article full text + AI digest **on-device only via SwiftData** — never goes to Supabase, zero server cost
- `ArticleExtractor`: loads URL in a hidden WKWebView, injects JS to find main content element (`article`/`main`/largest-div heuristic), returns clean text capped at 15 000 chars. Handles JS-rendered pages; gracefully fails paywalled content.
- `ArticleDigestEngine`: Foundation Models generates a ~200-word per-article digest from the raw text + existing metadata (note, tags, summary). More analytical than Enrich summary — designed for synthesis use.
- `ArticleFullTextStore`: SwiftData singleton with its own `ModelContainer`. Methods: `fetch(linkId:)`, `save(...)`, `delete(linkId:)`. No setup required in App file.
- Storage: ~5KB/article avg → 1 000 articles ≈ 5 MB on device

**Auto-save full text triggers**
- **Adding a note for the first time**: when you tap Save on a note that was previously empty, full text fetch + digest generation fires in the background if not already saved. Edit to existing note does NOT re-trigger.
- **Rating 5 stars**: tapping the 5th star auto-triggers full text save if not already saved.
- Both are silent background operations — `deepSavePhase` in `ArticleDetailView` updates to show the result, but no blocking UI.

**Full text in `ArticleDetailView`**
- "Full Text" section at bottom of the info Form
- Shows: Save Full Text / saving progress / "Saved · N words · date" with Re-fetch and Delete options
- Deep save button also available for manual save on any article
- On `.task` load: checks store and restores phase to `.saved(...)` if already saved

**All AI features now use full text digests when available**
- `notesContext(from:to:)` — Notes Review: prefers digest, falls back to summary
- `todaysSavedContext` — Daily Digest: prefers digest, falls back to summary, then note
- `CurateSheetView.generateMessage()` — Curate AI message: prefers digest, falls back to summary
- `libraryStatsContext` — Library Insights: **unchanged** — uses aggregate stats, not per-article content
- Pattern: `if let ft = ArticleFullTextStore.shared.fetch(linkId: link.id), !ft.digest.isEmpty { use digest } else { use summary/note }`

**Enrich with AI (`EnrichSheetView` / `EnrichEngine`)**
- Uses `LanguageModelSession` (Foundation Models, iOS 26 only)
- Falls back gracefully with `ContentUnavailableView` on older OS / devices without Apple Intelligence
- Returns: cleanTitle, summary, tags (3–6 comma-separated), category, status
- **Deterministic category override:** after AI responds, `refineCategory()` applies keyword rules in priority order — first match wins:
  1. Apple-specific (Vision Pro, visionOS)
  2. Apple-general (iPhone, iPad, Swift, SwiftUI, Xcode, WWDC, etc.)
  3. Claude / Anthropic
  4. AI/ML (OpenAI, ChatGPT, LLM, generative AI, etc.)
  5. Tech (JavaScript, Python, developer, cybersecurity, etc.)
- `unenrichedLinks` counts articles with no `summary` AND no `note` (both must be empty)
- "Enrich All" batch-processes unenriched articles sequentially, shows progress

**Tag Cloud (`TagCloudView`)**
- Full-screen sheet, tags weighted by frequency (font size 13–33pt, opacity 0.45–1.0)
- Custom `TagFlowLayout: Layout` for true word-wrapping
- Search bar to filter tags; tap any tag to close sheet and filter library
- Toolbar button shows `tag.fill` (indigo) when a tag filter is active
- `tagCounts` computed property on `LibraryViewModel` parses comma-separated tags

**Subtasks (`SubtaskStore`, `TaskRowView`, `SubtaskEditorView`)**
- **Supabase-backed** — syncs across iPhone, iPad, and Mac via `subtasks` table
- `SubtaskStore.shared.loadAll()` called at app startup in ContentView
- Long-press any Do-tab item → context menu → "Manage Subtasks" (`.contextMenu` used instead of `.onLongPressGesture` because inner Buttons swallow gestures in SwiftUI List)
- Inline expand/collapse with spring animation and mini progress capsule
- `SubtaskEditorView`: half-sheet (`.presentationDetents([.medium, .large])`), staggered entrance animation, auto-focuses add field
- **iPad/Mac Do tab** uses `TaskRowView` (same as iPhone) for full subtask support

**Editable fields in ArticleDetailView**
- Title: tap to edit inline (TextField + Save/Cancel)
- Category: Menu picker from `vm.categories` + "None" option
- Tags: tap to edit comma-separated TextField; normalizes to lowercase on save; always visible with "Add tags…" placeholder

**Swipe actions (iPhone)**
- Swipe right: Done/Undo toggle (green)
- Swipe left: Delete (red), Do (blue, sets status to "to-try"), Info (indigo)

**iPad/Mac specific**
- `NavigationSplitView` with sidebar (Read/Do/Library), article list, reader
- Portrait reading mode: auto-collapses to `.detailOnly` when article selected, back button to return
- Do tab uses `TaskRowView` with subtask support (same as iPhone)

### iOS App — AI Rule: Always Use Foundation Models

**All AI features in the iOS app use Apple's on-device Foundation Models (`FoundationModels` framework, iOS 26+). Never use external AI APIs (Claude API, OpenAI, etc.) in the iOS app — they cost money per call, require API keys in the app, and go over the internet.**

- Use `LanguageModelSession` (from `FoundationModels`) for all generative AI in the app
- Always gate with `if #available(iOS 26, *)` and provide a graceful fallback (`ContentUnavailableView` or skipping AI) for older OS
- Context passed to the model should always be pre-aggregated / summarised — never dump raw large data sets
- This rule applies to ALL new AI features: if it's in the iOS app, it uses Foundation Models, full stop

The website (`reading-list.js`) has no access to Foundation Models. If a website feature needs AI, that's a separate conversation — but the default answer is "do it from the iOS app instead."

### iOS App — Known Issues / Gotchas

- **`Link` name conflict:** The app's `Link` model clashes with `SwiftUI.Link<Label>` in SourceKit's single-file analysis. This shows as "Reference to generic type 'Link' requires arguments" in the IDE but **does not cause actual build failures** — the module compiler resolves it correctly. Do not rename the model.
- **Mac Catalyst SourceKit warnings:** `topBarLeading`, `topBarTrailing`, `navigationBarTitleDisplayMode` show as "unavailable in macOS" in the IDE but are fully supported on Mac Catalyst (iOS APIs via Catalyst). These are false positives — ignore them.
- **PBXFileSystemSynchronizedRootGroup:** The Xcode project uses filesystem-synced groups. New `.swift` files added to the correct folder are automatically included in the target — no need to manually edit `project.pbxproj` to add sources.
- **Deployment:** `chrislrose.aseva.ai` is company-managed and does NOT auto-deploy from GitHub pushes. GitHub Pages mirror auto-deploys. To update the primary site, manual deployment is needed (SSH access required).
- **Subtask sync:** Subtasks migrated from local UserDefaults to Supabase. Old local subtasks do NOT migrate — only new ones sync. If subtasks are not syncing, verify the `subtasks` table exists in Supabase and the RLS policies allow public CRUD.
- **Mac app distribution:** Without $99/year Apple Developer account, the Mac Catalyst app must be built from Xcode and manually copied to `/Applications`. Free provisioning certificates expire every 7 days. With paid account: Product → Archive → Distribute App → Direct Distribution.
- **iOS 26 Form buttons must use `.buttonStyle(.plain)`:** In iOS 26's Liquid Glass List rendering, buttons inside Form rows (especially multiple buttons in an HStack) will not fire reliably without explicit `.buttonStyle(.plain)`. Always add this to any Cancel/Save or action buttons placed inside a `Form`/`List` `Section`. Also use `@FocusState` on `TextEditor` fields to explicitly dismiss focus before saving.
- **`ArticleDetailView` is Form-based (not ScrollView):** Rewritten in the Curate AI commit. Contains: title row (tap to edit inline), status + category, rating (stars), tags, AI summary (read-only), note. All editable fields use the tap-to-edit inline pattern with Cancel/Save buttons.
- **`EnrichSheetView` is dead code:** After the `ArticleDetailView` rewrite, no view presents `EnrichSheetView`. Enrich with AI is still available via `LibraryView` toolbar menu → "Enrich All". Single-article enrich needs to be re-wired if needed.

### Website — OG / Social Previews

All HTML pages have Open Graph and Twitter Card meta tags for iMessage/social rich link previews:
- `og-image.png` — main site preview (1200×630, dark indigo)
- `og-reading-list.png` — reading list preview
- `c.html` — static collection share handler with OG tags + JS redirect to `reading-list.html?collection=ID`
- Collection share URLs use `c.html?id=` — set in `reading-list.js`
- OG images must be **PNG** (not SVG) — iMessage and most crawlers do not render SVG

### iOS Shortcut ("add-to-reading-list")

- Syncs across iPhone, iPad, Mac via iCloud
- Flow: Receive Any from Share Sheet → Get URLs from Input → construct `reading-list.html?add=URL` → Open
- Works on iOS (all apps), Mac Safari. Mac RSS apps (e.g., ReadKit) may not pass URLs through share sheet properly — clipboard workaround needed.
- **Must be logged into admin mode** on `chrislrose.aseva.ai` in the device's browser for silent quickSave. First use on a new device requires one-time admin login.

---

## Session Summary — 2026-03-25 (continued)

### Security Work (Website + Supabase)
- **RLS enabled** on 7 previously unprotected tables: `gear_hardware`, `gear_software`, `gear_projects`, `gear_podcasts`, `gear_hobbies`, `site_content`, `collections`
- Policies applied: public SELECT (anon key), authenticated INSERT/UPDATE/DELETE only
- Supabase anon key in client-side JS is **by design** — the real protection is RLS. No service role key was ever exposed.

### iOS Features Built This Session

| Feature | Entry Point | Status |
|---------|------------|--------|
| Daily Digest | Toolbar → "Today's Reading" | ✅ Done |
| Library Insights | Toolbar → "Library Insights" + iPad sidebar | ✅ Done |
| Notes Review | Toolbar → "Notes Review" + iPad sidebar | ✅ Done |
| Notes Review — custom date range | Part of Notes Review | ✅ Done |
| Notes Review — action items → subtasks | Part of Notes Review | ✅ Done |

### Key Architectural Decisions Made
- AI context is always **pre-aggregated stats or capped lists** — never raw link dumps to Foundation Models
- All three AI views follow the same phase state machine pattern (`idle → generating → ready / unavailable / error`) from `EnrichSheetView`
- Notes Review filters by `savedAt` (article save date) as a proxy for "when you wrote the note" — acceptable because there is no `note_updated_at` field in the schema
- Action items use `[N]` prefix convention in the AI response to identify source article for subtask auto-attachment

### Curate — AI-Personalised Messages (iOS app)
- `CurateSheetView` now has a "Personalise with AI" button (iOS 26 only)
- Flow: enter recipient name + hint → Foundation Models writes a warm first-person message as Chris, drawing on article titles, Chris's notes, and AI summaries → user sees editable preview → "Create Share Link" saves `enriched_message` to Supabase
- `SupabaseClient.createCollection` updated to accept `enrichedMessage` parameter
- Website `renderCollectionBanner` already renders `enriched_message` as paragraphs when present
- Falls back to basic link creation (no AI message) on iOS < 26

### Bug Fix — ArticleDetailView Note/Title/Tags Save (2026-03-25)
- **Bug:** After the Curate AI commit rewrote `ArticleDetailView` from ScrollView → Form, the inline Cancel/Save buttons in note/title/tags editing rows stopped working.
- **Cause:** iOS 26 Liquid Glass List rendering intercepts row-level taps before individual buttons fire unless buttons have `.buttonStyle(.plain)`.
- **Fix:** Added `.buttonStyle(.plain)` to all Cancel/Save buttons in `noteRow`, `titleRow`, `tagsRow`. Added `@FocusState` (`noteEditorFocused`) to `ArticleDetailView` so the TextEditor keyboard is explicitly dismissed before note save fires.

### Potential Next Steps
- **Supabase schema:** Add `note_updated_at` column to `links` table so Notes Review can filter by when the note was actually written (currently filters by `savedAt`)
- **Notes Review:** Consider a "week-at-a-glance" calendar view showing which days had saved articles with notes
- **Library Insights:** Could add trend comparison (this month vs last month)
- **Daily Digest:** Consider a push notification or widget that surfaces the digest summary
- **Distribution:** iOS app still requires manual Xcode build + copy. Paid Apple Developer account ($99/yr) would enable direct distribution archive

---

## Session Summary — 2026-03-27

### What We Built: Persistent Curate Recipients

The Curate feature was completely rearchitected. Previously, each "Curate" created a one-time snapshot collection with a new URL every time. Now recipients are persistent people with permanent URLs they can bookmark.

#### New Supabase Tables (must be created manually in Supabase SQL Editor)
- **`recipients`** — `id` (uuid), `name`, `slug` (unique, URL-safe), `created_at`
- **`recipient_batches`** — `id`, `recipient_id` (FK → recipients), `link_ids[]`, `note`, `enriched_message`, `created_at`
- Both tables have RLS: public SELECT, authenticated INSERT/UPDATE/DELETE
- SQL is in the plan file at `/Users/macmini/.claude/plans/resilient-greeting-penguin.md`

#### iOS App Changes
- **`Recipient.swift`** — new model (`Models/Recipient.swift`)
- **`SupabaseClient`** — new methods: `fetchRecipients()`, `createRecipient(name:slug:)` (with slug-conflict retry + 401 token refresh), `createBatch(recipientId:linkIds:note:enrichedMessage:)`
- **`CurateSheetView`** — fully redesigned with new phases: `loading → recipientPicker → newRecipient → form → generating → preview → saving → success`
  - On open: loads recipients from Supabase, shows picker or "New Person…" if empty
  - Each curate session creates a batch tied to the chosen recipient
  - Success screen shows permanent URL: `reading-list.html?recipient=<slug>`
  - Two labeled sections on preview: **Personal note** (your words, verbatim) + **AI Summary** (objective editorial summary of the articles, not a fake personal message)
  - "Generate AI Summary" + "Add to Feed without AI" both available on iOS 26
- **Auth fix:** Expired sessions now silently degrade to guest (public links) instead of showing "Session expired" error with no sign-in path

#### Website Changes (`reading-list.js`, `styles.css`)
- `?recipient=<slug>` mode: fetches recipient + all batches, deduplicates articles across batches, renders full living feed
- Latest batch articles get a **diagonal "NEW" ribbon** on their thumbnail
- Banner shows two labeled sections per batch: "✏️ Personal note" and "✨ AI Summary"
- Multiple batches: newest shown, older ones collapsible under "N older updates" `<details>` block
- Legacy `?collection=` URLs unchanged

### Current State
| Component | Status |
|-----------|--------|
| Supabase tables (`recipients`, `recipient_batches`) | ⚠️ **Requires manual SQL run in dashboard** |
| iOS app code | ✅ Built, needs Xcode rebuild |
| Website (`reading-list.js`, `styles.css`) | ✅ Deployed to GitHub Pages |
| Primary site (`chrislrose.aseva.ai`) | ✅ Deployed (auto-deploys from main) |

### Known Issues / Next Steps
- **Supabase SQL:** If not yet run, `createRecipient` and `createBatch` will fail with "Failed to save changes." Check Xcode console for the exact error (❌ print lines added).
- **No recipient management UI:** Recipients can only be created from the iOS Curate flow. There is no way to rename or delete a recipient yet — would need to be done directly in Supabase dashboard or a future admin UI.
- **No article removal from feed:** Feeds are append-only by design. A future "remove article" feature would need a join table approach rather than the current `link_ids[]` array.
- **`note_updated_at`:** Notes Review still filters by `savedAt` as a proxy. Adding a `note_updated_at` column to `links` would make it more accurate.
- **Distribution:** iOS app requires manual Xcode build + copy to device. Paid Apple Developer account ($99/yr) would enable direct distribution.

---

*Last updated: 2026-03-27 by Claude Code*
