// ReadabilityJS.swift
// Mozilla Readability-inspired article extractor.
// Injected as a WKUserScript; exposes window.extractArticle() → JSON string.

enum ReadabilityJS {
    static let source = #"""
(function(global) {
'use strict';

var POSITIVE = /article|body|content|entry|hentry|h-entry|main|page|post|text|blog|story|instapaper_body|reader/i;
var NEGATIVE = /hidden|^hid$| hid |banner|combx|comment|com-|contact|foot|footer|footnote|gdpr|masthead|media|meta|outbrain|promo|related|scroll|share|shoutbox|sidebar|skyscraper|sponsor|shopping|tags|tool|widget/i;

function innerText(el) {
    return (el.textContent || '').replace(/\s+/g, ' ').trim();
}

function linkDensity(el) {
    var len = innerText(el).length;
    if (!len) return 0;
    var linkLen = 0;
    el.querySelectorAll('a').forEach(function(a) { linkLen += innerText(a).length; });
    return linkLen / len;
}

function classWeight(el) {
    var cls = [(el.className || ''), (el.id || '')].join(' ');
    var w = 0;
    if (NEGATIVE.test(cls)) w -= 25;
    if (POSITIVE.test(cls)) w += 25;
    return w;
}

function baseScore(el) {
    var s = 0;
    switch (el.tagName) {
        case 'DIV':       s = 5;  break;
        case 'PRE': case 'TD': case 'BLOCKQUOTE': s = 3; break;
        case 'ADDRESS': case 'OL': case 'UL': case 'DL':
        case 'DD': case 'DT': case 'LI': case 'FORM': s = -3; break;
        case 'H1': case 'H2': case 'H3': case 'H4':
        case 'H5': case 'H6': case 'TH': s = -5; break;
    }
    return s + classWeight(el);
}

function scoreNode(candidates, node) {
    var text = innerText(node);
    if (text.length < 25) return;
    var parent = node.parentElement;
    var grandparent = parent && parent.parentElement;
    if (!parent) return;
    var pts = 1 + Math.min(Math.floor(text.length / 100), 3) + (text.split(',').length - 1);
    [[parent, 1], [grandparent, 2]].forEach(function(pair) {
        var ancestor = pair[0], divisor = pair[1];
        if (!ancestor || !ancestor.tagName) return;
        if (!candidates.has(ancestor)) candidates.set(ancestor, baseScore(ancestor));
        candidates.set(ancestor, candidates.get(ancestor) + pts / divisor);
    });
}

function cleanContent(el) {
    el.querySelectorAll('script,style,noscript,iframe,form,button,input,select,textarea').forEach(function(e) { e.remove(); });
    var all = Array.from(el.querySelectorAll('*')).reverse();
    all.forEach(function(node) {
        if (!node.parentElement) return;
        var cn = (node.className || '') + ' ' + (node.id || '');
        if (NEGATIVE.test(cn) && !POSITIVE.test(cn)) { node.remove(); return; }
        var tag = node.tagName;
        if (['DIV','SECTION','ASIDE','TABLE'].indexOf(tag) >= 0) {
            if (linkDensity(node) > 0.5 && innerText(node).length < 500) { node.remove(); return; }
        }
    });
    el.querySelectorAll('p,span').forEach(function(p) {
        if (!innerText(p).length && !p.querySelector('img,video')) p.remove();
    });
}

function bestTitle() {
    var og = document.querySelector('meta[property="og:title"]');
    if (og) {
        var t = (og.getAttribute('content') || '').trim();
        if (t.length > 3) return t.replace(/\s*[|\u2013\u2014\-]\s*.{3,}$/, '').trim();
    }
    var h1 = document.querySelector('h1');
    if (h1) return innerText(h1).replace(/\s*[|\u2013\u2014\-]\s*.{3,}$/, '').trim();
    return document.title.replace(/\s*[|\u2013\u2014\-]\s*.{3,}$/, '').trim();
}

function bestByline() {
    var sels = ['[rel="author"]','[class*="byline"]','[class*="author"]','[itemprop="author"]'];
    for (var i = 0; i < sels.length; i++) {
        var el = document.querySelector(sels[i]);
        if (el) {
            var t = innerText(el);
            if (t.length > 2 && t.length < 100) return t;
        }
    }
    return '';
}

global.extractArticle = function() {
    try {
        // Remove global noise
        document.querySelectorAll(
            'script,style,noscript,nav,header,footer,aside,iframe,' +
            '[class*="cookie"],[class*="popup"],[class*="modal"],[class*="overlay"],' +
            '[class*="banner"],[class*="sidebar"],[id*="sidebar"],' +
            '[class*="newsletter"],[class*="subscribe"],[class*="advertisement"],' +
            '[class*="-ad-"],[id*="header"],[id*="footer"],[id*="nav"],' +
            '[aria-label="advertisement"],[role="complementary"],' +
            '[class*="related"],[class*="recommended"]'
        ).forEach(function(el) { el.remove(); });

        var title = bestTitle();
        var byline = bestByline();

        // Fast path: semantic selectors
        var selectors = [
            '[itemprop="articleBody"]',
            'article[class*="article"]','article[class*="post"]','article[class*="story"]',
            'article[class*="content"]','article[class*="body"]',
            '[role="article"]','article',
            '.post-content','.article-content','.entry-content','.article-body',
            '.story-body','.post-body','#article-body','.content-body',
            '.article__body','.article__content','.story__body',
            '[class*="article-text"]','[class*="article-body"]',
            '[class*="post-body"]','[class*="entry-body"]','[class*="story-body"]',
            'main[class*="content"]','[role="main"]','main',
            '#content','#main-content','.content'
        ];

        var contentEl = null;
        for (var i = 0; i < selectors.length; i++) {
            var el = document.querySelector(selectors[i]);
            if (el && innerText(el).length > 250 && linkDensity(el) < 0.5) {
                contentEl = el;
                break;
            }
        }

        // Scoring fallback (Readability algorithm)
        if (!contentEl) {
            var candidates = new Map();
            document.querySelectorAll('p,td,pre,li').forEach(function(p) { scoreNode(candidates, p); });
            var top = null, topScore = 0;
            candidates.forEach(function(s, el) {
                var adj = s * (1 - linkDensity(el));
                if (adj > topScore) { topScore = adj; top = el; }
            });
            contentEl = top;
        }

        if (!contentEl) contentEl = document.body;

        var clone = contentEl.cloneNode(true);
        cleanContent(clone);

        var html = clone.innerHTML.trim();
        if (html.length < 100) {
            return JSON.stringify({success: false, reason: 'content_too_short'});
        }

        return JSON.stringify({success: true, title: title, byline: byline, content: html});
    } catch(e) {
        return JSON.stringify({success: false, reason: e.message});
    }
};

})(window);
"""#
}
