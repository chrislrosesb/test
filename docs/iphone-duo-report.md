# iPhone Duo × Procrastinate — Research Report

*Researched 2026-10-26 from Apple's official "Designing for iPhone Duo" HIG (published Sept 9, 2026), Apple Tech Talk summaries, and developer write-ups. This is the working doc for mocking up a Duo version of Procrastinate.*

---

## 1. The device in one paragraph

iPhone Duo is Apple's first foldable, announced Sept 9, 2026, shipped Oct 23, 2026 with **iOS 27.1** (the first and only Duo-supported iOS version — 27.1 shipped exclusively for it, and the fold-aware APIs arrived in the 27.1 SDK + Xcode 27.1). It's a book-style fold: a **5.4″ outer (cover) display** and a **7.6″ near-square inner display**, both OLED, 120Hz ProMotion, same 1.42:1 aspect ratio. A20 Pro chip, from $1,999. The matching aspect ratio is deliberate: content *scales* rather than rearranging when you open/close the phone.

## 2. Screen geometry (the numbers mockups need)

| Display | Physical px | Logical points (@3x) | Aspect | Size classes |
|---|---|---|---|---|
| **Outer (closed)** | 1398 × 2034, 460ppi | **466 × 678 pt** portrait | 1.45:1 | compact width × regular height (a normal, slightly wide iPhone) |
| **Inner (open)** | 1878 × 2670 panel, 430ppi | **669 × 951 pt** portrait (App Store screenshot spec 2007 × 2853 = @3x logical) | 1.42:1 | **regular × regular** (iPad-class!) |

- Natural orientation of the inner display is **landscape: 951 wide × 669 tall**.
- Outer display ≈ 90% of an iPhone 18 Pro's screen area; inner is 50% larger than an 18 Pro Max.
- **Mockup canvases:** closed = 466×678; open portrait = 669×951; open landscape = 951×669; book pose = two ~460-470pt-wide halves with a reserved fold strip in the middle.

## 3. Device poses (the layout states)

Apple's HIG shows **six poses**, but insists you do NOT design one layout per pose — you design **two size-class layouts** (compact = outer, regular = inner) and let them adapt:

