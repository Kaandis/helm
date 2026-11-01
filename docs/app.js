(() => {
  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
  const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)');
  const store = {
    get(key) { try { return localStorage.getItem(key); } catch { return null; } },
    set(key, value) { try { localStorage.setItem(key, value); } catch { /* private mode */ } },
  };

  // English lives in the HTML (what search engines index); Turkish is applied on top.
  const TR = {
    'nav.free': 'Ücretsiz',
    'nav.how': 'Nasıl çalışır',
    'nav.faq': 'SSS',
    'hero.line1': 'Sürükle, tuşa bas,',
    'hero.line2': 'bırak.',
    'hero.lead': 'Helm dosyalarını sürüklediğin yerde dönüştürür, küçültür ve gönderir. İşaretçinin altında bir araç çarkı açılır; önce hiçbir şey açman gerekmez.',
    'hero.download': 'Ücretsiz indir',
    'hero.github': 'GitHub’da yıldızla',
    'mb.file': 'Dosya', 'mb.edit': 'Düzen', 'mb.view': 'Görüntü', 'mb.go': 'Git', 'mb.window': 'Pencere',
    'note.t': 'Dene',
    'note.d': 'Bir dosyayı sürükle ve tüm araçları görmek için sağa sola salla, ya da tek bir çark için ⇧, ⌘, ⌃ tuşuna bas (veya aşağıdan seç). Bir aracın üstüne bırak.',
    'k.convert': 'Dönüştür', 'k.tools': 'Araçlar', 'k.actions': 'Eylemler',
    'demo.hint': 'Gerçekten çalışıyor: sürüklerken dosyayı salla, bir tuşa bas ya da önce buradan bir çark seç. Kes’i dene, sonra rafı Projects’in üstüne sürükle. Dock’ta yalnızca Harbor uygulamaları var.',
    'how.title': 'Dosyaların, gitmeleri gereken yere.',
    'f1.t': 'Zaten olduğun yerde', 'f1.d': 'Finder’da ya da masaüstünde sürüklemeye başla ve bir tuşa bas. Açılacak uygulama, aranacak pencere yok.',
    'f2.t': 'Her şey için salla', 'f2.d': 'Uyan tüm araçları görmek için sürüklerken salla, ya da yalnızca Dönüştür, Araçlar veya Eylemler için ⇧, ⌘, ⌃ tuşuna bas.',
    'f3.t': 'Sonunda Kes', 'f3.d': 'Finder’da hiç olmadı. Kesilen dosyalar, sen rafı bir klasöre sürükleyene ya da orada ⌥⌘V’ye basana kadar rafta bekler.',
    'f4.t': 'İzin yok, çevrimdışı', 'f4.d': 'Helm yalnızca sürüklemeyi ve bastığın tuşları okur. Her şey Mac’inde çalışır; sürüklemeler arasında hiçbir şey çalışmaz.',
    'list.title': 'Çarklarda neler var',
    'list.convert': 'Fotoğrafları JPG, PNG, HEIC, PDF ya da TIFF’e. PDF sayfalarını PNG ya da JPG’ye. Videoları MP4, MOV, GIF’e ya da seslerine. Sesleri M4A, WAV ya da AIFF’e.',
    'list.tools': 'Fotoğrafları sıkıştır, yarıya indir ya da bilgilerini sil, arka planı sil, metnini kopyala, tek PDF yap, QR kod oku. PDF’leri birleştir, böl, sıkıştır ya da metnini kopyala. Videoları sıkıştır ya da sesini kaldır. Arşivleri aç.',
    'list.actions': 'Kes, AirDrop, yolu kopyala, Mail, zip’le, orada Terminal aç ya da bir görseli her yere yapıştırmak için kopyala.',
    'cta.title': 'Ücretsiz. Hızlı. Elinin altında.',
    'cta.lead': 'Hesap yok, takip yok, izin yok.',
    'cta.note': 'macOS 15 veya üstü. Zip’i aç, Helm’i Uygulamalar’a taşı; ilk seferde sağ tıklayıp Aç’ı seç.',
    'faq.title': 'Sorular',
    'q1.q': '⌘’ye basmak dosyayı taşımaz mı?', 'q1.a': 'Yalnızca başka bir Finder klasörüne bırakırsan. Helm’in çarkına bırakılan dosya yalnızca okunur; orijinal yerinde kalır, sonuç yanına gelir.',
    'q2.q': 'Helm hangi izinleri istiyor?', 'q2.a': 'Hiçbirini. Sürüklemeyi sistemin sürükleme panosundan ve değiştirici tuşlardan fark eder; bunları her uygulama okuyabilir. Erişilebilirlik, Ekran Kaydı ya da Tam Disk Erişimi yok.',
    'q3.q': 'Başka uygulamaların yoluna çıkar mı?', 'q3.a': 'Menü yalnızca bir dosya sürüklemesini salladığında ya da sürüklerken çark tuşuna bastığında açılır. Tam ekran uygulamalarda hiç açılmaz; sürükleme kısayolları çakışan uygulamalar için kapatabilir, tuşları değiştirebilir ya da menü çubuğundan Helm’i duraklatabilirsin.',
    'q7.q': 'Kes nasıl çalışıyor?', 'q7.a': 'Dosyaları Kes’e bırak, köşedeki küçük bir rafta dokunulmadan beklesinler. Rafı herhangi bir klasöre sürükleyince oraya taşınırlar, ya da o klasörde ⌥⌘V’ye bas. Rafı kapatırsan hiçbir şey taşınmaz.',
    'q4.q': 'Buluta bir şey gidiyor mu?', 'q4.a': 'Hayır. Arka plan silme ve metin okuma, Mac’inde zaten olan modelleri kullanır; Önizleme ve Fotoğraflar’ın kullandıklarının aynısı. Helm’in hesabı yok, hiçbir yere bir şey göndermez.',
    'q5.q': 'Fotoğraflar’dan sürükleyince çark açılmıyor.', 'q5.a': 'Fotoğraflar ve Mail, yalnızca bırakılınca oluşan söz verilmiş dosyalar sürükler. Önce masaüstüne sürükle, sonra Helm’i onlarda kullan.',
    'q6.q': 'macOS açılamıyor diyor.', 'q6.a': 'Sürümler henüz notarize edilmedi. Helm’e sağ tıklayıp Aç’ı seç ya da şunu çalıştır: <code>xattr -dr com.apple.quarantine /Applications/Helm.app</code>',
    'footer.license': 'MIT Lisansı',
    'footer.disclaimer': 'Helm bağımsız bir projedir; Apple Inc. ile bağlantılı değildir, Apple tarafından onaylanmamış veya desteklenmemiştir. Mac ve macOS, Apple Inc.’in ABD’de ve diğer ülkelerde tescilli ticari markalarıdır.',
  };
  // Words the demo builds at runtime.
  const WORDS = {
    en: {
      convert: 'Convert', tools: 'Tools', actions: 'Actions', nothing: 'Nothing here',
      compress: 'Compress', half: 'Half Size', clean: 'Strip Metadata', makePDF: 'Make PDF', readQR: 'Read QR',
      merge: 'Merge', split: 'Split Pages', mute: 'Mute', extract: 'Extract', copyPath: 'Copy Path', terminal: 'Terminal', zip: 'Zip',
      sCompressed: 'compressed', sHalf: 'half', sClean: 'clean', sMuted: 'muted', sPages: 'pages', images: 'Images',
      noQR: 'No QR code found', pathCopied: 'Path copied', airdrop: 'AirDrop opens with', termOpen: 'Terminal opens on the Desktop',
      pick: 'Shake it, or hold ⇧, ⌘ or ⌃', desktop: 'Desktop',
      cut: 'Cut', mail: 'Mail', copyImage: 'Copy Image', copyText: 'Copy Text', removeBG: 'Remove Background', sCutout: 'cutout',
      mailOpen: 'Mail opens a new message', imageCopied: 'Image copied', textCopied: 'Text copied, 3 lines',
      cutDone: 'Drag the shelf onto a folder', items: 'items', itemsMoved: 'items moved', moved: 'Moved', shelfHint: 'Drag onto a folder to move',
      allTools: 'All Tools',
    },
    tr: {
      convert: 'Dönüştür', tools: 'Araçlar', actions: 'Eylemler', nothing: 'Burada araç yok',
      compress: 'Sıkıştır', half: 'Yarı Boyut', clean: 'Bilgileri Sil', makePDF: 'PDF Yap', readQR: 'QR Oku',
      merge: 'Birleştir', split: 'Sayfalara Böl', mute: 'Sesi Kaldır', extract: 'Aç', copyPath: 'Yolu Kopyala', terminal: 'Terminal', zip: 'Zip’le',
      sCompressed: 'sıkıştırılmış', sHalf: 'yarım', sClean: 'temiz', sMuted: 'sessiz', sPages: 'sayfaları', images: 'Görseller',
      noQR: 'QR kod bulunamadı', pathCopied: 'Yol kopyalandı', airdrop: 'AirDrop şununla açılır:', termOpen: 'Terminal Masaüstü’nde açılır',
      pick: 'Salla ya da ⇧, ⌘, ⌃ tuşuna bas', desktop: 'Masaüstü',
      cut: 'Kes', mail: 'Mail', copyImage: 'Görseli Kopyala', copyText: 'Metni Kopyala', removeBG: 'Arka Planı Sil', sCutout: 'dekupe',
      mailOpen: 'Mail yeni bir ileti açar', imageCopied: 'Görsel kopyalandı', textCopied: 'Metin kopyalandı, 3 satır',
      cutDone: 'Rafı bir klasörün üstüne sürükle', items: 'öğe', itemsMoved: 'öğe taşındı', moved: 'Taşındı', shelfHint: 'Taşımak için bir klasöre sürükle',
      allTools: 'Tüm Araçlar',
    },
  };

  const nodes = $$('[data-i18n]');
  const EN = Object.fromEntries(nodes.map((n) => [n.dataset.i18n, n.innerHTML]));
  const langButton = $('#lang');
  let lang = 'en';
  const w = (key) => WORDS[lang][key];

  function setLanguage(next) {
    lang = next;
    nodes.forEach((n) => { n.innerHTML = (next === 'tr' ? TR : EN)[n.dataset.i18n] ?? EN[n.dataset.i18n]; });
    document.documentElement.lang = next;
    langButton.textContent = next === 'tr' ? 'EN' : 'TR';
    langButton.setAttribute('aria-label', next === 'tr' ? 'Switch to English' : 'Türkçeye geç');
    $('#desk').setAttribute('aria-label', w('desktop'));
    store.set('lang', next);
    tickClock();
  }

  // The Mac is built at 960×600 and scaled to fit.
  const frame = $('#macFrame');
  const mac = $('#mac');
  let k = 1;
  function fit() {
    const pad = parseFloat(getComputedStyle(frame).paddingLeft);
    k = (frame.clientWidth - pad * 2) / 960;
    mac.style.transform = `scale(${k})`;
    frame.style.height = `${600 * k + pad * 2}px`;
  }
  addEventListener('resize', fit);
  fit();
  // Pointer position in the Mac's own 960×600 space.
  function local(e) {
    const box = mac.getBoundingClientRect();
    return { x: (e.clientX - box.left) / k, y: (e.clientY - box.top) / k };
  }

  const nav = $('#nav');
  const onScroll = () => nav.classList.toggle('scrolled', scrollY > 8);
  addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  function tickClock() {
    const now = new Date();
    const locale = lang === 'tr' ? 'tr-TR' : 'en-US';
    $('#menuClock').textContent = `${now.toLocaleDateString(locale, { weekday: 'short' })} ${now.toLocaleTimeString(locale, { hour: 'numeric', minute: '2-digit' })}`;
  }
  setInterval(tickClock, 10_000);

  // ---------- The desktop ----------

  const desk = $('#desk');
  const files = [
    { name: 'Beach', ext: 'heic', type: 'image' },
    { name: 'Report', ext: 'pdf', type: 'pdf' },
    { name: 'Trip', ext: 'mov', type: 'video' },
    { name: 'Projects', ext: '', type: 'folder' },
  ];
  const ROWS = 5;
  const slot = (i) => ({ x: 960 - 62 - Math.floor(i / ROWS) * 100, y: 82 + (i % ROWS) * 92 });
  const fullName = (f) => (f.ext ? `${f.name}.${f.ext}` : f.name);

  function iconHTML(f) {
    const label = f.type === 'image' || f.type === 'folder' ? '' : `<em>${(f.ext || '').toUpperCase()}</em>`;
    return `<span class="fi fi-${f.type}">${label}</span>`;
  }
  function render() {
    desk.innerHTML = files.map((f, i) => {
      const p = slot(i);
      return `<button class="desk-file${f.fresh ? ' fresh' : ''}${f.cut ? ' cut' : ''}" type="button" role="listitem" data-i="${i}" style="left:${p.x}px;top:${p.y}px" aria-label="${fullName(f)}">${iconHTML(f)}<span class="fname">${fullName(f)}</span></button>`;
    }).join('');
  }
  function unique(name, ext) {
    let candidate = name;
    for (let n = 2; files.some((f) => f.name === candidate && f.ext === ext); n++) candidate = `${name} ${n}`;
    return candidate;
  }
  render();

  // ---------- Tools, as in the app ----------

  const T = (id, label, glyph, run) => ({ id, label, glyph, run });
  const conv = (ext, glyph, type = 'image') => T(`to-${ext}`, ext.toUpperCase(), glyph, (f) => ({ out: [{ name: f.name, ext, type }] }));
  function toolsFor(kind, f) {
    const list = (() => {
      if (kind === 'actions') {
        return [
          T('cut', w('cut'), 'g-scissors', () => ({ cut: true })),
          T('airdrop', 'AirDrop', 'g-airdrop', (x) => ({ msg: `${w('airdrop')} ${fullName(x)}` })),
          T('path', w('copyPath'), 'g-link', () => ({ msg: w('pathCopied') })),
          T('mail', w('mail'), 'g-mail', () => ({ msg: w('mailOpen') })),
          T('zip', w('zip'), 'g-zip', (x) => ({ out: [{ name: x.name, ext: 'zip', type: 'zip' }] })),
          T('term', w('terminal'), 'g-term', () => ({ msg: w('termOpen') })),
        ].concat(f.type === 'image' ? [T('copyimg', w('copyImage'), 'g-photos', () => ({ msg: w('imageCopied') }))] : []);
      }
      const suffix = (x, s, ext = x.ext, type = x.type) => ({ out: [{ name: `${x.name} ${w(s)}`, ext, type }] });
      if (kind === 'convert') {
        switch (f.type) {
          case 'image': return [conv('jpg', 'g-photo'), conv('png', 'g-photo'), conv('heic', 'g-photo'), conv('pdf', 'g-doc', 'pdf'), conv('tiff', 'g-photo')];
          case 'pdf': return ['png', 'jpg'].map((ext) => T(`pages-${ext}`, ext.toUpperCase(), 'g-photo', (x) => ({ out: [{ name: `${x.name} ${w('sPages')}`, ext: '', type: 'folder' }] })));
          case 'video': return [conv('mp4', 'g-film', 'video'), conv('mov', 'g-film', 'video'), conv('gif', 'g-gif', 'image'), conv('m4a', 'g-wave', 'audio')];
          case 'audio': return [conv('m4a', 'g-wave', 'audio'), conv('wav', 'g-wave', 'audio'), conv('aiff', 'g-wave', 'audio')];
          default: return [];
        }
      }
      const copyText = T('text', w('copyText'), 'g-text', () => ({ msg: w('textCopied') }));
      switch (f.type) {
        case 'image': return [
          T('compress', w('compress'), 'g-shrink', (x) => suffix(x, 'sCompressed', x.ext === 'png' ? 'jpg' : x.ext)),
          T('half', w('half'), 'g-half', (x) => suffix(x, 'sHalf')),
          T('clean', w('clean'), 'g-clean', (x) => suffix(x, 'sClean')),
          T('cutout', w('removeBG'), 'g-subject', (x) => suffix(x, 'sCutout', 'png', 'cutout')),
          copyText,
          T('makepdf', w('makePDF'), 'g-doc', () => ({ out: [{ name: w('images'), ext: 'pdf', type: 'pdf' }] })),
          T('qr', w('readQR'), 'g-qr', () => ({ msg: w('noQR') })),
        ];
        case 'pdf': return [
          T('compress', w('compress'), 'g-shrink', (x) => suffix(x, 'sCompressed')),
          T('split', w('split'), 'g-split', (x) => ({ out: [{ name: x.name, ext: '', type: 'folder' }] })),
          copyText,
        ];
        case 'video': return [
          T('compress', w('compress'), 'g-shrink', (x) => suffix(x, 'sCompressed', 'mp4')),
          T('mute', w('mute'), 'g-mute', (x) => suffix(x, 'sMuted')),
        ];
        case 'zip': return [T('extract', w('extract'), 'g-box', (x) => ({ out: [{ name: x.name, ext: '', type: 'folder' }] }))];
        default: return [];
      }
    })();
    // Never offer the format the file is already in.
    return list.filter((t) => !(kind === 'convert' && t.id === `to-${f.ext}`));
  }
  const KINDS = ['convert', 'tools', 'actions'];
  const KEYS = { convert: '⇧', tools: '⌘', actions: '⌃' };

  // ---------- The helm: one wheel, or every tool after a shake ----------

  const SIZES = { wheel: { outer: 138, inner: 50 }, all: { outer: 168, inner: 62 } };
  const HANDLE = 13;
  const wheel = $('#wheel');
  const ringSvg = $('#wheelRing');
  const sectors = $('#wheelSectors');
  const labels = $('#wheelLabels');
  let menu = null; // { mode: 'wheel'|'all', kind, tools, groups, file, cx, cy, hovered, size }

  const polar = (r, a) => `${(r * Math.cos(a)).toFixed(2)} ${(r * Math.sin(a)).toFixed(2)}`;
  // Slices `first` to `last`, angles clockwise from the top.
  function arc(first, last, n, r0, r1) {
    const width = (2 * Math.PI) / n;
    const a0 = -Math.PI / 2 + (first - 0.5) * width + 0.012, a1 = -Math.PI / 2 + (last + 0.5) * width - 0.012;
    const large = a1 - a0 > Math.PI ? 1 : 0;
    return `M${polar(r1, a0)} A${r1} ${r1} 0 ${large} 1 ${polar(r1, a1)} L${polar(r0, a1)} A${r0} ${r0} 0 ${large} 0 ${polar(r0, a0)} Z`;
  }
  const boundary = (i, n) => -Math.PI / 2 + (i + 0.5) * (2 * Math.PI) / n;
  const legendHTML = (kind) => KINDS.map((key) => `<span class="${key === kind ? 'on' : ''}"><kbd>${KEYS[key]}</kbd>${w(key)}</span>`).join('');
  function hoveredGroup() {
    const h = menu?.hovered;
    return h == null ? null : menu.groups.find((g) => h >= g.first && h <= g.last)?.kind ?? null;
  }
  function drawWheel() {
    const { mode, kind, tools, file, groups } = menu;
    const { outer, inner } = menu.size;
    const R = outer + HANDLE + 4;
    const n = tools.length;
    wheel.style.width = wheel.style.height = `${R * 2}px`;
    wheel.style.margin = `${-R}px 0 0 ${-R}px`;
    wheel.classList.toggle('full', mode === 'all');
    ringSvg.setAttribute('viewBox', `${-R} ${-R} ${R * 2} ${R * 2}`);
    // Handles past the rim: one per gap on a small wheel, eight on the big helm.
    const spots = mode === 'all' || n < 3
      ? Array.from({ length: 8 }, (_, i) => ({ a: -Math.PI / 2 + i * Math.PI / 4, major: i === 0 }))
      : tools.map((_, i) => ({ a: boundary(i, n), major: false }));
    sectors.innerHTML = spots.map((s) => `<line class="handle${s.major ? ' major' : ''}" x1="${outer * Math.cos(s.a)}" y1="${outer * Math.sin(s.a)}" x2="${(outer + HANDLE - (s.major ? 0 : 3)) * Math.cos(s.a)}" y2="${(outer + HANDLE - (s.major ? 0 : 3)) * Math.sin(s.a)}"/>`).join('')
      + `<path class="ring" fill-rule="evenodd" d="M${outer} 0A${outer} ${outer} 0 1 1 -${outer} 0A${outer} ${outer} 0 1 1 ${outer} 0ZM${inner} 0A${inner} ${inner} 0 1 0 -${inner} 0A${inner} ${inner} 0 1 0 ${inner} 0Z"/>`
      + (mode === 'all' ? groups.filter((_, i) => i % 2 === 1).map((g) => `<path class="group" d="${arc(g.first, g.last, n, inner + 1, outer - 2)}"/>`).join('') : '')
      + tools.map((_, i) => `<path class="sector" data-i="${i}" d="${arc(i, i, n, inner + 4, outer - 5)}"/>`).join('')
      + (n > 1 ? tools.map((_, i) => `<line class="spoke" x1="${(inner + 10) * Math.cos(boundary(i, n))}" y1="${(inner + 10) * Math.sin(boundary(i, n))}" x2="${(outer - 10) * Math.cos(boundary(i, n))}" y2="${(outer - 10) * Math.sin(boundary(i, n))}"/>`).join('') : '')
      + `<circle class="rim" r="${outer - 1.25}"/>`;
    const radius = (inner + outer) / 2 + (mode === 'all' ? 2 : 0);
    labels.innerHTML = tools.map((t, i) => {
      const a = -Math.PI / 2 + i * (2 * Math.PI) / n;
      // The big helm shows icons only; the hub names the one you're on.
      return `<span class="wl" data-i="${i}" style="left:${R + radius * Math.cos(a)}px;top:${R + radius * Math.sin(a)}px" aria-label="${t.label}"><svg><use href="#${t.glyph}"/></svg>${mode === 'all' ? '' : t.label}</span>`;
    }).join('');
    const hub = $('.hub', wheel);
    hub.style.width = hub.style.height = `${inner * 2}px`;
    hub.style.margin = `${-inner}px 0 0 ${-inner}px`;
    $('#legend').innerHTML = legendHTML(kind);
    drawHub();
  }
  function drawHub() {
    const { mode, kind, tools, file } = menu;
    const on = mode === 'all' && menu.hovered != null ? tools[menu.hovered] : null;
    $('.hub', wheel).classList.toggle('naming', !!on);
    $('#hubTop').textContent = on ? on.label : tools.length ? (file.ext || '').toUpperCase() || '—' : '';
    $('#hubSub').textContent = on ? w(hoveredGroup()) : tools.length ? (mode === 'all' ? w('allTools') : w(kind)) : w('nothing');
  }
  function highlight() {
    const h = menu?.hovered;
    $$('.sector', sectors).forEach((s) => s.classList.toggle('on', Number(s.dataset.i) === h));
    $$('.wl', labels).forEach((s) => s.classList.toggle('on', Number(s.dataset.i) === h));
    if (menu?.mode === 'all') { $('#legend').innerHTML = legendHTML(hoveredGroup()); drawHub(); }
  }
  // `kind` is a wheel, or 'all' for the big helm.
  function openMenu(kind, file, at) {
    const mode = kind === 'all' ? 'all' : 'wheel';
    const reseat = !menu || menu.mode !== mode;
    let tools = [], groups = [];
    if (mode === 'all') {
      KINDS.forEach((k) => {
        const list = toolsFor(k, file);
        if (list.length) groups.push({ kind: k, first: tools.length, last: tools.length + list.length - 1 });
        tools = tools.concat(list);
      });
    } else {
      tools = toolsFor(kind, file);
    }
    menu = { mode, kind, file, tools, groups, cx: menu?.cx, cy: menu?.cy, hovered: null, size: SIZES[mode] };
    drawWheel();
    if (reseat) {
      // Centred on the pointer, kept inside the screen.
      const R = menu.size.outer + HANDLE + 4;
      menu.cx = Math.min(Math.max(at.x, R + 8), 960 - R - 8);
      menu.cy = Math.min(Math.max(at.y, 28 + R), 600 - R - 44);
      wheel.style.left = `${menu.cx}px`;
      wheel.style.top = `${menu.cy}px`;
      wheel.style.transformOrigin = `${R + at.x - menu.cx}px ${R + at.y - menu.cy}px`;
    }
    wheel.classList.add('open');
    highlight();
  }
  function closeMenu() {
    wheel.classList.remove('open');
    menu = null;
  }
  function indexAt(p) {
    if (!menu || !menu.tools.length) return null;
    const dx = p.x - menu.cx, dy = p.y - menu.cy;
    const d = Math.hypot(dx, dy);
    if (d <= menu.size.inner || d >= menu.size.outer + HANDLE) return null;
    let a = Math.atan2(dx, -dy);
    if (a < 0) a += 2 * Math.PI;
    const width = (2 * Math.PI) / menu.tools.length;
    return Math.floor((a + width / 2) / width) % menu.tools.length;
  }

  // ---------- Which menu ----------

  // A key held on the keyboard wins, then the wheel picked below; after a
  // shake, the big helm; a wheel opened by a key stays open after it.
  let picked = null;
  const held = { shift: false, meta: false, ctrl: false };
  function heldKind() {
    const down = Object.entries(held).filter(([, v]) => v).map(([key]) => key);
    if (down.length !== 1) return null;
    return { shift: 'convert', meta: 'tools', ctrl: 'actions' }[down[0]];
  }
  function syncKeys(e) {
    held.shift = e.shiftKey; held.meta = e.metaKey; held.ctrl = e.ctrlKey;
  }
  $$('.wheel-keys .try').forEach((b) => {
    b.addEventListener('click', () => {
      picked = picked === b.dataset.kind ? null : b.dataset.kind;
      $$('.wheel-keys .try').forEach((x) => x.setAttribute('aria-pressed', String(x.dataset.kind === picked)));
    });
  });

  // Three quick turns, each after 40 points of travel, within a second.
  function shakeDetector() {
    let extreme = null, direction = 0, turns = [];
    return (x, t) => {
      if (extreme === null) { extreme = x; return false; }
      const travel = x - extreme;
      if (direction === 0) {
        if (Math.abs(travel) > 40) { direction = Math.sign(travel); extreme = x; }
      } else if (travel * direction > 0) {
        extreme = x;
      } else if (Math.abs(travel) > 40) {
        direction = -direction;
        extreme = x;
        turns.push(t);
      }
      turns = turns.filter((s) => t - s < 1000);
      return turns.length >= 3;
    };
  }

  // ---------- Dragging ----------

  const ghost = $('#ghost');
  let drag = null; // { file, el, start, offset, moved, home, pointer, client, shaken, shake }

  desk.addEventListener('contextmenu', (e) => e.preventDefault());
  desk.addEventListener('pointerdown', (e) => {
    const el = e.target.closest('.desk-file');
    if (!el || e.button > 0 || drag) return;
    e.preventDefault();
    el.setPointerCapture(e.pointerId);
    syncKeys(e);
    const p = local(e);
    const index = Number(el.dataset.i);
    const home = slot(index);
    $$('.desk-file.selected').forEach((x) => x.classList.remove('selected'));
    el.classList.add('selected');
    drag = { file: files[index], el, start: p, offset: { x: p.x - home.x, y: p.y - home.y }, moved: false, home, pointer: p, client: { x: e.clientX, y: e.clientY }, shaken: false, shake: shakeDetector() };
  });
  desk.addEventListener('pointermove', (e) => {
    if (!drag) return;
    syncKeys(e);
    const p = local(e);
    drag.pointer = p;
    drag.client = { x: e.clientX, y: e.clientY };
    if (!drag.moved) {
      // A little hysteresis before it counts as a drag.
      if (Math.hypot(p.x - drag.start.x, p.y - drag.start.y) < 5) return;
      drag.moved = true;
      ghost.innerHTML = iconHTML(drag.file);
      ghost.dataset.hint = w('pick');
      ghost.hidden = false;
      ghost.classList.remove('back', 'gone');
      drag.el.classList.add('dragging');
      $('#noteCard').classList.add('done');
    }
    if (!drag.shaken && drag.shake(p.x, e.timeStamp)) drag.shaken = true;
    // The ghost stays where it was grabbed, 1:1 with the pointer.
    ghost.style.transform = `translate(${p.x - drag.offset.x}px, ${p.y - drag.offset.y}px)`;
    update();
  });
  function update() {
    if (!drag?.moved) return;
    const kind = heldKind() ?? picked ?? (drag.shaken ? 'all' : menu?.kind);
    if (kind && (!menu || menu.kind !== kind)) openMenu(kind, drag.file, drag.pointer);
    if (menu) {
      const h = indexAt(drag.pointer);
      if (h !== menu.hovered) { menu.hovered = h; highlight(); }
    }
    mac.classList.toggle('want-key', !menu);
  }
  addEventListener('keydown', (e) => { if (drag) { syncKeys(e); update(); } });
  addEventListener('keyup', (e) => { if (drag) { syncKeys(e); update(); } });

  desk.addEventListener('pointerup', finish);
  desk.addEventListener('pointercancel', () => finish(null));
  function finish(e) {
    if (!drag) return;
    const d = drag;
    drag = null;
    mac.classList.remove('want-key');
    if (!d.moved) return;
    const at = e ? local(e) : d.pointer;
    const index = e ? indexAt(at) : null;
    const tool = index != null ? menu.tools[index] : null;
    closeMenu();
    if (!tool) {
      // Cancelled: back the way it came.
      ghost.classList.add('back');
      ghost.style.transform = `translate(${d.home.x}px, ${d.home.y}px)`;
      setTimeout(() => { ghost.hidden = true; d.el.classList.remove('dragging'); }, reduceMotion.matches ? 0 : 320);
      return;
    }
    ghost.classList.add('gone');
    setTimeout(() => { ghost.hidden = true; }, 240);
    d.el.classList.remove('dragging');
    run(tool, d.file, at);
  }

  // ---------- Running a tool ----------

  const toast = $('#htoast');
  let toastTimer;
  function say(glyph, title, detail) {
    clearTimeout(toastTimer);
    $('#htIcon').innerHTML = `<use href="#${glyph}"/>`;
    $('#htTitle').textContent = title;
    $('#htDetail').textContent = detail;
    toast.classList.remove('working');
    toast.classList.add('show', 'done');
    toastTimer = setTimeout(() => toast.classList.remove('show'), 3200);
  }
  function run(tool, file, at) {
    clearTimeout(toastTimer);
    const result = tool.run(file);
    if (result.cut) {
      cutFiles(file);
      say('g-scissors', tool.label, w('cutDone'));
      return;
    }
    $('#htIcon').innerHTML = `<use href="#${tool.glyph}"/>`;
    $('#htTitle').textContent = tool.label;
    toast.classList.remove('done');
    toast.classList.add('show', 'working');
    const bar = $('#htBar i');
    bar.style.transition = 'none';
    bar.style.width = '0%';
    requestAnimationFrame(() => {
      bar.style.transition = `width ${reduceMotion.matches ? 0 : 700}ms cubic-bezier(.3, .6, .3, 1)`;
      bar.style.width = '100%';
    });
    setTimeout(() => {
      let detail = result.msg ?? '';
      if (result.out) {
        const made = result.out.map((o) => ({ ...o, name: unique(o.name, o.ext), fresh: true, made: true }));
        files.forEach((f) => { delete f.fresh; });
        files.push(...made);
        // Keep the desktop tidy: the oldest results make room.
        while (files.length > 15) files.splice(files.findIndex((f) => f.made), 1);
        detail = made.map(fullName).join(', ');
        render();
        // Each result comes out of the tool it was dropped on.
        $$('.desk-file.fresh').forEach((el) => {
          if (reduceMotion.matches) return;
          const p = slot(Number(el.dataset.i));
          el.style.transition = 'none';
          el.style.transform = `translate(${at.x - p.x}px, ${at.y - p.y - 36}px) scale(0.5)`;
          el.style.opacity = '0';
          requestAnimationFrame(() => requestAnimationFrame(() => {
            el.style.transition = '';
            el.style.transform = '';
            el.style.opacity = '';
          }));
        });
      }
      say('g-check', tool.label, detail);
    }, reduceMotion.matches ? 150 : 760);
  }

  // ---------- The Cut shelf ----------

  const shelf = $('#shelf');
  function cutFiles(file) {
    file.cut = true;
    render();
    const cut = files.filter((f) => f.cut);
    shelf.querySelector('.sh-icons').innerHTML = cut.slice(-3).map(iconHTML).join('');
    shelf.querySelector('.sh-name').textContent = cut.length === 1 ? fullName(cut[0]) : `${cut.length} ${w('items')}`;
    shelf.querySelector('.sh-hint').textContent = w('shelfHint');
    shelf.classList.add('open');
  }
  function clearShelf() {
    files.forEach((f) => { delete f.cut; });
    render();
    shelf.classList.remove('open');
  }
  shelf.querySelector('.sh-close').addEventListener('click', clearShelf);
  // Dragging the shelf onto a folder moves what's on it there.
  let shelfDrag = null;
  shelf.addEventListener('pointerdown', (e) => {
    if (e.target.closest('.sh-close') || e.button > 0) return;
    e.preventDefault();
    shelf.setPointerCapture(e.pointerId);
    const p = local(e);
    shelfDrag = { start: p, moved: false };
  });
  shelf.addEventListener('pointermove', (e) => {
    if (!shelfDrag) return;
    const p = local(e);
    if (!shelfDrag.moved) {
      if (Math.hypot(p.x - shelfDrag.start.x, p.y - shelfDrag.start.y) < 5) return;
      shelfDrag.moved = true;
      ghost.innerHTML = shelf.querySelector('.sh-icons').innerHTML;
      delete ghost.dataset.hint;
      ghost.hidden = false;
      ghost.classList.remove('back', 'gone');
    }
    ghost.style.transform = `translate(${p.x - 26}px, ${p.y - 30}px)`;
    const target = folderAt(e);
    $$('.desk-file.target').forEach((x) => x.classList.toggle('target', x === target));
    target?.classList.add('target');
  });
  function folderAt(e) {
    ghost.hidden = true;
    const el = document.elementFromPoint(e.clientX, e.clientY)?.closest?.('.desk-file');
    ghost.hidden = !shelfDrag?.moved;
    return el && files[Number(el.dataset.i)]?.type === 'folder' && !files[Number(el.dataset.i)].cut ? el : null;
  }
  shelf.addEventListener('pointerup', (e) => {
    const d = shelfDrag;
    shelfDrag = null;
    if (!d?.moved) return;
    const target = folderAt(e);
    $$('.desk-file.target').forEach((x) => x.classList.remove('target'));
    if (!target) {
      // Back onto the shelf.
      const box = shelf.getBoundingClientRect(), macBox = mac.getBoundingClientRect();
      ghost.classList.add('back');
      ghost.style.transform = `translate(${(box.left - macBox.left) / k + 40}px, ${(box.top - macBox.top) / k + 16}px)`;
      setTimeout(() => { ghost.hidden = true; }, reduceMotion.matches ? 0 : 320);
      return;
    }
    const folder = files[Number(target.dataset.i)];
    const count = files.filter((f) => f.cut).length;
    ghost.classList.add('gone');
    setTimeout(() => { ghost.hidden = true; }, 240);
    for (let i = files.length - 1; i >= 0; i--) if (files[i].cut) files.splice(i, 1);
    render();
    shelf.classList.remove('open');
    say('g-check', w('cut'), `${count === 1 ? w('moved') : `${count} ${w('itemsMoved')}`} → ${fullName(folder)}`);
  });

  // ---------- The Harbor Dock ----------

  const HARBOR = [
    { name: 'Inlet', url: 'https://kaandis.github.io/inlet/', icon: 'assets/inlet-icon.png?v=1' },
    { name: 'Ferry', url: 'https://kaandis.github.io/ferry/', icon: 'assets/ferry-icon.png?v=1' },
    { name: 'Stow', url: 'https://kaandis.github.io/stow/', icon: 'assets/stow-icon.png?v=1' },
    { name: 'Helm', url: 'https://kaandis.github.io/helm/', icon: 'assets/icon.png?v=1', running: true, self: true },
    { name: 'Harbor', url: 'https://kaandis.github.io/harbor/', icon: 'assets/harbor-icon.png?v=1' },
  ];
  const dock = $('#dock');
  const label = $('#dockLabel');
  dock.innerHTML = HARBOR.map((app) => `<a href="${app.url}" class="${app.running ? 'running' : ''}" aria-label="${app.name}"${app.self ? ' data-self' : ' target="_blank" rel="noopener"'}><img src="${app.icon}" alt="" width="52" height="52"></a>`).join('');
  $$('a', dock).forEach((a) => {
    a.addEventListener('pointerenter', () => {
      const box = a.getBoundingClientRect();
      const macBox = mac.getBoundingClientRect();
      label.textContent = a.getAttribute('aria-label');
      label.hidden = false;
      label.style.left = `${(box.left + box.width / 2 - macBox.left) / k}px`;
    });
    a.addEventListener('pointerleave', () => { label.hidden = true; });
    if (a.hasAttribute('data-self')) {
      a.addEventListener('click', (e) => {
        e.preventDefault();
        scrollTo({ top: 0, behavior: reduceMotion.matches ? 'auto' : 'smooth' });
      });
    }
  });

  const saved = store.get('lang');
  const initial = (saved === 'tr' || saved === 'en') ? saved : ((navigator.language || '').toLowerCase().startsWith('tr') ? 'tr' : 'en');
  setLanguage(initial);
  langButton.addEventListener('click', () => setLanguage(lang === 'tr' ? 'en' : 'tr'));
})();
