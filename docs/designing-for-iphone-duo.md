# Designing for iPhone Duo — Context for AI Agents

> Hand this file to any LLM working on an iOS app that must support iPhone Duo. It is self-contained. Compiled 2026-10-26 from Apple's Human Interface Guidelines page "Designing for iPhone Duo" (published 2026-09-09), Apple's iPhone Duo tech talks, and Apple's spec sheet. Where a detail comes from secondary sources it is marked *(unverified)* — confirm against the Xcode 27.1 SDK before relying on it.

---

## 0. Read this first: the three rules agents get wrong

1. **Do not redesign the app.** Duo support means *adapting the existing app's layouts*, not inventing a new look. Before designing anything, read the app's actual SwiftUI/UIKit source: its color scheme (light/dark/forced dark), tint colors, fonts, card styles, corner radii, icons (SF Symbol names), and existing iPad/regular-width layouts. Reuse all of it.
2. **It must look like a native iOS 26/27 app with Liquid Glass**, not a web app. That means system materials, SF Pro / SF Symbols, system colors, glass toolbars and tab bars, capsule controls — never web-style flat cards, custom brand palettes, or "website" typography.
3. **Never branch on device.** Duo still reports itself as an **iPhone** (`userInterfaceIdiom == .phone`) even when the inner display is iPad-sized. Choose layouts with **size classes and container geometry**, never idiom, interface orientation, model name, or `UIScreen.main.bounds`.

---

## 1. The hardware

| | Outer (cover) display | Inner (folding) display |
|---|---|---|
| Size | 5.4″ OLED | 7.6″ OLED, folds in the middle |
| Pixels | 1398 × 2034 @ 460 ppi | App Store screenshot spec 2007 × 2853 |
| **Points (@3x) — use these for mockups** | **466 × 678** (portrait) | **669 × 951** portrait / **951 × 669** landscape |
| Aspect | ~1.45 : 1 (wider & shorter than other iPhones) | ~1.42 : 1 (near-square) |
| Size classes | **compact width** × regular height | **regular width × regular height** (iPad-class) |
| Front camera | In the corner, always visible; the Dynamic Island grows out of it | Under the display — invisible until the camera is active |

- Both displays: ProMotion 120 Hz, Always-On, up to 3,000 nits.
- Natural orientation of the inner display is **landscape**.
- Ships with **iOS 27.1** — the first iOS version supporting Duo. The Duo APIs are in the **iOS 27.1 SDK / Xcode 27.1**. Apps must be **rebuilt with the 27.1 SDK** to get edge-to-edge layouts and vertical bars; old binaries run letterboxed beside the side status bar.

---

## 2. Poses (device postures)

Apple shows six poses: closed, open portrait, open landscape, partially folded like a book, set down on a surface (tabletop), and standing on its edge (tent / with a kickstand case).

**You do NOT design one layout per pose.** Design two size-class layouts and let them adapt:
- **Compact width** → outer display (and a narrow Split View slot on the inner display).
- **Regular width** → inner display.

What changes per pose:

| Pose | Display | Layout behavior |
|---|---|---|
| **Closed** | Outer, 466×678 | Compact layout. Tab bar, toolbar, status bar and Dynamic Island run **vertically down the trailing edge**. |
| **Open, portrait** | Inner, 669×951 | Regular layout. The **only** pose that keeps standard **horizontal** top/bottom bars. |
| **Open, landscape** | Inner, 951×669 | Regular layout. Controls stay **vertical on the side**, at the same height as when closed, so nothing jumps when you open the phone. |
| **Partially folded, book** (fold runs vertically) | Inner | The fold becomes a reserved region splitting the screen into **left / right** halves. Split-view panes become **equal width**. Alerts, menus, sheets and popovers move off the crease (alerts go to the trailing half). |
| **Tabletop** (fold horizontal, bottom half flat on a table) | Inner | Fold splits **top / bottom**. Put content to *watch* on top and **touch controls on the bottom** half. Optional, but it's the strongest demo moment for media apps. |
| **Standing on edge / kickstand** | Inner or outer | Hands-free use: video, recipes, timers, calls. |

**Open ↔ closed transitions:** the app is **not** backgrounded. It resizes in place. You must preserve all state across the swap: navigation stack, scroll position, text selection, form input, playback position, uploads in flight. The two displays share an aspect ratio, so content **scales** rather than reflowing dramatically.

