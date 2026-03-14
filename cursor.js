/*!
 * cursor.js — Custom dual-ring cursor
 * Small dot follows mouse exactly; larger ring follows with lerp.
 * Ring morphs on hover over interactive elements.
 * Disabled entirely on touch/mobile devices.
 */
(function () {
  'use strict';

  var isMobile = window.matchMedia('(hover: none)').matches;
  var motionOK = !window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  if (isMobile) return;

  var dot  = document.createElement('div'); dot.id  = 'cursor-dot';
  var ring = document.createElement('div'); ring.id = 'cursor-ring';
  document.body.append(dot, ring);

  var mx = -200, my = -200;
  var rx = -200, ry = -200;
  var isHover   = false;
  var DOT_R     = 4;   // half of 8px dot
  var RING_R    = 14;  // half of 28px ring
  var RING_R_H  = 22;  // half of 44px ring on hover
  var LERP      = 0.12;

  // Update dot instantly on mousemove
  document.addEventListener('mousemove', function (e) {
    mx = e.clientX;
    my = e.clientY;
    dot.style.transform = 'translate(' + (mx - DOT_R) + 'px, ' + (my - DOT_R) + 'px)';
  }, { passive: true });

  // Lerp ring position each frame
  function lerp(a, b, t) { return a + (b - a) * t; }

  function animateRing() {
    rx = lerp(rx, mx, LERP);
    ry = lerp(ry, my, LERP);
    var offset = isHover ? RING_R_H : RING_R;
    ring.style.transform = 'translate(' + (rx - offset) + 'px, ' + (ry - offset) + 'px)';
    requestAnimationFrame(animateRing);
  }

  if (motionOK) {
    animateRing();
  } else {
    // No lerp in reduced-motion: just snap ring to cursor
    document.addEventListener('mousemove', function (e) {
      var offset = isHover ? RING_R_H : RING_R;
      ring.style.transform = 'translate(' + (e.clientX - offset) + 'px, ' + (e.clientY - offset) + 'px)';
    }, { passive: true });
  }

  // Morph ring on interactive elements
  var INTERACTIVES = 'a, button, [role="button"], input, textarea, select, label, .nav-action-btn, .card, .bento-cell, .skill-pill, .vendor-tag, .contact-link, .cmd-item';

  document.addEventListener('mouseover', function (e) {
    if (e.target.closest(INTERACTIVES)) {
      ring.classList.add('cursor-hover');
      isHover = true;
    }
  });

  document.addEventListener('mouseout', function (e) {
    if (e.target.closest(INTERACTIVES)) {
      ring.classList.remove('cursor-hover');
      isHover = false;
    }
  });

  // Hide on window leave, show on re-enter
  document.addEventListener('mouseleave', function () {
    dot.style.opacity  = '0';
    ring.style.opacity = '0';
  });

  document.addEventListener('mouseenter', function () {
    dot.style.opacity  = '1';
    ring.style.opacity = '0.55';
  });
}());
