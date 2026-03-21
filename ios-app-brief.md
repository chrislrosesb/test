# iOS Reading List App — Full Brief

*Written 2026-03-21. This document captures all decisions, ideas, and context from the planning conversation so work can resume on any machine.*

---

## Concept

A native iOS 26 reading list app that serves as a beautiful, fast front-end to the same Supabase database that powers the website reading list at `https://chrislrose.aseva.ai/reading-list.html`. The app is primarily a **reading and discovery experience** — saving articles continues through the existing iOS Shortcut/bookmarklet workflow.

---

## Key Decisions Made

### What the app IS
- A native SwiftUI reading experience for the existing Supabase `links` table
- Browse, search, filter, open articles
- On-device AI enrichment via Foundation Models (iOS 26)
- Liquid Glass iOS 26 design language throughout
- Same Supabase backend as the website — any changes in the app show on the web and vice versa

### What the app is NOT
- Not a replacement for the website/admin panel (adding categories, bulk editing stays on web)
- No Share Extension for saving articles — **this was deliberately skipped** because:
  - Requires $99/year Apple Developer account for the 1-year cert
  - Without it, app and extension must be re-signed every 7 days which would break the share sheet mid-workflow
  - The existing iOS Shortcut → bookmarklet → Supabase flow works well and should be kept as-is

### Saving flow (unchanged)
Keep the existing setup exactly as-is:
- iOS Shortcut exposed in the Share Sheet calls the bookmarklet
- Bookmarklet opens `https://chrislrose.aseva.ai/reading-list.html?add=URL`
- Article saves to Supabase
- App picks it up on next open / pull to refresh

### Developer account
- **No paid Apple Developer account** ($99/year)
- Use free personal team in Xcode
- App installs on user's own iPhone via USB from Xcode
- Cert expires every 7 days → reconnect phone, hit Run in Xcode (30 seconds)
- This is acceptable because the app is a reader, not a share extension — expiry doesn't break any active workflows

---

## Supabase Connection

```
URL:  https://ownqyyfgferczpdgihgr.supabase.co
Anon key: sb_publishable_RPJSQlVO4isbKnZve8NlWg_55EO350Y
```

### Tables used by the app
- `links` — main reading list (see data model below)
- `categories` — managed list with `name` + `sort_order`

### links table data model
```
url           text
title         text
description   text
image         text        (OG image URL)
favicon       text
domain        text
category      text        (single, from categories table)
tags          text        (freeform comma-separated)
stars         int         (1–5)
note          text        (personal note)
status        text        ('to-read' | 'to-try' | 'to-share' | 'done' | null)
read          boolean     (kept in sync with status for backwards compat)
private       boolean
saved_at      timestamptz
```

---

## iOS 26 Design Features to Use

### Must-have
- **Liquid Glass** — `.glassEffect()` modifier on cards, search bar, filter chips, action buttons, sheets
  - Use `GlassEffectContainer` to coordinate transitions between glass elements
  - Apply `.interactive()` on tappable glass elements for bounce/shimmer feedback
- **Floating tab bar with minimize** — `.tabBarMinimizeBehavior(.onScrollDown)` so the tab bar hides while reading and reappears on scroll up
- **Spring animations** — `.spring(duration: 0.5, bounce: 0.6)` for card transitions, sheet appearances, filter changes
- **In-app browser** — Native WebView integration to open articles without leaving the app
- **Search tab role** — `Tab(role: .search)` for consistent search placement

### Nice-to-have
- **Dynamic Island** — flash a confirmation when an article is saved (brief activity), or show unread count
- **Home screen widget** — recent saves or unread count with Liquid Glass widget styling
- **Lock screen widget** — unread count

### Inspiration
- Apple Invites app: Liquid Glass panels over full-bleed imagery, spring-physics card interactions, tab bar minimize. The reading list cards should use article thumbnail images as full-bleed backgrounds with a glass overlay for title/metadata.

---