Apple's canonical example (Mail): closed shows the inbox *or* one email. Open shows both side by side.

---

## 3. Vertical controls — the signature Duo pattern

On the outer display (and the inner display in landscape), the system moves bars that are normally at the top and bottom of the screen **to the side**, to save vertical space.

Top-to-bottom order along the trailing edge:
1. Camera / **Dynamic Island** (it expands *vertically* for Live Activities)
2. Status bar
3. **Toolbar**: navigation item (Back / Close / menu) at the top, then the prominent action (Done), then the remaining grouped items
4. **Tab bar** at the bottom

Rules:
- Use **standard** `TabView`, `.toolbar`, `NavigationStack` and `NavigationSplitView`. You get vertical placement for free. Standalone UIKit bar instances do **not** participate.
- Give every toolbar item **both a title and an SF Symbol**, so the system can choose how to show it. Prefer symbols, because text-labelled buttons stay horizontal.
- Group related items with `ToolbarItemGroup` / `UIBarButtonItemGroup`. Don't add manual spacers.
- When space runs out, items overflow from bottom to top. Set `visibilityPriority` on items that must stay visible (frequent actions, items with badges).
- Bar compression: navigation-focused screens collapse the **toolbar** into overflow and keep the tab bar (the default). Task-focused screens collapse the **tab bar** instead (`ToolbarVerticalCompressionBehavior` / `UIVerticalBarCompressionBehavior`).
- Move custom overflow menus into the **system overflow menu** (`ToolbarOverflowMenu` / `additionalOverflowItems`). Use the ellipsis only for overflow.
- Keep controls next to the content they affect. In a two-pane layout, the leading pane's controls stay at the **top of that pane**. The trailing pane's controls go on the vertical rail.
- Vertical controls stay on the same physical side in right-to-left languages, because they're aligned with the hardware.
- Safe areas are **asymmetric**. Handle each inset independently. Never assume the island is at the top.
- Full-bleed is allowed for immersive screens that don't scroll (Calculator spans the full width), as long as nothing collides with the island or status bar.

---

## 4. Reserved regions and the fold

Reserved regions are areas content should avoid:
- **Outer camera / Dynamic Island**: always present.
- **Inner camera**: present only while the camera is active. The UI moves aside.
- **Folding region**: present only when partially folded. It divides the inner display into usable halves.

APIs: `ReservedRegion` on `GeometryProxy` (SwiftUI) or `UIView.ReservedRegion` (UIKit). These expose **division** regions (the fold) and **occlusion** regions (cameras).

- System alerts, sheets, menus and popovers avoid the fold automatically. `NavigationSplitView` / `UISplitViewController` re-balance column widths automatically, as in Notes.
- Scrolling content (feeds, lists, articles) does **not** need to dodge the fold. Fixed, important controls do.
- Grids: prefer an **even number of columns**, so the crease falls between items.
- Make small adjustments, not big rearrangements, as the device folds. Controls that jump are hard to track.

---

## 5. Layout building blocks (iOS 27.1)

| Need | Use |
|---|---|
| List + detail (Mail/Notes pattern) | `NavigationSplitView` / `UISplitViewController`. It collapses to one pane on the outer display and expands on the inner display. **This is the #1 tool.** If the app already has an iPad layout built on it, reuse it for the inner display. |
| Two views that must both stay visible | `ArrangementView` (SwiftUI) / `UIArrangementViewController`, **split** type. It splits horizontally when wide and vertically when tall, and you can restrict the axes. |
| A foreground over a background (player controls over artwork, a panel over a map) | `ArrangementView`, **overlay** type. The primary sits on top of the secondary. When partially folded, they separate onto the two halves. The secondary can collapse. |
| Hinge angle effects | `onHingeChange` / `UIHingeInteraction` give discrete states plus a continuous angle. **Use these for effects only, never for layout.** Handle devices without a hinge. |
| Choosing a layout | `@Environment(\.horizontalSizeClass)`, `ViewThatFits`, `GeometryReader` |

Arrangement rules: put navigation containers **outside** arrangements, never inside. Never put an arrangement inside a `List` or `ScrollView`. An `HStack`/`VStack` pair maps to a split arrangement. A `ZStack` maps to an overlay arrangement.

---

## 6. Multitasking

