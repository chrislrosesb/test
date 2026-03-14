/*!
 * theme.js — Light/dark mode toggle handler
 * The actual theme detection/application happens inline in <head> (no flash).
 * This file only wires up the toggle button click.
 */
(function () {
  'use strict';

  var btn = document.getElementById('theme-toggle');
  if (!btn) return;

  btn.addEventListener('click', function () {
    var isLight = document.documentElement.getAttribute('data-theme') === 'light';
    if (isLight) {
      document.documentElement.removeAttribute('data-theme');
      localStorage.setItem('theme', 'dark');
    } else {
      document.documentElement.setAttribute('data-theme', 'light');
      localStorage.setItem('theme', 'light');
    }
  });
}());