## Foundation Models (On-Device AI) Features

All AI runs via the `FoundationModels` framework introduced in iOS 26. Completely on-device, private, no API cost, no network needed.

### The Enrich Button (core feature)
Each article card has an **Enrich** button. Tapping it runs all of the following in a few seconds and presents results in a glass sheet for review:

1. **Title cleanup** — strips site names, pipes, SEO garbage from scraped titles
   - "The 10 Best AI Tools You NEED in 2025 | TechCrunch" → "10 Essential AI Tools for 2025"
2. **TL;DR summary** — 2–3 sentence summary saved to the `note` field
3. **Tag suggestions** — shows chips the user taps to accept or dismiss, writes back to `tags`
4. **Category suggestion** — highlights the best match from existing categories
5. **Status suggestion** — tutorial content → to-try, opinion/news → to-share, deep research → to-read

User reviews suggestions in the sheet → taps Accept → writes back to Supabase → updates the website too.

### Enrich All
A button (possibly in a toolbar or settings) that runs enrichment across the entire unread pile in the background. User taps and walks away; comes back to a fully enriched library.

### Batch Triage View
A dedicated screen showing un-enriched articles as a swipeable card stack:
- Swipe right → accept all AI suggestions
- Swipe left → skip this article
- Very fast way to process a large backlog

### Other Foundation Models ideas to consider
- **Natural language search** — "articles about SwiftUI I haven't read yet" interpreted semantically
- **Related articles** — semantic similarity within the library, shown at the bottom of each article
- **Daily digest** — morning summary: "You have 12 unread. 4 about AI. Here are 3 to start with."
- **Cross-article insights** — "You've saved 9 articles about AI agents this month"
- **"Why did I save this?"** — for old unsorted saves, infer likely reason from surrounding saves
- **Expand quick notes** — user types "good ref" → model expands to something useful based on article content
- **Duplicate detection** — "You saved something similar in March — want to link them?"

---

## App Structure (Suggested)

### Tab bar (floating, Liquid Glass, minimizes on scroll)
1. **Reading List** — main feed, all articles with filters
2. **Search** — dedicated search tab (Tab role: .search), natural language
3. **Triage** — batch enrichment / swipe-to-process view
4. **Stats / Insights** — reading patterns, AI insights, streaks (optional, build last)

### Main reading list view
- Filter chips at top: All / To Read / To Try / To Share / Done
- Category filter (same categories as website)
- Article cards: full-bleed thumbnail, glass overlay with title + domain + tags
- Swipe actions: mark read, change status, delete
- Tap → in-app WebView browser
- Long press → quick actions sheet (Enrich, Copy URL, Share, Delete)

### Article detail / reader
- Full-bleed hero image
- Title (cleaned), domain, saved date
- TL;DR summary (if enriched)
- Tags, category, status pill
- "Open in browser" button (opens WebView)
- Enrich button if not yet enriched
- Note field (editable)

---

## Tech Stack

- **Language:** Swift
- **UI framework:** SwiftUI (iOS 26 target)
- **Minimum iOS version:** iOS 26
- **Backend:** Supabase (existing, shared with website)
- **Supabase Swift SDK:** `github.com/supabase/supabase-swift`
- **AI:** `FoundationModels` framework (iOS 26, on-device)
- **Architecture:** MVVM — `ReadingListViewModel` fetches from Supabase, publishes to views

---

## Article Reading — Three Modes

Three reading modes, offered via a **Reader | Web** toggle in the toolbar. A smart fallback chain picks the best available mode automatically.

### Fallback chain (automatic)
```
Tap to read
    ↓
Pre-fetched content in Supabase? → Reader view (instant, fully offline)
    ↓ not available
Fetch + parse with Readability?  → Reader view (clean, no ads)
    ↓ fails (paywall / JS-heavy / blocked)
Full WebKit view                 → always works
```

