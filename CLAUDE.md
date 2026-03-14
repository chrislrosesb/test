# CLAUDE.md — Personal Website Decision Log

This file tracks architectural decisions, design choices, and customization notes
for the personal website hosted on GitHub Pages.

---

## Project Overview

A static, three-page personal website:
- `index.html` — Homepage (hero, "What I Do", recent projects, CTA)
- `about.html` — About page (photo, bio, skills, values)
- `contact.html` — Contact page (social links + contact form)
- `styles.css` — Shared stylesheet

**Hosting:** GitHub Pages (static files, no build step required)

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

### No JavaScript
Intentional. The site works without JS. The contact form relies on a third-party
service (Formspree) for processing.

### Photo placeholder
Each page has a `<div class="photo-placeholder">` with a person SVG icon.
**To replace:** swap the `<div class="photo-placeholder">` with:
```html
<img src="images/your-photo.jpg" alt="[Your Name]" class="photo-placeholder" />
```
Add appropriate `width`/`height` and keep the `border-radius` from the CSS.

---

## Contact Form

GitHub Pages is a **static host** — it cannot process form submissions natively.

**Chosen approach:** [Formspree](https://formspree.io)
- Free tier supports 50 submissions/month
- No JavaScript required (pure HTML form POST)
- Steps to activate:
  1. Create a free account at formspree.io
  2. Create a new form and copy the endpoint ID
  3. In `contact.html`, replace `YOUR_FORM_ID` in the `action` attribute:
     ```html
     action="https://formspree.io/f/YOUR_FORM_ID"
     ```

**Alternatives considered:**
- Netlify Forms — requires hosting on Netlify instead of GitHub Pages
- EmailJS — requires adding a JS snippet; adds complexity
- Mailto link — no server processing, poor UX

---

## GitHub Pages Deployment

The site is deployed from the `main` branch (or `gh-pages` branch, depending on
your repo settings).

**To enable GitHub Pages:**
1. Push all files to your repository
2. Go to **Settings → Pages** in your GitHub repo
3. Under **Source**, select the branch (e.g. `main`) and folder (`/ (root)`)
4. Save — GitHub will provide a URL like `https://yourusername.github.io/repo-name/`

**Custom domain (optional):**
- Add a `CNAME` file to the repo root containing your domain (e.g. `yourname.com`)
- Configure your DNS to point to GitHub Pages IPs (see GitHub docs)

---

## Customization Checklist

Replace all placeholder text before going live:

- [ ] `[Your Name]` — your full name (appears in nav, hero, footer, `<title>`)
- [ ] `[Your Location]` — city / country
- [ ] `[Your Role / Title]` — e.g. "Software Engineer", "Designer"
- [ ] `[Your Education]` — e.g. "B.Sc. Computer Science, MIT"
- [ ] `[A fun personal fact]` — e.g. "Runs on cold brew"
- [ ] Hero paragraph — your personal pitch
- [ ] About page paragraphs — your real story
- [ ] Skills tags — your actual skill set
- [ ] Projects section — your real projects
- [ ] Photo placeholder — your actual photo (see above)
- [ ] Social links in `contact.html` — GitHub, LinkedIn, Twitter, email
- [ ] Formspree form ID — to activate the contact form
- [ ] `<meta name="description">` on each page — for SEO

---

## Future Ideas (not yet implemented)

- Dark mode toggle (CSS `prefers-color-scheme` media query + JS toggle)
- Blog / writing section (could be a separate `blog/` directory with an index)
- Project detail pages
- Analytics (Plausible or Fathom — privacy-respecting)
- Favicon (`favicon.ico` / `<link rel="icon">`)
- Open Graph meta tags for social sharing previews

---

## File Structure

```
/
├── index.html       # Homepage
├── about.html       # About page
├── contact.html     # Contact page
├── styles.css       # Shared CSS (no preprocessor, no build step)
└── CLAUDE.md        # This file — decision log
```

---

*Last updated: 2026-03-14 by Claude Code*
