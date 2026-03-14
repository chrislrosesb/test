/*!
 * easter-egg.js — Matrix / Konami code easter egg
 * Type "matrix" anywhere on the page (not in an input) to toggle matrix rain.
 * Konami code (↑↑↓↓←→←→BA) also works.
 * Accent-colored falling Katakana characters.
 */
(function () {
  'use strict';

  var SEQUENCE = 'matrix';
  var KONAMI   = [38, 38, 40, 40, 37, 39, 37, 39, 66, 65];

  var typed      = '';
  var konamiIdx  = 0;
  var active     = false;
  var matCanvas  = null;
  var matRaf     = null;
  var matDrops   = [];

  function getAccentColor() {
    return getComputedStyle(document.documentElement)
             .getPropertyValue('--color-accent').trim() || '#58a6ff';
  }

  // ── Glitch flash ─────────────────────────────────────────────
  function glitch() {
    var motionOK = !window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (!motionOK) return;
    document.body.classList.add('glitch-active');
    setTimeout(function () { document.body.classList.remove('glitch-active'); }, 360);
  }

  // ── Matrix canvas ─────────────────────────────────────────────
  function startMatrix() {
    if (!matCanvas) {
      matCanvas = document.createElement('canvas');
      matCanvas.id = 'matrix-canvas';
      document.body.appendChild(matCanvas);
    }

    var ctx = matCanvas.getContext('2d');
    matCanvas.width  = window.innerWidth;
    matCanvas.height = window.innerHeight;
    matCanvas.classList.add('active');

    var cols   = Math.floor(window.innerWidth / 16);
    matDrops   = Array(cols).fill(1);
    var color  = getAccentColor();

    function draw() {
      ctx.fillStyle = 'rgba(13,17,23,0.05)';
      ctx.fillRect(0, 0, matCanvas.width, matCanvas.height);

      ctx.fillStyle = color;
      ctx.font      = '14px "JetBrains Mono", monospace';

      for (var i = 0; i < matDrops.length; i++) {
        var char = String.fromCharCode(0x30A0 + Math.floor(Math.random() * 96));
        ctx.fillText(char, i * 16, matDrops[i] * 16);
        if (matDrops[i] * 16 > matCanvas.height && Math.random() > 0.975) {
          matDrops[i] = 0;
        }
        matDrops[i]++;
      }

      matRaf = requestAnimationFrame(draw);
    }

    draw();
  }

  function stopMatrix() {
    if (matRaf) { cancelAnimationFrame(matRaf); matRaf = null; }
    if (matCanvas) {
      matCanvas.classList.remove('active');
      // Clear the canvas
      var ctx = matCanvas.getContext('2d');
      ctx.clearRect(0, 0, matCanvas.width, matCanvas.height);
    }
  }

  // ── Toggle ────────────────────────────────────────────────────
  function activate() {
    active = true;
    glitch();
    setTimeout(startMatrix, 380);
  }

  function deactivate() {
    active = false;
    glitch();
    setTimeout(stopMatrix, 200);
  }

  function toggle() {
    active ? deactivate() : activate();
  }

  // ── Keyboard listener ─────────────────────────────────────────
  document.addEventListener('keydown', function (e) {
    // Don't trigger while typing in form fields
    var tag = e.target.tagName;
    if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return;
    if (e.target.isContentEditable) return;

    // Konami code check
    if (e.keyCode === KONAMI[konamiIdx]) {
      konamiIdx++;
      if (konamiIdx === KONAMI.length) {
        toggle();
        konamiIdx = 0;
      }
    } else {
      konamiIdx = (e.keyCode === KONAMI[0]) ? 1 : 0;
    }

    // "matrix" typed sequence
    if (e.key && e.key.length === 1) {
      typed += e.key.toLowerCase();
      if (typed.length > SEQUENCE.length) {
        typed = typed.slice(-SEQUENCE.length);
      }
      if (typed === SEQUENCE) {
        toggle();
        typed = '';
      }
    }
  });
}());
