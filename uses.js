(function () {
  'use strict';

  var SUPABASE_URL  = 'https://ownqyyfgferczpdgihgr.supabase.co';
  var SUPABASE_ANON = 'sb_publishable_RPJSQlVO4isbKnZve8NlWg_55EO350Y';
  var db = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON);

  function init() {
    Promise.all([
      db.from('gear_hardware').select('*').order('sort_order'),
      db.from('gear_software').select('*').order('sort_order'),
      db.from('site_content').select('*').eq('id', 'now').single(),
      db.from('gear_hobbies').select('*').order('sort_order'),
      db.from('gear_projects').select('*').order('sort_order')
    ]).then(function (results) {
      renderHardware(results[0].data || []);
      renderSoftware(results[1].data || []);
      renderNow(results[2].data);
      renderHobbies(results[3].data || []);
      renderProjects(results[4].data || []);
    }).catch(function (err) {
      console.warn('[uses] load failed:', err.message);
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  function renderHardware(items) {
    var grid = document.getElementById('hardware-grid');
    if (!grid) return;
    grid.innerHTML = '';
    if (!items.length) {
      grid.innerHTML = '<p style="color:var(--color-text-muted);font-size:0.9rem;">No hardware items yet.</p>';
      return;
    }
    items.forEach(function (item) {
      var card = document.createElement('div');
      card.className = 'hardware-card anim-fade-up';
      var photoHtml = item.image_url
        ? '<img class="hardware-photo" src="' + escAttr(item.image_url) + '" alt="' + escAttr(item.name) + '" loading="lazy" onerror="this.style.display=\'none\'">' + deviceSvg()
        : deviceSvg();
      card.innerHTML =
        '<div class="hardware-photo-wrap">' + photoHtml + '</div>' +
        '<div class="hardware-card-body">' +
          '<h3>' + escHtml(item.name) + '</h3>' +
          (item.badge ? '<span class="hardware-badge">' + escHtml(item.badge) + '</span>' : '') +
          '<p>' + escHtml(item.description || '') + '</p>' +
        '</div>';
      grid.appendChild(card);
    });
  }

  function renderSoftware(items) {
    var grid = document.getElementById('software-grid');
    if (!grid) return;
    grid.innerHTML = '';
    if (!items.length) {
      grid.innerHTML = '<p style="color:var(--color-text-muted);font-size:0.9rem;">No software items yet.</p>';
      return;
    }
    items.forEach(function (item) {
      var iconHtml = item.icon
        ? '<div style="font-size:1.75rem;line-height:1;margin-bottom:0.75rem;">' + escHtml(item.icon) + '</div>'
        : '<div style="margin-bottom:0.75rem;">' + codeSvg() + '</div>';
      var inner =
        iconHtml +
        '<h3>' + escHtml(item.name) + '</h3>' +
        (item.badge ? '<span class="hardware-badge">' + escHtml(item.badge) + '</span>' : '') +
        '<p>' + escHtml(item.description || '') + '</p>';
      var card;
      if (item.url) {
        card = document.createElement('a');
        card.href = item.url;
        card.target = '_blank';
        card.rel = 'noopener noreferrer';
        card.className = 'card anim-fade-up card--link';
      } else {
        card = document.createElement('div');
        card.className = 'card anim-fade-up';
      }
      card.innerHTML = inner;
      grid.appendChild(card);
    });
  }

  function renderProjects(items) {
    var grid = document.getElementById('projects-grid');
    if (!grid) return;
    grid.innerHTML = '';
    if (!items.length) {
      grid.innerHTML = '<p style="color:var(--color-text-muted);font-size:0.9rem;">No projects yet.</p>';
      return;
    }
    items.forEach(function (item) {
      var iconHtml = item.icon
        ? '<div style="font-size:1.75rem;line-height:1;margin-bottom:0.75rem;">' + escHtml(item.icon) + '</div>'
        : '<div style="margin-bottom:0.75rem;">' + codeSvg() + '</div>';
      var inner =
        iconHtml +
        '<h3>' + escHtml(item.name) + '</h3>' +
        (item.badge ? '<span class="hardware-badge">' + escHtml(item.badge) + '</span>' : '') +
        '<p>' + escHtml(item.description || '') + '</p>';
      var card;
      if (item.url) {
        card = document.createElement('a');
        card.href = item.url;
        card.target = '_blank';
        card.rel = 'noopener noreferrer';
        card.className = 'card anim-fade-up card--link';
      } else {
        card = document.createElement('div');
        card.className = 'card anim-fade-up';
      }
      card.innerHTML = inner;
      grid.appendChild(card);
    });
  }

  function renderHobbies(items) {
    var grid = document.getElementById('hobbies-grid');
    if (!grid) return;
    grid.innerHTML = '';
    if (!items.length) {
      grid.innerHTML = '<p style="color:var(--color-text-muted);font-size:0.9rem;">No hobbies yet.</p>';
      return;
    }
    items.forEach(function (item) {
      var card = document.createElement('div');
      card.className = 'hardware-card anim-fade-up';
      var photoHtml = item.image_url
        ? '<img class="hardware-photo" src="' + escAttr(item.image_url) + '" alt="' + escAttr(item.name) + '" loading="lazy" onerror="this.style.display=\'none\'">' + deviceSvg()
        : deviceSvg();
      card.innerHTML =
        '<div class="hardware-photo-wrap">' + photoHtml + '</div>' +
        '<div class="hardware-card-body">' +
          '<h3>' + escHtml(item.name) + '</h3>' +
          (item.badge ? '<span class="hardware-badge">' + escHtml(item.badge) + '</span>' : '') +
          '<p>' + escHtml(item.description || '') + '</p>' +
        '</div>';
      grid.appendChild(card);
    });
  }

  function renderNow(row) {
    var section = document.getElementById('now-section');
    var content = document.getElementById('now-content');
    if (!section || !content) return;
    if (!row || !row.content || !row.content.trim()) {
      section.style.display = 'none';
      return;
    }
    var dateStr = '';
    try {
      dateStr = new Date(row.updated_at).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
    } catch (e) {}
    content.innerHTML =
      '<p class="now-content-text">' + escHtml(row.content) + '</p>' +
      (dateStr ? '<p class="now-updated">Last updated: ' + escHtml(dateStr) + '</p>' : '');
  }

  function deviceSvg() {
    return '<svg class="hardware-photo-fallback" width="56" height="56" viewBox="0 0 24 24" fill="none" stroke="var(--color-accent)" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="2" y="3" width="20" height="14" rx="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>';
  }

  function codeSvg() {
    return '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--color-accent)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>';
  }

  function escHtml(str) {
    return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }
  function escAttr(str) { return escHtml(str); }

}());
