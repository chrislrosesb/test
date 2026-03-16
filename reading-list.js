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
    var linkPrivate    = document.getElementById('link-private');
    var linkSaveStatus = document.getElementById('link-save-status');
    var linkModalSave  = document.getElementById('link-modal-save');

    // ── Load data ───────────────────────────────────────────────
    function loadData() {
      var linksQuery = db.from('links').select('*').order('saved_at', { ascending: false });
      if (!state.isAdmin) linksQuery = linksQuery.eq('private', false);

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
          applyFilters();
        });
        filterTabs.appendChild(btn);
      });
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

    // ── Build card ──────────────────────────────────────────────
    function buildCard(link) {
      var card = document.createElement('article');
      card.className = 'link-card anim-fade-up';
      card.dataset.id = link.id;

      // Image
      var imgHtml;
      if (link.image) {
        imgHtml =
          '<img class="link-card-image" src="' + escAttr(link.image) + '" alt="" loading="lazy" ' +
          'onerror="this.style.display=\'none\';this.nextElementSibling.style.display=\'flex\';" />' +
          '<div class="link-card-image-placeholder" style="display:none;">' + bookmarkIcon() + '</div>';
      } else {
        imgHtml = '<div class="link-card-image-placeholder">' + bookmarkIcon() + '</div>';
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

      card.innerHTML =
        '<div class="link-card-actions">' +
          '<button class="link-card-action-btn edit" data-id="' + escAttr(link.id) + '" aria-label="Edit link">&#9998;</button>' +
          '<button class="link-card-action-btn delete" data-id="' + escAttr(link.id) + '" aria-label="Delete link">&times;</button>' +
        '</div>' +
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
          // Build bookmarklet href
          var bl = 'javascript:(function(){' +
            "var u=encodeURIComponent(location.href);" +
            "window.open('https://chrislrosesb.github.io/test/reading-list.html?add='+u,'_blank');" +
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

    function fetchOG(url) {
      ogStatus.textContent = 'Fetching metadata\u2026';
      var domain = '';
      try { domain = new URL(url).hostname.replace(/^www\./, ''); } catch (e) {}

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

    // ── Bookmarklet ?add= param ──────────────────────────────────
    function checkAddParam() {
      var params = new URLSearchParams(window.location.search);
      var addUrl = params.get('add');
      if (addUrl && state.isAdmin) {
        openAddModal(decodeURIComponent(addUrl));
        window.history.replaceState({}, '', window.location.pathname);
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
    checkAddParam();
    // Restore admin session if Supabase still has a valid token
    db.auth.getSession().then(function (res) {
      if (res.data && res.data.session) {
        activateAdmin(true);
      }
    });

  }); // end DOMContentLoaded

}());
