/*!
 * command-palette.js — Keyboard-first command palette (⌘K / Ctrl+K)
 * Navigate pages, jump to sections, open external links.
 * Full keyboard navigation: ↑↓ to move, Enter to select, Esc to close.
 */
(function () {
  'use strict';

  var overlay  = document.getElementById('cmd-overlay');
  var input    = document.getElementById('cmd-input');
  var results  = document.getElementById('cmd-results');
  var trigger  = document.getElementById('cmd-palette-trigger');
  var backdrop = document.getElementById('cmd-backdrop');

  if (!overlay || !input || !results) return;

  // ── Command definitions ──────────────────────────────────────
  function nav(href) {
    if (window.pageTransitionTo) {
      window.pageTransitionTo(href);
    } else {
      window.location.href = href;
    }
  }

  function jumpTo(page, hash) {
    var currentPage = window.location.pathname.split('/').pop() || 'index.html';
    if (currentPage === page || (page === 'index.html' && currentPage === '')) {
      close();
      var el = document.getElementById(hash);
      if (el) el.scrollIntoView({ behavior: 'smooth' });
    } else {
      nav(page + '#' + hash);
    }
  }

  var ALL_COMMANDS = [
    // Navigation
    { section: 'Navigate', label: 'Home',            hint: 'index.html',   action: function () { nav('index.html'); } },
    { section: 'Navigate', label: 'About',           hint: 'about.html',   action: function () { nav('about.html'); } },
    { section: 'Navigate', label: 'Contact',         hint: 'contact.html', action: function () { nav('contact.html'); } },
    { section: 'Navigate', label: 'Uses',            hint: 'uses.html',    action: function () { nav('uses.html'); } },
    // Jump to sections
    { section: 'Jump to',  label: 'What I Do',       hint: 'home',         action: function () { jumpTo('index.html', 'what-i-do'); } },
    { section: 'Jump to',  label: 'Expertise',       hint: 'home',         action: function () { jumpTo('index.html', 'expertise'); } },
    { section: 'Jump to',  label: 'GitHub Activity', hint: 'home',         action: function () { jumpTo('index.html', 'github-activity'); } },
    { section: 'Jump to',  label: 'Career Timeline', hint: 'about',        action: function () { jumpTo('about.html', 'career-timeline'); } },
    { section: 'Jump to',  label: 'Skills',          hint: 'about',        action: function () { jumpTo('about.html', 'skills'); } },
    // External
    { section: 'External', label: 'LinkedIn',        hint: '↗',            action: function () { window.open('https://www.linkedin.com/in/chrislrose', '_blank'); } },
    { section: 'External', label: 'Email Chris',     hint: '↗',            action: function () { window.location.href = 'mailto:crose@aseva.com'; } },
    { section: 'External', label: 'Phone',           hint: '↗',            action: function () { window.location.href = 'tel:+18058846368'; } },
  ];

  var filtered  = ALL_COMMANDS.slice();
  var activeIdx = -1;

  // ── Render ───────────────────────────────────────────────────
  function render(commands) {
    filtered  = commands;
    activeIdx = -1;
    results.innerHTML = '';

    if (!commands.length) {
      var empty = document.createElement('div');
      empty.className = 'cmd-section-label';
      empty.textContent = 'No results';
      results.appendChild(empty);
      return;
    }

    var sections = {};
    commands.forEach(function (cmd) {
      if (!sections[cmd.section]) sections[cmd.section] = [];
      sections[cmd.section].push(cmd);
    });

    var flatIdx = 0;
    Object.keys(sections).forEach(function (sec) {
      var label = document.createElement('div');
      label.className = 'cmd-section-label';
      label.textContent = sec;
      results.appendChild(label);

      sections[sec].forEach(function (cmd) {
        var item = document.createElement('div');
        item.className = 'cmd-item';
        item.setAttribute('role', 'option');
        item.dataset.idx = flatIdx;

        // Icon
        var icon = document.createElement('span');
        icon.className = 'cmd-item-icon';
        icon.innerHTML = getIcon(cmd.section, cmd.label);

        var lbl = document.createElement('span');
        lbl.className = 'cmd-item-label';
        lbl.textContent = cmd.label;

        item.appendChild(icon);
        item.appendChild(lbl);

        if (cmd.hint) {
          var hint = document.createElement('span');
          hint.className = 'cmd-item-hint';
          hint.textContent = cmd.hint;
          item.appendChild(hint);
        }

        (function (c) {
          item.addEventListener('mousedown', function (e) {
            e.preventDefault();
            c.action();
            close();
          });
        }(cmd));

        results.appendChild(item);
        flatIdx++;
      });
    });
  }

  function setActive(idx) {
    var items = results.querySelectorAll('.cmd-item');
    items.forEach(function (el) { el.removeAttribute('aria-selected'); });
    if (idx >= 0 && idx < items.length) {
      items[idx].setAttribute('aria-selected', 'true');
      items[idx].scrollIntoView({ block: 'nearest' });
    }
    activeIdx = idx;
  }

  // ── Open / close ─────────────────────────────────────────────
  function open() {
    overlay.removeAttribute('hidden');
    input.value = '';
    render(ALL_COMMANDS);
    setTimeout(function () { input.focus(); }, 40);
    activeIdx = -1;
  }

  function close() {
    overlay.setAttribute('hidden', '');
    input.blur();
  }

  // ── Event listeners ──────────────────────────────────────────
  document.addEventListener('keydown', function (e) {
    // Open shortcut
    if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
      e.preventDefault();
      overlay.hasAttribute('hidden') ? open() : close();
      return;
    }

    if (overlay.hasAttribute('hidden')) return;

    if (e.key === 'Escape')    { e.preventDefault(); close(); }
    if (e.key === 'ArrowDown') { e.preventDefault(); setActive(Math.min(activeIdx + 1, filtered.length - 1)); }
    if (e.key === 'ArrowUp')   { e.preventDefault(); setActive(Math.max(activeIdx - 1, 0)); }
    if (e.key === 'Enter' && activeIdx >= 0) {
      e.preventDefault();
      filtered[activeIdx].action();
      close();
    }
  });

  if (backdrop) backdrop.addEventListener('click', close);
  if (trigger)  trigger.addEventListener('click', open);

  input.addEventListener('input', function () {
    var q = input.value.toLowerCase().trim();
    if (!q) { render(ALL_COMMANDS); return; }
    render(ALL_COMMANDS.filter(function (c) {
      return c.label.toLowerCase().indexOf(q) !== -1 ||
             c.section.toLowerCase().indexOf(q) !== -1;
    }));
  });

  // ── Icons (inline SVG, minimal) ──────────────────────────────
  function getIcon(section, label) {
    if (section === 'Navigate') {
      return '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>';
    }
    if (section === 'Jump to') {
      return '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="4" y1="6" x2="20" y2="6"/><line x1="4" y1="12" x2="14" y2="12"/><line x1="4" y1="18" x2="11" y2="18"/></svg>';
    }
    if (label === 'LinkedIn') {
      return '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 8a6 6 0 0 1 6 6v7h-4v-7a2 2 0 0 0-2-2 2 2 0 0 0-2 2v7h-4v-7a6 6 0 0 1 6-6z"/><rect x="2" y="9" width="4" height="12"/><circle cx="4" cy="4" r="2"/></svg>';
    }
    if (label === 'Email Chris') {
      return '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/></svg>';
    }
    return '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>';
  }
}());