- **Split View on iPhone, for the first time**: two apps, or two windows of the same app, share the inner display. Users can save app pairs. Your app may get about half of 951 pt, which is a compact-width slot, so the compact layout must work there too.
- In Split View, each app puts its vertical controls on its **outer** edge. The left app's controls are on the left.
- Pinned Picture in Picture can reduce your height.
- Multiple scenes are supported, but new windows can only open on the inner display. Handle scene-request failures.

---

## 7. Camera (only if relevant)

- `CameraCaptureAccessory` shows a preview or teleprompter for the subject on the outer display while the photographer frames the shot on the inner display.
- A camera reported as `.front` may not face the user. Use `AVCaptureDeviceDirectionCoordinator`, one per display view.
- Use `AVCaptureDevice.RotationCoordinator` for upright previews across display changes.

---

## 8. A practical recipe for an existing SwiftUI app

1. Find where the app chooses between its iPhone UI and iPad UI. If it uses `userInterfaceIdiom` or `UIDevice`, switch it to `horizontalSizeClass`: compact gets the phone `TabView`, regular gets the iPad-style `NavigationSplitView`.
2. Make sure state survives that swap. Hoist the selected item, scroll position, and playing media into the shared view model. Unfolding must not lose your place.
3. Audit for fixed widths, aspect-ratio locks, hard-coded offsets and `UIScreen.main` reads.
4. Make sure every toolbar button has a `Label(title, systemImage:)`. Set `visibilityPriority` on the important ones.
5. Use `ArrangementView` for any tabletop-worthy media screen: media on top, controls below.
6. Test in **Xcode 27.1 Device Hub** (simulate open, close, rotate, partial fold), then on hardware.
7. Rebuild with the 27.1 SDK and bump the build number.

---

## 9. Mocking up Duo screens (HTML or design canvas)

Use exact point canvases: **466×678** (closed), **951×669** (open landscape), **669×951** (open portrait or tabletop), plus a book pose of two halves with a crease.

To look native rather than web:
- **Fonts:** `-apple-system, "SF Pro Text"` for body, `"SF Pro Display"` for large titles (34 pt bold), `ui-serif` ("New York") only for reader-mode article text, `ui-rounded` where the app uses `.rounded`.
- **iOS dynamic type sizes (pt):** Large Title 34, Title 28, Headline 17 semibold, Body 17, Subheadline 15, Footnote 13, Caption 12, Caption2 11.
- **Dark-mode system colors:** background `#000000`, secondarySystemBackground `#1C1C1E`, tertiary `#2C2C2E`, label `#FFFFFF`, secondaryLabel `rgba(235,235,245,0.6)`, tertiaryLabel `rgba(235,235,245,0.3)`. Blue `#0A84FF`, orange `#FF9F0A`, green `#30D158`, purple `#BF5AF2`, pink `#FF375F`, teal `#40C8E0`. For light mode, use the light variants (blue `#007AFF`, and so on).
- **Liquid Glass recipe (CSS approximation):** `background: rgba(255,255,255,0.10); backdrop-filter: blur(20px) saturate(180%); border: 1px solid rgba(255,255,255,0.16); box-shadow: inset 0 1px 0 rgba(255,255,255,0.22), 0 8px 24px rgba(0,0,0,0.35); border-radius: 999px`. Controls sit in **floating capsules**, not full-width bars. The selected tab is a lighter glass bubble with a tinted icon and label. Prominent actions such as Done are a **tinted glass** circle.
- Corner radii: use continuous curves. Cards are about 16, inset images about 12, and thumbnails about 10. Touch targets are at least 44 pt.
- Icons: draw them as close to the real **SF Symbol** names the app uses as you can (`book`, `hammer`, `books.vertical`, `sparkles`, `line.3.horizontal`, `magnifyingglass`, `checkmark`, `info.circle`, `globe`, `square.and.arrow.up`, and so on).
- **Avoid:** website palettes, Inter or Google fonts, flat full-width top nav bars on the outer display, horizontal bottom tab bars on the outer display, content on the fold crease, and redesigning the app's existing components.

---

## 10. Sources

- Apple HIG — Designing for iPhone Duo: https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo
- Apple — Preparing your app for iPhone Duo (developer overview): https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo
- Apple — iPhone Duo tech specs: https://www.apple.com/iphone-duo/specs/
- Tech talk summaries: https://swiftjectivec.com/iPhone-Duo-First-Developer-Good-to-Knows/
- Point math and "what moves, splits and stays": https://blakecrosley.com/blog/designing-for-iphone-duo