1. **Closed** — outer display only. Compact width. System moves tab bar, toolbar, status bar and Dynamic Island to the **side** (vertical controls, see §4).
2. **Open flat, portrait** — inner display, regular×regular. The one pose that keeps **normal horizontal bars** (enough vertical space).
3. **Open flat, landscape** — inner display; controls stay **vertical on the side**, same height as on the outer display, so nothing jumps as you open the phone.
4. **Partially folded "book"** — held like a paperback. The fold divides the inner display into **left/right regions**. Split panes equalize their widths; alerts/menus/sheets slide to one side; nothing should sit on the crease.
5. **Tabletop / "laptop"** — half-folded, sitting on a surface, hinge horizontal. Fold divides screen into **top/bottom**: *content/media on the top half, touch controls on the bottom half* (Apple's example layout). Optional but a lovely demo moment.
6. **Standing on its edges** (tent/stand, e.g. with the $129 Folio kickstand) — hands-free viewing: video calls, recipes, timers.

**Opening/closing behavior:** the app does NOT background — it adapts in place and must preserve everything (scroll position, text selection, playback position, half-typed forms). Mail's canonical pattern: closed = inbox *or* one email; open = both side-by-side.

## 4. What iOS 27.1 changes system-wide on Duo

- **Vertical controls** — on the outer display (and inner-landscape), the Dynamic Island, status bar, toolbar and tab bar all run **vertically along one side** (trailing edge in LTR, aligned with the corner camera). Top of the stack = Back/Close, then prominent actions (Done), then grouped toolbar items, tab bar below. You get this free from standard SwiftUI `TabView`/`toolbar` **after rebuilding with the iOS 27.1 SDK** — old binaries run letterboxed beside the status bar instead.
- **Bar compression** — when space runs out, toolbars compress into an overflow menu before tabs (default), or you flip it for task-focused screens (`ToolbarVerticalCompressionBehavior`). Items need **symbol + title** so the system can re-render them; set `visibilityPriority` on the ones that must survive (e.g. a badge).
- **Split View multitasking on iPhone** — first time ever: two apps (or two windows of one app) share the inner display; each puts its vertical controls on its *outer* edge. Users can save app pairs. Your app may get roughly half of 951pt.
- **Dynamic Island on the side** — expands vertically for Live Activities. Never assume symmetric top/bottom safe areas; safe areas on Duo are **asymmetric per edge**.
- **Dock & Home Screen controls move to the sides** too.

## 5. The new layout APIs (iOS 27.1 SDK)

| API | What it does | Procrastinate relevance |
|---|---|---|
| `ReservedRegion` (SwiftUI `GeometryProxy`/UIKit `UIView`) | Query regions content must avoid: **division regions** (the fold when partially open), **occlusion regions** (inner camera when active, outer camera/Dynamic Island). Scrolling feeds don't need to dodge it; important fixed controls do. | Keep reader toolbar & FAB-ish controls off the crease. |
| `ArrangementView` / `UIArrangementViewController` | Container for exactly two views that auto-arranges around the fold. **Split** type = side-by-side (horizontal when wide, vertical when tall) for two views that must both stay visible. **Overlay** = one atop the other; when partially folded, they separate onto the two halves. Layout only — never put navigation inside one, never inside a scroll view/list. | Tabletop audio-briefing layout (artwork top / controls bottom); reader + notes pairing. |
| `onHingeChange` / `UIHingeInteraction` | Discrete hinge states + continuous angle. Apple: use for *effects*, not layout (layout belongs to arrangements + reserved regions). Must handle no-hinge devices. | Gimmick potential only; skip for v1. |
| `NavigationSplitView` / `UISplitViewController` | Adapt automatically: expand to columns on inner, collapse to single pane on outer, auto-adjust pane widths around the fold (like Notes). | **Our main tool — we already use it on iPad.** |
| `ToolbarOverflowMenu` / `additionalOverflowItems` | Merge custom overflow into the single system overflow menu. | Hamburger-menu actions could fold in here. |
| Xcode 27.1 **Device Hub** | Simulate open, close, rotate, partial fold — no hardware needed. | How we'll test mockups → real builds. |

**Apple's hard rules:** never branch on `userInterfaceIdiom` (Duo still reports *iPhone*), interface orientation, or `UIScreen.main`. Size classes + local geometry only. The inner display even ignores your supported-orientations list for resizable apps.

## 6. What this means for Procrastinate specifically

The genuinely good news: **we already built the regular-width app** — `IPadNavigationView` (NavigationSplitView, sidebar, list + reading pane). The Duo inner display is regular×regular, exactly the environment that layout targets.

The catch: **if ContentView picks iPhone-vs-iPad UI by device idiom, Duo gets the stretched iPhone TabView on the inner display** — precisely the anti-pattern Apple calls out. The single most important code change is switching that decision to `horizontalSizeClass`:
- compact → `TabView` (outer display, and Split View half-width)
- regular → `IPadNavigationView` (inner display)

Then one phone gives us both experiences, and fold/unfold morphs between them — which also forces us to preserve state across the swap (open article, scroll position, playing audio briefing).

### Mockup-worthy moments, per pose

1. **Closed (466×678)** — Read/Do/Library/Discover tab bar runs *vertically down the right edge* with the hamburger at top. One-handed triage: save, mark done, quick skim. This is "the iPhone 18 that happens to open."
2. **Open portrait (669×951)** — Library as a true card grid (even number of columns — Apple says grids should split cleanly at the fold), horizontal bars like today's iPad.
3. **Open landscape (951×669)** — Mail-style reader: reading list left pane, article right pane, vertical controls on the trailing edge. Our `IPadNavigationView` almost verbatim.
4. **Book pose (half open, vertical fold)** — two equal panes: list left / article right, pane widths equalized, nothing on the crease. Alerts hop to the trailing half.
5. **Tabletop (half open, horizontal fold)** — **Audio Briefing mode**: artwork + transcript on the top half, transport controls on the bottom half (an overlay `ArrangementView`). Also great for Today's Reading digest while making coffee.
6. **Split View** — Procrastinate article on one side, Notes/Safari on the other; our controls hug our outer edge.

### Lower-priority Duo-isms
- Dynamic Island is on the *side* now — any future Live Activity mock should reflect that.
- Keep push-notification copy short enough for the outer display.
- Inner camera is invisible until active (we don't use the camera — ignore).
- `CameraCaptureAccessory` (outer-display preview while shooting on inner) — not relevant to us.

## 7. Suggested mockup plan (next step, not started)

1. Static HTML/SVG mock, one artboard per pose above (6 frames), using the real point dimensions from §2 and Procrastinate's existing palette.
2. The hero frames: **closed triage view**, **open landscape reader**, **tabletop audio briefing**.
3. If we then want it live: the size-class switch in `ContentView` + a Device Hub run in Xcode 27.1 would put the real app on a simulated Duo.

## 8. Sources

- [Apple HIG — Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo) (primary; poses, reserved regions, arrangement views, vertical controls)
- [Apple — iPhone Duo tech specs](https://www.apple.com/uk/iphone-duo/specs/)
- [swiftjective-c — iPhone Duo first developer good-to-knows](https://swiftjectivec.com/iPhone-Duo-First-Developer-Good-to-Knows/) (Tech Talk summaries: hinge APIs, bars, camera, Device Hub)
- [Appwrite — iPhone Duo: what's new and what developers can build](https://appwrite.io/blog/post/phone-duo-whats-new-and-what-developers-can-build) (hardware, readiness checklist, app-type effort table)
- [Blake Crosley — Designing for iPhone Duo / The 1.42 Problem](https://blakecrosley.com/blog/designing-for-iphone-duo) (point math, what moves/splits/stays)
- [iClarified — Apple details how apps should work on iPhone Duo](https://www.iclarified.com/102174/apple-details-how-apps-should-work-on-iphone-duo) (Mail/Notes/Netflix examples, app pairs)
- [RevenueCat — Paywalls on iPhone Duo](https://www.revenuecat.com/blog/engineering/paywalls-on-iphone-duo.md) (sheets & fold)
- Caveat: inner-display point size (669×951) comes from App Store screenshot specs; a couple of API names were reconstructed from Apple's Tech Talk captions by third parties — verify in the Xcode 27.1 SDK before building for real.
