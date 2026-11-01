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
    'note.d': 'Bu masaüstünde bir dosya sürükle ve ⇧, ⌘ ya da ⌃ tuşuna bas (ya da aşağıdan bir çark seç). Bir dilimin üstüne bırak; vazgeçmek için ortaya bırak.',
    'k.convert': 'Dönüştür', 'k.tools': 'Araçlar', 'k.actions': 'Eylemler',
    'demo.hint': 'Gerçekten çalışıyor: sürüklerken bir tuşa bas ya da önce buradan bir çark seç. Dock’ta yalnızca Harbor uygulamaları var; her simge kendi sitesine götürür.',
    'how.title': 'Dosyaların, gitmeleri gereken yere.',
    'f1.t': 'Zaten olduğun yerde', 'f1.d': 'Finder’da ya da masaüstünde sürüklemeye başla ve bir tuşa bas. Açılacak uygulama, aranacak pencere yok.',
    'f2.t': 'Üç çark', 'f2.d': '⇧ dönüştürür, ⌘ araçları getirir, ⌃ paylaşır ve zip’ler. Her biri yalnızca tuttuğun dosyalara uyanları gösterir.',
    'f3.t': 'İzin yok', 'f3.d': 'Helm yalnızca sürüklemeyi ve bastığın tuşları okur. Orijinallere dokunulmaz; sonuçlar yanlarına gelir.',
    'f4.t': 'Çevrimdışı ve hafif', 'f4.d': 'Her şey macOS’te zaten olanla saniyeler içinde çalışır; sürüklemeler arasında hiçbir şey çalışmaz.',
    'list.title': 'Çarklarda neler var',
    'list.convert': 'Fotoğrafları JPG, PNG, HEIC, PDF ya da TIFF’e. PDF sayfalarını PNG ya da JPG’ye. Videoları MP4, MOV, GIF’e ya da seslerine. Sesleri M4A, WAV ya da AIFF’e.',
    'list.tools': 'Fotoğrafları sıkıştır, yarıya indir ya da bilgilerini sil, tek PDF yap, QR kod oku. PDF’leri birleştir, böl ya da sıkıştır. Videoları sıkıştır ya da sesini kaldır. Arşivleri aç.',
    'list.actions': 'AirDrop, yolu kopyala, orada Terminal aç ya da zip’le.',
    'cta.title': 'Ücretsiz. Hızlı. Elinin altında.',
    'cta.lead': 'Hesap yok, takip yok, izin yok.',
    'cta.note': 'macOS 15 veya üstü. Zip’i aç, Helm’i Uygulamalar’a taşı; ilk seferde sağ tıklayıp Aç’ı seç.',
    'faq.title': 'Sorular',
    'q1.q': '⌘’ye basmak dosyayı taşımaz mı?', 'q1.a': 'Yalnızca başka bir Finder klasörüne bırakırsan. Helm’in çarkına bırakılan dosya yalnızca okunur; orijinal yerinde kalır, sonuç yanına gelir.',
    'q2.q': 'Helm hangi izinleri istiyor?', 'q2.a': 'Hiçbirini. Sürüklemeyi sistemin sürükleme panosundan ve değiştirici tuşlardan fark eder; bunları her uygulama okuyabilir. Erişilebilirlik, Ekran Kaydı ya da Tam Disk Erişimi yok.',
    'q3.q': 'Başka uygulamaların yoluna çıkar mı?', 'q3.a': 'Çark yalnızca bir dosya sürüklerken çark tuşuna bastığında açılır. Tam ekran uygulamalarda hiç açılmaz; sürükleme kısayolları çakışan uygulamalar için kapatabilir, tuşları değiştirebilir ya da menü çubuğundan Helm’i duraklatabilirsin.',
    'q4.q': 'Neden bulut yükleme ya da yapay zekâyla arka plan silme yok?', 'q4.a': 'Bunlar bir sunucu, hesap ya da büyük bir indirme ister. Helm, macOS’te zaten olanla çevrimdışı ve saniyeler içinde çalışanlarla yetinir.',
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
      pick: 'Hold ⇧, ⌘ or ⌃', desktop: 'Desktop',
    },
    tr: {
      convert: 'Dönüştür', tools: 'Araçlar', actions: 'Eylemler', nothing: 'Burada araç yok',
      compress: 'Sıkıştır', half: 'Yarı Boyut', clean: 'Bilgileri Sil', makePDF: 'PDF Yap', readQR: 'QR Oku',
      merge: 'Birleştir', split: 'Sayfalara Böl', mute: 'Sesi Kaldır', extract: 'Aç', copyPath: 'Yolu Kopyala', terminal: 'Terminal', zip: 'Zip’le',
      sCompressed: 'sıkıştırılmış', sHalf: 'yarım', sClean: 'temiz', sMuted: 'sessiz', sPages: 'sayfaları', images: 'Görseller',
      noQR: 'QR kod bulunamadı', pathCopied: 'Yol kopyalandı', airdrop: 'AirDrop şununla açılır:', termOpen: 'Terminal Masaüstü’nde açılır',
      pick: '⇧, ⌘ ya da ⌃ tuşuna bas', desktop: 'Masaüstü',
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
      return `<button class="desk-file${f.fresh ? ' fresh' : ''}" type="button" role="listitem" data-i="${i}" style="left:${p.x}px;top:${p.y}px" aria-label="${fullName(f)}">${iconHTML(f)}<span class="fname">${fullName(f)}</span></button>`;
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
          T('airdrop', 'AirDrop', 'g-airdrop', (x) => ({ msg: `${w('airdrop')} ${fullName(x)}` })),
          T('path', w('copyPath'), 'g-link', () => ({ msg: w('pathCopied') })),
          T('term', w('terminal'), 'g-term', () => ({ msg: w('termOpen') })),
          T('zip', w('zip'), 'g-zip', (x) => ({ out: [{ name: x.name, ext: 'zip', type: 'zip' }] })),
        ];
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
      switch (f.type) {
        case 'image': return [
          T('compress', w('compress'), 'g-shrink', (x) => suffix(x, 'sCompressed', x.ext === 'png' ? 'jpg' : x.ext)),
          T('half', w('half'), 'g-half', (x) => suffix(x, 'sHalf')),
          T('clean', w('clean'), 'g-clean', (x) => suffix(x, 'sClean')),
          T('makepdf', w('makePDF'), 'g-doc', () => ({ out: [{ name: w('images'), ext: 'pdf', type: 'pdf' }] })),
          T('qr', w('readQR'), 'g-qr', () => ({ msg: w('noQR') })),
        ];
        case 'pdf': return [
          T('compress', w('compress'), 'g-shrink', (x) => suffix(x, 'sCompressed')),
          T('split', w('split'), 'g-scissors', (x) => ({ out: [{ name: x.name, ext: '', type: 'folder' }] })),
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

  // ---------- The wheel ----------

  const OUTER = 150, INNER = 54;
  const wheel = $('#wheel');
  const sectors = $('#wheelSectors');
  const labels = $('#wheelLabels');
  const KEYS = { convert: '⇧', tools: '⌘', actions: '⌃' };
  let wheelState = null; // { kind, tools, cx, cy, hovered }

  function arc(i, n, r0, r1) {
    const width = (2 * Math.PI) / n;
    const mid = -Math.PI / 2 + i * width;
    const a0 = mid - width / 2 + 0.012, a1 = mid + width / 2 - 0.012;
    const p = (r, a) => `${(r * Math.cos(a)).toFixed(2)} ${(r * Math.sin(a)).toFixed(2)}`;
    const large = width > Math.PI ? 1 : 0;
    return `M${p(r1, a0)} A${r1} ${r1} 0 ${large} 1 ${p(r1, a1)} L${p(r0, a1)} A${r0} ${r0} 0 ${large} 0 ${p(r0, a0)} Z`;
  }
  function drawWheel() {
    const { kind, tools, file } = wheelState;
    const n = tools.length;
    sectors.innerHTML = `<path class="ring" fill-rule="evenodd" d="M${OUTER} 0A${OUTER} ${OUTER} 0 1 1 -${OUTER} 0A${OUTER} ${OUTER} 0 1 1 ${OUTER} 0ZM${INNER} 0A${INNER} ${INNER} 0 1 0 -${INNER} 0A${INNER} ${INNER} 0 1 0 ${INNER} 0Z"/>`
      + tools.map((_, i) => `<path class="sector" data-i="${i}" d="${arc(i, n, INNER + 4, OUTER - 4)}"/>`).join('')
      + (n > 1 ? tools.map((_, i) => {
        const a = -Math.PI / 2 + (i + 0.5) * (2 * Math.PI) / n;
        return `<line class="spoke" x1="${(INNER + 10) * Math.cos(a)}" y1="${(INNER + 10) * Math.sin(a)}" x2="${(OUTER - 10) * Math.cos(a)}" y2="${(OUTER - 10) * Math.sin(a)}"/>`;
      }).join('') : '');
    const radius = (INNER + OUTER) / 2;
    labels.innerHTML = tools.map((t, i) => {
      const a = -Math.PI / 2 + i * (2 * Math.PI) / n;
      return `<span class="wl" data-i="${i}" style="left:${160 + radius * Math.cos(a)}px;top:${160 + radius * Math.sin(a)}px"><svg><use href="#${t.glyph}"/></svg>${t.label}</span>`;
    }).join('');
    $('#hubTop').textContent = n ? (file.ext || 'DIR').toUpperCase() : '';
    $('#hubSub').textContent = n ? w(kind) : w('nothing');
    $('#legend').innerHTML = Object.keys(KEYS).map((key) => `<span class="${key === kind ? 'on' : ''}"><kbd>${KEYS[key]}</kbd>${w(key)}</span>`).join('');
    highlight();
  }
  function highlight() {
    const h = wheelState?.hovered;
    $$('.sector', sectors).forEach((s) => s.classList.toggle('on', Number(s.dataset.i) === h));
    $$('.wl', labels).forEach((s) => s.classList.toggle('on', Number(s.dataset.i) === h));
  }
  function openWheel(kind, file, at) {
    const fresh = !wheelState;
    // Centred on the pointer, kept inside the screen.
    const cx = fresh ? Math.min(Math.max(at.x, 170), 960 - 170) : wheelState.cx;
    const cy = fresh ? Math.min(Math.max(at.y, 190), 600 - 275) : wheelState.cy;
    wheelState = { kind, file, tools: toolsFor(kind, file), cx, cy, hovered: null };
    if (fresh) {
      wheel.style.left = `${cx}px`;
      wheel.style.top = `${cy}px`;
      // Blooms from the pointer.
      wheel.style.transformOrigin = `${160 + at.x - cx}px ${160 + at.y - cy}px`;
    }
    drawWheel();
    wheel.classList.add('open');
  }
  function closeWheel() {
    wheel.classList.remove('open');
    wheelState = null;
  }
  function sliceAt(p) {
    if (!wheelState || !wheelState.tools.length) return null;
    const dx = p.x - wheelState.cx, dy = p.y - wheelState.cy;
    const d = Math.hypot(dx, dy);
    if (d <= INNER || d >= OUTER + 24) return null;
    let a = Math.atan2(dx, -dy);
    if (a < 0) a += 2 * Math.PI;
    const width = (2 * Math.PI) / wheelState.tools.length;
    return Math.floor((a + width / 2) / width) % wheelState.tools.length;
  }

  // ---------- Which wheel ----------

  // A key held on the keyboard wins; otherwise the wheel picked below.
  let picked = null;
  const held = { shift: false, meta: false, ctrl: false };
  function heldKind() {
    const down = Object.entries(held).filter(([, v]) => v).map(([key]) => key);
    if (down.length !== 1) return null;
    return { shift: 'convert', meta: 'tools', ctrl: 'actions' }[down[0]];
  }
  const kindNow = () => heldKind() ?? picked;
  function syncKeys(e) {
    held.shift = e.shiftKey; held.meta = e.metaKey; held.ctrl = e.ctrlKey;
  }
  $$('.wheel-keys .try').forEach((b) => {
    b.addEventListener('click', () => {
      picked = picked === b.dataset.kind ? null : b.dataset.kind;
      $$('.wheel-keys .try').forEach((x) => x.setAttribute('aria-pressed', String(x.dataset.kind === picked)));
    });
  });

  // ---------- Dragging ----------

  const ghost = $('#ghost');
  let drag = null; // { file, index, el, start, offset, moved, home }

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
    drag = { file: files[index], index, el, start: p, offset: { x: p.x - home.x, y: p.y - home.y }, moved: false, home, pointer: p };
  });
  desk.addEventListener('pointermove', (e) => {
    if (!drag) return;
    syncKeys(e);
    const p = local(e);
    drag.pointer = p;
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
    // The ghost stays where it was grabbed, 1:1 with the pointer.
    ghost.style.transform = `translate(${p.x - drag.offset.x}px, ${p.y - drag.offset.y}px)`;
    update();
  });
  function update() {
    if (!drag?.moved) return;
    const kind = kindNow();
    // Opens once a wheel key is down; another key switches it; it stays
    // open after the key comes up, as in the app.
    if (kind && (!wheelState || wheelState.kind !== kind)) openWheel(kind, drag.file, drag.pointer);
    if (wheelState) {
      const h = sliceAt(drag.pointer);
      if (h !== wheelState.hovered) { wheelState.hovered = h; highlight(); }
    }
    mac.classList.toggle('want-key', !wheelState);
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
    const index = e ? sliceAt(local(e)) : null;
    const tool = index != null ? wheelState.tools[index] : null;
    const at = e ? local(e) : d.pointer;
    closeWheel();
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
  function run(tool, file, at) {
    clearTimeout(toastTimer);
    const result = tool.run(file);
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
        const made = result.out.map((o) => ({ ...o, name: unique(o.name, o.ext), fresh: true }));
        files.forEach((f) => { delete f.fresh; });
        files.push(...made);
        // Keep the desktop tidy: the oldest results make room.
        while (files.length > 15) files.splice(3, 1);
        detail = made.map(fullName).join(', ');
        render();
        // Each result comes out of the slice it was dropped on.
        $$('.desk-file.fresh').forEach((el) => {
          if (reduceMotion.matches) return;
          const i = Number(el.dataset.i);
          const p = slot(i);
          el.style.transition = 'none';
          el.style.transform = `translate(${at.x - p.x - 45}px, ${at.y - p.y - 36}px) scale(0.5)`;
          el.style.opacity = '0';
          requestAnimationFrame(() => requestAnimationFrame(() => {
            el.style.transition = '';
            el.style.transform = '';
            el.style.opacity = '';
          }));
        });
      }
      $('#htIcon').innerHTML = '<use href="#g-check"/>';
      $('#htDetail').textContent = detail;
      toast.classList.remove('working');
      toast.classList.add('done');
      toastTimer = setTimeout(() => toast.classList.remove('show'), 3200);
    }, reduceMotion.matches ? 150 : 760);
  }

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
