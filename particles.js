/*!
 * particles.js — Interactive constellation particle background
 * Replaces the static CSS gradient mesh with a canvas-based particle system.
 * Particles drift, connect with lines when close, and gently repel from the mouse.
 * Respects prefers-reduced-motion (exits early → CSS gradient remains).
 */
(function () {
  'use strict';

  var motionOK = !window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (!motionOK) return;

  // Create and inject canvas
  var canvas = document.createElement('canvas');
  canvas.id  = 'particle-canvas';
  document.body.prepend(canvas);
  document.documentElement.classList.add('particles-active');

  var ctx = canvas.getContext('2d');
  var W, H, particles = [];

  var PARTICLE_COUNT  = 65;
  var CONNECTION_DIST = 130;
  var REPEL_DIST      = 80;
  var REPEL_FORCE     = 0.28;

  var mouseX = -9999, mouseY = -9999;

  // Read accent color from CSS variable (updates on theme toggle)
  function getAccentRgb() {
    var hex = getComputedStyle(document.documentElement)
                .getPropertyValue('--color-accent').trim();
    // Hex → "r,g,b"
    if (hex.charAt(0) === '#') {
      var r = parseInt(hex.slice(1, 3), 16);
      var g = parseInt(hex.slice(3, 5), 16);
      var b = parseInt(hex.slice(5, 7), 16);
      return r + ',' + g + ',' + b;
    }
    return '88,166,255'; // fallback dark-theme default
  }

  var RGB = getAccentRgb();

  // Update color on theme change
  var observer = new MutationObserver(function () {
    RGB = getAccentRgb();
  });
  observer.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });

  function resize() {
    W = canvas.width  = window.innerWidth;
    H = canvas.height = window.innerHeight;
  }

  function initParticles() {
    particles = [];
    for (var i = 0; i < PARTICLE_COUNT; i++) {
      particles.push({
        x:  Math.random() * W,
        y:  Math.random() * H,
        vx: (Math.random() - 0.5) * 0.3,
        vy: (Math.random() - 0.5) * 0.3,
        r:  Math.random() * 1.2 + 0.7
      });
    }
  }

  function draw() {
    ctx.clearRect(0, 0, W, H);

    for (var i = 0; i < particles.length; i++) {
      var p = particles[i];

      // Mouse repulsion
      var dx = p.x - mouseX;
      var dy = p.y - mouseY;
      var dist = Math.sqrt(dx * dx + dy * dy);
      if (dist < REPEL_DIST && dist > 0) {
        var force = (REPEL_DIST - dist) / REPEL_DIST * REPEL_FORCE;
        p.vx += (dx / dist) * force;
        p.vy += (dy / dist) * force;
      }

      // Dampen + move
      p.vx *= 0.99;
      p.vy *= 0.99;
      p.x  += p.vx;
      p.y  += p.vy;

      // Wrap edges
      if (p.x < 0) p.x = W;  if (p.x > W) p.x = 0;
      if (p.y < 0) p.y = H;  if (p.y > H) p.y = 0;

      // Draw particle dot
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
      ctx.fillStyle = 'rgba(' + RGB + ',0.4)';
      ctx.fill();
    }

    // Draw connection lines
    for (var i = 0; i < particles.length; i++) {
      for (var j = i + 1; j < particles.length; j++) {
        var ddx = particles[i].x - particles[j].x;
        var ddy = particles[i].y - particles[j].y;
        var d   = Math.sqrt(ddx * ddx + ddy * ddy);
        if (d < CONNECTION_DIST) {
          var alpha = (1 - d / CONNECTION_DIST) * 0.22;
          ctx.beginPath();
          ctx.moveTo(particles[i].x, particles[i].y);
          ctx.lineTo(particles[j].x, particles[j].y);
          ctx.strokeStyle = 'rgba(' + RGB + ',' + alpha + ')';
          ctx.lineWidth   = 0.6;
          ctx.stroke();
        }
      }
    }

    requestAnimationFrame(draw);
  }

  window.addEventListener('resize', function () {
    resize();
    initParticles();
  }, { passive: true });

  document.addEventListener('mousemove', function (e) {
    mouseX = e.clientX;
    mouseY = e.clientY;
  }, { passive: true });

  resize();
  initParticles();
  draw();
}());
