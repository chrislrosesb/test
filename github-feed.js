/*!
 * github-feed.js — Live GitHub public activity feed
 * Fetches recent public events for chrislrose and renders them with a skeleton loader.
 * Loaded only on index.html.
 */
(function () {
  'use strict';

  var feedEl = document.getElementById('github-feed');
  if (!feedEl) return;

  var USERNAME = 'chrislrose';
  var API_URL  = 'https://api.github.com/users/' + USERNAME + '/events/public?per_page=30';

  // ── Helpers ──────────────────────────────────────────────────
  function timeAgo(dateStr) {
    var then = new Date(dateStr).getTime();
    var s    = Math.floor((Date.now() - then) / 1000);
    if (s < 60)    return s + 's ago';
    if (s < 3600)  return Math.floor(s / 60) + 'm ago';
    if (s < 86400) return Math.floor(s / 3600) + 'h ago';
    return Math.floor(s / 86400) + 'd ago';
  }

  function getDescription(event) {
    switch (event.type) {
      case 'PushEvent': {
        var commits = event.payload.commits || [];
        var msg = commits[0] ? commits[0].message.split('\n')[0] : '';
        return commits.length + ' commit' + (commits.length !== 1 ? 's' : '') +
               (msg ? ' · ' + msg.slice(0, 60) + (msg.length > 60 ? '…' : '') : '');
      }
      case 'CreateEvent':
        return 'Created ' + (event.payload.ref_type || 'repository') +
               (event.payload.ref ? ' ' + event.payload.ref : '');
      case 'PullRequestEvent':
        return (event.payload.action || 'Updated') + ' pull request' +
               (event.payload.pull_request ? ' · ' + event.payload.pull_request.title.slice(0, 55) : '');
      case 'IssuesEvent':
        return (event.payload.action || 'Updated') + ' issue' +
               (event.payload.issue ? ' · ' + event.payload.issue.title.slice(0, 55) : '');
      case 'WatchEvent':   return 'Starred repository';
      case 'ForkEvent':    return 'Forked repository';
      case 'ReleaseEvent': return 'Published a release';
      default:
        return event.type.replace('Event', '').replace(/([A-Z])/g, ' $1').trim();
    }
  }

  function getIcon(type) {
    var icons = {
      PushEvent:        '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>',
      CreateEvent:      '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>',
      PullRequestEvent: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="18" cy="18" r="3"/><circle cx="6" cy="6" r="3"/><path d="M13 6h3a2 2 0 0 1 2 2v7"/><line x1="6" y1="9" x2="6" y2="21"/></svg>',
      ForkEvent:        '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="18" r="3"/><circle cx="6" cy="6" r="3"/><circle cx="18" cy="6" r="3"/><path d="M18 9v1a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2V9"/><line x1="12" y1="12" x2="12" y2="15"/></svg>',
    };
    return icons[type] || '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.07 4.93a10 10 0 0 1 0 14.14M4.93 4.93a10 10 0 0 0 0 14.14"/></svg>';
  }

  // ── Render functions ─────────────────────────────────────────
  function renderEvents(events) {
    var PRIORITY = ['PushEvent', 'CreateEvent', 'PullRequestEvent', 'IssuesEvent', 'ForkEvent'];
    var shown = events
      .filter(function (e) { return PRIORITY.indexOf(e.type) !== -1; })
      .slice(0, 5);

    if (!shown.length) shown = events.slice(0, 5);

    if (!shown.length) {
      renderError('No recent public activity found.');
      return;
    }

    feedEl.innerHTML = '';

    shown.forEach(function (event) {
      var el = document.createElement('div');
      el.className = 'github-event anim-fade-up';
      el.innerHTML =
        '<div class="github-event-icon">' + getIcon(event.type) + '</div>' +
        '<div class="github-event-body">' +
          '<div class="github-event-repo">' + escHtml(event.repo.name) + '</div>' +
          '<div class="github-event-desc">' + escHtml(getDescription(event)) + '</div>' +
        '</div>' +
        '<div class="github-event-time">' + timeAgo(event.created_at) + '</div>';
      feedEl.appendChild(el);
    });

    // Re-trigger ScrollTrigger for newly injected elements
    if (typeof ScrollTrigger !== 'undefined') {
      ScrollTrigger.refresh();
    }
  }

  function renderError(msg) {
    feedEl.innerHTML =
      '<div class="github-feed-error">' +
        (msg || 'GitHub activity unavailable.') + ' ' +
        '<a href="https://github.com/' + USERNAME + '" target="_blank" rel="noopener">View on GitHub →</a>' +
      '</div>';
  }

  function escHtml(str) {
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  // ── Fetch with timeout ───────────────────────────────────────
  var controller = (typeof AbortController !== 'undefined') ? new AbortController() : null;
  var timeout    = controller ? setTimeout(function () { controller.abort(); }, 7000) : null;

  var fetchOpts  = controller ? { signal: controller.signal } : {};

  fetch(API_URL, fetchOpts)
    .then(function (res) {
      if (timeout) clearTimeout(timeout);
      if (!res.ok) throw new Error('HTTP ' + res.status);
      return res.json();
    })
    .then(renderEvents)
    .catch(function (err) {
      if (timeout) clearTimeout(timeout);
      console.warn('[github-feed] Failed to load:', err.message);
      renderError();
    });
}());
