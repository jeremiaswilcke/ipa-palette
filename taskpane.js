/*
 * IPA-Palette – Task-Pane-Logik (ohne Frameworks, ohne Build-Schritt).
 * Abhaengigkeiten: ipa-data.js (window.IPA_DATA) und, in Word, office.js.
 */
(function () {
  'use strict';

  var D = window.IPA_DATA;
  var $ = function (id) { return document.getElementById(id); };

  if (!D) {
    document.body.textContent = 'Die IPA-Daten (ipa-data.js) konnten nicht geladen werden.';
    return;
  }

  /* ------------------------------------------------------------------ */
  /* Speicher (localStorage kann fehlen oder Fehler werfen)              */
  /* ------------------------------------------------------------------ */
  var PREFIX = 'ipaPalette.';
  var store = {
    get: function (key, fallback) {
      try {
        var raw = window.localStorage.getItem(PREFIX + key);
        return raw === null || raw === undefined ? fallback : JSON.parse(raw);
      } catch (e) { return fallback; }
    },
    set: function (key, value) {
      try { window.localStorage.setItem(PREFIX + key, JSON.stringify(value)); } catch (e) { /* ignorieren */ }
    }
  };

  var RECENT_MAX = 16;
  var FONTS = [
    { value: '', label: 'Dokumentschrift beibehalten' },
    { value: 'Charis SIL', label: 'Charis SIL' },
    { value: 'Doulos SIL', label: 'Doulos SIL' },
    { value: 'Gentium Plus', label: 'Gentium Plus' },
    { value: 'Times New Roman', label: 'Times New Roman' }
  ];
  var DEFAULT_OPEN = { haeufig: true, recent: true };

  var openState = (function () {
    var s = store.get('sections', {});
    return s && typeof s === 'object' && !Array.isArray(s) ? s : {};
  })();
  var recent = (function () {
    var r = store.get('recent', []);
    return Array.isArray(r) ? r.filter(function (x) { return typeof x === 'string' && x; }).slice(0, RECENT_MAX) : [];
  })();

  /* ------------------------------------------------------------------ */
  /* Hilfsfunktionen                                                     */
  /* ------------------------------------------------------------------ */
  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined && text !== null) e.textContent = text;
    return e;
  }

  function cpText(ins) { return D.codepoints(ins).join(' '); }

  // Sehr kleine Zeichen werden etwas groesser dargestellt
  var BIG = new Set([0x02C8, 0x02CC, 0x02D0, 0x02D1, 0x002E, 0x203F, 0x02BC, 0xA71B, 0xA71C].map(function (c) { return String.fromCodePoint(c); }));

  function symButton(item, extraClass) {
    var cls = 'sym' + (extraClass ? ' ' + extraClass : '') + (BIG.has(item.ins) ? ' big' : '');
    var b = el('button', cls, item.show);
    b.type = 'button';
    b.setAttribute('data-ins', item.ins);
    b.title = item.name + ' (' + cpText(item.ins) + ')';
    b.setAttribute('aria-label', item.name);
    return b;
  }

  function gridOf(items) {
    var g = el('div', 'grid');
    items.forEach(function (it) { g.appendChild(symButton(it)); });
    return g;
  }

  /* ------------------------------------------------------------------ */
  /* Modus: Word oder Browser                                            */
  /* ------------------------------------------------------------------ */
  var mode = 'init';   // 'init' | 'word' | 'browser'
  function setMode(m) {
    mode = m;
    document.documentElement.setAttribute('data-mode', m);
    $('notice').hidden = m !== 'browser';
  }

  function initOffice() {
    if (typeof Office === 'undefined' || !Office || typeof Office.onReady !== 'function') {
      setMode('browser');
      return;
    }
    var settled = false;
    var timer = setTimeout(function () { if (!settled && mode === 'init') setMode('browser'); }, 4000);
    try {
      var p = Office.onReady(function (info) {
        settled = true;
        clearTimeout(timer);
        var isWord = !!(info && typeof Office.HostType !== 'undefined' && info.host === Office.HostType.Word);
        setMode(isWord ? 'word' : 'browser');
      });
      if (p && typeof p.catch === 'function') p.catch(function () { if (mode === 'init') setMode('browser'); });
    } catch (e) {
      setMode('browser');
    }
  }

  /* ------------------------------------------------------------------ */
  /* Toast und Zwischenablage                                            */
  /* ------------------------------------------------------------------ */
  var toastTimer = null;
  function toast(prefix, text) {
    var t = $('toast');
    t.textContent = '';
    t.appendChild(document.createTextNode(prefix));
    if (text) { t.appendChild(el('span', 'ipa', text)); }
    t.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { t.classList.remove('show'); }, 1600);
  }

  function copyViaTextarea(text) {
    var prev = document.activeElement;
    var ta = document.createElement('textarea');
    ta.value = text;
    ta.setAttribute('readonly', '');
    ta.setAttribute('aria-hidden', 'true');
    ta.style.cssText = 'position:fixed;top:0;left:0;width:1px;height:1px;opacity:0;pointer-events:none;';
    document.body.appendChild(ta);
    var ok = false;
    try {
      ta.focus({ preventScroll: true });
      ta.select();
      ta.setSelectionRange(0, ta.value.length);
      ok = document.execCommand('copy');
    } catch (e) { ok = false; }
    document.body.removeChild(ta);
    try { if (prev && typeof prev.focus === 'function') prev.focus({ preventScroll: true }); } catch (e) { /* ignorieren */ }
    return ok;
  }

  function copyText(text) {
    try {
      if (navigator.clipboard && typeof navigator.clipboard.writeText === 'function') {
        return navigator.clipboard.writeText(text).then(
          function () { return true; },
          function () { return copyViaTextarea(text); }
        );
      }
    } catch (e) { /* weiter mit Fallback */ }
    return Promise.resolve(copyViaTextarea(text));
  }

  /* ------------------------------------------------------------------ */
  /* Einfuegen in Word                                                   */
  /* ------------------------------------------------------------------ */
  var wordQueue = Promise.resolve();
  function runWord(fn) {
    var p = wordQueue.then(fn);
    wordQueue = p.then(function () {}, function () {});
    return p;
  }

  function currentFont() { return $('font').value || ''; }

  async function wordInsert(text, fontName) {
    await Word.run(async function (ctx) {
      var sel = ctx.document.getSelection();
      var r = sel.insertText(text, 'Replace');
      if (fontName) r.font.name = fontName;
      r.select('End');
      await ctx.sync();
    });
  }

  async function wordBrackets(open, close, fontName) {
    await Word.run(async function (ctx) {
      var sel = ctx.document.getSelection();
      sel.load('text');
      await ctx.sync();
      if (sel.text && sel.text.length > 0) {
        // Auswahl umklammern; Cursor hinter die schliessende Klammer
        var a = sel.insertText(open, 'Start');
        var b = sel.insertText(close, 'End');
        if (fontName) { a.font.name = fontName; b.font.name = fontName; }
        sel.select('End');
      } else {
        // Leere Auswahl: beide Klammern einfuegen, Cursor dazwischen
        var r1 = sel.insertText(open, 'Replace');
        var r2 = r1.insertText(close, 'After');
        if (fontName) { r1.font.name = fontName; r2.font.name = fontName; }
        r1.select('End');
      }
      await ctx.sync();
    });
  }

  /**
   * Fuegt Text ein (Word) oder kopiert ihn (Browser).
   * action: Funktion, die in Word ausgefuehrt wird (liefert ein Promise); copy: Text fuer die Zwischenablage.
   * Gibt ein Promise<boolean> zurueck: true bei Erfolg.
   */
  function deliver(wordAction, copy) {
    if (mode === 'word') {
      return runWord(wordAction).then(
        function () { return true; },
        function (err) {
          if (window.console && console.warn) console.warn('IPA-Palette: Einfügen in Word fehlgeschlagen', err);
          return copyText(copy).then(function (ok) {
            if (ok) toast('Einfügen nicht möglich, kopiert: ', copy); else toast('Einfügen nicht möglich');
            return false;
          });
        }
      );
    }
    return copyText(copy).then(function (ok) {
      if (ok) toast('Kopiert: ', copy); else toast('Kopieren nicht möglich');
      return ok;
    });
  }

  function insertText(text) {
    var font = currentFont();
    return deliver(function () { return wordInsert(text, font); }, text);
  }

  function insertBrackets(b) {
    var font = currentFont();
    return deliver(function () { return wordBrackets(b.open, b.close, font); }, b.open + b.close);
  }

  /* ------------------------------------------------------------------ */
  /* Infoleiste                                                          */
  /* ------------------------------------------------------------------ */
  function showInfo(item) {
    if (!item) return;
    var g = $('info-glyph');
    g.textContent = item.show;
    g.removeAttribute('data-empty');
    $('info-name').textContent = item.name;
    $('info-cp').textContent = cpText(item.ins);
    var xs = D.xsampaFor(item.ins);
    $('info-xs').textContent = xs ? 'X-SAMPA: ' + xs : '';
  }

  function itemOf(btn) { return D.itemByIns(btn.getAttribute('data-ins')); }

  /* ------------------------------------------------------------------ */
  /* Abschnitte aufbauen                                                 */
  /* ------------------------------------------------------------------ */
  function buildConsonantTable(table) {
    var wrap = el('div', 'scroll-wrap');
    var scroll = el('div', 'scroll');
    scroll.tabIndex = 0;
    scroll.setAttribute('role', 'region');
    scroll.setAttribute('aria-label', 'Konsonantentabelle (seitlich scrollbar)');
    var t = el('table', 'ctable');

    var thead = el('thead');
    var hr = el('tr');
    hr.appendChild(el('th', 'corner'));
    table.places.forEach(function (p) {
      var th = el('th', null, p);
      th.scope = 'col';
      hr.appendChild(th);
    });
    thead.appendChild(hr);
    t.appendChild(thead);

    var tbody = el('tbody');
    table.rows.forEach(function (row) {
      var tr = el('tr');
      var th = el('th', 'manner', row.label);
      th.scope = 'row';
      tr.appendChild(th);
      row.cells.forEach(function (c) {
        var td = el('td');
        if (c.span > 1) td.colSpan = c.span;
        if (c.type === 'na') {
          td.className = 'na';
          td.setAttribute('aria-hidden', 'true');
        } else if (c.type === 'cell') {
          var pair = el('div', 'pair');
          [c.voiceless, c.voiced].forEach(function (it) {
            if (it) pair.appendChild(symButton(it, 'slot'));
            else pair.appendChild(el('span', 'slot'));
          });
          td.appendChild(pair);
        }
        tr.appendChild(td);
      });
      tbody.appendChild(tr);
    });
    t.appendChild(tbody);
    scroll.appendChild(t);
    wrap.appendChild(scroll);

    function updateShadow() {
      var more = scroll.scrollLeft + scroll.clientWidth < scroll.scrollWidth - 2;
      wrap.classList.toggle('more-right', more);
    }
    scroll.addEventListener('scroll', updateShadow, { passive: true });
    window.addEventListener('resize', updateShadow);
    setTimeout(updateShadow, 0);
    // Tabelle wird erst beim Oeffnen des Abschnitts sichtbar -> danach neu messen
    wrap.updateShadow = updateShadow;

    var frag = document.createDocumentFragment();
    frag.appendChild(wrap);
    frag.appendChild(el('p', 'legend', 'In jeder Zelle: links stimmlos, rechts stimmhaft. Grau = artikulatorisch unmöglich.'));
    frag.updateShadow = updateShadow;
    return frag;
  }

  function buildVowelTrapezoid(table) {
    var root = el('div', 'vowel');

    var head = el('div', 'vhead');
    var hc = el('div', 'vcells');
    hc.style.setProperty('--i', '0');
    table.columns.forEach(function (c) { hc.appendChild(el('span', null, c)); });
    head.appendChild(hc);
    head.appendChild(el('span'));
    root.appendChild(head);

    var body = el('div', 'vbody');
    table.rows.forEach(function (row, i) {
      var r = el('div', 'vrow');
      var cells = el('div', 'vcells');
      cells.style.setProperty('--i', String(i));
      row.cells.forEach(function (c) {
        var cell = el('div', 'vcell');
        [c.unrounded, c.rounded].forEach(function (it) {
          if (it) cell.appendChild(symButton(it));
          else cell.appendChild(el('span', 'slot'));
        });
        cells.appendChild(cell);
      });
      r.appendChild(cells);
      var lab = el('div', 'vlabel', row.short);
      lab.title = row.label;
      r.appendChild(lab);
      body.appendChild(r);
    });
    root.appendChild(body);
    root.appendChild(el('p', 'legend', 'In jeder Zelle: links ungerundet, rechts gerundet.'));
    return root;
  }

  var recentGrid = null;
  var recentHint = null;
  var shadowUpdaters = [];

  function buildSection(s) {
    var det = el('details', 'sec');
    det.id = 'sec-' + s.id;
    det.setAttribute('data-id', s.id);

    var sum = el('summary');
    sum.appendChild(el('span', 'title', s.title));
    if (s.type !== 'recent') sum.appendChild(el('span', 'count', String(uniqueCount(s.items))));
    det.appendChild(sum);

    var body = el('div', 'body');
    if (s.type === 'grid') {
      body.appendChild(gridOf(s.items));
    } else if (s.type === 'recent') {
      recentGrid = el('div', 'grid');
      recentGrid.id = 'recent-grid';
      recentHint = el('p', 'hint', 'Noch nichts eingefügt. Hier erscheinen die zuletzt verwendeten Symbole.');
      body.appendChild(recentGrid);
      body.appendChild(recentHint);
    } else if (s.type === 'consonants') {
      var frag = buildConsonantTable(s.table);
      shadowUpdaters.push(frag.updateShadow);
      body.appendChild(frag);
    } else if (s.type === 'vowels') {
      body.appendChild(buildVowelTrapezoid(s.table));
    } else if (s.type === 'groups') {
      s.groups.forEach(function (g) {
        body.appendChild(el('h3', 'sub', g.title));
        body.appendChild(gridOf(g.items));
      });
    }
    det.appendChild(body);

    var open = Object.prototype.hasOwnProperty.call(openState, s.id) ? !!openState[s.id] : !!DEFAULT_OPEN[s.id];
    det.open = open;
    det.addEventListener('toggle', function () {
      openState[s.id] = det.open;
      store.set('sections', openState);
      if (det.open) shadowUpdaters.forEach(function (f) { f(); });
    });
    return det;
  }

  function uniqueCount(items) {
    var seen = {};
    var n = 0;
    items.forEach(function (i) { if (!seen[i.ins]) { seen[i.ins] = 1; n++; } });
    return n;
  }

  /* ------------------------------------------------------------------ */
  /* Zuletzt verwendet                                                   */
  /* ------------------------------------------------------------------ */
  function renderRecent() {
    if (!recentGrid) return;
    var focused = document.activeElement;
    var focusIns = focused && recentGrid.contains(focused) ? focused.getAttribute('data-ins') : null;
    recentGrid.textContent = '';
    var focusTarget = null;
    recent.forEach(function (ins) {
      var item = D.itemByIns(ins) || { ins: ins, show: ins, name: 'Eingefügtes Zeichen', kind: 'letter' };
      var b = symButton(item);
      if (focusIns !== null && ins === focusIns) focusTarget = b;
      recentGrid.appendChild(b);
    });
    recentHint.hidden = recent.length > 0;
    if (focusTarget) { try { focusTarget.focus({ preventScroll: true }); } catch (e) { /* ignorieren */ } }
  }

  function recordRecent(ins) {
    recent = [ins].concat(recent.filter(function (x) { return x !== ins; })).slice(0, RECENT_MAX);
    store.set('recent', recent);
    renderRecent();
  }

  /* ------------------------------------------------------------------ */
  /* Suche                                                               */
  /* ------------------------------------------------------------------ */
  function runSearch() {
    var q = $('search').value.trim();
    var results = $('results');
    var sections = $('sections');
    $('main').classList.toggle('searching', !!q);   // Werkzeuge ausblenden, damit Treffer direkt unter dem Suchfeld stehen
    if (!q) {
      results.hidden = true;
      results.textContent = '';
      sections.hidden = false;
      return;
    }
    var items = D.search(q);
    results.textContent = '';
    if (items.length) {
      results.appendChild(el('div', 'count', items.length === 1 ? '1 Treffer' : items.length + ' Treffer'));
      results.appendChild(gridOf(items));
    } else {
      results.appendChild(el('p', 'hint', 'Keine Treffer für „' + q + '“.'));
    }
    results.hidden = false;
    sections.hidden = true;
  }

  /* ------------------------------------------------------------------ */
  /* X-SAMPA-Schnelleingabe                                              */
  /* ------------------------------------------------------------------ */
  function normalizeQuotes(s) {
    // Betriebssysteme ersetzen " und ' mitunter durch typografische Anfuehrungszeichen
    return s.replace(/[“”„‟]/g, '"').replace(/[‘’‚‛]/g, "'");
  }

  function xsConverted() { return D.xsampaToIpa(normalizeQuotes($('xs-input').value)); }

  function updatePreview() {
    var out = $('xs-out');
    var ipa = xsConverted();
    if (ipa) {
      out.textContent = ipa;
      out.removeAttribute('data-empty');
    } else {
      out.textContent = 'Vorschau erscheint hier';
      out.setAttribute('data-empty', 'true');
    }
  }

  function insertXsampa() {
    var input = $('xs-input');
    var ipa = xsConverted();
    if (!input.value.trim() || !ipa) { input.focus(); return Promise.resolve(false); }
    return insertText(ipa).then(function (ok) {
      if (ok) { input.value = ''; updatePreview(); }
      input.focus();
      return ok;
    });
  }

  function buildCheatSheet() {
    var box = $('xs-cheat');
    var keys = D.xsampaCheat;
    var table = el('table');
    table.setAttribute('aria-label', 'Wichtige X-SAMPA-Codes');
    var tbody = el('tbody');
    for (var i = 0; i < keys.length; i += 3) {
      var tr = el('tr');
      for (var j = i; j < i + 3; j++) {
        if (j < keys.length) {
          var ipa = D.xsampaToIpa(keys[j]);
          var item = D.itemByIns(ipa);
          tr.appendChild(el('td', 'k', keys[j]));
          tr.appendChild(el('td', 'v', item ? item.show : ipa));
        } else {
          tr.appendChild(el('td', 'k'));
          tr.appendChild(el('td', 'v'));
        }
      }
      tbody.appendChild(tr);
    }
    table.appendChild(tbody);
    box.appendChild(table);
    var p = el('p');
    var ex1 = '"hal@';
    var ex2 = 't_S';
    p.appendChild(document.createTextNode('Beispiele: '));
    var s1 = el('span', 'ex');
    s1.appendChild(document.createTextNode(ex1 + ' → '));
    s1.appendChild(el('b', null, D.xsampaToIpa(ex1)));
    var s2 = el('span', 'ex');
    s2.appendChild(document.createTextNode(ex2 + ' → '));
    s2.appendChild(el('b', null, D.xsampaToIpa(ex2)));
    p.appendChild(s1);
    p.appendChild(document.createTextNode('  ·  '));
    p.appendChild(s2);
    box.appendChild(p);
    box.appendChild(el('p', null, 'Nach Wells (1995). Gross- und Kleinschreibung zählt; „_“ bildet den Bindebogen.'));
  }

  /* ------------------------------------------------------------------ */
  /* Aufbau und Ereignisse                                               */
  /* ------------------------------------------------------------------ */
  function buildUI() {
    // Schriftart
    var sel = $('font');
    FONTS.forEach(function (f) {
      var o = el('option', null, f.label);
      o.value = f.value;
      sel.appendChild(o);
    });
    var savedFont = store.get('font', '');
    sel.value = FONTS.some(function (f) { return f.value === savedFont; }) ? savedFont : '';
    sel.addEventListener('change', function () { store.set('font', sel.value); });

    // Klammern
    var bwrap = $('brackets');
    D.brackets.forEach(function (b) {
      var btn = el('button', 'btn', b.label);
      btn.type = 'button';
      btn.setAttribute('data-bracket', b.id);
      btn.title = b.name + ' – umklammert markierten Text oder fügt leere Klammern ein';
      btn.setAttribute('aria-label', b.name);
      btn.addEventListener('click', function () { insertBrackets(b); });
      bwrap.appendChild(btn);
    });

    // Abschnitte
    var host = $('sections');
    D.sections.forEach(function (s) { host.appendChild(buildSection(s)); });
    renderRecent();

    buildCheatSheet();
  }

  function wireEvents() {
    // Symbole: Klick (Delegation)
    document.addEventListener('click', function (e) {
      var btn = e.target && e.target.closest ? e.target.closest('button.sym') : null;
      if (!btn) return;
      var item = itemOf(btn);
      if (!item) return;
      showInfo(item);
      var fromRecent = !!btn.closest('#recent-grid');
      insertText(item.ins).then(function (ok) {
        // Beim Klick in "Zuletzt verwendet" bleibt die Reihenfolge stabil
        if (ok && !fromRecent) recordRecent(item.ins);
      });
    });

    // Infoleiste: Hover und Fokus
    function infoFromEvent(e) {
      var btn = e.target && e.target.closest ? e.target.closest('button.sym') : null;
      if (btn) showInfo(itemOf(btn));
    }
    document.addEventListener('mouseover', infoFromEvent);
    document.addEventListener('focusin', infoFromEvent);

    // Suche
    var search = $('search');
    search.addEventListener('input', runSearch);
    search.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && search.value) { search.value = ''; runSearch(); e.stopPropagation(); }
    });

    // X-SAMPA
    var xs = $('xs-input');
    xs.addEventListener('input', updatePreview);
    xs.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' && !e.isComposing) { e.preventDefault(); insertXsampa(); }
    });
    $('xs-insert').addEventListener('click', function () { insertXsampa(); });
    var help = $('xs-help');
    help.addEventListener('click', function () {
      var cheat = $('xs-cheat');
      var show = cheat.hidden;
      cheat.hidden = !show;
      help.setAttribute('aria-expanded', show ? 'true' : 'false');
    });
  }

  function boot() {
    setMode('init');
    buildUI();
    wireEvents();
    initOffice();
    shadowUpdaters.forEach(function (f) { f(); });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})();
