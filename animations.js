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

  window.addEventListener('load', initHeroAnimation);

  /* ── Helper: run fn when DOM is ready ──────────────────────── */
  function onReady(fn) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', fn);
    } else {
      fn();
    }
  }

  onReady(function () {

    /* ── 5. Scroll reveal system ───────────────────────────────── */
    if (document.querySelectorAll('.anim-fade-up').length) {
      ScrollTrigger.batch('.anim-fade-up', {
        onEnter: function (elements) {
          gsap.from(elements, {
            opacity: 0,
            y: 32,
            duration: 0.65,
            stagger: 0.08,
            ease: 'power3.out',
            overwrite: true,
            onComplete: function () {
              // Release GPU compositing layer after animation completes
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
      ScrollTrigger.batch('.bento-cell', {
        onEnter: function (elements) {
          gsap.from(elements, {
            opacity: 0,
            y: 20,
            scale: 0.96,
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

  }); /* end onReady */

}());
