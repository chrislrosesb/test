(function () {
  'use strict';

  var SUPABASE_URL  = 'https://ownqyyfgferczpdgihgr.supabase.co';
  var SUPABASE_ANON = 'sb_publishable_RPJSQlVO4isbKnZve8NlWg_55EO350Y';
  var db = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON);

  var state = {
    categories:        [],
    hardware:          [],
    software:          [],
    editingHardwareId: null,
    editingSoftwareId: null
  };

  document.addEventListener('DOMContentLoaded', function () {

    // ── DOM refs ──────────────────────────────────────────────────
    var loginSection  = document.getElementById('admin-login');
    var dashSection   = document.getElementById('admin-dashboard');
    var loginEmail    = document.getElementById('login-email');
    var loginPassword = document.getElementById('login-password');
    var loginSubmit   = document.getElementById('login-submit');
    var loginError    = document.getElementById('login-error');

    var tabs     = document.querySelectorAll('.admin-tab');
    var sections = document.querySelectorAll('.admin-section');

    var catChips  = document.getElementById('cat-chips');
    var catInput  = document.getElementById('cat-input');
    var catAddBtn = document.getElementById('cat-add-btn');
    var catStatus = document.getElementById('cat-status');

    var hwModal    = document.getElementById('hw-modal');
    var hwStatus   = document.getElementById('hw-status');
    var swModal    = document.getElementById('sw-modal');
    var swStatus   = document.getElementById('sw-status');

    var nowTextarea = document.getElementById('now-textarea');
    var nowSaveBtn  = document.getElementById('now-save-btn');
    var nowStatus   = document.getElementById('now-status');
    var nowUpdated  = document.getElementById('now-updated');

    // ── Auth ──────────────────────────────────────────────────────
    db.auth.getSession().then(function (res) {
      if (res.data && res.data.session) {
        showDashboard();
      } else {
        loginSection.removeAttribute('hidden');
      }
    });

    loginSubmit.addEventListener('click', submitLogin);
    loginPassword.addEventListener('keydown', function (e) {
      if (e.key === 'Enter') submitLogin();
    });

    function submitLogin() {
      var email = loginEmail.value.trim();
      var pw    = loginPassword.value;
      if (!email || !pw) { loginError.textContent = 'Please enter your email and password.'; return; }
      loginError.textContent = '';
      loginSubmit.disabled    = true;
      loginSubmit.textContent = 'Signing in\u2026';
      db.auth.signInWithPassword({ email: email, password: pw }).then(function (res) {
        loginSubmit.disabled    = false;
        loginSubmit.textContent = 'Sign in';
        if (res.error) {
          loginError.textContent = res.error.message;
          loginPassword.value = '';
        } else {
          showDashboard();
        }
      });
    }

    document.getElementById('logout-btn').addEventListener('click', function () {
      db.auth.signOut().then(function () { window.location.reload(); });
    });

    function showDashboard() {
      loginSection.setAttribute('hidden', '');
      dashSection.removeAttribute('hidden');
      loadAll();
      buildBookmarklet();
    }

    // ── Tabs ─────────────────────────────────────────────────────
    tabs.forEach(function (tab) {
      tab.addEventListener('click', function () {
        tabs.forEach(function (t) { t.classList.remove('active'); });
        sections.forEach(function (s) { s.classList.remove('active'); });
        tab.classList.add('active');
        document.getElementById(tab.dataset.tab).classList.add('active');
      });
    });

    // ── Load all ─────────────────────────────────────────────────
    function loadAll() {
      loadCategories();
      loadGear();
      loadNow();
    }

    // ── Categories ────────────────────────────────────────────────
    function loadCategories() {
      db.from('categories').select('name, sort_order').order('sort_order').then(function (res) {
        state.categories = (res.data || []).map(function (c) { return c.name; });
        renderCategoryChips();
      });
    }

    function renderCategoryChips() {
      catChips.innerHTML = '';
      state.categories.forEach(function (cat) {
        var chip = document.createElement('span');
        chip.className = 'cat-chip';
        chip.innerHTML = escHtml(cat) + '<button type="button" aria-label="Remove ' + escAttr(cat) + '">\u00d7</button>';
        chip.querySelector('button').addEventListener('click', function () {
          state.categories = state.categories.filter(function (c) { return c !== cat; });
          renderCategoryChips();
          persistCategories();
        });
        catChips.appendChild(chip);
      });
    }

    catAddBtn.addEventListener('click', addCategory);
    catInput.addEventListener('keydown', function (e) { if (e.key === 'Enter') addCategory(); });

    function addCategory() {
      var name = catInput.value.trim();
      if (!name) return;
      if (state.categories.indexOf(name) !== -1) {
        catStatus.style.color = '#f85149';
        catStatus.textContent = 'Category already exists.';
        return;
      }
      state.categories.push(name);
      catInput.value = '';
      catStatus.textContent = '';
      renderCategoryChips();
      persistCategories();
    }

    function persistCategories() {
      catStatus.style.color = 'var(--color-text-dim)';
      catStatus.textContent = 'Saving\u2026';
      var rows = state.categories.map(function (name, i) { return { name: name, sort_order: i }; });
      db.from('categories').delete().neq('name', '').then(function () {
        return db.from('categories').insert(rows);
      }).then(function (res) {
        if (res.error) {
          catStatus.style.color = '#f85149';
          catStatus.textContent = '\u2717 Failed: ' + res.error.message;
        } else {
          catStatus.style.color = 'var(--color-accent)';
          catStatus.textContent = '\u2713 Saved';
          setTimeout(function () { catStatus.textContent = ''; }, 3000);
        }
      });
    }

    function buildBookmarklet() {
      var dest = window.location.origin + '/reading-list.html';
      var bl = 'javascript:(function(){' +
        "var u=encodeURIComponent(location.href);" +
        "window.open('" + dest + "?add='+u,'_blank');" +
        '})();';
      document.getElementById('bookmarklet-link').href = bl;
    }

    // ── Gear: Hardware ────────────────────────────────────────────
    function loadGear() {
      Promise.all([
        db.from('gear_hardware').select('*').order('sort_order'),
        db.from('gear_software').select('*').order('sort_order')
      ]).then(function (results) {
        state.hardware = results[0].data || [];
        state.software = results[1].data || [];
        renderHardwareList();
        renderSoftwareList();
      });
    }

    function renderHardwareList() {
      var list = document.getElementById('hardware-list');
      list.innerHTML = '';
      if (!state.hardware.length) {
        list.innerHTML = '<p style="color:var(--color-text-muted);font-size:0.85rem;padding:0.5rem 0;">No hardware items yet.</p>';
        return;
      }
      state.hardware.forEach(function (item) {
        var row = document.createElement('div');
        row.className = 'admin-list-item';
        row.innerHTML =
          '<span class="admin-list-item-name">' + escHtml(item.name) + '</span>' +
          (item.badge ? '<span class="admin-list-item-meta">' + escHtml(item.badge) + '</span>' : '') +
          '<button class="btn admin-item-btn" data-action="edit">Edit</button>' +
          '<button class="btn admin-item-btn admin-item-btn--danger" data-action="del">Delete</button>';
        row.querySelector('[data-action="edit"]').addEventListener('click', function () { openHardwareModal(item); });
        row.querySelector('[data-action="del"]').addEventListener('click', function () { deleteHardware(item.id, item.name); });
        list.appendChild(row);
      });
    }

    document.getElementById('add-hardware-btn').addEventListener('click', function () { openHardwareModal(null); });
    document.getElementById('hw-modal-close').addEventListener('click', closeHardwareModal);
    document.getElementById('hw-modal-backdrop').addEventListener('click', closeHardwareModal);
    document.getElementById('hw-save-btn').addEventListener('click', saveHardware);

    function openHardwareModal(item) {
      state.editingHardwareId = item ? item.id : null;
      document.getElementById('hw-modal-title').textContent = item ? 'Edit Hardware' : 'Add Hardware';
      document.getElementById('hw-name').value  = item ? item.name          : '';
      document.getElementById('hw-badge').value = item ? (item.badge    || '') : '';
      document.getElementById('hw-image').value = item ? (item.image_url || '') : '';
      document.getElementById('hw-desc').value  = item ? (item.description || '') : '';
      hwStatus.textContent = '';
      hwModal.removeAttribute('hidden');
      setTimeout(function () { document.getElementById('hw-name').focus(); }, 40);
    }

    function closeHardwareModal() { hwModal.setAttribute('hidden', ''); }

    function saveHardware() {
      var name = document.getElementById('hw-name').value.trim();
      if (!name) { hwStatus.style.color = '#f85149'; hwStatus.textContent = 'Name is required.'; return; }
      var id    = state.editingHardwareId || (slugify(name) + '-' + Date.now().toString(36));
      var orig  = state.editingHardwareId ? state.hardware.find(function (h) { return h.id === state.editingHardwareId; }) : null;
      var entry = {
        id:          id,
        name:        name,
        badge:       document.getElementById('hw-badge').value.trim() || null,
        image_url:   document.getElementById('hw-image').value.trim() || null,
        description: document.getElementById('hw-desc').value.trim(),
        sort_order:  orig ? orig.sort_order : state.hardware.length
      };
      hwStatus.style.color = 'var(--color-text-dim)';
      hwStatus.textContent = 'Saving\u2026';
      db.from('gear_hardware').upsert(entry).then(function (res) {
        if (res.error) { hwStatus.style.color = '#f85149'; hwStatus.textContent = '\u2717 ' + res.error.message; return; }
        closeHardwareModal();
        loadGear();
      });
    }

    function deleteHardware(id, name) {
      if (!window.confirm('Delete \u201C' + name + '\u201D?')) return;
      db.from('gear_hardware').delete().eq('id', id).then(function () { loadGear(); });
    }

    // ── Gear: Software ────────────────────────────────────────────
    function renderSoftwareList() {
      var list = document.getElementById('software-list');
      list.innerHTML = '';
      if (!state.software.length) {
        list.innerHTML = '<p style="color:var(--color-text-muted);font-size:0.85rem;padding:0.5rem 0;">No software items yet.</p>';
        return;
      }
      state.software.forEach(function (item) {
        var row = document.createElement('div');
        row.className = 'admin-list-item';
        row.innerHTML =
          '<span class="admin-list-item-name">' + escHtml(item.name) + '</span>' +
          '<button class="btn admin-item-btn" data-action="edit">Edit</button>' +
          '<button class="btn admin-item-btn admin-item-btn--danger" data-action="del">Delete</button>';
        row.querySelector('[data-action="edit"]').addEventListener('click', function () { openSoftwareModal(item); });
        row.querySelector('[data-action="del"]').addEventListener('click', function () { deleteSoftware(item.id, item.name); });
        list.appendChild(row);
      });
    }

    document.getElementById('add-software-btn').addEventListener('click', function () { openSoftwareModal(null); });
    document.getElementById('sw-modal-close').addEventListener('click', closeSoftwareModal);
    document.getElementById('sw-modal-backdrop').addEventListener('click', closeSoftwareModal);
    document.getElementById('sw-save-btn').addEventListener('click', saveSoftware);

    function openSoftwareModal(item) {
      state.editingSoftwareId = item ? item.id : null;
      document.getElementById('sw-modal-title').textContent = item ? 'Edit Software' : 'Add Software';
      document.getElementById('sw-name').value  = item ? item.name              : '';
      document.getElementById('sw-badge').value = item ? (item.badge  || '')    : '';
      document.getElementById('sw-icon').value  = item ? (item.icon   || '')    : '';
      document.getElementById('sw-url').value   = item ? (item.url    || '')    : '';
      document.getElementById('sw-desc').value  = item ? (item.description || '') : '';
      swStatus.textContent = '';
      swModal.removeAttribute('hidden');
      setTimeout(function () { document.getElementById('sw-name').focus(); }, 40);
    }

    function closeSoftwareModal() { swModal.setAttribute('hidden', ''); }

    function saveSoftware() {
      var name = document.getElementById('sw-name').value.trim();
      if (!name) { swStatus.style.color = '#f85149'; swStatus.textContent = 'Name is required.'; return; }
      var id   = state.editingSoftwareId || (slugify(name) + '-' + Date.now().toString(36));
      var orig = state.editingSoftwareId ? state.software.find(function (s) { return s.id === state.editingSoftwareId; }) : null;
      var entry = {
        id:          id,
        name:        name,
        badge:       document.getElementById('sw-badge').value.trim() || null,
        icon:        document.getElementById('sw-icon').value.trim()  || null,
        url:         document.getElementById('sw-url').value.trim()   || null,
        description: document.getElementById('sw-desc').value.trim(),
        sort_order:  orig ? orig.sort_order : state.software.length
      };
      swStatus.style.color = 'var(--color-text-dim)';
      swStatus.textContent = 'Saving\u2026';
      db.from('gear_software').upsert(entry).then(function (res) {
        if (res.error) { swStatus.style.color = '#f85149'; swStatus.textContent = '\u2717 ' + res.error.message; return; }
        closeSoftwareModal();
        loadGear();
      });
    }

    function deleteSoftware(id, name) {
      if (!window.confirm('Delete \u201C' + name + '\u201D?')) return;
      db.from('gear_software').delete().eq('id', id).then(function () { loadGear(); });
    }

    // ── Now ───────────────────────────────────────────────────────
    function loadNow() {
      db.from('site_content').select('*').eq('id', 'now').single().then(function (res) {
        if (res.data) {
          nowTextarea.value = res.data.content || '';
          if (res.data.updated_at) {
            nowUpdated.textContent = 'Last updated: ' + new Date(res.data.updated_at).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
          }
        }
      });
    }

    nowSaveBtn.addEventListener('click', function () {
      nowSaveBtn.disabled    = true;
      nowSaveBtn.textContent = 'Saving\u2026';
      db.from('site_content').update({ content: nowTextarea.value, updated_at: new Date().toISOString() }).eq('id', 'now').then(function (res) {
        nowSaveBtn.disabled    = false;
        nowSaveBtn.textContent = 'Save';
        if (res.error) {
          nowStatus.style.color = '#f85149';
          nowStatus.textContent = '\u2717 Failed: ' + res.error.message;
        } else {
          nowStatus.style.color = 'var(--color-accent)';
          nowStatus.textContent = '\u2713 Saved';
          nowUpdated.textContent = 'Last updated: ' + new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
          setTimeout(function () { nowStatus.textContent = ''; }, 3000);
        }
      });
    });

    // ── Escape key ────────────────────────────────────────────────
    document.addEventListener('keydown', function (e) {
      if (e.key !== 'Escape') return;
      if (!hwModal.hasAttribute('hidden')) { closeHardwareModal(); return; }
      if (!swModal.hasAttribute('hidden')) { closeSoftwareModal(); }
    });

    // ── Utilities ─────────────────────────────────────────────────
    function slugify(str) {
      return str.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 40);
    }
    function escHtml(str) {
      return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    }
    function escAttr(str) { return escHtml(str); }

  }); // end DOMContentLoaded

}());
