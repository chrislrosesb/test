/*!
 * reading-list.js — Public reading list + admin CRUD
 * Data lives in links.json (committed to repo).
 * Admin writes via GitHub Contents API using a PAT stored in localStorage.
 */
(function () {
  'use strict';

  // ── Config ────────────────────────────────────────────────────
  // Fill in your Supabase project URL and anon key (Settings → API in Supabase dashboard)
  var SUPABASE_URL  = 'https://ownqyyfgferczpdgihgr.supabase.co';
  var SUPABASE_ANON = 'sb_publishable_RPJSQlVO4isbKnZve8NlWg_55EO350Y';
  var db = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON);

  var MICROLINK  = 'https://api.microlink.io?url=';

  // ── State ─────────────────────────────────────────────────────
  var state = {
    allLinks:       [],
    categories:     [],
    filtered:       [],
    activeCategory: 'All',
    activeStatus:   'all',   // 'all' | 'unread'
    activeSort:     'newest',
    searchQuery:    '',
    isAdmin:        false,
    editingId:      null,
    starValue:      3
  };

  // ── Boot ──────────────────────────────────────────────────────
  document.addEventListener('DOMContentLoaded', function () {

    // DOM refs
    var linksGrid     = document.getElementById('links-grid');
    var filterTabs    = document.getElementById('filter-tabs');
    var filterSort    = document.getElementById('filter-sort');
    var filterSearch  = document.getElementById('filter-search');
    var adminFab      = document.getElementById('admin-fab');
    var adminFabIcon  = document.getElementById('admin-fab-icon');
    var adminBadge    = document.getElementById('admin-badge');
    var adminAddBtn   = document.getElementById('admin-add-btn');
    var filterShuffle = document.getElementById('filter-shuffle-btn');
    var settingsPanel = document.getElementById('settings-panel');
    var settingsSave  = document.getElementById('settings-save-btn');
    var settingsLock  = document.getElementById('settings-lock-btn');
    var bookmarklet   = document.getElementById('bookmarklet-link');

    var authModal    = document.getElementById('auth-modal');
    var authBackdrop = document.getElementById('auth-modal-backdrop');
    var authClose    = document.getElementById('auth-modal-close');
    var authEmail    = document.getElementById('admin-email');
    var authPassword = document.getElementById('admin-password');
    var authError    = document.getElementById('auth-error');
    var authSubmit   = document.getElementById('auth-submit-btn');
    var categoryChips    = document.getElementById('category-chips');
    var newCategoryInput = document.getElementById('new-category-input');
    var addCategoryBtn   = document.getElementById('add-category-btn');
    var categoryStatus   = document.getElementById('category-status');
    var persistToast     = document.getElementById('persist-toast');

    var linkModal      = document.getElementById('link-modal');
    var linkBackdrop   = document.getElementById('link-modal-backdrop');
    var linkModalClose = document.getElementById('link-modal-close');
    var linkModalTitle = document.getElementById('link-modal-title');
    var linkEditId     = document.getElementById('link-edit-id');
    var linkUrl        = document.getElementById('link-url');
    var ogStatus       = document.getElementById('og-fetch-status');
    var linkTitle      = document.getElementById('link-title');
    var linkDesc       = document.getElementById('link-description');
    var linkNote       = document.getElementById('link-note');
    var linkCategory   = document.getElementById('link-category');
    var starPicker     = document.getElementById('star-picker');
    var linkUnread     = document.getElementById('link-unread');
    var linkPrivate    = document.getElementById('link-private');
    var linkSaveStatus = document.getElementById('link-save-status');
    var linkModalSave  = document.getElementById('link-modal-save');

    // ── Load data ───────────────────────────────────────────────
    function loadData() {
      var linksQuery = db.from('links').select('*').order('saved_at', { ascending: false });
      if (!state.isAdmin) linksQuery = linksQuery.eq('private', false);

      // Pre-select category from URL param (for shareable collection links)
      var urlCat = new URLSearchParams(window.location.search).get('category');
      if (urlCat) state.activeCategory = urlCat;

      Promise.all([
        linksQuery,
        db.from('categories').select('name, sort_order').order('sort_order')
      ]).then(function (results) {
        var linksRes = results[0], catsRes = results[1];
        if (linksRes.error) throw linksRes.error;
        state.allLinks   = linksRes.data || [];
        state.categories = (catsRes.data || []).map(function (c) { return c.name; });
        buildFilterTabs();
        buildCategorySelect();
        applyFilters();
      }).catch(function (err) {
        console.warn('[reading-list] load failed:', err.message);
        linksGrid.innerHTML =
          '<div class="links-empty">' +
          '<p>Could not load the reading list. Please try again later.</p>' +
          '</div>';
      });
    }

    // ── Filters / sort / search ─────────────────────────────────
    function applyFilters() {
      var links = state.allLinks.slice();

      if (state.activeCategory !== 'All') {
        links = links.filter(function (l) { return l.category === state.activeCategory; });
      }

      if (state.activeStatus === 'unread') {
        links = links.filter(function (l) { return l.read === false; });
      }

      var q = state.searchQuery.toLowerCase().trim();
      if (q) {
        links = links.filter(function (l) {
          return (l.title       && l.title.toLowerCase().indexOf(q)       !== -1) ||
                 (l.description && l.description.toLowerCase().indexOf(q) !== -1) ||
                 (l.note        && l.note.toLowerCase().indexOf(q)        !== -1) ||
                 (l.domain      && l.domain.toLowerCase().indexOf(q)      !== -1);
        });
      }

      if (state.activeSort === 'stars') {
        links.sort(function (a, b) { return (b.stars || 0) - (a.stars || 0); });
      } else {
        links.sort(function (a, b) { return new Date(b.saved_at) - new Date(a.saved_at); });
      }

      state.filtered = links;
      renderGrid();
    }

    filterSort.addEventListener('change', function () {
      state.activeSort = filterSort.value;
      applyFilters();
    });

    var searchTimer = null;
    filterSearch.addEventListener('input', function () {
      clearTimeout(searchTimer);
      var val = filterSearch.value;
      searchTimer = setTimeout(function () {
        state.searchQuery = val;
        applyFilters();
      }, 200);
    });

    // ── Filter tabs ─────────────────────────────────────────────
    function buildFilterTabs() {
      filterTabs.innerHTML = '';

      // Unread toggle tab
      var unreadCount = state.allLinks.filter(function (l) { return l.read === false; }).length;
      var unreadBtn = document.createElement('button');
      unreadBtn.className = 'filter-tab filter-tab-unread' + (state.activeStatus === 'unread' ? ' active' : '');
      unreadBtn.innerHTML = (unreadCount > 0 ? '<span class="filter-unread-dot"></span>' : '') + 'Unread' + (unreadCount > 0 ? ' <span class="filter-unread-count">' + unreadCount + '</span>' : '');
      unreadBtn.addEventListener('click', function () {
        state.activeStatus = state.activeStatus === 'unread' ? 'all' : 'unread';
        buildFilterTabs();
        applyFilters();
      });
      filterTabs.appendChild(unreadBtn);

      // Separator
      var sep = document.createElement('span');
      sep.className = 'filter-tab-sep';
      filterTabs.appendChild(sep);

      // Category tabs
      var cats = ['All'].concat(state.categories);
      cats.forEach(function (cat) {
        var btn = document.createElement('button');
        btn.className = 'filter-tab' + (cat === state.activeCategory ? ' active' : '');
        btn.textContent = cat;
        btn.addEventListener('click', function () {
          state.activeCategory = cat;
          filterTabs.querySelectorAll('.filter-tab:not(.filter-tab-unread)').forEach(function (t) {
            t.classList.toggle('active', t.textContent === cat);
          });
          // Sync URL so the link is shareable
          var url = new URL(window.location.href);
          if (cat === 'All') { url.searchParams.delete('category'); }
          else { url.searchParams.set('category', cat); }
          window.history.replaceState({}, '', url.toString());
          applyFilters();
        });
        filterTabs.appendChild(btn);
      });
    }

    // ── Shuffle ──────────────────────────────────────────────────
    filterShuffle.addEventListener('click', function () {
      if (!state.filtered.length) return;
      var pick = state.filtered[Math.floor(Math.random() * state.filtered.length)];
      var card = document.querySelector('.link-card[data-id="' + pick.id + '"]');
      if (!card) return;
      card.scrollIntoView({ behavior: 'smooth', block: 'center' });
      card.classList.add('card-shuffle-highlight');
      setTimeout(function () { card.classList.remove('card-shuffle-highlight'); }, 1800);
    });

    // ── Render grid ─────────────────────────────────────────────
    function renderGrid() {
      linksGrid.innerHTML = '';

      if (!state.filtered.length) {
        var empty = document.createElement('div');
        empty.className = 'links-empty';
        empty.innerHTML =
          '<svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
            '<path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/>' +
          '</svg>' +
          '<p>No links found' +
          (state.searchQuery ? ' matching &ldquo;' + escHtml(state.searchQuery) + '&rdquo;' : '') +
          '.</p>';
        linksGrid.appendChild(empty);
        return;
      }

      state.filtered.forEach(function (link) {
        linksGrid.appendChild(buildCard(link));
      });

      if (typeof ScrollTrigger !== 'undefined') {
        ScrollTrigger.refresh();
      }
    }

    // ── Build card ──────────────────────────────────────────────
    function buildCard(link) {
      var card = document.createElement('article');
      card.className = 'link-card anim-fade-up';
      card.dataset.id = link.id;

      // Image — known brand SVG, or blur-backdrop (with OG image layered on top if present)
      var imgHtml;
      var brandSvg = generatePlaceholderSvg(link.category, link.domain);
      var fav2 = link.favicon || ('https://www.google.com/s2/favicons?domain=' + escAttr(link.domain || '') + '&sz=64');
      if (brandSvg) {
        // Known brand: OG image on top, fall back to brand SVG
        var fallbackSrc = brandSvg;
        imgHtml =
          '<img class="link-card-image" src="' + escAttr(link.image || brandSvg) + '" alt="" loading="lazy" ' +
          'onerror="this.onerror=null;this.src=\'' + escAttr(fallbackSrc) + '\';" />';
      } else {
        // Unknown domain: blur-backdrop is always the base; OG image floats on top if it exists
        var ogOverlay = link.image
          ? '<img class="link-card-og-overlay" src="' + escAttr(link.image) + '" alt="" loading="lazy" onerror="this.style.display=\'none\'">'
          : '';
        imgHtml =
          '<div class="link-card-placeholder" style="--fav-url: url(\'' + escAttr(fav2) + '\')">' +
            '<img class="link-card-placeholder-favicon" src="' + escAttr(fav2) + '" alt="" loading="lazy" ' +
            'onerror="this.style.display=\'none\'">' +
            ogOverlay +
          '</div>';
      }

      // Stars
      var starsHtml = '<span class="star-display">';
      for (var i = 1; i <= 5; i++) {
        starsHtml += '<span class="star' + (i <= (link.stars || 0) ? ' filled' : '') + '">' +
          (i <= (link.stars || 0) ? '&#9733;' : '&#9734;') + '</span>';
      }
      starsHtml += '</span>';

      // Date
      var dateStr = '';
      if (link.saved_at) {
        try {
          dateStr = new Date(link.saved_at).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
        } catch (e) {}
      }

      var unreadBadge = (link.read === false)
        ? '<span class="link-card-unread-badge">Unread</span>'
        : '';
      var readToggleBtn = state.isAdmin
        ? '<button class="link-card-action-btn read-toggle" data-id="' + escAttr(link.id) + '" aria-label="' + (link.read === false ? 'Mark as read' : 'Mark as unread') + '" title="' + (link.read === false ? 'Mark as read' : 'Mark as unread') + '">' + (link.read === false ? '&#10003;' : '&#9675;') + '</button>'
        : '';

      card.innerHTML =
        '<div class="link-card-actions">' +
          '<button class="link-card-action-btn copy" data-id="' + escAttr(link.id) + '" data-url="' + escAttr(link.url) + '" aria-label="Copy link">&#128279;</button>' +
          readToggleBtn +
          '<button class="link-card-action-btn edit" data-id="' + escAttr(link.id) + '" aria-label="Edit link">&#9998;</button>' +
          '<button class="link-card-action-btn delete" data-id="' + escAttr(link.id) + '" aria-label="Delete link">&times;</button>' +
        '</div>' +
        unreadBadge +
        '<a href="' + escAttr(link.url) + '" target="_blank" rel="noopener noreferrer" tabindex="-1" aria-hidden="true" style="display:block;text-decoration:none;">' +
          imgHtml +
        '</a>' +
        '<div class="link-card-header">' +
          (link.favicon ? '<img class="link-card-favicon" src="' + escAttr(link.favicon) + '" alt="" loading="lazy" onerror="this.style.display=\'none\';" />' : '') +
          '<span class="link-card-domain">' + escHtml(link.domain || '') + '</span>' +
        '</div>' +
        '<div class="link-card-body">' +
          '<a href="' + escAttr(link.url) + '" target="_blank" rel="noopener noreferrer" style="text-decoration:none;">' +
            '<p class="link-card-title">' + escHtml(link.title || 'Untitled') + '</p>' +
          '</a>' +
          (link.description ? '<p class="link-card-description">' + escHtml(link.description) + '</p>' : '') +
          (link.note ? '<p class="link-card-note">' + escHtml(link.note) + '</p>' : '') +
          '<div class="link-card-meta">' +
            (link.category ? '<span class="tag">' + escHtml(link.category) + '</span>' : '') +
            starsHtml +
            (dateStr ? '<span class="link-card-date">' + escHtml(dateStr) + '</span>' : '') +
          '</div>' +
        '</div>';

      card.querySelector('.link-card-action-btn.copy').addEventListener('click', function (e) {
        e.preventDefault();
        e.stopPropagation();
        navigator.clipboard.writeText(link.url).then(function () {
          showToast('Link copied to clipboard', 'success');
        }).catch(function () {
          showToast('Could not copy — try manually', 'error');
        });
      });

      if (state.isAdmin) {
        card.querySelector('.link-card-action-btn.read-toggle').addEventListener('click', function (e) {
          e.preventDefault();
          e.stopPropagation();
          toggleRead(link.id);
        });
      }

      card.querySelector('.link-card-action-btn.edit').addEventListener('click', function (e) {
        e.preventDefault();
        e.stopPropagation();
        openEditModal(link.id);
      });

      card.querySelector('.link-card-action-btn.delete').addEventListener('click', function (e) {
        e.preventDefault();
        e.stopPropagation();
        confirmDelete(link.id);
      });

      return card;
    }

    function bookmarkIcon() {
      return '<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/></svg>';
    }

    // ── Source placeholder generator ───────────────────────────
    // Source logo SVG paths + brand colors
    var sourceLogos = {
      'reddit.com':           { path: 'M12 8c2.6 0 5 1.2 5 3.5S14.6 15 12 15s-5-1.2-5-3.5S9.4 8 12 8zm-2.5 4a.75.75 0 100-1.5.75.75 0 000 1.5zm5 0a.75.75 0 100-1.5.75.75 0 000 1.5zM12 14c-1 0-1.8-.3-2.2-.7a.4.4 0 01.5-.5c.4.3 1 .5 1.7.5s1.3-.2 1.7-.5a.4.4 0 01.5.5c-.4.4-1.2.7-2.2.7zM18.8 9.2a1.6 1.6 0 11-2.3 2.2M5.2 9.2a1.6 1.6 0 102.3 2.2M16 6.5l-1-3.5h-2l1.5 4M12 3a9 9 0 100 18 9 9 0 000-18z', viewBox: '0 0 24 24', color: '#FF4500', color2: '#cc3700' },
      'x.com':                { path: 'M4 4l6.5 8.5L4 20h2l5.5-6.3L16 20h5l-7-9 6-7h-2l-5 5.7L9 4H4z', viewBox: '0 0 24 24', color: '#000000', color2: '#1a1a1a' },
      'twitter.com':          { path: 'M23 3a10.9 10.9 0 01-3.14 1.53 4.48 4.48 0 00-7.86 3v1A10.66 10.66 0 013 4s-4 9 5 13a11.64 11.64 0 01-7 2c9 5 20 0 20-11.5a4.5 4.5 0 00-.08-.83A7.72 7.72 0 0023 3z', viewBox: '0 0 24 24', color: '#1DA1F2', color2: '#0d8bd9' },
      'github.com':           { path: 'M12 2C6.477 2 2 6.477 2 12c0 4.42 2.87 8.17 6.84 9.5.5.08.66-.23.66-.5v-1.69c-2.77.6-3.36-1.34-3.36-1.34-.46-1.16-1.11-1.47-1.11-1.47-.91-.62.07-.6.07-.6 1 .07 1.53 1.03 1.53 1.03.87 1.52 2.34 1.07 2.91.83.09-.65.35-1.09.63-1.34-2.22-.25-4.55-1.11-4.55-4.94 0-1.1.39-1.99 1.03-2.69-.1-.25-.45-1.27.1-2.64 0 0 .84-.27 2.75 1.02A9.56 9.56 0 0112 6.8c.85.004 1.7.114 2.5.336 1.91-1.29 2.75-1.02 2.75-1.02.55 1.37.2 2.39.1 2.64.64.7 1.03 1.59 1.03 2.69 0 3.84-2.34 4.68-4.57 4.93.36.31.68.92.68 1.85v2.74c0 .27.16.59.67.5A10.003 10.003 0 0022 12c0-5.523-4.477-10-10-10z', viewBox: '0 0 24 24', color: '#24292e', color2: '#1a1e22' },
      'youtube.com':          { path: 'M19.6 3.2H4.4A2.4 2.4 0 002 5.6v8.8a2.4 2.4 0 002.4 2.4h15.2a2.4 2.4 0 002.4-2.4V5.6a2.4 2.4 0 00-2.4-2.4zM10 14V6l6 4-6 4z', viewBox: '0 0 24 20', color: '#FF0000', color2: '#cc0000' },
      'medium.com':           { path: 'M13.5 12a6.5 6.5 0 11-13 0 6.5 6.5 0 0113 0zm7.1 0c0 3.4-1.5 6.1-3.3 6.1S14 15.4 14 12s1.5-6.1 3.3-6.1 3.3 2.7 3.3 6.1zm3.4 0c0 3-.5 5.5-1.2 5.5S21.6 15 21.6 12s.5-5.5 1.2-5.5 1.2 2.5 1.2 5.5z', viewBox: '0 0 24 24', color: '#02B875', color2: '#01874c' },
      'news.ycombinator.com': { path: 'M12 2L4 6v6c0 5.25 3.4 10.15 8 11.35C16.6 22.15 20 17.25 20 12V6L12 2zm-1 13V9h2v6h-2zm0-8V5h2v2h-2z', viewBox: '0 0 24 24', color: '#FF6600', color2: '#cc5200' },
      'substack.com':         { path: 'M3 7h18v2H3V7zm0 4h18v2H3v-2zm0 4h18v2H3v-2z', viewBox: '0 0 24 24', color: '#FF6719', color2: '#cc5214' },
      'linkedin.com':         { path: 'M4 9h3v12H4zm1.5-5.5a1.5 1.5 0 100 3 1.5 1.5 0 000-3zM9 9h3v1.6C12.6 9.6 13.8 9 15 9c3 0 5 1.6 5 5v6h-3v-5.5c0-1.5-.5-2.5-2-2.5s-3 1-3 3V21H9z', viewBox: '0 0 24 24', color: '#0A66C2', color2: '#08519b' },
      'instagram.com':        { path: 'M12 2.2c3.2 0 3.6 0 4.9.1 3.3.2 4.8 1.7 5 5 .1 1.3.1 1.7.1 4.9 0 3.2 0 3.6-.1 4.9-.2 3.3-1.7 4.8-5 5-1.3.1-1.7.1-4.9.1-3.2 0-3.6 0-4.9-.1-3.3-.2-4.8-1.7-5-5-.1-1.3-.1-1.7-.1-4.9 0-3.2 0-3.6.1-4.9.2-3.3 1.7-4.8 5-5 1.3-.1 1.7-.1 4.9-.1zm0 2.2c-3.2 0-3.5 0-4.8.1-2.2.1-3.2 1.1-3.3 3.3-.1 1.3-.1 1.6-.1 4.8s0 3.5.1 4.8c.1 2.2 1.1 3.2 3.3 3.3 1.3.1 1.6.1 4.8.1s3.5 0 4.8-.1c2.2-.1 3.2-1.1 3.3-3.3.1-1.3.1-1.6.1-4.8s0-3.5-.1-4.8c-.1-2.2-1.1-3.2-3.3-3.3-1.3-.1-1.6-.1-4.8-.1zm0 3.6a4 4 0 110 8 4 4 0 010-8zm0 1.8a2.2 2.2 0 100 4.4 2.2 2.2 0 000-4.4zM18.5 7.5a1 1 0 100 2 1 1 0 000-2z', viewBox: '0 0 24 24', color: '#E1306C', color2: '#b32456' },
      'tiktok.com':           { path: 'M19.59 6.69a4.83 4.83 0 01-3.77-4.25V2h-3.45v13.67a2.89 2.89 0 01-2.88 2.5 2.89 2.89 0 01-2.89-2.89 2.89 2.89 0 012.89-2.89c.28 0 .54.04.79.1V9.01a6.27 6.27 0 00-.79-.05 6.34 6.34 0 00-6.34 6.34 6.34 6.34 0 006.34 6.34 6.34 6.34 0 006.33-6.34V8.69a8.18 8.18 0 004.78 1.52V6.76a4.85 4.85 0 01-1.01-.07z', viewBox: '0 0 24 24', color: '#010101', color2: '#1a1a2e' }
    };

    function generateFallbackSvg(domain) {
      var initial = domain ? domain.replace('www.', '').charAt(0).toUpperCase() : '?';
      var svg =
        '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="180" viewBox="0 0 320 180">' +
          '<rect width="320" height="180" fill="#161b22"/>' +
          '<text x="160" y="110" text-anchor="middle" fill="#484f58" font-family="Inter,system-ui,sans-serif" font-size="72" font-weight="700">' + initial + '</text>' +
        '</svg>';
      return 'data:image/svg+xml,' + encodeURIComponent(svg);
    }

    // Returns a brand SVG data URI for known domains, or null for unknown domains.
    function generatePlaceholderSvg(category, domain) {
      var source = null;
      if (domain) {
        for (var key in sourceLogos) {
          if (domain.indexOf(key) !== -1) { source = sourceLogos[key]; break; }
        }
      }

      if (!source) return null;

      var svg =
        '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="180" viewBox="0 0 320 180">' +
          '<defs>' +
            '<linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">' +
              '<stop offset="0%" stop-color="' + source.color + '"/>' +
              '<stop offset="100%" stop-color="' + source.color2 + '"/>' +
            '</linearGradient>' +
          '</defs>' +
          '<rect width="320" height="180" fill="url(#bg)"/>' +
          '<g transform="translate(130, 60)">' +
            '<svg viewBox="' + source.viewBox + '" width="60" height="60">' +
              (source.text
                ? '<text x="12" y="19" text-anchor="middle" fill="#ffffff" font-family="Inter,system-ui,sans-serif" font-size="20" font-weight="700">' + source.text + '</text>'
                : '<path d="' + source.path + '" fill="#ffffff"/>') +
            '</svg>' +
          '</g>' +
          '<text x="160" y="168" text-anchor="middle" fill="#ffffff" font-family="Inter,system-ui,sans-serif" font-size="11" font-weight="500" opacity="0.5">' +
            escHtml(domain) +
          '</text>' +
        '</svg>';

      return 'data:image/svg+xml,' + encodeURIComponent(svg);
    }

    // ── Admin auth ───────────────────────────────────────────────
    function activateAdmin(reload) {
      state.isAdmin = true;
      document.body.classList.add('admin-mode');
      adminFab.classList.add('unlocked');
      adminFab.setAttribute('aria-label', 'Admin settings');
      adminBadge.classList.add('visible');
      adminFabIcon.innerHTML =
        '<rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>' +
        '<path d="M7 11V7a5 5 0 0 1 9.9-1"/>';
      if (reload !== false) { loadData(); }
    }

    function deactivateAdmin() {
      state.isAdmin = false;
      document.body.classList.remove('admin-mode');
      adminFab.classList.remove('unlocked');
      adminFab.setAttribute('aria-label', 'Admin login');
      adminBadge.classList.remove('visible');
      settingsPanel.classList.remove('open');
      adminFabIcon.innerHTML =
        '<rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>' +
        '<path d="M7 11V7a5 5 0 0 1 10 0v4"/>';
      db.auth.signOut();
      loadData();
    }

    // ── Admin FAB ────────────────────────────────────────────────
    adminFab.addEventListener('click', function () {
      if (!state.isAdmin) {
        openAuthModal();
      } else {
        if (settingsPanel.classList.contains('open')) {
          settingsPanel.classList.remove('open');
        } else {
          renderCategoryChips();
          // Build bookmarklet href — use current page URL so it works on any host
          var dest = location.href.split('?')[0];
          var bl = 'javascript:(function(){' +
            "var u=encodeURIComponent(location.href);" +
            "window.open('" + dest + "?add='+u,'_blank');" +
            '})();';
          bookmarklet.href = bl;
          settingsPanel.classList.add('open');
        }
      }
    });

    // ── Auth modal ───────────────────────────────────────────────
    function openAuthModal() {
      authModal.removeAttribute('hidden');
      if (authEmail) authEmail.value = '';
      authPassword.value = '';
      authError.textContent = '';
      setTimeout(function () { (authEmail || authPassword).focus(); }, 40);
    }

    function closeAuthModal() {
      authModal.setAttribute('hidden', '');
    }

    authClose.addEventListener('click', closeAuthModal);
    authBackdrop.addEventListener('click', closeAuthModal);
    authPassword.addEventListener('keydown', function (e) {
      if (e.key === 'Enter') { e.preventDefault(); submitAuth(); }
    });
    authSubmit.addEventListener('click', submitAuth);

    function submitAuth() {
      var email = authEmail ? authEmail.value.trim() : '';
      var pw    = authPassword.value;
      if (!email || !pw) { authError.textContent = 'Please enter your email and password.'; return; }
      authError.textContent = '';
      authSubmit.disabled = true;
      authSubmit.textContent = 'Signing in\u2026';

      db.auth.signInWithPassword({ email: email, password: pw })
        .then(function (res) {
          authSubmit.disabled = false;
          authSubmit.textContent = 'Unlock';
          if (res.error) {
            authError.textContent = res.error.message;
            authPassword.value = '';
            authPassword.focus();
          } else {
            closeAuthModal();
            activateAdmin(true);
            if (pendingAddUrl) {
              var url = pendingAddUrl;
              pendingAddUrl = null;
              setTimeout(function () { openAddModal(url); }, 100);
            }
          }
        });
    }

    // ── Settings panel ───────────────────────────────────────────
    settingsSave.addEventListener('click', function () {
      settingsPanel.classList.remove('open');
    });

    settingsLock.addEventListener('click', function () {
      settingsPanel.classList.remove('open');
      deactivateAdmin();
    });

    addCategoryBtn.addEventListener('click', function () {
      var name = newCategoryInput.value.trim();
      if (!name) return;
      if (state.categories.indexOf(name) !== -1) {
        categoryStatus.style.color = '#f85149';
        categoryStatus.textContent = 'Category already exists.';
        return;
      }
      state.categories.push(name);
      newCategoryInput.value = '';
      categoryStatus.textContent = '';
      renderCategoryChips();
      buildCategorySelect();
      buildFilterTabs();
      persistCategories();
    });

    newCategoryInput.addEventListener('keydown', function (e) {
      if (e.key === 'Enter') { e.preventDefault(); addCategoryBtn.click(); }
    });

    // ── OG fetch (on URL input) ──────────────────────────────────
    var ogTimer = null;
    linkUrl.addEventListener('input', function () {
      clearTimeout(ogTimer);
      var url = linkUrl.value.trim();
      if (!url || url.indexOf('http') !== 0) return;
      ogTimer = setTimeout(function () { fetchOG(url); }, 700);
    });

    function extractYouTubeId(url) {
      try {
        var u = new URL(url);
        if (u.hostname.indexOf('youtu.be') !== -1) return u.pathname.slice(1).split('/')[0];
        return u.searchParams.get('v') || '';
      } catch (e) { return ''; }
    }

    function fetchOG(url) {
      ogStatus.textContent = 'Fetching metadata\u2026';
      var domain = '';
      try { domain = new URL(url).hostname.replace(/^www\./, ''); } catch (e) {}

      // YouTube: use oEmbed for reliable title + stable (non-expiring) thumbnail
      var ytId = (domain === 'youtube.com' || domain === 'youtu.be') ? extractYouTubeId(url) : '';
      if (ytId) {
        fetch('https://www.youtube.com/oembed?url=' + encodeURIComponent(url) + '&format=json')
          .then(function (r) { if (!r.ok) throw new Error('oembed HTTP ' + r.status); return r.json(); })
          .then(function (d) {
            if (d.title       && !linkTitle.value) linkTitle.value = d.title;
            if (d.author_name && !linkDesc.value)  linkDesc.value  = 'By ' + d.author_name;
            linkTitle.dataset.ogImage = 'https://img.youtube.com/vi/' + ytId + '/maxresdefault.jpg';
            linkTitle.dataset.domain  = domain;
            linkTitle.dataset.favicon = 'https://www.google.com/s2/favicons?domain=' + domain + '&sz=64';
            ogStatus.textContent = 'Metadata loaded.';
            setTimeout(function () { ogStatus.textContent = ''; }, 2500);
          })
          .catch(function (err) {
            console.warn('[reading-list] YouTube oEmbed failed:', err.message);
            ogStatus.textContent = 'Could not fetch metadata \u2014 fill in manually.';
          });
        return;
      }

      fetch(MICROLINK + encodeURIComponent(url))
        .then(function (r) {
          if (!r.ok) throw new Error('HTTP ' + r.status);
          return r.json();
        })
        .then(function (data) {
          if (data.status !== 'success') throw new Error('microlink: ' + (data.message || 'failed'));
          var d    = data.data || {};
          var t    = d.title                          || '';
          var desc = d.description                    || '';
          var img  = (d.image && d.image.url)         || '';
          var logo = (d.logo  && d.logo.url)          || '';
          if (t    && !linkTitle.value) linkTitle.value = t;
          if (desc && !linkDesc.value)  linkDesc.value  = desc;
          if (img)  linkTitle.dataset.ogImage = img;
          if (domain) {
            linkTitle.dataset.domain  = domain;
            linkTitle.dataset.favicon = logo || ('https://www.google.com/s2/favicons?domain=' + domain + '&sz=64');
          }
          ogStatus.textContent = img ? 'Metadata loaded.' : 'Metadata loaded \u2014 no preview image.';
          setTimeout(function () { ogStatus.textContent = ''; }, 2500);
        })
        .catch(function (err) {
          console.warn('[reading-list] OG fetch failed:', err.message);
          ogStatus.textContent = 'Could not fetch metadata \u2014 fill in manually.';
        });
    }

    // ── Add / Edit modal ─────────────────────────────────────────
    adminAddBtn.addEventListener('click', function () { openAddModal(null); });

    function openAddModal(prefillUrl) {
      state.editingId = null;
      linkModalTitle.textContent = 'Add Link';
      linkEditId.value = '';
      linkUrl.value    = prefillUrl || '';
      linkTitle.value  = '';
      linkTitle.dataset.ogImage = '';
      linkTitle.dataset.domain  = '';
      linkTitle.dataset.favicon = '';
      linkDesc.value   = '';
      linkNote.value   = '';
      linkUnread.checked  = false;
      linkPrivate.checked = false;
      linkSaveStatus.textContent = '';
      ogStatus.textContent = '';
      state.starValue = 3;
      updateStarPicker(3);
      buildCategorySelect();
      linkModal.removeAttribute('hidden');
      setTimeout(function () { linkUrl.focus(); }, 40);
      if (prefillUrl) { fetchOG(prefillUrl); }
    }

    function openEditModal(id) {
      var link = state.allLinks.find(function (l) { return l.id === id; });
      if (!link) return;
      state.editingId = id;
      linkModalTitle.textContent = 'Edit Link';
      linkEditId.value = id;
      linkUrl.value    = link.url         || '';
      linkTitle.value  = link.title       || '';
      linkTitle.dataset.ogImage = link.image   || '';
      linkTitle.dataset.domain  = link.domain  || '';
      linkTitle.dataset.favicon = link.favicon || '';
      linkDesc.value   = link.description || '';
      linkNote.value   = link.note        || '';
      linkUnread.checked  = link.read === false;
      linkPrivate.checked = !!link.private;
      linkSaveStatus.textContent = '';
      ogStatus.textContent = '';
      state.starValue = link.stars || 3;
      updateStarPicker(link.stars || 3);
      buildCategorySelect();
      linkCategory.value = link.category || '';
      linkModal.removeAttribute('hidden');
      setTimeout(function () { linkTitle.focus(); }, 40);
    }

    function closeLinkModal() {
      linkModal.setAttribute('hidden', '');
      state.editingId = null;
      linkModalSave.disabled = false;
    }

    linkModalClose.addEventListener('click', closeLinkModal);
    linkBackdrop.addEventListener('click', closeLinkModal);

    function buildCategorySelect() {
      linkCategory.innerHTML = '';
      state.categories.forEach(function (cat) {
        var opt = document.createElement('option');
        opt.value = cat;
        opt.textContent = cat;
        linkCategory.appendChild(opt);
      });
    }

    // ── Star picker ──────────────────────────────────────────────
    function updateStarPicker(val) {
      starPicker.querySelectorAll('.star').forEach(function (s, i) {
        s.classList.toggle('filled', i < val);
        s.classList.remove('hover');
      });
    }

    starPicker.querySelectorAll('.star').forEach(function (star, idx) {
      star.addEventListener('mouseenter', function () {
        starPicker.querySelectorAll('.star').forEach(function (s, i) {
          s.classList.toggle('hover', i <= idx);
        });
      });
      star.addEventListener('mouseleave', function () {
        starPicker.querySelectorAll('.star').forEach(function (s) { s.classList.remove('hover'); });
      });
      star.addEventListener('click', function () {
        state.starValue = idx + 1;
        updateStarPicker(idx + 1);
      });
      star.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          state.starValue = idx + 1;
          updateStarPicker(idx + 1);
        }
      });
    });

    // ── Save link ────────────────────────────────────────────────
    linkModalSave.addEventListener('click', saveLink);

    function saveLink() {
      var url = linkUrl.value.trim();
      if (!url) {
        linkSaveStatus.style.color = '#f85149';
        linkSaveStatus.textContent = 'URL is required.';
        return;
      }

      var domain  = linkTitle.dataset.domain  || '';
      var favicon = linkTitle.dataset.favicon || '';
      var image   = linkTitle.dataset.ogImage || '';

      if (!domain) {
        try {
          domain  = new URL(url).hostname.replace(/^www\./, '');
          favicon = 'https://www.google.com/s2/favicons?domain=' + domain + '&sz=64';
        } catch (e) {}
      }

      var isEdit = !!state.editingId;
      var now    = new Date().toISOString();
      var orig   = isEdit ? state.allLinks.find(function (l) { return l.id === state.editingId; }) : null;

      var entry = {
        id:          isEdit ? state.editingId : generateId(url),
        url:         url,
        title:       linkTitle.value.trim() || 'Untitled',
        description: linkDesc.value.trim(),
        image:       image,
        favicon:     favicon,
        domain:      domain,
        category:    linkCategory.value,
        stars:       state.starValue,
        note:        linkNote.value.trim(),
        read:        !linkUnread.checked,
        private:     linkPrivate.checked,
        saved_at:    isEdit && orig ? orig.saved_at : now
      };

      linkSaveStatus.style.color = 'var(--color-text-muted)';
      linkSaveStatus.textContent = 'Saving\u2026';
      linkModalSave.disabled = true;

      // Optimistic update
      if (isEdit) {
        var idx = state.allLinks.findIndex(function (l) { return l.id === state.editingId; });
        if (idx !== -1) { state.allLinks[idx] = entry; }
      } else {
        state.allLinks.unshift(entry);
      }
      applyFilters();
      closeLinkModal();

      persistToSupabase(entry, isEdit).then(function () {
        showToast('\u2713 Saved', 'success');
      }).catch(function (err) {
        console.error('[reading-list] save failed:', err.message);
        showToast('\u2717 Save failed: ' + err.message, 'error');
      });
    }

    // ── Supabase write ───────────────────────────────────────────
    function persistToSupabase(entry, isEdit) {
      var op = isEdit
        ? db.from('links').update(entry).eq('id', entry.id)
        : db.from('links').insert(entry);
      return op.then(function (res) {
        if (res.error) throw new Error(res.error.message);
      });
    }

    // ── Delete ───────────────────────────────────────────────────
    function confirmDelete(id) {
      var link = state.allLinks.find(function (l) { return l.id === id; });
      if (!link) return;
      if (!window.confirm('Delete \u201C' + link.title + '\u201D? This cannot be undone.')) return;

      state.allLinks = state.allLinks.filter(function (l) { return l.id !== id; });
      applyFilters();

      db.from('links').delete().eq('id', id).then(function (res) {
        if (res.error) console.error('[reading-list] Delete failed:', res.error.message);
      });
    }

    // ── Toggle read status ───────────────────────────────────────
    function toggleRead(id) {
      var link = state.allLinks.find(function (l) { return l.id === id; });
      if (!link) return;
      var newRead = !(link.read === false); // false→true, true/null/undefined→false
      link.read = newRead;
      applyFilters();
      db.from('links').update({ read: newRead }).eq('id', id).then(function (res) {
        if (res.error) {
          console.error('[reading-list] read toggle failed:', res.error.message);
          link.read = !newRead; // revert
          applyFilters();
        } else {
          buildFilterTabs(); // refresh unread count badge
        }
      });
    }

    // ── Bookmarklet ?add= param ──────────────────────────────────
    var pendingAddUrl = null;

    function checkAddParam() {
      var search = window.location.search;
      var addUrl = search.startsWith('?add=') ? search.slice(5) : null;
      if (!addUrl) return;
      window.history.replaceState({}, '', window.location.pathname);
      if (state.isAdmin) {
        openAddModal(addUrl);
      } else {
        pendingAddUrl = addUrl;
        openAuthModal();
      }
    }

    // ── Keyboard: Escape ─────────────────────────────────────────
    document.addEventListener('keydown', function (e) {
      if (e.key !== 'Escape') return;
      if (!authModal.hasAttribute('hidden'))  { closeAuthModal();  return; }
      if (!linkModal.hasAttribute('hidden'))  { closeLinkModal();  return; }
      if (settingsPanel.classList.contains('open')) {
        settingsPanel.classList.remove('open');
      }
    });

    // ── Utilities ────────────────────────────────────────────────
    function generateId(url) {
      var slug = url.replace(/^https?:\/\//, '').replace(/[^a-z0-9]/gi, '-').toLowerCase().slice(0, 40);
      return slug + '-' + Date.now().toString(36);
    }

    function escHtml(str) {
      return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
    }

    function escAttr(str) { return escHtml(str); }

    // ── Toast ────────────────────────────────────────────────────
    function showToast(msg, type) {
      if (!persistToast) return;
      persistToast.textContent = msg;
      persistToast.className = 'persist-toast persist-toast--' + (type || 'info');
      persistToast.removeAttribute('hidden');
      clearTimeout(persistToast._timer);
      persistToast._timer = setTimeout(function () {
        persistToast.setAttribute('hidden', '');
      }, type === 'error' ? 6000 : 3000);
    }

    // ── Category chips ───────────────────────────────────────────
    function renderCategoryChips() {
      if (!categoryChips) return;
      categoryChips.innerHTML = '';
      state.categories.forEach(function (cat) {
        var chip = document.createElement('span');
        chip.className = 'cat-chip';
        chip.innerHTML = escHtml(cat) +
          '<button type="button" aria-label="Remove ' + escAttr(cat) + '">\u00d7</button>';
        chip.querySelector('button').addEventListener('click', function () {
          state.categories = state.categories.filter(function (c) { return c !== cat; });
          renderCategoryChips();
          buildCategorySelect();
          buildFilterTabs();
          persistCategories();
        });
        categoryChips.appendChild(chip);
      });
    }

    // ── Persist categories to Supabase ───────────────────────────
    function persistCategories() {
      categoryStatus.style.color = 'var(--color-text-dim)';
      categoryStatus.textContent = 'Saving\u2026';
      var rows = state.categories.map(function (name, i) {
        return { name: name, sort_order: i };
      });
      db.from('categories').delete().neq('name', '').then(function () {
        return db.from('categories').insert(rows);
      }).then(function (res) {
        if (res.error) {
          categoryStatus.style.color = '#f85149';
          categoryStatus.textContent = '\u2717 Failed: ' + res.error.message;
        } else {
          categoryStatus.style.color = 'var(--color-accent)';
          categoryStatus.textContent = '\u2713 Categories saved.';
          setTimeout(function () { categoryStatus.textContent = ''; }, 3000);
        }
      });
    }

    // ── Init ─────────────────────────────────────────────────────
    loadData();
    // Restore admin session if Supabase still has a valid token, then check ?add= param
    db.auth.getSession().then(function (res) {
      if (res.data && res.data.session) {
        activateAdmin(true);
      }
      checkAddParam();
    });

  }); // end DOMContentLoaded

}());
