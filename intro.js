/*!
 * intro.js — Animated intro: Classic Mac '84 boot → Matrix pill choice → site reveal
 * Requires: gsap.min.js (loaded before this script)
 * ~5 second sequence. Always plays with skip support. Respects prefers-reduced-motion.
 */
(function () {
  'use strict';

  // ── Guard: reduced motion → skip entirely ──────────────────
  var motionOK = !window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (!motionOK) {
    var overlay = document.getElementById('intro-overlay');
    if (overlay) overlay.remove();
    document.body.classList.remove('intro-active');
    window.introComplete = true;
    window.dispatchEvent(new CustomEvent('intro-done'));
    return;
  }

  // ── State ──────────────────────────────────────────────────
  var skipped = false;
  var finished = false;
  var tl = null; // master GSAP timeline

  // ── DOM refs ───────────────────────────────────────────────
  var overlay       = document.getElementById('intro-overlay');
  if (!overlay) return;

  var happyMac      = overlay.querySelector('.intro-happy-mac');
  var helloSvg      = overlay.querySelector('.intro-hello-svg');
  var wakeText      = overlay.querySelector('.intro-wake-text');
  var pills         = overlay.querySelector('.intro-pills');
  var pillRed       = overlay.querySelector('.intro-pill--red');
  var pillBlue      = overlay.querySelector('.intro-pill--blue');
  var skipEl        = overlay.querySelector('.intro-skip');
  var matrixCanvas  = document.getElementById('intro-matrix-canvas');
  var glitchFlash   = overlay.querySelector('.intro-glitch-flash');

  // ── Matrix rain (intro-specific, smaller scale) ────────────
  var matCtx, matDrops, matCols, matRaf;

  function initIntroMatrix() {
    if (!matrixCanvas) return;
    matCtx = matrixCanvas.getContext('2d');
    matrixCanvas.width  = window.innerWidth;
    matrixCanvas.height = window.innerHeight;
    matCols = Math.floor(window.innerWidth / 18);
    matDrops = [];
    for (var i = 0; i < matCols; i++) {
      matDrops.push(Math.random() * -40 | 0); // stagger start positions
    }
  }

  function drawIntroMatrix() {
    matCtx.fillStyle = 'rgba(0, 0, 0, 0.06)';
    matCtx.fillRect(0, 0, matrixCanvas.width, matrixCanvas.height);

    matCtx.fillStyle = '#00ff41';
    matCtx.font = '15px "JetBrains Mono", monospace';

    for (var i = 0; i < matDrops.length; i++) {
      if (matDrops[i] > 0) {
        var char = String.fromCharCode(0x30A0 + Math.floor(Math.random() * 96));
        matCtx.fillText(char, i * 18, matDrops[i] * 18);
      }
      if (matDrops[i] * 18 > matrixCanvas.height && Math.random() > 0.975) {
        matDrops[i] = 0;
      }
      matDrops[i]++;
    }
    matRaf = requestAnimationFrame(drawIntroMatrix);
  }

  function startIntroMatrix() {
    initIntroMatrix();
    drawIntroMatrix();
  }

  function stopIntroMatrix() {
    if (matRaf) { cancelAnimationFrame(matRaf); matRaf = null; }
  }

  // ── "hello" SVG path draw animation ────────────────────────
  function animateHelloPath(duration) {
    if (!helloSvg) return;
    var paths = helloSvg.querySelectorAll('path');
    paths.forEach(function (path) {
      var len = path.getTotalLength();
      path.style.strokeDasharray  = len;
      path.style.strokeDashoffset = len;
    });

    gsap.to(helloSvg, { opacity: 1, duration: 0.01 });
    gsap.to(paths, {
      strokeDashoffset: 0,
      duration: duration || 1.2,
      ease: 'power2.inOut',
      stagger: 0.15,
      onComplete: function () {
        // Fill in after drawing
        gsap.to(paths, { fill: '#fff', duration: 0.4, ease: 'power1.in' });
      }
    });
  }

  // ── Typewriter for wake text ───────────────────────────────
  function typeText(el, text, speed, callback) {
    var i = 0;
    el.textContent = '';
    gsap.to(el, { opacity: 1, duration: 0.01 });

    function tick() {
      if (skipped) { el.textContent = text; if (callback) callback(); return; }
      i++;
      el.textContent = text.slice(0, i);
      if (i < text.length) {
        setTimeout(tick, speed);
      } else {
        if (callback) callback();
      }
    }
    tick();
  }

  // ── Finish / reveal site ───────────────────────────────────
  function finishIntro(chosenPill) {
    if (finished) return;
    finished = true;
    stopIntroMatrix();

    // If red pill was chosen, do a brief matrix rain intensify then proceed
    var exitDelay = chosenPill === 'red' ? 600 : 200;

    // Glitch flash
    if (glitchFlash) {
      gsap.to(glitchFlash, {
        opacity: 0.8,
        duration: 0.08,
        yoyo: true,
        repeat: 3,
        ease: 'steps(1)'
      });
    }

    setTimeout(function () {
      // Fade out overlay
      gsap.to(overlay, {
        opacity: 0,
        duration: 0.5,
        ease: 'power2.in',
        onComplete: function () {
          overlay.classList.add('intro-hidden');
          document.body.classList.remove('intro-active');
          window.introComplete = true;
          window.dispatchEvent(new CustomEvent('intro-done'));
        }
      });
    }, exitDelay);
  }

  // ── Skip handler ───────────────────────────────────────────
  function skip() {
    if (finished) return;
    skipped = true;
    if (tl) tl.progress(1);
    finishIntro('blue');
  }

  // Skip on any key or click/tap
  document.addEventListener('keydown', function onSkipKey(e) {
    if (!finished && !overlay.classList.contains('intro-hidden')) {
      // Don't skip if user is interacting with pills
      if (e.target.classList && e.target.classList.contains('intro-pill')) return;
      skip();
      document.removeEventListener('keydown', onSkipKey);
    }
  });

  if (skipEl) {
    skipEl.addEventListener('click', skip);
  }

  // ── Pill click handlers ────────────────────────────────────
  if (pillBlue) {
    pillBlue.addEventListener('click', function () {
      if (finished) return;
      pillBlue.classList.add('intro-pill--glow');
      finishIntro('blue');
    });
  }

  if (pillRed) {
    pillRed.addEventListener('click', function () {
      if (finished) return;
      pillRed.classList.add('intro-pill--glow');
      // Brief easter-egg: flash matrix rain green, then reveal
      if (matrixCanvas) {
        gsap.to(matrixCanvas, { opacity: 0.7, duration: 0.3 });
      }
      startIntroMatrix();
      setTimeout(function () { finishIntro('red'); }, 800);
    });
  }

  // ── Master timeline ────────────────────────────────────────
  function runIntro() {
    tl = gsap.timeline({
      onComplete: function () {
        // Auto-select blue pill after timeline finishes if user hasn't chosen
        if (!finished && !skipped) {
          setTimeout(function () {
            if (!finished) {
              if (pillBlue) pillBlue.classList.add('intro-pill--glow');
              setTimeout(function () { finishIntro('blue'); }, 700);
            }
          }, 1800);
        }
      }
    });

    // Phase 1: Classic Mac boot (~0 – 2s)
    // Happy Mac appears
    tl.to(happyMac, {
      opacity: 1,
      duration: 0.5,
      ease: 'power2.out'
    }, 0.3);

    // Small scale-in bounce for Happy Mac
    tl.from(happyMac, {
      scale: 0.7,
      duration: 0.6,
      ease: 'back.out(1.7)'
    }, 0.3);

    // "hello" draws in
    tl.call(function () {
      animateHelloPath(1.0);
    }, null, 1.0);

    // Phase 2: Matrix wake-up (~2 – 3.5s)
    // Fade out Mac elements slightly and start transition
    tl.to([happyMac], {
      opacity: 0.2,
      duration: 0.5,
      ease: 'power1.in'
    }, 2.2);

    // Hello fades to green tint
    tl.to(helloSvg ? helloSvg.querySelectorAll('path') : [], {
      stroke: '#00ff41',
      fill: '#00ff41',
      duration: 0.4,
      ease: 'power1.in'
    }, 2.2);

    // Subtle matrix rain starts in background
    tl.call(function () {
      if (matrixCanvas) {
        startIntroMatrix();
        gsap.to(matrixCanvas, { opacity: 0.15, duration: 0.6 });
      }
    }, null, 2.3);

    // Wake text types
    tl.call(function () {
      typeText(wakeText, 'Wake up, Chris...', 55);
    }, null, 2.5);

    // Phase 3: The Choice (~3.5 – 5s)
    // Hello fades out
    tl.to(helloSvg, {
      opacity: 0,
      y: -20,
      duration: 0.4,
      ease: 'power1.in'
    }, 3.5);

    // Happy Mac fades out
    tl.to(happyMac, {
      opacity: 0,
      duration: 0.3,
    }, 3.5);

    // Pills appear
    tl.to(pills, {
      opacity: 1,
      duration: 0.5,
      ease: 'power2.out'
    }, 3.8);

    tl.from(pills.children, {
      y: 20,
      opacity: 0,
      duration: 0.45,
      stagger: 0.15,
      ease: 'power2.out'
    }, 3.8);

    // Show skip text
    if (skipEl) {
      tl.to(skipEl, { opacity: 1, duration: 0.3 }, 0.8);
    }
  }

  // ── Init ───────────────────────────────────────────────────
  document.body.classList.add('intro-active');
  window.introComplete = false;

  // Wait for fonts + page to be ready
  if (document.readyState === 'complete') {
    runIntro();
  } else {
    window.addEventListener('load', runIntro);
  }

}());
