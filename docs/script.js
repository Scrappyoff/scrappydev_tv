(function () {
  'use strict';
  var KEY_PROGRESS = 'scrappy_tv_docs_progress_v1';
  var KEY_LANG = 'scrappy_tv_docs_lang';
  var root = document.documentElement;

  function read(key) { try { return localStorage.getItem(key); } catch (e) { return null; } }
  function write(key, value) { try { localStorage.setItem(key, value); } catch (e) { /* storage unavailable: nothing is remembered */ } }

  // ---------------------------------------------------------------- language (English by default)
  var TITLES = { en: 'Scrappy.Dev TV — Documentation', fr: 'Scrappy.Dev TV — Documentation' };
  var PLACEHOLDER = { en: 'Search a problem…', fr: 'Rechercher un problème…' };
  var COPIED = { en: 'Copied!', fr: 'Copié !' };
  var SHOWLESS = { en: 'Show less', fr: 'Réduire' };

  function setLang(lang) {
    if (lang !== 'fr') { lang = 'en'; }
    root.setAttribute('lang', lang);
    document.title = TITLES[lang];
    document.getElementById('search').placeholder = PLACEHOLDER[lang];
    Array.prototype.forEach.call(document.querySelectorAll('[data-setlang]'), function (b) { b.classList.toggle('on', b.getAttribute('data-setlang') === lang); });
    write(KEY_LANG, lang);
    refreshMore();
  }
  Array.prototype.forEach.call(document.querySelectorAll('[data-setlang]'), function (b) {
    b.addEventListener('click', function () { setLang(b.getAttribute('data-setlang')); });
  });

  // ---------------------------------------------------------------- progress: stable ids, fixed total
  var boxes = Array.prototype.slice.call(document.querySelectorAll('input[type="checkbox"][data-id]'));
  var bar = document.getElementById('bar');
  var pct = document.getElementById('pct');
  var pcount = document.getElementById('pcount');
  var state = {};
  try { state = JSON.parse(read(KEY_PROGRESS)) || {}; } catch (e) { state = {}; }
  if (typeof state !== 'object' || state === null || Array.isArray(state)) { state = {}; }

  function refreshProgress() {
    var total = boxes.length;
    var done = boxes.filter(function (b) { return b.checked; }).length;
    var value = total ? Math.round(done / total * 100) : 0;
    bar.style.width = value + '%';
    pct.textContent = value + '%';
    pcount.textContent = done + '/' + total;
  }
  boxes.forEach(function (box) {
    box.checked = state[box.getAttribute('data-id')] === true;
    box.addEventListener('change', function () {
      var id = box.getAttribute('data-id');
      if (box.checked) { state[id] = true; } else { delete state[id]; }
      write(KEY_PROGRESS, JSON.stringify(state));
      refreshProgress();
    });
  });
  document.getElementById('reset').addEventListener('click', function () {
    state = {};
    boxes.forEach(function (b) { b.checked = false; });
    write(KEY_PROGRESS, '{}');
    refreshProgress();
  });

  // ---------------------------------------------------------------- tabs
  var tabs = document.querySelectorAll('.tab');
  var panes = document.querySelectorAll('.pane');
  Array.prototype.forEach.call(tabs, function (tab) {
    tab.addEventListener('click', function () {
      var name = tab.getAttribute('data-tab');
      Array.prototype.forEach.call(tabs, function (t) { t.classList.toggle('on', t === tab); });
      Array.prototype.forEach.call(panes, function (p) { p.classList.toggle('on', p.getAttribute('data-pane') === name); });
      write('scrappy_tv_docs_tab', name);
    });
  });
  var savedTab = read('scrappy_tv_docs_tab');
  if (savedTab) {
    var wanted = document.querySelector('.tab[data-tab="' + savedTab + '"]');
    if (wanted) { wanted.click(); }
  }

  // ---------------------------------------------------------------- code: highlighting, copy, collapse
  var RULES = {
    lua: { kw: /^(and|break|do|else|elseif|end|false|for|function|goto|if|in|local|nil|not|or|repeat|return|then|true|until|while)$/ },
    sql: { kw: /^(CREATE|TABLE|IF|NOT|EXISTS|NULL|PRIMARY|KEY|INSERT|INTO|VALUES|ON|DUPLICATE|UPDATE|DEFAULT|ENGINE|CHARSET|INDEX|VARCHAR|LONGTEXT|BIGINT|INT|UNSIGNED|InnoDB|utf8mb4)$/i },
    cfg: { kw: /^(ensure|set|add_ace|add_principal|start|restart|stop|exec)$/ }
  };
  function esc(s) { return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
  function highlight(text, lang) {
    var comment = lang === 'lua' ? '--\\[\\[[\\s\\S]*?\\]\\]|--[^\\n]*' : lang === 'sql' ? '--[^\\n]*' : '#[^\\n]*';
    var re = new RegExp('(' + comment + ')|("(?:[^"\\\\\\n]|\\\\.)*"|\'(?:[^\'\\\\\\n]|\\\\.)*\'|`[^`\\n]*`)|(\\b\\d+(?:\\.\\d+)?\\b)|([A-Za-z_][A-Za-z0-9_]*)', 'g');
    var kw = (RULES[lang] || RULES.lua).kw;
    var out = '', last = 0, m;
    while ((m = re.exec(text)) !== null) {
      out += esc(text.slice(last, m.index));
      last = m.index + m[0].length;
      if (m[1]) { out += '<span class="tk-c">' + esc(m[1]) + '</span>'; }
      else if (m[2]) { out += '<span class="tk-s">' + esc(m[2]) + '</span>'; }
      else if (m[3]) { out += '<span class="tk-n">' + esc(m[3]) + '</span>'; }
      else {
        var w = m[4], after = text.slice(last).match(/^\s*([=(])/), before = text.charAt(m.index - 1);
        if (kw.test(w)) { out += '<span class="tk-k">' + w + '</span>'; }
        else if (lang === 'lua' && after && after[1] === '=' && /[\s{,]/.test(before || ' ') && text.charAt(last + (after[0].length)) !== '=') { out += '<span class="tk-p">' + w + '</span>'; }
        else if (lang === 'lua' && after && after[1] === '(') { out += '<span class="tk-f">' + w + '</span>'; }
        else { out += w; }
      }
    }
    return out + esc(text.slice(last));
  }
  Array.prototype.forEach.call(document.querySelectorAll('figure.code'), function (fig) {
    var code = fig.querySelector('code');
    var lang = fig.getAttribute('data-lang') || 'lua';
    code.innerHTML = highlight(code.textContent.replace(/^\n+|\s+$/g, ''), lang);
  });

  function copyText(text, button) {
    function done() {
      button.classList.add('done');
      var old = button.innerHTML;
      button.innerHTML = '<span>' + COPIED[root.getAttribute('lang') === 'fr' ? 'fr' : 'en'] + '</span>';
      setTimeout(function () { button.classList.remove('done'); button.innerHTML = old; }, 1400);
    }
    function fallback() {
      var area = document.createElement('textarea');
      area.value = text; area.style.position = 'fixed'; area.style.opacity = '0';
      document.body.appendChild(area); area.select();
      try { document.execCommand('copy'); done(); } catch (e) { /* copy impossible */ }
      document.body.removeChild(area);
    }
    if (navigator.clipboard && navigator.clipboard.writeText) { navigator.clipboard.writeText(text).then(done, fallback); } else { fallback(); }
  }
  Array.prototype.forEach.call(document.querySelectorAll('[data-copy]'), function (btn) {
    btn.addEventListener('click', function () { copyText(btn.closest('figure').querySelector('pre').textContent, btn); });
  });
  Array.prototype.forEach.call(document.querySelectorAll('[data-copytext]'), function (btn) {
    btn.addEventListener('click', function () { copyText(btn.getAttribute('data-copytext'), btn); });
  });
  var moreButtons = Array.prototype.slice.call(document.querySelectorAll('[data-more]'));
  var moreHtml = moreButtons.map(function (b) { return b.innerHTML; });
  function refreshMore() {
    moreButtons.forEach(function (b, i) {
      var open = !b.closest('figure').classList.contains('collapsed');
      b.innerHTML = open ? '<span>' + SHOWLESS[root.getAttribute('lang') === 'fr' ? 'fr' : 'en'] + '</span>' : moreHtml[i];
    });
  }
  moreButtons.forEach(function (b) {
    b.addEventListener('click', function () { b.closest('figure').classList.toggle('collapsed'); refreshMore(); });
  });
  // the "show less" button must stay reachable once expanded
  document.addEventListener('click', function () {
    moreButtons.forEach(function (b) { b.style.display = b.closest('figure').classList.contains('collapsed') ? '' : 'block'; });
  });

  // ---------------------------------------------------------------- troubleshooting search
  var search = document.getElementById('search');
  search.addEventListener('input', function () {
    var q = search.value.trim().toLowerCase();
    Array.prototype.forEach.call(document.querySelectorAll('#faqlist details'), function (d) {
      var lang = root.getAttribute('lang');
      var text = Array.prototype.map.call(d.querySelectorAll('summary > span, p'), function (n) { return n.classList.contains(lang === 'fr' ? 'en' : 'fr') ? '' : n.textContent; }).join(' ').toLowerCase();
      var hit = !q || text.indexOf(q) !== -1;
      d.style.display = hit ? '' : 'none';
      if (q && hit) { d.open = true; }
    });
  });

  // ---------------------------------------------------------------- navigation
  var side = document.getElementById('side');
  document.getElementById('burger').addEventListener('click', function () { side.classList.toggle('open'); });
  var links = Array.prototype.slice.call(side.querySelectorAll('a'));
  links.forEach(function (a) { a.addEventListener('click', function () { side.classList.remove('open'); }); });
  if ('IntersectionObserver' in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { links.forEach(function (a) { a.classList.toggle('on', a.getAttribute('href') === '#' + e.target.id); }); }
      });
    }, { rootMargin: '-25% 0px -65% 0px' });
    Array.prototype.forEach.call(document.querySelectorAll('main section[id]'), function (s) { io.observe(s); });
  }

  setLang(read(KEY_LANG) === 'fr' ? 'fr' : 'en');
  refreshProgress();
})();