### Mode 1 — Full WebKit (WKWebView)
Full webpage rendered inside the app. No leaving to Safari.
- **Pros:** Always works, supports paywalls, renders exactly as intended
- **Cons:** Slow on heavy pages, ads load, no typography control
- **Effort:** Trivial — SwiftUI `WebView` is a few lines

### Mode 2 — Reader View (Readability)
Strips the page to article text + images, rendered in clean customisable typography. Same algorithm used by Safari Reader, Reeder, Instapaper, Pocket.
- Uses the open-source **Readability.js** (Mozilla) bundled inside a hidden WKWebView, or a Swift package equivalent
- **Pros:** Fast, clean, beautiful, no ads, your typography
- **Cons:** Fails on paywalled/JS-heavy sites — falls back to WebKit automatically
- **Effort:** Medium — integrate Readability library, handle failures

### Mode 3 — Pre-fetched (RSS-style, fastest)
Article text fetched and stored in Supabase at save time, not read time. Loads instantly, works fully offline.
- Requires a **Supabase Edge Function** that runs Readability on the URL when an article is saved and stores extracted text in a new `content` column on the `links` table
- Content is frozen at save time (doesn't update if article changes later)
- **Effort:** Medium-high — Edge Function + new DB column + UI

### Reader typography controls
When in Reader or Pre-fetched mode, expose a typography panel (common in RSS apps):
- Font size (slider)
- Line height
- Font choice: sans-serif (Inter/system) vs serif (New York)
- Theme: Dark / Light / Sepia

### Implementation note
Build Mode 1 first (trivial), Mode 2 second (most useful day-to-day), Mode 3 last (nicest but requires backend work). The Reader/Web toggle in the toolbar lets the user override the automatic fallback at any time.

---

## Development Setup (on the new Mac)

1. Install **Xcode 26** from the Mac App Store (~15GB)
2. Pull this repo: `git clone https://github.com/chrislrosesb/test.git`
3. Create a new Xcode project: **File → New → Project → iOS → App → SwiftUI**
   - Product Name: `ReadingList`
   - Bundle ID: `com.chrisrose.readinglist`
   - Minimum Deployment: iOS 26
   - Save inside the cloned repo folder (e.g. `/test/ios/`)
4. Open the project folder with Claude Code (`claude` in the terminal)
5. Sign into Claude in Xcode: **Xcode → Settings → Intelligence**
6. Claude Code builds everything from here

### Xcode + Claude Code integration
- Xcode 26.3 natively runs the Claude Agent SDK (same as Claude Code CLI)
- Sign into Claude in Xcode Intelligence settings
- Claude can write code, trigger builds, read SwiftUI previews, and iterate autonomously
- Also set up **XcodeBuildMCP** server for Claude Code CLI → Xcode build system integration

---

## Build Order (suggested phases)

### Phase 1 — Read-only viewer
- Supabase fetch, display links in a list
- Basic filter by status and category
- Tap to open articles using the smart reader (see Article Reading section below)
- iOS 26 design: Liquid Glass cards, floating tab bar

### Phase 2 — Enrich
- Foundation Models integration
- Enrich button on each card
- Review sheet with accept/dismiss for each suggestion
- Writes back to Supabase

### Phase 3 — Batch features
- Enrich All background task
- Batch triage swipe view
- Natural language search

### Phase 4 — Polish & extras
- Dynamic Island integration
- Home screen widget
- Daily digest
- Stats/insights tab

---

## Website Reading List Reference

For UI/UX reference, the web reading list is at:
`https://chrislrose.aseva.ai/reading-list.html`

Key web features that should translate to the app:
- Filter by category (chips)
- Filter by status (to-read / to-try / to-share / done)
- Star ratings (1–5)
- Search (multi-token fuzzy — each space-separated word matches independently)
- Grid view (tiles) and list/feed view
- Copy URL button per card
- Admin: add/edit/delete links, manage categories (stays web-only)

---

*Resume this work on the new Mac by pulling the repo and showing Claude Code this file.*
