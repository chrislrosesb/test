/*!
 * animations.js — Apple / Linear motion layer for chrisrose.com
 * No dependencies. Respects prefers-reduced-motion.
 */
(function () {
  'use strict';

  var motionOK = !window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var isMobile = window.innerWidth <= 700;

  /* ── 1. Page-load progress bar ──────────────────────────────────
   * Thin accent line across the top that fills on load.             */
  var bar = document.createElement('div');
  bar.id = 'page-progress';
  document.body.prepend(bar);

  window.addEventListener('load', function () {
    bar.style.width = '100%';
    setTimeout(function () { bar.style.opacity = '0'; }, 900);
  });

  /* ── 2. Cursor spotlight ────────────────────────────────────────
   * Updates CSS custom properties used by body::after gradient.    */
  if (motionOK && !isMobile) {
    document.addEventListener('mousemove', function (e) {
      document.documentElement.style.setProperty('--cursor-x', e.clientX + 'px');
      document.documentElement.style.setProperty('--cursor-y', e.clientY + 'px');
    });
  }

  /* ── 3. Nav: hide on scroll-down, reveal on scroll-up ──────────
   * Classic Apple / Linear UX pattern.                             */
  var nav = document.querySelector('nav');
  if (nav) {
    var prevScroll = 0;
    window.addEventListener('scroll', function () {
      var y = window.scrollY;
      if (y > prevScroll && y > 80) {
        nav.classList.add('nav-hidden');
      } else {
        nav.classList.remove('nav-hidden');
      }
      prevScroll = y < 0 ? 0 : y;
    }, { passive: true });
  }

  /* ── Helper: run fn when DOM is ready ──────────────────────────── */
  function onReady(fn) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', fn);
    } else {
      fn();
    }
  }

  onReady(function () {

    /* ── 4. Hero entrance sequence ────────────────────────────────
     * Staggered fade-up: eyebrow → h1 word-by-word → p → btns → photo */
    var h1 = document.querySelector('.hero h1');
    if (h1 && motionOK) {
      var eyebrow = document.querySelector('.hero-eyebrow');
      var heroP   = document.querySelector('.hero-text > p');
      var btns    = Array.prototype.slice.call(document.querySelectorAll('.hero-cta .btn'));
      var photo   = document.querySelector('.hero-photo');

      /* Split h1 into per-word spans, preserving <br> tags */
      h1.innerHTML = h1.innerHTML
        .split(/(<br\s*\/?>)/gi)
        .map(function (chunk) {
          if (/<br/i.test(chunk)) return chunk;
          return chunk.trim().split(/\s+/).filter(Boolean)
            .map(function (w) { return '<span class="hero-word">' + w + '</span>'; })
            .join(' ');
        })
        .join('');

      var words = Array.prototype.slice.call(h1.querySelectorAll('.hero-word'));
      var seq   = [eyebrow].concat(words, [heroP], btns, [photo]).filter(Boolean);

      /* Hide all elements initially */
      seq.forEach(function (el) {
        el.style.opacity    = '0';
        el.style.transform  = 'translateY(20px)';
        el.style.transition = 'opacity .65s cubic-bezier(.16,1,.3,1), transform .65s cubic-bezier(.16,1,.3,1)';
        el.style.willChange = 'opacity, transform';
      });

      /* Reveal each element on a staggered timer */
      var t = 60;
      seq.forEach(function (el) {
        (function (el, delay) {
          setTimeout(function () {
            el.style.opacity   = '1';
            el.style.transform = 'translateY(0)';
          }, delay);
        }(el, t));

        if (el === eyebrow)                           t += 130;
        else if (el.classList.contains('hero-word'))  t += 42;
        else if (el === heroP)                        t += 110;
        else                                          t += 90;
      });
    }

    /* ── 5. Scroll-triggered section reveals ─────────────────────
     * IntersectionObserver fades-up content as user scrolls in.   */
    if (motionOK && 'IntersectionObserver' in window) {
      var revealSelector = [
        '.section-header',
        '.card',
        '.contact-link',
        '.contact-form',
        '.about-photo-wrap',
      ].join(', ');

      var revealTargets = document.querySelectorAll(revealSelector);

      Array.prototype.forEach.call(revealTargets, function (el) {
        /* Skip anything already animated in the hero */
        if (el.closest && el.closest('.hero')) return;

        /* Stagger cards that share the same grid parent */
        if (el.classList.contains('card')) {
          var siblings = Array.prototype.slice.call(
            el.parentElement.querySelectorAll('.card')
          );
          el.style.transitionDelay = (siblings.indexOf(el) * 90) + 'ms';
        }

        el.classList.add('reveal');
      });

      var observer = new IntersectionObserver(function (entries, obs) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add('visible');
            obs.unobserve(entry.target);
          }
        });
      }, { threshold: 0.1, rootMargin: '0px 0px -30px 0px' });

      Array.prototype.forEach.call(
        document.querySelectorAll('.reveal'),
        function (el) { observer.observe(el); }
      );
    }

    /* ── 6. Card 3-D tilt on hover ───────────────────────────────
     * Subtle perspective tilt that follows the mouse — tactile,    *
     * purposeful, never dizzying.                                  */
    if (motionOK && !isMobile) {
      Array.prototype.forEach.call(document.querySelectorAll('.card'), function (card) {
        card.addEventListener('mousemove', function (e) {
          var r = card.getBoundingClientRect();
          var x = (e.clientX - r.left)  / r.width  - 0.5;
          var y = (e.clientY - r.top)   / r.height - 0.5;
          card.style.transform  = 'translateY(-4px) rotateX(' + (-y * 5) + 'deg) rotateY(' + (x * 5) + 'deg)';
          card.style.transition = 'transform .08s linear, box-shadow var(--transition), border-color var(--transition)';
        });

        card.addEventListener('mouseleave', function () {
          card.style.transform  = '';
          card.style.transition = 'transform .5s cubic-bezier(.16,1,.3,1), box-shadow var(--transition), border-color var(--transition)';
        });
      });
    }

    /* ── 7. Hero photo ring pulse ─────────────────────────────────
     * Slow, breathing box-shadow animation on the circular photo.  */
    var heroPhoto = document.querySelector('.hero-photo .photo-placeholder');
    if (heroPhoto && motionOK) {
      heroPhoto.classList.add('photo-ring-pulse');
    }

  }); /* end onReady */

}());
