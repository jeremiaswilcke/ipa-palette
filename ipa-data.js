/*
 * IPA-Palette: Symboldaten, X-SAMPA-Tabelle, Konverter und Suche.
 *
 * Laeuft im Browser (window.IPA_DATA) und in Node (module.exports), damit die
 * reine Logik ohne DOM getestet werden kann.
 *
 * Alle Diakritika, Modifikatorbuchstaben und leicht verwechselbaren Zeichen
 * werden ueber Codepunkte definiert (cp(0x0325) usw.), nie als unsichtbare
 * Literale. Der Abschnitt "X-SAMPA" unten nutzt \u-Escapes aus demselben Grund.
 */
(function (root) {
  'use strict';

  var cp = function () { return String.fromCodePoint.apply(null, arguments); };
  var G = cp(0x0261);          // ɡ (LATEIN KLEINBUCHSTABE SCHREIB-G), nicht ASCII-g
  var TIE = cp(0x0361);        // Ligaturbogen oben
  var RE_MARK = /^\p{M}+$/u;

  /* ------------------------------------------------------------------ */
  /* X-SAMPA (Wells 1995)                                                 */
  /* ------------------------------------------------------------------ */
  var XSAMPA = {
    // Kleinbuchstaben
    "a": "a",
    "b": "b",
    "b_<": "ɓ",
    "c": "c",
    "d": "d",
    "d`": "ɖ",
    "d_<": "ɗ",
    "e": "e",
    "f": "f",
    "g": "\u0261",
    "g_<": "ɠ",
    "h": "h",
    "h\\": "ɦ",
    "i": "i",
    "j": "j",
    "j\\": "ʝ",
    "k": "k",
    "l": "l",
    "l`": "ɭ",
    "l\\": "ɺ",
    "m": "m",
    "n": "n",
    "n`": "ɳ",
    "o": "o",
    "p": "p",
    "p\\": "ɸ",
    "q": "q",
    "r": "r",
    "r`": "ɽ",
    "r\\": "ɹ",
    "r\\`": "ɻ",
    "s": "s",
    "s`": "ʂ",
    "s\\": "ɕ",
    "t": "t",
    "t`": "ʈ",
    "u": "u",
    "v": "v",
    "v\\": "ʋ",
    "w": "w",
    "x": "x",
    "x\\": "ɧ",
    "y": "y",
    "z": "z",
    "z`": "ʐ",
    "z\\": "ʑ",
    // Grossbuchstaben
    "A": "ɑ",
    "B": "β",
    "B\\": "ʙ",
    "C": "ç",
    "D": "ð",
    "E": "ɛ",
    "F": "ɱ",
    "G": "ɣ",
    "G\\": "ɢ",
    "G\\_<": "ʛ",
    "H": "ɥ",
    "H\\": "ʜ",
    "I": "ɪ",
    "I\\": "ᵻ",
    "J": "ɲ",
    "J\\": "ɟ",
    "J\\_<": "ʄ",
    "K": "ɬ",
    "K\\": "ɮ",
    "L": "ʎ",
    "L\\": "ʟ",
    "M": "ɯ",
    "M\\": "ɰ",
    "N": "ŋ",
    "N\\": "ɴ",
    "O": "ɔ",
    "O\\": "ʘ",
    "P": "ʋ",
    "Q": "ɒ",
    "R": "ʁ",
    "R\\": "ʀ",
    "S": "ʃ",
    "T": "θ",
    "U": "ʊ",
    "U\\": "ᵿ",
    "V": "ʌ",
    "W": "ʍ",
    "X": "χ",
    "X\\": "ħ",
    "Y": "ʏ",
    "Z": "ʒ",
    // Sonstige Zeichen und Ziffern
    ".": ".",
    "\"": "\u02C8",
    "%": "\u02CC",
    "'": "\u02B2",
    ":": "\u02D0",
    ":\\": "\u02D1",
    "@": "ə",
    "@\\": "ɘ",
    "@`": "ɚ",
    "3`": "ɝ",
    "{": "æ",
    "}": "ʉ",
    "1": "ɨ",
    "2": "ø",
    "3": "ɜ",
    "3\\": "ɞ",
    "4": "ɾ",
    "5": "ɫ",
    "6": "ɐ",
    "7": "ɤ",
    "8": "ɵ",
    "9": "œ",
    "&": "ɶ",
    "?": "ʔ",
    "?\\": "ʕ",
    "<\\": "ʢ",
    ">\\": "ʡ",
    "^": "\uA71B",
    "!": "\uA71C",
    "!\\": "\u01C3",
    "|": "|",
    "|\\": "\u01C0",
    "||": "\u2016",
    "|\\|\\": "\u01C1",
    "=\\": "\u01C2",
    "-\\": "\u203F",
    "`": "\u02DE",
    "-": "",
    // Diakritika
    "_\"": "\u0308",
    "_+": "\u031F",
    "_-": "\u0320",
    "_/": "\u030C",
    "_0": "\u0325",
    "=": "\u0329",
    "_=": "\u0329",
    "_>": "\u02BC",
    "_?\\": "\u02E4",
    "_\\": "\u0302",
    "_^": "\u032F",
    "_}": "\u031A",
    "~": "\u0303",
    "_~": "\u0303",
    "_A": "\u0318",
    "_a": "\u033A",
    "_B": "\u030F",
    "_B_L": "\u1DC5",
    "_c": "\u031C",
    "_d": "\u032A",
    "_e": "\u0334",
    "_F": "\u0302",
    "_G": "\u02E0",
    "_H": "\u0301",
    "_H_T": "\u1DC4",
    "_h": "\u02B0",
    "_j": "\u02B2",
    "_k": "\u0330",
    "_L": "\u0300",
    "_l": "\u02E1",
    "_M": "\u0304",
    "_m": "\u033B",
    "_N": "\u033C",
    "_n": "\u207F",
    "_O": "\u0339",
    "_o": "\u031E",
    "_q": "\u0319",
    "_R": "\u030C",
    "_R_F": "\u1DC8",
    "_r": "\u031D",
    "_T": "\u030B",
    "_t": "\u0324",
    "_v": "\u032C",
    "_w": "\u02B7",
    "_X": "\u0306",
    "_x": "\u033D",
    "_": "\u0361",
    // Leerzeichen bleibt Leerzeichen
    " ": " "
  };

  var XS_MAP = new Map(Object.keys(XSAMPA).map(function (k) { return [k, XSAMPA[k]]; }));
  var XS_MAXLEN = 4;
  XS_MAP.forEach(function (_v, k) { if (k.length > XS_MAXLEN) throw new Error('X-SAMPA-Schluessel zu lang: ' + k); });

  /** X-SAMPA nach IPA: gieriges Longest-Match (max. 4 Zeichen), Unbekanntes bleibt unveraendert. */
  function xsampaToIpa(input) {
    var s = String(input == null ? '' : input);
    var out = '';
    var i = 0;
    while (i < s.length) {
      var hit = false;
      for (var len = Math.min(XS_MAXLEN, s.length - i); len >= 1; len--) {
        var key = s.substr(i, len);
        if (XS_MAP.has(key)) { out += XS_MAP.get(key); i += len; hit = true; break; }
      }
      if (!hit) { out += s.charAt(i); i += 1; }
    }
    return out;
  }

  // Rueckwaerts-Tabelle: IPA-Zeichen -> alle X-SAMPA-Schluessel, kuerzester zuerst.
  function keyRank(a, b) {
    if (a.length !== b.length) return a.length - b.length;
    var pa = (a.match(/[^A-Za-z0-9_]/g) || []).length;
    var pb = (b.match(/[^A-Za-z0-9_]/g) || []).length;
    if (pa !== pb) return pa - pb;
    return a < b ? -1 : a > b ? 1 : 0;
  }
  var REVERSE = new Map();
  XS_MAP.forEach(function (v, k) {
    if (v === '' || /^\s+$/.test(v)) return;
    if (!REVERSE.has(v)) REVERSE.set(v, []);
    REVERSE.get(v).push(k);
  });
  REVERSE.forEach(function (keys) { keys.sort(keyRank); });

  /** Kuerzester X-SAMPA-Code fuer ein IPA-Zeichen oder eine Zeichenfolge; null, wenn keiner existiert. */
  function xsampaFor(ins) {
    if (REVERSE.has(ins)) return REVERSE.get(ins)[0];
    var chars = Array.from(ins);
    if (chars.length < 2) return null;
    var code = '';
    for (var i = 0; i < chars.length; i++) {
      var k = REVERSE.get(chars[i]);
      if (!k) return null;
      code += k[0];
    }
    return xsampaToIpa(code) === ins ? code : null;   // nur anzeigen, wenn die Rueckkonvertierung stimmt
  }
  /** Alle X-SAMPA-Codes fuer ein Einzelzeichen (fuer die Suche). */
  function xsampaKeysFor(ins) {
    if (REVERSE.has(ins)) return REVERSE.get(ins).slice();
    var one = xsampaFor(ins);
    return one ? [one] : [];
  }

  /* ------------------------------------------------------------------ */
  /* Hilfsfunktionen fuer Items                                          */
  /* ------------------------------------------------------------------ */
  function codepoints(ins) {
    return Array.from(ins).map(function (c) {
      var h = c.codePointAt(0).toString(16).toUpperCase();
      while (h.length < 4) h = '0' + h;
      return 'U+' + h;
    });
  }

  var MARK = cp(0x25CC);       // ◌

  /** kind: 'letter' | 'combining' (Kombinationszeichen) | 'modifier' (Modifikatorbuchstabe) */
  function makeItem(ins, name, kind) {
    kind = kind || (RE_MARK.test(ins) ? 'combining' : 'letter');
    return {
      ins: ins,
      show: kind === 'letter' ? ins : MARK + ins,
      name: name,
      kind: kind
    };
  }

  var BY_INS = new Map();    // erstes Vorkommen gewinnt
  function reg(item) { if (!BY_INS.has(item.ins)) BY_INS.set(item.ins, item); return item; }
  function canon(item) { return BY_INS.get(item.ins) || reg(item); }

  /* ------------------------------------------------------------------ */
  /* Pulmonale Konsonanten                                               */
  /* ------------------------------------------------------------------ */
  var PLACES = ['bilab.', 'labiodent.', 'dent.', 'alv.', 'postalv.', 'retrofl.', 'palat.', 'velar', 'uvular', 'pharyng.', 'glottal'];
  var PLACE_ADJ = ['bilabialer', 'labiodentaler', 'dentaler', 'alveolarer', 'postalveolarer', 'retroflexer', 'palataler', 'velarer', 'uvularer', 'pharyngaler', 'glottaler'];

  // Zellformat "stimmlos|stimmhaft"; "3:" = Zelle ueber dental+alveolar+postalveolar; "X" = unmoeglich; "" = leer
  var CONS_ROWS = [
    { label: 'Plosiv', noun: 'Plosiv', cells: ['p|b', '', '3:t|d', 'ʈ|ɖ', 'c|ɟ', 'k|' + G, 'q|ɢ', 'X', 'ʔ|'] },
    { label: 'Nasal', noun: 'Nasal', cells: ['|m', '|ɱ', '3:|n', '|ɳ', '|ɲ', '|ŋ', '|ɴ', 'X', 'X'] },
    { label: 'Vibrant', noun: 'Vibrant', cells: ['|ʙ', '', '3:|r', '', '', 'X', '|ʀ', '', 'X'] },
    { label: 'Tap/Flap', noun: 'Tap', cells: ['', '|ⱱ', '3:|ɾ', '|ɽ', '', 'X', '', '', 'X'] },
    { label: 'Frikativ', noun: 'Frikativ', cells: ['ɸ|β', 'f|v', 'θ|ð', 's|z', 'ʃ|ʒ', 'ʂ|ʐ', 'ç|ʝ', 'x|ɣ', 'χ|ʁ', 'ħ|ʕ', 'h|ɦ'] },
    { label: 'lat. Frikativ', noun: 'lateraler Frikativ', cells: ['X', 'X', '3:ɬ|ɮ', '', '', '', '', 'X', 'X'] },
    { label: 'Approximant', noun: 'Approximant', cells: ['', '|ʋ', '3:|ɹ', '|ɻ', '|j', '|ɰ', '', '', ''] },
    { label: 'lat. Approx.', noun: 'lateraler Approximant', cells: ['X', 'X', '3:|l', '|ɭ', '|ʎ', '|ʟ', '', 'X', 'X'] }
  ];
  var CONS_NAME_OVERRIDE = {
    'ʔ': 'glottaler Plosiv (Glottisverschluss, Knacklaut)',
    'ɾ': 'stimmhafter alveolarer Tap/Flap',
    'ⱱ': 'stimmhafter labiodentaler Flap'
  };

  function buildConsonants() {
    var flat = [];
    var rows = CONS_ROWS.map(function (row) {
      var col = 0;
      var cells = [];
      row.cells.forEach(function (raw) {
        var span = 1;
        var s = raw;
        if (s.indexOf('3:') === 0) { span = 3; s = s.slice(2); }
        var cell = { col: col, span: span };
        if (s === 'X') {
          cell.type = 'na';
        } else if (s === '') {
          cell.type = 'empty';
        } else {
          cell.type = 'cell';
          var parts = s.split('|');
          var adj = PLACE_ADJ[col + (span === 3 ? 1 : 0)];
          var mk = function (sym, voiced) {
            if (!sym) return null;
            var name = CONS_NAME_OVERRIDE[sym] || ((voiced ? 'stimmhafter ' : 'stimmloser ') + adj + ' ' + row.noun);
            var item = reg(makeItem(sym, name, 'letter'));
            flat.push(item);
            return item;
          };
          cell.voiceless = mk(parts[0], false);
          cell.voiced = mk(parts[1], true);
        }
        cells.push(cell);
        col += span;
      });
      if (col !== PLACES.length) throw new Error('Konsonantenzeile "' + row.label + '" hat ' + col + ' statt ' + PLACES.length + ' Spalten');
      return { label: row.label, noun: row.noun, cells: cells };
    });
    return { places: PLACES.slice(), rows: rows, items: flat };
  }

  /* ------------------------------------------------------------------ */
  /* Vokale                                                              */
  /* ------------------------------------------------------------------ */
  var VOWEL_COLS = ['vorne', 'zentral', 'hinten'];
  var VOWEL_NOUNS = ['Vorderzungenvokal', 'Zentralvokal', 'Hinterzungenvokal'];
  // Zellformat "ungerundet|gerundet"; in short steckt ein weiches Trennzeichen (U+00AD), damit das Etikett umbrechen darf
  var VOWEL_ROWS = [
    { label: 'geschlossen', short: 'geschl.', adj: 'geschlossener', cells: ['i|y', 'ɨ|ʉ', 'ɯ|u'] },
    { label: 'fast geschlossen', short: 'f. geschl.', adj: 'fast geschlossener', cells: ['ɪ|ʏ', '', '|ʊ'] },
    { label: 'halbgeschlossen', short: 'halb' + cp(0x00AD) + 'geschl.', adj: 'halbgeschlossener', cells: ['e|ø', 'ɘ|ɵ', 'ɤ|o'] },
    { label: 'mittel', short: 'mittel', adj: 'mittlerer', cells: ['', 'ə|', ''] },
    { label: 'halboffen', short: 'halboffen', adj: 'halboffener', cells: ['ɛ|œ', 'ɜ|ɞ', 'ʌ|ɔ'] },
    { label: 'fast offen', short: 'f. offen', adj: 'fast offener', cells: ['æ|', 'ɐ|', ''] },
    { label: 'offen', short: 'offen', adj: 'offener', cells: ['a|ɶ', '', 'ɑ|ɒ'] }
  ];
  var VOWEL_NAME_OVERRIDE = {
    'ə': 'Schwa – mittlerer Zentralvokal',
    'ɐ': 'fast offener Zentralvokal (a-Schwa)'
  };

  function buildVowels() {
    var flat = [];
    var rows = VOWEL_ROWS.map(function (row) {
      var cells = row.cells.map(function (raw, c) {
        var parts = raw === '' ? ['', ''] : raw.split('|');
        var mk = function (sym, rounded) {
          if (!sym) return null;
          var name = VOWEL_NAME_OVERRIDE[sym] || (row.adj + ' ' + (rounded ? 'gerundeter' : 'ungerundeter') + ' ' + VOWEL_NOUNS[c]);
          var item = reg(makeItem(sym, name, 'letter'));
          flat.push(item);
          return item;
        };
        return { unrounded: mk(parts[0], false), rounded: mk(parts[1], true) };
      });
      return { label: row.label, short: row.short, adj: row.adj, cells: cells };
    });
    return { columns: VOWEL_COLS.slice(), rows: rows, items: flat };
  }

  /* ------------------------------------------------------------------ */
  /* Affrikaten, nicht-pulmonal, andere Symbole                          */
  /* ------------------------------------------------------------------ */
  function affricates() {
    var pairs = [
      ['t', 's', 'stimmlose alveolare Affrikate'],
      ['d', 'z', 'stimmhafte alveolare Affrikate'],
      ['t', 'ʃ', 'stimmlose postalveolare Affrikate'],
      ['d', 'ʒ', 'stimmhafte postalveolare Affrikate'],
      ['p', 'f', 'stimmlose labiodentale Affrikate'],
      ['b', 'v', 'stimmhafte labiodentale Affrikate'],
      ['t', 'ɕ', 'stimmlose alveolopalatale Affrikate'],
      ['d', 'ʑ', 'stimmhafte alveolopalatale Affrikate'],
      ['ʈ', 'ʂ', 'stimmlose retroflexe Affrikate'],
      ['ɖ', 'ʐ', 'stimmhafte retroflexe Affrikate'],
      ['t', 'ɬ', 'stimmlose laterale Affrikate'],
      ['k', 'x', 'stimmlose velare Affrikate'],
      ['k', 'p', 'stimmloser labial-velarer Plosiv'],
      [G, 'b', 'stimmhafter labial-velarer Plosiv']
    ];
    var items = pairs.map(function (p) { return reg(makeItem(p[0] + TIE + p[1], p[2], 'letter')); });
    items.push(reg(makeItem(cp(0x0361), 'Ligaturbogen oben', 'combining')));
    items.push(reg(makeItem(cp(0x035C), 'Ligaturbogen unten', 'combining')));
    return items;
  }

  function nonPulmonic() {
    var L = function (c, name, kind) { return reg(makeItem(typeof c === 'number' ? cp(c) : c, name, kind || 'letter')); };
    return [
      {
        title: 'Klicks', items: [
          L(0x0298, 'bilabialer Klick'),
          L(0x01C0, 'dentaler Klick'),
          L(0x01C3, '(post)alveolarer Klick'),
          L(0x01C2, 'palatoalveolarer Klick'),
          L(0x01C1, 'alveolar-lateraler Klick')
        ]
      },
      {
        title: 'Implosive', items: [
          L('ɓ', 'stimmhafter bilabialer Implosiv'),
          L('ɗ', 'stimmhafter dentaler/alveolarer Implosiv'),
          L('ʄ', 'stimmhafter palataler Implosiv'),
          L('ɠ', 'stimmhafter velarer Implosiv'),
          L('ʛ', 'stimmhafter uvularer Implosiv')
        ]
      },
      {
        title: 'Ejektive', items: [
          L(0x02BC, 'Ejektiv-Zeichen', 'modifier'),
          L('p' + cp(0x02BC), 'bilabialer Ejektiv'),
          L('t' + cp(0x02BC), 'dentaler/alveolarer Ejektiv'),
          L('k' + cp(0x02BC), 'velarer Ejektiv'),
          L('s' + cp(0x02BC), 'alveolarer frikativer Ejektiv')
        ]
      }
    ];
  }

  function otherSymbols() {
    var rows = [
      ['ʍ', 'stimmloser labial-velarer Frikativ'],
      ['w', 'stimmhafter labial-velarer Approximant'],
      ['ɥ', 'stimmhafter labial-palataler Approximant'],
      ['ʜ', 'stimmloser epiglottaler Frikativ'],
      ['ʢ', 'stimmhafter epiglottaler Frikativ'],
      ['ʡ', 'epiglottaler Plosiv'],
      ['ɕ', 'stimmloser alveolopalataler Frikativ'],
      ['ʑ', 'stimmhafter alveolopalataler Frikativ'],
      ['ɺ', 'stimmhafter alveolarer lateraler Flap'],
      ['ɧ', 'gleichzeitig ʃ und x'],
      ['ɫ', 'velarisiertes (dunkles) l'],
      ['ɚ', 'rhotisches Schwa'],
      ['ɝ', 'rhotischer halboffener Zentralvokal'],
      [cp(0x1D7B), 'fast geschlossener ungerundeter Zentralvokal'],
      [cp(0x1D7F), 'fast geschlossener gerundeter Zentralvokal']
    ];
    return rows.map(function (r) { return reg(makeItem(r[0], r[1], 'letter')); });
  }

  /* ------------------------------------------------------------------ */
  /* Diakritika, Suprasegmentalia, Toene                                  */
  /* ------------------------------------------------------------------ */
  function fromCodes(list, forceModifier) {
    return list.map(function (e) {
      var ins = cp(e[0]);
      var kind = RE_MARK.test(ins) ? 'combining' : (forceModifier ? 'modifier' : 'letter');
      return reg(makeItem(ins, e[1], kind));
    });
  }

  function diacritics() {
    return fromCodes([
      [0x0325, 'stimmlos'],
      [0x030A, 'stimmlos (Ring oben, bei Unterlänge)'],
      [0x032C, 'stimmhaft'],
      [0x02B0, 'aspiriert'],
      [0x0339, 'stärker gerundet'],
      [0x031C, 'schwächer gerundet'],
      [0x031F, 'vorverlagert'],
      [0x0320, 'rückverlagert'],
      [0x0308, 'zentralisiert'],
      [0x033D, 'zur Mitte zentralisiert'],
      [0x0329, 'silbisch'],
      [0x030D, 'silbisch (oben)'],
      [0x032F, 'nicht silbisch'],
      [0x0311, 'nicht silbisch (oben)'],
      [0x02DE, 'rhotisch'],
      [0x0324, 'behaucht (breathy voice)'],
      [0x0330, 'knarrend (creaky voice)'],
      [0x033C, 'linguolabial'],
      [0x02B7, 'labialisiert'],
      [0x02B2, 'palatalisiert'],
      [0x02E0, 'velarisiert'],
      [0x02E4, 'pharyngalisiert'],
      [0x0334, 'velarisiert oder pharyngalisiert'],
      [0x031D, 'angehoben'],
      [0x031E, 'abgesenkt'],
      [0x0318, 'vorverlagerte Zungenwurzel (ATR)'],
      [0x0319, 'rückverlagerte Zungenwurzel (RTR)'],
      [0x032A, 'dental'],
      [0x033A, 'apikal'],
      [0x033B, 'laminal'],
      [0x0303, 'nasaliert'],
      [0x207F, 'nasale Lösung'],
      [0x02E1, 'laterale Lösung'],
      [0x031A, 'keine hörbare Lösung'],
      [0x1DBF, 'dentale frikative Lösung'],
      [0x02E3, 'velare frikative Lösung'],
      [0x1D4A, 'Schwa-Lösung']
    ], true);
  }

  function suprasegmentals() {
    return fromCodes([
      [0x02C8, 'Hauptakzent'],
      [0x02CC, 'Nebenakzent'],
      [0x02D0, 'lang'],
      [0x02D1, 'halblang'],
      [0x0306, 'extra kurz'],
      [0x007C, 'kleine Gruppe (Fuß)'],
      [0x2016, 'große Gruppe (Intonation)'],
      [0x002E, 'Silbengrenze'],
      [0x203F, 'Bindung']
    ], false);
  }

  function tones() {
    return fromCodes([
      [0x030B, 'extra hoch'],
      [0x0301, 'hoch'],
      [0x0304, 'mittel'],
      [0x0300, 'tief'],
      [0x030F, 'extra tief'],
      [0x030C, 'steigend'],
      [0x0302, 'fallend'],
      [0x1DC4, 'hoch steigend'],
      [0x1DC5, 'tief steigend'],
      [0x1DC8, 'steigend-fallend'],
      [0x02E5, 'extra hoch (Tonbuchstabe)'],
      [0x02E6, 'hoch (Tonbuchstabe)'],
      [0x02E7, 'mittel (Tonbuchstabe)'],
      [0x02E8, 'tief (Tonbuchstabe)'],
      [0x02E9, 'extra tief (Tonbuchstabe)'],
      [0xA71C, 'Downstep'],
      [0xA71B, 'Upstep'],
      [0x2197, 'globales Steigen'],
      [0x2198, 'globales Fallen']
    ], false);
  }

  /* ------------------------------------------------------------------ */
  /* Haeufig (DE/EN)                                                      */
  /* ------------------------------------------------------------------ */
  function frequent() {
    var NS = cp(0x032F);   // nicht silbisch
    var SY = cp(0x0329);   // silbisch
    var composite = {};
    composite['ɐ' + NS] = 'nicht silbisches ɐ (Diphthong-Glied)';
    composite['ɪ' + NS] = 'nicht silbisches ɪ (Diphthong-Glied)';
    composite['ʊ' + NS] = 'nicht silbisches ʊ (Diphthong-Glied)';
    composite['n' + SY] = 'silbisches n';
    composite['l' + SY] = 'silbisches l';
    var list = ['ə', 'ɐ', 'ɪ', 'ʊ', 'ʏ', 'ɛ', 'œ', 'ø', 'ɔ', 'a', 'ɑ', 'æ', 'ʌ', 'ɒ', 'ɜ',
      'ʃ', 'ʒ', 'ç', 'x', 'ʁ', 'ʀ', 'ɾ', 'ɹ', 'ŋ', cp(0x0294), 'θ', 'ð',
      't' + TIE + 's', 'p' + TIE + 'f', 't' + TIE + 'ʃ', 'd' + TIE + 'ʒ',
      'ɐ' + NS, 'ɪ' + NS, 'ʊ' + NS, 'n' + SY, 'l' + SY,
      cp(0x02D0), cp(0x02C8), cp(0x02CC)];
    return list.map(function (ins) {
      if (BY_INS.has(ins)) return BY_INS.get(ins);
      if (!composite[ins]) throw new Error('Kein Name fuer haeufiges Symbol ' + codepoints(ins).join(' '));
      return reg(makeItem(ins, composite[ins], 'letter'));
    });
  }

  /* ------------------------------------------------------------------ */
  /* Aufbau                                                              */
  /* ------------------------------------------------------------------ */
  var consonants = buildConsonants();
  var affr = affricates();
  var nonp = nonPulmonic();
  var other = otherSymbols();
  var vowels = buildVowels();
  var dia = diacritics();
  var sup = suprasegmentals();
  var ton = tones();
  var freq = frequent();

  var nonpFlat = [];
  nonp.forEach(function (g) { g.items.forEach(function (i) { nonpFlat.push(i); }); });

  var sections = [
    { id: 'haeufig', title: 'Häufig (DE/EN)', type: 'grid', items: freq },
    { id: 'recent', title: 'Zuletzt verwendet', type: 'recent', items: [] },
    { id: 'pulmonic', title: 'Pulmonale Konsonanten', type: 'consonants', table: consonants, items: consonants.items },
    { id: 'affricates', title: 'Affrikaten & Doppelartikulation', type: 'grid', items: affr },
    { id: 'nonpulmonic', title: 'Nicht-pulmonale Konsonanten', type: 'groups', groups: nonp, items: nonpFlat },
    { id: 'other', title: 'Andere Symbole', type: 'grid', items: other },
    { id: 'vowels', title: 'Vokale', type: 'vowels', table: vowels, items: vowels.items },
    { id: 'diacritics', title: 'Diakritika', type: 'grid', items: dia },
    { id: 'suprasegmentals', title: 'Suprasegmentalia', type: 'grid', items: sup },
    { id: 'tones', title: 'Töne & Wortakzente', type: 'grid', items: ton }
  ];

  // Alle eindeutigen Items in Anzeigereihenfolge (fuer Suche)
  var allItems = [];
  (function () {
    var seen = new Set();
    sections.forEach(function (s) {
      s.items.forEach(function (i) { if (!seen.has(i.ins)) { seen.add(i.ins); allItems.push(i); } });
    });
  })();

  /* ------------------------------------------------------------------ */
  /* Suche                                                               */
  /* ------------------------------------------------------------------ */
  function norm(s) { return s.normalize('NFC').toLowerCase(); }
  var SEARCH_INDEX = allItems.map(function (item) {
    return {
      item: item,
      name: norm(item.name),
      cps: codepoints(item.ins).map(function (c) { return parseInt(c.slice(2), 16); }),
      xs: xsampaKeysFor(item.ins)
    };
  });

  /** Sucht in Name, Symbol, X-SAMPA-Code (gross-/kleinschreibungsabhaengig) und Codepunkt ("U+0283" oder "0283"). */
  function search(query) {
    var q = String(query == null ? '' : query).trim();
    if (!q) return [];
    var qn = norm(q);
    var tokens = qn.split(/\s+/).filter(Boolean);
    var hex = /^(?:u\+)?([0-9a-f]{4,6})$/i.exec(q);
    var wantHex = null;
    if (hex && (/^u\+/i.test(q) || /[0-9]/.test(hex[1]))) wantHex = parseInt(hex[1], 16);
    var scored = [];
    SEARCH_INDEX.forEach(function (e, idx) {
      var score = Infinity;
      if (e.item.ins === q) score = 0;
      else if (e.item.ins.indexOf(q) !== -1) score = 1;
      if (e.xs.indexOf(q) !== -1) score = Math.min(score, 0);
      if (wantHex !== null && e.cps.indexOf(wantHex) !== -1) score = Math.min(score, 0);
      if (qn.length >= 2 && tokens.length && tokens.every(function (t) { return e.name.indexOf(t) !== -1; })) {
        var wordStart = tokens.every(function (t) { return (' ' + e.name).indexOf(' ' + t) !== -1; });
        score = Math.min(score, wordStart ? 2 : 3);
      }
      if (score !== Infinity) scored.push({ item: e.item, score: score, idx: idx });
    });
    scored.sort(function (a, b) { return a.score - b.score || a.idx - b.idx; });
    return scored.map(function (s) { return s.item; });
  }

  /* ------------------------------------------------------------------ */
  /* X-SAMPA-Spickzettel (Auswahl der haeufigsten Codes)                  */
  /* ------------------------------------------------------------------ */
  var CHEAT = ['S', 'Z', 'T', 'D', 'N', 'C', 'R', '?', '@', '6', 'E', 'I', 'U', 'Y', '2', '9', 'O', 'A',
    '{', 'V', 'Q', '3', ':', '"', '%', 'r\\', '4', 'j\\', 'h\\', 'L', '_', '~', '=', '_^', '_h', '_w'];

  var D = {
    version: '1.0',
    zeichen: { G: G, TIE: TIE, DOTTED_CIRCLE: MARK },
    sections: sections,
    allItems: allItems,
    itemByIns: function (ins) { return BY_INS.get(ins) || null; },
    consonants: consonants,
    vowels: vowels,
    xsampa: XSAMPA,
    xsampaMaxKeyLength: XS_MAXLEN,
    xsampaCheat: CHEAT,
    xsampaToIpa: xsampaToIpa,
    xsampaFor: xsampaFor,
    xsampaKeysFor: xsampaKeysFor,
    codepoints: codepoints,
    search: search,
    brackets: [
      { id: 'phonetisch', open: '[', close: ']', label: '[ ]', name: 'Phonetische Transkription [ ]' },
      { id: 'phonemisch', open: '/', close: '/', label: '/ /', name: 'Phonemische Transkription / /' },
      { id: 'graphemisch', open: cp(0x27E8), close: cp(0x27E9), label: cp(0x27E8) + ' ' + cp(0x27E9), name: 'Graphemische Notation ' + cp(0x27E8) + ' ' + cp(0x27E9) }
    ]
  };

  root.IPA_DATA = D;
  if (typeof module !== 'undefined' && module.exports) module.exports = D;
})(typeof window !== 'undefined' ? window : globalThis);
