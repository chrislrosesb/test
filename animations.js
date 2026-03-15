/*!
 * animations.js — Full GSAP motion layer for chrisrose.com
 * Requires: gsap.min.js + ScrollTrigger.min.js (loaded before this script)
 * Respects prefers-reduced-motion.
 */
(function () {
  'use strict';

  // Remove no-js guard immediately so content is never invisible without JS
  document.documentElement.classList.remove('no-js');

  // Register ScrollTrigger plugin
  gsap.registerPlugin(ScrollTrigger);

  var motionOK = !window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var isMobile = window.matchMedia('(hover: none)').matches;

  // If motion is disabled, make all animation targets visible and exit early
  if (!motionOK) {
    gsap.set([
      '.anim-fade-up', '.hero-eyebrow', '.hero-word',
      '.hero-text > p', '.hero-cta', '.hero-photo'
    ], { opacity: 1, y: 0, x: 0, scale: 1 });
    initNavEnhancements();
    // Still init typewriter (it shows static text when motion disabled)
    (function initTypewriterStatic() {
      var container = document.querySelector('.hero-typewriter');
      if (!container) return;
      var textEl = document.getElementById('typewriter-text');
      if (!textEl) return;
      var phrasesRaw = container.getAttribute('data-phrases');
      try {
        var phrases = phrasesRaw ? JSON.parse(phrasesRaw) : [];
        if (phrases.length) textEl.textContent = phrases[0];
      } catch (e) {}
    }());
    return;
  }

  /* ── 1. Page-load progress bar ───────────────────────────────── */
  var bar = document.createElement('div');
  bar.id = 'page-progress';
  document.body.prepend(bar);

  window.addEventListener('load', function () {
    bar.style.width = '100%';
    setTimeout(function () { bar.style.opacity = '0'; }, 900);
  });

  /* ── 2. Cursor spotlight ─────────────────────────────────────── */
  if (!isMobile) {
    document.addEventListener('mousemove', function (e) {
      document.documentElement.style.setProperty('--cursor-x', e.clientX + 'px');
      document.documentElement.style.setProperty('--cursor-y', e.clientY + 'px');
    });
  }

  /* ── 3. Nav enhancements ─────────────────────────────────────── */
  function initNavEnhancements() {
    var nav = document.querySelector('nav');
    if (!nav) return;

    // Hide/reveal on scroll + scrolled state
    var prevScroll = 0;
    window.addEventListener('scroll', function () {
      var y = window.scrollY;
      if (y > prevScroll && y > 80) {
        nav.classList.add('nav-hidden');
      } else {
        nav.classList.remove('nav-hidden');
      }
      nav.classList.toggle('scrolled', y > 20);
      prevScroll = y < 0 ? 0 : y;
    }, { passive: true });

    // Sliding pill indicator (desktop only)
    var navLinks = document.querySelector('.nav-links');
    if (!navLinks || isMobile) return;

    var indicator = document.createElement('div');
    indicator.className = 'nav-indicator';
    navLinks.appendChild(indicator);

    var activeLink = navLinks.querySelector('a.active');
    if (activeLink) {
      var activeLi = activeLink.closest('li');
      indicator.style.left  = activeLi.offsetLeft + 'px';
      indicator.style.width = activeLi.offsetWidth + 'px';
    }

    navLinks.querySelectorAll('li').forEach(function (li) {
      li.addEventListener('mouseenter', function () {
        indicator.style.left  = li.offsetLeft + 'px';
        indicator.style.width = li.offsetWidth + 'px';
      });
    });

    navLinks.addEventListener('mouseleave', function () {
      var active = navLinks.querySelector('a.active');
      if (active) {
        var li = active.closest('li');
        indicator.style.left  = li.offsetLeft + 'px';
        indicator.style.width = li.offsetWidth + 'px';
      }
    });
  }

  initNavEnhancements();

  /* ── 4. Hero entrance sequence ───────────────────────────────── */
  function initHeroAnimation() {
    var h1 = document.querySelector('.hero h1');
    if (!h1) return;

    // Split h1 into per-word spans (works on plain text h1, preserves <br>)
    h1.innerHTML = h1.innerHTML
      .split(/(<br\s*\/?>)/gi)
      .map(function (chunk) {
        if (/<br/i.test(chunk)) return chunk;
        return chunk.trim().split(/\s+/).filter(Boolean)
          .map(function (w) { return '<span class="hero-word">' + w + '</span>'; })
          .join(' ');
      })
      .join('');

    var heroWords   = document.querySelectorAll('.hero-word');
    var heroEyebrow = document.querySelector('.hero-eyebrow');
    var heroP       = document.querySelector('.hero-text > p');
    var heroCta     = document.querySelector('.hero-cta');
    var heroPhoto   = document.querySelector('.hero-photo');

    if (!heroWords.length) return;

    var tl = gsap.timeline({ defaults: { ease: 'power3.out' } });

    tl
      // Eyebrow badge appears first — establishes context
      .from(heroEyebrow, { opacity: 0, y: 12, duration: 0.55, delay: 0.1 })
      // Headline words tip forward as they rise — the signature cinematic move
      .from(heroWords, {
        opacity: 0,
        y: 28,
        rotationX: 6,
        duration: 0.65,
        stagger: 0.09,
        transformOrigin: '0% 50%'
      }, '-=0.2')
      // Body paragraph
      .from(heroP, { opacity: 0, y: 16, duration: 0.5 }, '-=0.25')
      // CTA buttons
      .from(heroCta, { opacity: 0, y: 14, duration: 0.45 }, '-=0.2');

    // Photo glides in from the right on a parallel track
    if (heroPhoto) {
      tl.from(heroPhoto, {
        opacity: 0,
        x: 24,
        scale: 0.97,
        duration: 0.7,
        ease: 'power2.out'
      }, 0.35);
    }
  }

  // If intro is active, wait for it to finish before running hero animation.
  // Otherwise (other pages, or intro already done), run on load as normal.
  if (window.introComplete) {
    initHeroAnimation();
  } else if (document.getElementById('intro-overlay') && !document.getElementById('intro-overlay').classList.contains('intro-hidden')) {
    window.addEventListener('intro-done', function () {
      initHeroAnimation();
    }, { once: true });
  } else {
    window.addEventListener('load', initHeroAnimation);
  }

  /* ── Helper: run fn when DOM is ready ──────────────────────── */
  function onReady(fn) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', fn);
    } else {
      fn();
    }
  }

  /* ── 3b. Scroll progress bar ────────────────────────────────── */
  var scrollBar = document.createElement('div');
  scrollBar.id = 'scroll-progress';
  document.body.prepend(scrollBar);

  window.addEventListener('scroll', function () {
    var scrollTop  = window.scrollY || document.documentElement.scrollTop;
    var docHeight  = document.documentElement.scrollHeight - window.innerHeight;
    var pct        = docHeight > 0 ? (scrollTop / docHeight) * 100 : 0;
    scrollBar.style.width = pct + '%';
  }, { passive: true });

  /* ── 3c. Typewriter cycling text ────────────────────────────── */
  function initTypewriter() {
    var container = document.querySelector('.hero-typewriter');
    if (!container) return;
    var textEl = document.getElementById('typewriter-text');
    if (!textEl) return;

    var phrasesRaw = container.getAttribute('data-phrases');
    var phrases    = phrasesRaw ? JSON.parse(phrasesRaw) : [];
    if (!phrases.length) return;

    if (!motionOK) {
      textEl.textContent = phrases[0];
      return;
    }

    var idx = 0, charIdx = 0, deleting = false;
    var TYPING_SPEED = 75, DELETE_SPEED = 40, PAUSE_AFTER = 2400, PAUSE_BEFORE = 350;

    function tick() {
      var current = phrases[idx];
      if (!deleting) {
        charIdx++;
        textEl.textContent = current.slice(0, charIdx);
        if (charIdx === current.length) {
          deleting = true;
          setTimeout(tick, PAUSE_AFTER);
          return;
        }
        setTimeout(tick, TYPING_SPEED);
      } else {
        charIdx--;
        textEl.textContent = current.slice(0, charIdx);
        if (charIdx === 0) {
          deleting = false;
          idx = (idx + 1) % phrases.length;
          setTimeout(tick, PAUSE_BEFORE);
          return;
        }
        setTimeout(tick, DELETE_SPEED);
      }
    }
    setTimeout(tick, 1300);
  }

  // Delay typewriter start until after intro (if present)
  if (window.introComplete) {
    initTypewriter();
  } else if (document.getElementById('intro-overlay') && !document.getElementById('intro-overlay').classList.contains('intro-hidden')) {
    window.addEventListener('intro-done', function () {
      initTypewriter();
    }, { once: true });
  } else {
    initTypewriter();
  }

  /* ── 3d. Page transitions ────────────────────────────────────── */
  function initPageTransitions() {
    var overlay = document.createElement('div');
    overlay.id  = 'page-transition-overlay';
    document.body.prepend(overlay);

    // Animate page IN (overlay fades out on load)
    gsap.to(overlay, {
      opacity: 0,
      duration: 0.4,
      ease: 'power2.out',
      onComplete: function () { overlay.style.pointerEvents = 'none'; }
    });

    // Expose for command palette
    window.pageTransitionTo = function (href) {
      overlay.style.pointerEvents = 'all';
      gsap.to(overlay, {
        opacity: 1,
        duration: 0.28,
        ease: 'power2.in',
        onComplete: function () { window.location.href = href; }
      });
    };

    // Intercept nav + internal links
    document.querySelectorAll('a[href]').forEach(function (link) {
      var href = link.getAttribute('href');
      if (!href || href.charAt(0) === '#' || href.indexOf('mailto:') === 0 ||
          href.indexOf('tel:') === 0 || link.target === '_blank') return;
      if (href.indexOf('http') === 0 && href.indexOf(window.location.origin) !== 0) return;
      link.addEventListener('click', function (e) {
        e.preventDefault();
        window.pageTransitionTo(link.href);
      });
    });
  }
  initPageTransitions();

  onReady(function () {

    /* ── 5. Scroll reveal system ───────────────────────────────── */
    if (document.querySelectorAll('.anim-fade-up').length) {
      // GSAP owns the initial hidden state — never CSS — so content is always
      // visible if GSAP fails to load or ScrollTrigger doesn't fire.
      gsap.set('.anim-fade-up', { opacity: 0, y: 32 });

      ScrollTrigger.batch('.anim-fade-up', {
        onEnter: function (elements) {
          gsap.to(elements, {
            opacity: 1,
            y: 0,
            duration: 0.65,
            stagger: 0.08,
            ease: 'power3.out',
            overwrite: true,
            onComplete: function () {
              elements.forEach(function (el) {
                el.style.willChange = 'auto';
              });
            }
          });
        },
        start: 'top 88%',
        once: true
      });
    }

    /* ── 6. Card parallax tilt ─────────────────────────────────── */
    if (!isMobile) {
      document.querySelectorAll('.card').forEach(function (card) {
        card.addEventListener('mousemove', function (e) {
          var rect = card.getBoundingClientRect();
          var x    = (e.clientX - rect.left) / rect.width  - 0.5;
          var y    = (e.clientY - rect.top)  / rect.height - 0.5;

          gsap.to(card, {
            rotateX: -y * 3,
            rotateY:  x * 3,
            boxShadow:
              (x * 12) + 'px ' + (y * 10 + 8) + 'px 32px rgba(0,0,0,0.6), ' +
              '0 0 40px rgba(88,166,255,' + (0.04 + Math.abs(x) * 0.06) + ')',
            duration: 0.3,
            ease: 'power1.out',
            transformPerspective: 800,
            transformOrigin: 'center center'
          });
        });

        card.addEventListener('mouseleave', function () {
          gsap.to(card, {
            rotateX: 0,
            rotateY: 0,
            boxShadow: 'var(--shadow-sm)',
            duration: 0.4,
            ease: 'power2.out'
          });
        });
      });
    }

    /* ── 7. Bento cell cascade animation ───────────────────────── */
    if (document.querySelectorAll('.bento-cell').length) {
      gsap.set('.bento-cell', { opacity: 0, y: 20, scale: 0.96 });

      ScrollTrigger.batch('.bento-cell', {
        onEnter: function (elements) {
          gsap.to(elements, {
            opacity: 1,
            y: 0,
            scale: 1,
            duration: 0.45,
            stagger: 0.04,
            ease: 'power2.out',
            overwrite: true
          });
        },
        start: 'top 90%',
        once: true
      });
    }

    /* ── 8. Hero photo ring pulse ──────────────────────────────── */
    var heroPhoto = document.querySelector('.hero-photo .photo-placeholder');
    if (heroPhoto) {
      heroPhoto.classList.add('photo-ring-pulse');
    }

    /* ── 9. Achievement counters ───────────────────────────────── */
    (function initAchievementCounters() {
      var counterEls = document.querySelectorAll('.achievement-number[data-counter-to]');
      if (!counterEls.length) return;

      if (!motionOK) {
        counterEls.forEach(function (el) {
          el.textContent = el.getAttribute('data-counter-to') + (el.getAttribute('data-counter-suffix') || '');
        });
        return;
      }

      counterEls.forEach(function (el) {
        var target = parseInt(el.getAttribute('data-counter-to'), 10);
        var suffix = el.getAttribute('data-counter-suffix') || '';
        var obj    = { val: 0 };

        ScrollTrigger.create({
          trigger: el,
          start: 'top 88%',
          once: true,
          onEnter: function () {
            gsap.to(obj, {
              val: target,
              duration: 1.6,
              ease: 'power2.out',
              onUpdate: function () {
                el.textContent = Math.round(obj.val) + suffix;
              },
              onComplete: function () {
                el.textContent = target + suffix;
              }
            });
          }
        });
      });
    }());

  }); /* end onReady */

}());
