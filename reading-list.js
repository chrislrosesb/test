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

  var MICROLINK    = 'https://api.microlink.io?url=';
  var IMG_PROXY    = 'https://chrislrose.aseva.ai/proxy.php?url=';

  // Domains whose CDN images require a server-side proxy to bypass hotlink protection
  var PROXY_DOMAINS = ['cdninstagram.com', 'fbcdn.net'];

  function proxyImage(url) {
    if (!url) return url;
    try {
      var host = new URL(url).hostname;
      for (var i = 0; i < PROXY_DOMAINS.length; i++) {
        if (host === PROXY_DOMAINS[i] || host.endsWith('.' + PROXY_DOMAINS[i])) {
          return IMG_PROXY + encodeURIComponent(url);
        }
      }
    } catch (e) {}
    return url;
  }
  var PRIMARY_URL  = 'https://chrislrose.aseva.ai/reading-list.html';

  // ── State ─────────────────────────────────────────────────────
  var state = {
    allLinks:       [],
    categories:     [],
    filtered:       [],
    activeCategory: 'All',
    activeStatus:   'all',   // 'all' | 'to-read' | 'to-try' | 'to-share' | 'done'
    activeSort:     'newest',
    searchQuery:    '',
    isAdmin:        false,
    editingId:      null,
    starValue:      3,
    selectionMode:  false,
    selectedIds:    new Set(),
    collectionId:   null,
    collectionData: null
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
    var filterViewBtn    = document.getElementById('filter-view-btn');
    var filterViewIconGrid = document.getElementById('filter-view-icon-grid');
    var filterViewIconList = document.getElementById('filter-view-icon-list');
    var filterShuffle    = document.getElementById('filter-shuffle-btn');
    var curateBtnEl      = document.getElementById('filter-curate-btn');
    var selectionBar     = document.getElementById('selection-action-bar');
    var selectionCountEl = document.getElementById('selection-count');
    var selectionRecipientInput = document.getElementById('selection-recipient');
    var selectionMsgInput  = document.getElementById('selection-message');
    var selectionCreateBtn = document.getElementById('selection-create-btn');
    var selectionCancelBtn = document.getElementById('selection-cancel-btn');
    var collectionBannerEl = document.getElementById('collection-banner');
    var settingsPanel = document.getElementById('settings-panel');
    var settingsLock  = document.getElementById('settings-lock-btn');
    var bookmarklet   = document.getElementById('bookmarklet-link');

    var authModal    = document.getElementById('auth-modal');
    var authBackdrop = document.getElementById('auth-modal-backdrop');
    var authClose    = document.getElementById('auth-modal-close');
    var authEmail    = document.getElementById('admin-email');
    var authPassword = document.getElementById('admin-password');
    var authError    = document.getElementById('auth-error');
    var authSubmit   = document.getElementById('auth-submit-btn');
    var persistToast = document.getElementById('persist-toast');

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
    var linkStatus     = document.getElementById('link-status');
    var linkTags       = document.getElementById('link-tags');
    var linkCategory   = document.getElementById('link-category');
    var starPicker     = document.getElementById('star-picker');
    var filterStatus   = document.getElementById('filter-status');
    var linkPrivate    = document.getElementById('link-private');
    var linkSaveStatus = document.getElementById('link-save-status');
    var linkModalSave  = document.getElementById('link-modal-save');

    // ── Load data ───────────────────────────────────────────────
    function loadData() {
      var linksQuery = db.from('links').select('*').order('saved_at', { ascending: false });
      if (!state.isAdmin) linksQuery = linksQuery.eq('private', false);

      var params = new URLSearchParams(window.location.search);
      var urlCat        = params.get('category');
      var urlCollection = params.get('collection');
      if (urlCat && !urlCollection) state.activeCategory = urlCat;
      if (urlCollection) state.collectionId = urlCollection;

      var queries = [
        linksQuery,
        db.from('categories').select('name, sort_order').order('sort_order')
      ];
      if (state.collectionId) {
        queries.push(db.from('collections').select('*').eq('id', state.collectionId).single());
      }

      Promise.all(queries).then(function (results) {
        var linksRes = results[0], catsRes = results[1];
        if (linksRes.error) throw linksRes.error;
        state.allLinks   = linksRes.data || [];
        state.categories = (catsRes.data || []).map(function (c) { return c.name; });

        // Collection view mode
        if (state.collectionId && results[2] && !results[2].error && results[2].data) {
          state.collectionData = results[2].data;
          document.body.classList.add('collection-mode');
          renderCollectionBanner(results[2].data);
          var idOrder = results[2].data.link_ids || [];
          state.filtered = idOrder
            .map(function (id) { return state.allLinks.find(function (l) { return l.id === id; }); })
            .filter(Boolean);
          renderGrid();
          return;
        }

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

      if (state.activeStatus !== 'all') {
        links = links.filter(function (l) { return l.status === state.activeStatus; });
      }

      var q = state.searchQuery.toLowerCase().trim();
      if (q) {
        var tokens = q.split(/\s+/).filter(Boolean); // multi-token search
        links = links.filter(function (l) {
          var haystack = [l.title, l.description, l.note, l.domain, l.category, l.tags]
            .filter(Boolean).join(' ').toLowerCase();
          return tokens.every(function (tok) { return haystack.indexOf(tok) !== -1; });
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

    filterStatus.addEventListener('change', function () {
      state.activeStatus = filterStatus.value;
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

      // Category tabs
      var cats = ['All'].concat(state.categories);
      cats.forEach(function (cat) {
        var btn = document.createElement('button');
        btn.className = 'filter-tab' + (cat === state.activeCategory ? ' active' : '');
        btn.textContent = cat;
        btn.addEventListener('click', function () {
          state.activeCategory = cat;
          filterTabs.querySelectorAll('.filter-tab').forEach(function (t) {
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

    // ── View mode (feed / grid) ──────────────────────────────────
    var viewMode = localStorage.getItem('rl-view') || 'feed';
    if (viewMode === 'compact') viewMode = 'feed'; // backwards compat

    function applyViewMode() {
      if (viewMode === 'grid') {
        linksGrid.classList.remove('links-grid--feed');
        linksGrid.classList.add('links-grid--grid');
        filterViewIconGrid.style.display = 'none';
        filterViewIconList.style.display = '';
        filterViewBtn.title = 'Switch to list view';
      } else {
        linksGrid.classList.add('links-grid--feed');
        linksGrid.classList.remove('links-grid--grid');
        filterViewIconGrid.style.display = '';
        filterViewIconList.style.display = 'none';
        filterViewBtn.title = 'Switch to grid view';
      }
    }

    filterViewBtn.addEventListener('click', function () {
      viewMode = viewMode === 'feed' ? 'grid' : 'feed';
      localStorage.setItem('rl-view', viewMode);
      applyViewMode();
    });

    applyViewMode();

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

    // ── Curate / selection mode ──────────────────────────────────
    curateBtnEl.addEventListener('click', function () {
      if (state.selectionMode) {
        exitSelectionMode();
      } else {
        enterSelectionMode();
      }
    });

    function enterSelectionMode() {
      state.selectionMode = true;
      state.selectedIds   = new Set();
      document.body.classList.add('selection-mode');
      curateBtnEl.classList.add('active');
      selectionBar.removeAttribute('hidden');
      selectionRecipientInput.value = '';
      selectionMsgInput.value = '';
      updateSelectionBar();
    }

    function exitSelectionMode() {
      state.selectionMode = false;
      state.selectedIds   = new Set();
      document.body.classList.remove('selection-mode');
      curateBtnEl.classList.remove('active');
      selectionBar.setAttribute('hidden', '');
      document.querySelectorAll('.link-card.card-selected').forEach(function (c) {
        c.classList.remove('card-selected');
      });
    }

    function updateSelectionBar() {
      var n = state.selectedIds.size;
      selectionCountEl.textContent = n + ' link' + (n !== 1 ? 's' : '') + ' selected';
    }

    selectionCancelBtn.addEventListener('click', exitSelectionMode);

    selectionCreateBtn.addEventListener('click', function () {
      if (state.selectedIds.size === 0) {
        showToast('Select at least one link first', 'error');
        return;
      }
      var id        = Date.now().toString(36);
      var recipient = selectionRecipientInput.value.trim() || null;
      var message   = selectionMsgInput.value.trim() || null;
      var ids       = Array.from(state.selectedIds);

      selectionCreateBtn.disabled    = true;
      selectionCreateBtn.textContent = 'Creating\u2026';

      db.from('collections').insert({
        id:         id,
        recipient:  recipient,
        message:    message,
        link_ids:   ids,
        created_at: new Date().toISOString()
      }).then(function (res) {
        selectionCreateBtn.disabled    = false;
        selectionCreateBtn.textContent = 'Create share link';
        if (res.error) {
          showToast('Failed: ' + res.error.message, 'error');
          return;
        }
        var shareUrl = 'https://chrislrose.aseva.ai/c.html?id=' + id;
        exitSelectionMode();
        showShareModal(shareUrl);
      });
    });

    // ── Share modal ───────────────────────────────────────────────
    function showShareModal(url) {
      var shareModal   = document.getElementById('share-modal');
      var shareUrlInput = document.getElementById('share-url-input');
      var shareCopyBtn = document.getElementById('share-copy-btn');
      var shareDoneBtn = document.getElementById('share-done-btn');
      var shareBackdrop = document.getElementById('share-modal-backdrop');
      var shareClose   = document.getElementById('share-modal-close');

      shareUrlInput.value = url;
      shareModal.removeAttribute('hidden');
      setTimeout(function () { shareUrlInput.select(); }, 50);

      shareCopyBtn.onclick = function () {
        navigator.clipboard.writeText(url).then(function () {
          showToast('Link copied!', 'success');
        }).catch(function () {
          showToast('Could not copy \u2014 copy it manually', 'error');
        });
      };

      function closeShareModal() { shareModal.setAttribute('hidden', ''); }
      shareDoneBtn.onclick  = closeShareModal;
      shareClose.onclick    = closeShareModal;
      shareBackdrop.onclick = closeShareModal;
    }

    // ── Collection banner ─────────────────────────────────────────
    function renderCollectionBanner(collection) {
      var count   = (collection.link_ids || []).length;
      var dateStr = '';
      try {
        dateStr = new Date(collection.created_at).toLocaleDateString('en-US', { year: 'numeric', month: 'long' });
      } catch (e) {}

      var html =
        '<div class="collection-banner">' +
          '<span class="collection-banner-icon">\uD83D\uDCDA</span>' +
          '<div>' +
            '<div class="collection-banner-title">Chris\u2019s picks for ' + (collection.recipient ? escHtml(collection.recipient) : 'you') + '</div>' +
            '<div class="collection-banner-meta">' +
              count + ' article' + (count !== 1 ? 's' : '') +
              (dateStr ? ' \u00b7 ' + dateStr : '') +
            '</div>' +
          '</div>' +
        '</div>';

      if (collection.message) {
        html += '<div class="collection-message">' + escHtml(collection.message) + '</div>';
      }

      collectionBannerEl.innerHTML = html;
      collectionBannerEl.removeAttribute('hidden');
    }

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

    // ── Status popover ──────────────────────────────────────────
    var activePopover = null;

    function openStatusPopover(id, pillEl) {
      if (activePopover) { activePopover.remove(); activePopover = null; }

      var opts = [
        { value: null,        label: '\u25CB  No status' },
        { value: 'to-read',   label: '\uD83D\uDCD6 To Read' },
        { value: 'to-try',    label: '\u26A1 To Try' },
        { value: 'to-share',  label: '\uD83D\uDC8C To Share' },
        { value: 'done',      label: '\u2713  Done' }
      ];

      var popover = document.createElement('div');
      popover.className = 'status-popover';

      opts.forEach(function (opt) {
        var btn = document.createElement('button');
        btn.className = 'status-popover-option';
        btn.textContent = opt.label;
        btn.addEventListener('click', function (e) {
          e.stopPropagation();
          setLinkStatus(id, opt.value);
          popover.remove();
          activePopover = null;
        });
        popover.appendChild(btn);
      });

      document.body.appendChild(popover);
      activePopover = popover;

      var rect = pillEl.getBoundingClientRect();
      popover.style.position = 'fixed';
      var top = rect.bottom + 4;
      var left = rect.left;
      if (left + 160 > window.innerWidth) left = window.innerWidth - 164;
      popover.style.top = top + 'px';
      popover.style.left = left + 'px';
    }

    document.addEventListener('click', function (e) {
      if (activePopover && !activePopover.contains(e.target)) {
        activePopover.remove();
        activePopover = null;
      }
    });

    function setLinkStatus(id, newStatus) {
      var link = state.allLinks.find(function (l) { return l.id === id; });
      if (!link) return;
      var prevStatus = link.status;
      link.status = newStatus || null;
      link.read   = (newStatus === 'done');
      applyFilters();
      db.from('links').update({ status: link.status, read: link.read }).eq('id', id).then(function (res) {
        if (res.error) {
          link.status = prevStatus;
          link.read   = (prevStatus === 'done');
          applyFilters();
          showToast('Could not save status: ' + res.error.message, 'error');
        }
      });
    }

    // ── Build card ──────────────────────────────────────────────
    function buildCard(link) {
      var card = document.createElement('article');
      card.className = 'link-card anim-fade-up';
      card.dataset.id = link.id;
      card.dataset.imageUrl = link.image || '';
      if (link.status) card.classList.add('status-' + link.status);

      // Thumbnail image HTML
      var imgHtml;
      var brandSvg = generatePlaceholderSvg(link.category, link.domain);
      var fav2 = link.favicon || ('https://www.google.com/s2/favicons?domain=' + escAttr(link.domain || '') + '&sz=64');
      var cardImage = proxyImage(link.image);
      if (brandSvg) {
        imgHtml =
          '<img class="link-card-image" src="' + escAttr(cardImage || brandSvg) + '" alt="" loading="lazy" ' +
          'onerror="this.onerror=null;this.src=\'' + escAttr(brandSvg) + '\';" />';
      } else {
        var ogOverlay = cardImage
          ? '<img class="link-card-og-overlay" src="' + escAttr(cardImage) + '" alt="" loading="lazy" onerror="this.style.display=\'none\'">'
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

      // Status pill label
      var statusLabels = { 'to-read': '\uD83D\uDCD6 To Read', 'to-try': '\u26A1 To Try', 'to-share': '\uD83D\uDC8C To Share', 'done': '\u2713 Done' };
      var pillLabel = link.status ? (statusLabels[link.status] || link.status) : '\u25CB None';
      var statusPill =
        '<button class="link-card-status-pill status-' + (link.status || 'none') + '" ' +
        'data-id="' + escAttr(link.id) + '" aria-label="Set status" title="Change status">' +
        pillLabel + ' \u25BE</button>';

      // Tags
      var tagsHtml = '';
      if (link.tags) {
        link.tags.split(',').forEach(function (t) {
          var tag = t.trim();
          if (tag) tagsHtml += '<span class="tag tag-secondary">' + escHtml(tag) + '</span>';
        });
      }

      // Favicon
      var faviconHtml = link.favicon
        ? '<img class="link-card-favicon" src="' + escAttr(link.favicon) + '" alt="" loading="lazy" onerror="this.style.display=\'none\';" />'
        : '';

      card.innerHTML =
        // Thumbnail
        '<div class="link-card-thumb-wrap">' +
          '<a href="' + escAttr(link.url) + '" target="_blank" rel="noopener noreferrer" tabindex="-1" aria-hidden="true">' +
            imgHtml +
          '</a>' +
        '</div>' +
        // Main content
        '<div class="link-card-main">' +
          '<a href="' + escAttr(link.url) + '" target="_blank" rel="noopener noreferrer" style="text-decoration:none;color:inherit;">' +
            '<p class="link-card-title">' + escHtml(link.title || 'Untitled') + '</p>' +
          '</a>' +
          '<div class="link-card-byline">' +
            faviconHtml +
            (link.domain ? '<span class="link-card-domain">' + escHtml(link.domain) + '</span>' : '') +
            (link.domain && (link.stars || dateStr) ? '<span style="opacity:0.4">\u00b7</span>' : '') +
            (link.stars ? starsHtml : '') +
            (dateStr ? '<span class="link-card-date">' + escHtml(dateStr) + '</span>' : '') +
          '</div>' +
          (link.note ? '<p class="link-card-note-inline">' + escHtml(link.note) + '</p>' : '') +
        '</div>' +
        // Right column
        '<div class="link-card-right">' +
          '<div class="link-card-tags">' +
            (link.category ? '<span class="tag">' + escHtml(link.category) + '</span>' : '') +
            tagsHtml +
          '</div>' +
          statusPill +
          '<div class="link-card-actions">' +
            '<button class="link-card-action-btn copy" data-id="' + escAttr(link.id) + '" data-url="' + escAttr(link.url) + '" aria-label="Copy link">&#128279;</button>' +
            '<button class="link-card-action-btn edit" data-id="' + escAttr(link.id) + '" aria-label="Edit link">&#9998;</button>' +
            '<button class="link-card-action-btn delete" data-id="' + escAttr(link.id) + '" aria-label="Delete link">&times;</button>' +
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
        var pillEl = card.querySelector('.link-card-status-pill');
        pillEl.addEventListener('click', function (e) {
          e.preventDefault();
          e.stopPropagation();
          openStatusPopover(link.id, pillEl);
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

      // Selection mode — clicking the card toggles its selected state
      card.addEventListener('click', function (e) {
        if (!state.selectionMode) return;
        // Prevent navigating the link while selecting
        var anchor = e.target.tagName === 'A' ? e.target : e.target.closest('a');
        if (anchor) e.preventDefault();
        if (state.selectedIds.has(link.id)) {
          state.selectedIds.delete(link.id);
          card.classList.remove('card-selected');
        } else {
          state.selectedIds.add(link.id);
          card.classList.add('card-selected');
        }
        updateSelectionBar();
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
      'tiktok.com':           { path: 'M19.59 6.69a4.83 4.83 0 01-3.77-4.25V2h-3.45v13.67a2.89 2.89 0 01-2.88 2.5 2.89 2.89 0 01-2.89-2.89 2.89 2.89 0 012.89-2.89c.28 0 .54.04.79.1V9.01a6.27 6.27 0 00-.79-.05 6.34 6.34 0 00-6.34 6.34 6.34 6.34 0 006.34 6.34 6.34 6.34 0 006.33-6.34V8.69a8.18 8.18 0 004.78 1.52V6.76a4.85 4.85 0 01-1.01-.07z', viewBox: '0 0 24 24', color: '#010101', color2: '#1a1a2e' },
      'threads.net':          { path: 'M12.186 24h-.007c-3.581-.024-6.334-1.205-8.184-3.509C2.35 18.44 1.5 15.586 1.472 12.01v-.017c.03-3.579.879-6.43 2.525-8.482C5.845 1.205 8.6.024 12.18 0h.014c2.746.02 5.043.725 6.826 2.098 1.677 1.29 2.858 3.13 3.509 5.467l-2.04.569c-1.104-3.96-3.898-5.984-8.304-6.015-2.91.022-5.11.936-6.54 2.717C4.307 6.504 3.616 8.914 3.589 12c.027 3.086.718 5.496 2.057 7.164 1.43 1.783 3.631 2.698 6.54 2.717 2.623-.02 4.358-.631 5.8-2.045 1.647-1.613 1.618-3.593 1.09-4.798-.31-.71-.873-1.3-1.634-1.75-.192 1.352-.622 2.446-1.284 3.272-.886 1.102-2.14 1.704-3.73 1.79-1.202.065-2.361-.218-3.259-.801-1.063-.689-1.685-1.74-1.752-2.964-.065-1.19.408-2.285 1.33-3.082.88-.76 2.119-1.207 3.583-1.291a13.853 13.853 0 011.57.044v-.785c0-1.64-.906-2.534-2.635-2.572a5.08 5.08 0 00-.137-.003c-1.075 0-2.266.343-2.993.905L8.3 7.79c.89-.797 2.547-1.37 4.065-1.376h.064c2.867.064 4.473 1.73 4.473 4.527v4.307c.38.205.733.44 1.048.704 1.11.918 1.784 2.197 1.889 3.6.18 2.42-.888 4.75-2.84 6.22-1.504 1.124-3.476 1.714-5.814 1.228zm.02-9.69c-.734 0-1.37.138-1.85.4-.512.278-.783.686-.764 1.151.04.822.78 1.41 1.85 1.35 1.046-.059 1.82-.546 2.254-1.41.255-.514.396-1.147.42-1.882a13.04 13.04 0 00-1.91-.609z', viewBox: '0 0 24 24', color: '#000000', color2: '#1a1a2e' }
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
          // Build bookmarklet href — always points to primary domain
          var bl = 'javascript:(function(){' +
            "var u=encodeURIComponent(location.href);" +
            "window.open('" + PRIMARY_URL + "?add='+u,'_blank');" +
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
              setTimeout(function () { quickSave(url); }, 100);
            }
          }
        });
    }

    // ── Settings panel ───────────────────────────────────────────
    settingsLock.addEventListener('click', function () {
      settingsPanel.classList.remove('open');
      deactivateAdmin();
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
      linkPrivate.checked = false;
      linkStatus.value = '';
      linkTags.value   = '';
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
      linkDesc.value    = link.description || '';
      linkNote.value    = link.note        || '';
      linkStatus.value  = link.status      || '';
      linkTags.value    = link.tags        || '';
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

      var entryStatus = linkStatus.value || null;
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
        status:      entryStatus,
        tags:        linkTags.value.trim() || null,
        read:        entryStatus === 'done',
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

    // ── Cycle status (the ○ button on each card) ─────────────────
    var statusCycle = [null, 'to-read', 'to-try', 'to-share', 'done'];
    function toggleStatus(id) {
      var link = state.allLinks.find(function (l) { return l.id === id; });
      if (!link) return;
      var currentIdx = statusCycle.indexOf(link.status || null);
      var nextIdx    = (currentIdx + 1) % statusCycle.length;
      var newStatus  = statusCycle[nextIdx];
      var prevStatus = link.status;
      link.status = newStatus;
      link.read   = (newStatus === 'done');
      applyFilters();
      db.from('links').update({ status: newStatus, read: link.read }).eq('id', id).then(function (res) {
        if (res.error) {
          console.error('[reading-list] status toggle failed:', res.error.message);
          link.status = prevStatus;
          link.read   = (prevStatus === 'done');
          applyFilters();
        }
      });
    }

    // ── Bookmarklet ?add= param ──────────────────────────────────
    var pendingAddUrl = null;

    function checkAddParam() {
      var search = window.location.search;
      var addUrl = search.startsWith('?add=') ? decodeURIComponent(search.slice(5)) : null;
      if (!addUrl) return;
      window.history.replaceState({}, '', window.location.pathname);
      if (state.isAdmin) {
        quickSave(addUrl);
      } else {
        pendingAddUrl = addUrl;
        openAuthModal();
      }
    }

    // ── Quick Save (auto-save with no form) ─────────────────────
    function quickSave(url) {
      showToast('Saving…', 'info');

      var domain = '';
      try { domain = new URL(url).hostname.replace(/^www\./, ''); } catch (e) {}

      // Check for YouTube oEmbed first
      var ytMatch = url.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/)([^&]+)/);
      var metaPromise;

      if (ytMatch) {
        metaPromise = fetch('https://www.youtube.com/oembed?url=' + encodeURIComponent(url) + '&format=json')
          .then(function (r) { return r.json(); })
          .then(function (d) {
            return {
              title: d.title || '',
              description: d.author_name ? 'By ' + d.author_name : '',
              image: d.thumbnail_url || '',
              favicon: 'https://www.google.com/s2/favicons?domain=youtube.com&sz=64'
            };
          });
      } else {
        metaPromise = fetch(MICROLINK + encodeURIComponent(url))
          .then(function (r) { return r.json(); })
          .then(function (data) {
            if (data.status !== 'success') throw new Error('microlink failed');
            var d = data.data || {};
            return {
              title: d.title || '',
              description: d.description || '',
              image: (d.image && d.image.url) || '',
              favicon: (d.logo && d.logo.url) || ('https://www.google.com/s2/favicons?domain=' + domain + '&sz=64')
            };
          });
      }

      metaPromise
        .catch(function () {
          // Metadata fetch failed — save with just the URL
          return { title: '', description: '', image: '', favicon: '' };
        })
        .then(function (meta) {
          var entry = {
            id:          generateId(url),
            url:         url,
            title:       meta.title || url,
            description: meta.description || null,
            image:       meta.image || null,
            favicon:     meta.favicon || null,
            domain:      domain || null,
            category:    null,
            tags:        null,
            stars:       0,
            note:        null,
            status:      'to-read',
            read:        false,
            private:     false,
            saved_at:    new Date().toISOString()
          };

          return persistToSupabase(entry, false).then(function () {
            // Add to local state
            state.allLinks.unshift(entry);
            applyFilters();
            showToast('Saved: ' + (meta.title || domain || 'Link'), 'success');
            // Auto-close after a brief moment (works when opened via bookmarklet window.open)
            setTimeout(function () { window.close(); }, 1500);
          });
        })
        .catch(function (err) {
          showToast('Save failed: ' + err.message, 'error');
        });
    }

    // ── Keyboard: Escape ─────────────────────────────────────────
    document.addEventListener('keydown', function (e) {
      if (e.key !== 'Escape') return;
      if (!authModal.hasAttribute('hidden'))  { closeAuthModal();  return; }
      if (!linkModal.hasAttribute('hidden'))  { closeLinkModal();  return; }
      var shareModal = document.getElementById('share-modal');
      if (shareModal && !shareModal.hasAttribute('hidden')) { shareModal.setAttribute('hidden', ''); return; }
      if (state.selectionMode) { exitSelectionMode(); return; }
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
