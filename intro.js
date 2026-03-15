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
    var path = helloSvg.querySelector('path');
    if (!path) return;
    var len = path.getTotalLength();
    path.style.strokeDasharray  = len;
    path.style.strokeDashoffset = len;

    gsap.to(helloSvg, { opacity: 1, duration: 0.01 });
    gsap.to(path, {
      strokeDashoffset: 0,
      duration: duration || 1.8,
      ease: 'power2.inOut'
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

  // ── Skip handler (active only before pills appear) ─────────
  var skipEnabled = true;

  function skip() {
    if (finished || !skipEnabled) return;
    skipped = true;
    if (tl) tl.progress(1);
    finishIntro('blue');
  }

  function disableSkip() {
    skipEnabled = false;
    if (skipEl) gsap.to(skipEl, { opacity: 0, duration: 0.3 });
  }

  // Skip on any key or click/tap (disabled once pills show)
  document.addEventListener('keydown', function onSkipKey(e) {
    if (!finished && !overlay.classList.contains('intro-hidden') && skipEnabled) {
      if (e.target.classList && e.target.classList.contains('intro-pill')) return;
      skip();
      document.removeEventListener('keydown', onSkipKey);
    }
  });

  if (skipEl) {
    skipEl.addEventListener('click', skip);
  }

  // ── 90s internet chaos (red pill easter egg) ──────────────
  function runChaosSequence() {
    var chaosDiv    = overlay.querySelector('.intro-chaos');
    var chaosBg     = overlay.querySelector('.intro-chaos-bg');
    var banner      = overlay.querySelector('.intro-chaos-banner');
    var visitor     = overlay.querySelector('.intro-chaos-visitor');
    var popup       = overlay.querySelector('.intro-chaos-popup');
    var marquee     = overlay.querySelector('.intro-chaos-marquee');
    var counter     = overlay.querySelector('.intro-chaos-counter');
    var exitText    = overlay.querySelector('.intro-chaos-exit');

    if (!chaosDiv) { finishIntro('red'); return; }

    // Hide current intro elements
    gsap.to([wakeText, pills], { opacity: 0, duration: 0.2 });

    // Show chaos container
    chaosDiv.style.display = 'flex';
    gsap.to(chaosBg, { opacity: 1, duration: 0.3 });

    // Stagger in the chaos elements
    gsap.to(banner,  { opacity: 1, duration: 0.01, delay: 0.3 });
    gsap.to(visitor, { opacity: 1, duration: 0.01, delay: 0.7 });
    gsap.to(popup,   { opacity: 1, duration: 0.01, delay: 1.1 });
    gsap.to(marquee, { opacity: 1, duration: 0.01, delay: 1.5 });
    gsap.to(counter, { opacity: 1, duration: 0.01, delay: 1.8 });

    // After chaos plays, show the exit message
    setTimeout(function () {
      typeText(exitText, '...you can\'t stay here. Welcome to reality.', 45, function () {
        setTimeout(function () { finishIntro('red'); }, 800);
      });
    }, 2800);
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
      runChaosSequence();
    });
  }

  // ── Master timeline ────────────────────────────────────────
  function runIntro() {
    tl = gsap.timeline();

    // Phase 1: Classic Mac boot (~0 – 3s)
    // Happy Mac appears
    tl.to(happyMac, {
      opacity: 1,
      duration: 0.6,
      ease: 'power2.out'
    }, 0.5);

    // Small scale-in bounce for Happy Mac
    tl.from(happyMac, {
      scale: 0.7,
      duration: 0.7,
      ease: 'back.out(1.7)'
    }, 0.5);

    // "hello" draws in (starts at 1.2s, takes 1.8s to draw)
    tl.call(function () {
      animateHelloPath(1.8);
    }, null, 1.2);

    // Show skip text
    if (skipEl) {
      tl.to(skipEl, { opacity: 1, duration: 0.3 }, 1.0);
    }

    // ── Pause: let "hello" breathe (~3.0 – 4.2s) ──────────

    // Phase 2: Matrix wake-up (~4.2 – 6s)
    // Fade out Mac elements slightly and start transition
    tl.to([happyMac], {
      opacity: 0.2,
      duration: 0.6,
      ease: 'power1.in'
    }, 4.2);

    // Hello stroke turns green
    tl.to(helloSvg ? helloSvg.querySelector('path') : [], {
      stroke: '#00ff41',
      duration: 0.5,
      ease: 'power1.in'
    }, 4.2);

    // Subtle matrix rain starts in background
    tl.call(function () {
      if (matrixCanvas) {
        startIntroMatrix();
        gsap.to(matrixCanvas, { opacity: 0.15, duration: 0.8 });
      }
    }, null, 4.5);

    // Wake text types
    tl.call(function () {
      typeText(wakeText, 'Wake up, Chris...', 65);
    }, null, 4.8);

    // Phase 3: The Choice (~6 – 7.5s)
    // Hello fades out
    tl.to(helloSvg, {
      opacity: 0,
      y: -20,
      duration: 0.5,
      ease: 'power1.in'
    }, 6.0);

    // Happy Mac fades out
    tl.to(happyMac, {
      opacity: 0,
      duration: 0.4,
    }, 6.0);

    // Pills appear — disable skip so user must choose
    tl.call(disableSkip, null, 6.5);

    tl.to(pills, {
      opacity: 1,
      duration: 0.6,
      ease: 'power2.out'
    }, 6.5);

    tl.from(pills.children, {
      y: 20,
      opacity: 0,
      duration: 0.5,
      stagger: 0.2,
      ease: 'power2.out'
    }, 6.5);
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
