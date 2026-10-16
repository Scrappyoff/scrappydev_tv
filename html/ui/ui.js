
(function () {
	'use strict';

	var RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'scrappydev_tv';
	var $ = function (id) { return document.getElementById(id); };
	function tr(value) { return window.ScrappyI18n ? window.ScrappyI18n.t(String(value), state.cfg.locale) : value; }
	var LS = { history: 'scrappydevtv2:history', favs: 'scrappydevtv2:favs', titles: 'scrappydevtv2:titles', engine: 'scrappydevtv2:engine' };

	var state = {
		mode: null,
		view: {}, recvAt: Date.now(),
		cfg: { home: 'https://duckduckgo.com/', engines: [], quick: [], invertWheel: false },
		engine: null, tab: 'recent', lastVolume: 50, streamer: false, drawer: false
	};

	function post(name, data) {
		try {
			return fetch('https://' + RES + '/' + name, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json; charset=UTF-8' },
				body: JSON.stringify(data || {})
			}).catch(function () {});
		} catch (e) { return null; }
	}

	function load(key, fallback) {
		try { var v = JSON.parse(localStorage.getItem(key)); return v === null || v === undefined ? fallback : v; }
		catch (e) { return fallback; }
	}
	function save(key, value) { try { localStorage.setItem(key, JSON.stringify(value)); } catch (e) {  } }

	var audioCtx = null;
	function tick(freq, dur) {
		try {
			audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
			var o = audioCtx.createOscillator(), g = audioCtx.createGain();
			o.type = 'sine'; o.frequency.value = freq || 660;
			g.gain.value = 0.015;
			g.gain.exponentialRampToValueAtTime(0.0001, audioCtx.currentTime + (dur || 0.08));
			o.connect(g); g.connect(audioCtx.destination);
			o.start(); o.stop(audioCtx.currentTime + (dur || 0.08));
		} catch (e) {  }
	}

	function toast(text, kind) {
		var el = document.createElement('div');
		el.className = 'toast' + (kind ? ' ' + kind : '');
		el.textContent = tr(text);
		$('toasts').appendChild(el);
		setTimeout(function () { el.style.transition = 'opacity .3s'; el.style.opacity = '0'; }, 2400);
		setTimeout(function () { if (el.parentNode) el.parentNode.removeChild(el); }, 2800);
	}

	function esc(s) {
		return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
			return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
		});
	}

	function normalize(raw) {
		var v = String(raw || '').trim();
		if (!v || /\s/.test(v)) return '';
		if (/^[a-z][a-z0-9+.-]*:\/\//i.test(v)) return v;
		if (/^[^\s/]+\.[a-z]{2,}([/:?#]|$)/i.test(v)) return 'https://' + v;
		return '';
	}

	var TYPES = [
		[/(^|\.)(youtube\.com|youtu\.be|youtube-nocookie\.com)$/i, 'YouTube'], [/(^|\.)twitch\.tv$/i, 'Twitch'],
		[/(^|\.)kick\.com$/i, 'Kick'], [/(^|\.)(dailymotion\.com|dai\.ly)$/i, 'Dailymotion'], [/(^|\.)vimeo\.com$/i, 'Vimeo'],
		[/(^|\.)facebook\.com$/i, 'Facebook'], [/(^|\.)soundcloud\.com$/i, 'SoundCloud']
	];

	function detect(raw) {
		var url = normalize(raw);
		if (!raw || !String(raw).trim()) return null;
		if (!url) return { label: 'Recherche', hint: 'Ce texte sera cherché avec le moteur sélectionné.' };
		var host = '';
		try { host = new URL(url).hostname; } catch (e) { return { label: 'Invalide', warn: true, hint: 'Ce lien semble incorrect.' }; }
		if (!/^https?:$/.test(new URL(url).protocol)) return { label: 'Invalide', warn: true, hint: 'Seuls les liens http(s) sont acceptés.' };
		var path = url.split(/[?#]/)[0];
		if (/youtu(\.be|be\.com)/i.test(host) && youtubeId(url)) return { label: 'YouTube', hint: 'Lecture synchronisée pour tous les joueurs proches.' };
		if (/\.(mp4|webm|mov|m4v|ogv)$/i.test(path)) return { label: 'Vidéo', hint: 'Vidéo directe : lecture synchronisée.' };
		if (/\.m3u8$/i.test(path)) return { label: 'Flux HLS', hint: 'Flux en direct : lecture synchronisée.' };
		if (/\.(mp3|ogg|wav|m4a|aac|flac|opus)$/i.test(path)) return { label: 'Audio', hint: 'Fichier audio direct.' };
		if (/\.(png|jpe?g|gif|webp|bmp|avif)$/i.test(path)) return { label: 'Image', hint: "Affiche l'image sur l'écran." };
		for (var i = 0; i < TYPES.length; i++) if (TYPES[i][0].test(host)) return { label: TYPES[i][1], hint: 'Site navigable avec le mode souris.' };
		return { label: 'Site web', hint: 'Site navigable avec le mode souris.' };
	}

	function youtubeId(url) {
		var m = String(url || '').match(/(?:youtu\.be\/|youtube(?:-nocookie)?\.com\/(?:watch\?(?:.*&)?v=|embed\/|shorts\/|live\/|v\/))([A-Za-z0-9_-]{11})/);
		return m ? m[1] : null;
	}

	function shortUrl(url) { return String(url || '').replace(/^https?:\/\/(www\.)?/i, ''); }

	function engines() {
		var list = state.cfg.engines && state.cfg.engines.length ? state.cfg.engines : [{ id: 'ddg', label: 'DuckDuckGo', url: 'https://duckduckgo.com/?q=%s' }];
		return list;
	}

	function currentEngine() {
		var list = engines();
		for (var i = 0; i < list.length; i++) if (list[i].id === state.engine) return list[i];
		return list[0];
	}

	function resolveInput(raw) {
		var text = String(raw || '').trim();
		if (!text) return null;
		var url = normalize(text);
		if (url) return { url: url, search: false };
		var eng = currentEngine();
		return { url: eng.url.replace('%s', encodeURIComponent(text)), search: true, engine: eng.label, text: text };
	}

	function getHistory() { return load(LS.history, []); }
	function getFavs() { return load(LS.favs, []); }
	function getTitles() { return load(LS.titles, {}); }

	function addHistory(url) {
		if (!url) return;
		var h = getHistory().filter(function (x) { return x.url !== url; });
		h.unshift({ url: url, ts: Date.now() });
		save(LS.history, h.slice(0, 14));
	}

	function isFav(url) { return getFavs().some(function (f) { return f.url === url; }); }

	function toggleFav(url) {
		if (!url) return;
		var favs = getFavs(), idx = -1;
		favs.forEach(function (f, i) { if (f.url === url) idx = i; });
		if (idx >= 0) { favs.splice(idx, 1); toast('Retiré des favoris'); }
		else { favs.unshift({ url: url }); toast('Ajouté aux favoris', 'ok'); }
		save(LS.favs, favs.slice(0, 30));
		refreshFav();
		if (state.tab === 'favs') renderTab();
	}

	var fetching = {};
	function fetchTitle(url) {
		var id = youtubeId(url);
		if (!id || getTitles()[url] || fetching[url]) return;
		fetching[url] = true;
		try {
			fetch('https://www.youtube.com/oembed?format=json&url=' + encodeURIComponent(url))
				.then(function (r) { return r.ok ? r.json() : null; })
				.then(function (j) {
					if (!j || !j.title) return;
					var t = getTitles(); t[url] = j.title; save(LS.titles, t);
					renderNow(); renderTab();
				}).catch(function () {});
		} catch (e) {  }
	}

	function fmtTime(sec) {
		sec = Math.max(0, Math.floor(sec));
		var h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
		var mm = (h ? ('0' + m).slice(-2) : String(m)), ss = ('0' + s).slice(-2);
		return (h ? h + ':' : '') + mm + ':' + ss;
	}

	function elapsedSeconds() {
		var v = state.view || {};
		var ms = v.positionMs || 0;
		if (!v.paused) ms += Date.now() - state.recvAt;
		return ms / 1000;
	}

	function isTimed() { var v = state.view || {}; return !!v.url && (v.kind === 'youtube' || v.kind === 'media'); }

	function renderNow() {
		var v = state.view || {};
		var playing = !!v.url;
		var card = $('nowcard');
		card.classList.toggle('playing', playing && !v.paused && v.kind !== 'web');

		var on = v.on !== false;
		$('statuspill').classList.toggle('live', on && playing);
		$('statustext').textContent = tr(!on ? 'Éteinte' : (v.menu ? 'Menu' : (playing ? (v.paused ? 'En pause' : 'En lecture') : 'Allumée')));

		var img = $('nowimg'), yt = playing ? youtubeId(v.url) : null;
		if (yt) {
			img.src = 'https://img.youtube.com/vi/' + yt + '/mqdefault.jpg'; img.hidden = false;
			img.onerror = function () { img.hidden = true; card.classList.remove('has-img'); };
			card.classList.add('has-img');
		} else if (playing && v.kind === 'image') {
			img.src = v.url; img.hidden = false;
			img.onerror = function () { img.hidden = true; card.classList.remove('has-img'); };
			card.classList.add('has-img');
		} else {
			img.hidden = true; img.removeAttribute('src'); card.classList.remove('has-img');
		}

		$('nowlabel').textContent = tr(playing ? (v.paused ? 'En pause' : 'En cours de lecture') : 'Aucune lecture en cours');
		$('nowtitle').textContent = playing ? (getTitles()[v.url] || shortUrl(v.url)) : tr('Tape une adresse ou une recherche ci-dessous');

		var type = $('nowtype');
		if (playing && v.label) { type.textContent = tr(v.label); type.hidden = false; } else { type.hidden = true; }

		$('transport').hidden = !isTimed();
		$('pauseico').innerHTML = v.paused ? '<path d="M8 5.5v13l11-6.5z"/>' : '<path d="M8 5v14M16 5v14"/>';
		renderTime();

		var empty = !playing;
		$('stage').classList.toggle('empty', empty);
		$('pilot').innerHTML = v.controller ? tr('Pilote : ') + '<b>' + esc(v.controller) + '</b>' : '';
		refreshFav();
	}

	function renderTime() {
		var t = $('nowtime');
		if (isTimed()) { t.textContent = fmtTime(elapsedSeconds()); t.hidden = false; } else { t.hidden = true; }
	}

	function renderVolume() {
		var v = Math.max(0, Math.min(100, Number((state.view || {}).volume)));
		if (isNaN(v)) v = 50;
		if (v > 0) state.lastVolume = v;
		if ((state.view || {}).muted) v = 0;
		$('vol').value = v;
		$('volfill').style.width = 'calc(9px + (100% - 18px) * ' + (v / 100) + ')';
		$('volvalue').textContent = Math.round(v) + '%';
		$('volicon').innerHTML = v === 0
			? '<path d="M4 9.5v5h3.5L12 18.5v-13L7.5 9.5z"/><path d="M16 9.5l5 5M21 9.5l-5 5"/>'
			: '<path d="M4 9.5v5h3.5L12 18.5v-13L7.5 9.5z"/><path d="M15.5 9a4 4 0 0 1 0 6"/>' + (v > 55 ? '<path d="M18 6.5a8 8 0 0 1 0 11"/>' : '');
	}

	function renderDetect(inputId, chipId) {
		var value = $(inputId).value;
		var d = detect(value);
		var chip = $(chipId);
		if (chipId === 'detect') $('clearbtn').hidden = !value;
		if (!d) {
			chip.hidden = true;
			if (chipId === 'detect') { $('hint').className = 'field-hint'; $('hint').textContent = tr('Colle un lien (YouTube, vidéo MP4, image, site web…) ou écris ce que tu cherches.'); }
		} else {
			chip.hidden = false; chip.textContent = tr(d.label); chip.classList.toggle('warn', !!d.warn);
			if (chipId === 'detect') { $('hint').className = 'field-hint' + (d.warn ? ' warn' : ''); $('hint').textContent = tr(d.hint || ''); }
		}
		refreshFav();
	}

	function renderEngines() {
		var box = $('engines'), sel = $('pengine');
		var list = engines(), cur = currentEngine();
		box.innerHTML = list.map(function (e) {
			return '<button class="engine' + (e.id === cur.id ? ' active' : '') + '" data-engine="' + esc(e.id) + '" type="button">' + esc(e.label) + '</button>';
		}).join('');
		sel.innerHTML = list.map(function (e) {
			return '<option value="' + esc(e.id) + '"' + (e.id === cur.id ? ' selected' : '') + '>' + esc(e.label) + '</option>';
		}).join('');
	}

	function renderQuick() {
		$('quick').innerHTML = (state.cfg.quick || []).map(function (q) {
			return '<button class="chip" data-go="' + esc(q.url) + '" type="button">' + esc(q.label) + '</button>';
		}).join('');
	}

	function refreshFav() {
		var el = state.mode === 'pointer' ? '' : ($('addr') ? $('addr').value : '');
		var current = normalize(el) || (state.view || {}).url;
		$('favbtn').classList.toggle('on', !!current && isFav(current));
	}

	function itemHtml(entry) {
		var url = entry.url, yt = youtubeId(url), d = detect(url) || { label: 'Lien' };
		var icon = yt ? '<img src="https://img.youtube.com/vi/' + yt + '/default.jpg" alt="" onerror="this.remove()">' : esc(d.label.slice(0, 3));
		var title = getTitles()[url] || shortUrl(url);
		return '<div class="item-row" style="display:flex;align-items:center;gap:4px">' +
			'<button class="item" data-go="' + esc(url) + '" type="button" title="' + esc(url) + '">' +
				'<span class="item-ico">' + icon + '</span>' +
				'<span class="item-copy"><b>' + esc(title) + '</b><small>' + esc(d.label) + '</small></span></button>' +
			'<button class="item-x" data-remove="' + esc(url) + '" type="button" aria-label="' + tr('Retirer') + '"><svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6 6 18"/></svg></button></div>';
	}

	function renderTab() {
		var list = state.tab === 'favs' ? getFavs() : getHistory();
		list.forEach(function (e) { fetchTitle(e.url); });
		$('tabbody').innerHTML = list.length ? list.map(itemHtml).join('')
			: (state.tab === 'favs'
				? '<div class="empty">Aucun favori pour l\'instant.<br>Appuie sur ★ pour garder un lien sous la main.</div>'
				: '<div class="empty">' + tr('Aucun lien récent.') + '<br>' + tr('Ce que tu lances apparaîtra ici.') + '</div>');
	}

	function setTab(tab) {
		state.tab = tab;
		Array.prototype.forEach.call(document.querySelectorAll('.tab'), function (b) { b.classList.toggle('active', b.getAttribute('data-tab') === tab); });
		renderTab();
	}

	function renderAll() { renderNow(); renderVolume(); renderRemote(); }

	var STAGE_TOP = 78, STAGE_BOTTOM = 56;

	function layoutStage() {
		var vw = window.innerWidth, vh = window.innerHeight;
		var maxW = vw * 0.94, maxH = vh - STAGE_TOP - STAGE_BOTTOM;
		var w = Math.min(maxW, maxH * 16 / 9), h = w * 9 / 16;
		var left = (vw - w) / 2, top = STAGE_TOP + (maxH - h) / 2;
		var st = $('stage');
		st.style.left = left + 'px'; st.style.top = top + 'px'; st.style.width = w + 'px'; st.style.height = h + 'px';
		state.rect = { left: left, top: top, w: w, h: h };
		post('stage', { cx: (left + w / 2) / vw, cy: (top + h / 2) / vh, w: w / vw, h: h / vh });
	}

	function norm(e) {
		var r = state.rect || { left: 0, top: 0, w: 1, h: 1 };
		return {
			x: Math.max(0, Math.min(1, (e.clientX - r.left) / r.w)),
			y: Math.max(0, Math.min(1, (e.clientY - r.top) / r.h))
		};
	}

	var pending = null, raf = 0;
	function flushMove() {
		raf = 0;
		if (pending) { post('mouse', { t: 'm', x: pending.x, y: pending.y }); pending = null; }
	}

	function bindStage() {
		var st = $('stage'), cur = $('cursor');
		function place(e) {
			var r = state.rect;
			cur.style.left = (e.clientX - r.left) + 'px';
			cur.style.top = (e.clientY - r.top) + 'px';
		}
		st.addEventListener('mouseenter', function () { cur.hidden = false; });
		st.addEventListener('mouseleave', function () { cur.hidden = true; cur.classList.remove('down'); });
		st.addEventListener('mousemove', function (e) {
			place(e);
			pending = norm(e);
			if (!raf) raf = requestAnimationFrame(flushMove);
		});
		function button(e) { return e.button === 2 ? 'right' : (e.button === 1 ? 'middle' : 'left'); }
		st.addEventListener('mousedown', function (e) {
			e.preventDefault();
			if (raf) { cancelAnimationFrame(raf); flushMove(); }
			cur.classList.add('down');
			var p = norm(e);
			post('mouse', { t: 'd', x: p.x, y: p.y, b: button(e) });
		});
		st.addEventListener('mouseup', function (e) {
			cur.classList.remove('down');
			var p = norm(e);
			post('mouse', { t: 'u', x: p.x, y: p.y, b: button(e) });
		});
		st.addEventListener('contextmenu', function (e) { e.preventDefault(); });
		st.addEventListener('wheel', function (e) {
			e.preventDefault();
			var dy = e.deltaMode === 1 ? e.deltaY * 40 : e.deltaY;
			post('mouse', { t: 'w', dy: Math.max(-1200, Math.min(1200, dy)) });
		}, { passive: false });
	}

	function submit(raw) {
		var r = resolveInput(raw);
		if (!r) { toast('Écris une adresse ou une recherche', 'error'); tick(300, 0.12); return false; }
		post('play', { url: r.url });
		addHistory(r.url);
		toast(r.search ? tr('Recherche') + ' “' + r.text + '” (' + r.engine + ')' : 'Envoi à la télévision…');
		tick(760, 0.09);
		if (state.tab === 'recent') renderTab();
		return true;
	}

	var volTimer = null;
	function sendVolume(v, immediate) {
		state.view.volume = v;
		if (immediate) { clearTimeout(volTimer); volTimer = null; post('volume', { value: v }); return; }
		if (volTimer) return;
		volTimer = setTimeout(function () { volTimer = null; post('volume', { value: state.view.volume }); }, 110);
	}

	var actions = {
		close: function () { tick(440, 0.07); post('close'); },
		go: function () { if (submit($('addr').value)) { $('addr').value = ''; renderDetect('addr', 'detect'); } },
		pgo: function () { if (submit($('paddr').value)) { $('paddr').value = ''; renderDetect('paddr', 'pdetect'); } },
		fav: function () { toggleFav(normalize($('addr').value) || (state.view || {}).url); tick(880, 0.06); },
		stop: function () { tick(300, 0.14); post('stop'); },
		pointer: function () { tick(620, 0.07); post('pointerOpen'); },
		'pointer-close': function () { tick(500, 0.06); post('pointerClose'); },
		home: function () { post('play', { url: state.cfg.home }); tick(600, 0.06); },
		reload: function () {
			var url = (state.view || {}).url;
			if (url) { post('play', { url: url }); toast('Rechargé pour tout le monde'); tick(600, 0.06); }
		},
		'toggle-pause': function () { post('pause', { paused: !(state.view || {}).paused }); tick(560, 0.05); },
		'seek-back': function () { post('seek', { seconds: -10, relative: true }); tick(520, 0.05); },
		'seek-fwd': function () { post('seek', { seconds: 10, relative: true }); tick(680, 0.05); },
		mute: function () { press('mute'); },
		drawer: function () { toggleDrawer(); },
		streamer: function () { tick(520, 0.06); flashLed(); post('streamer'); }
	};

	document.addEventListener('click', function (e) {
		var t = e.target.closest ? e.target.closest('[data-act],[data-go],[data-engine],[data-remove],[data-tab]') : null;
		if (!t) return;
		if (t.hasAttribute('data-act')) { var fn = actions[t.getAttribute('data-act')]; if (fn) fn(); return; }
		if (t.hasAttribute('data-go')) { post('play', { url: t.getAttribute('data-go') }); addHistory(t.getAttribute('data-go')); toast('Envoi à la télévision…'); tick(760, 0.09); if (state.tab === 'recent') renderTab(); return; }
		if (t.hasAttribute('data-engine')) { state.engine = t.getAttribute('data-engine'); save(LS.engine, state.engine); renderEngines(); tick(520, 0.05); return; }
		if (t.hasAttribute('data-tab')) { tick(520, 0.05); setTab(t.getAttribute('data-tab')); return; }
		if (t.hasAttribute('data-remove')) {
			var url = t.getAttribute('data-remove');
			if (state.tab === 'recent') save(LS.history, getHistory().filter(function (x) { return x.url !== url; }));
			else save(LS.favs, getFavs().filter(function (x) { return x.url !== url; }));
			renderTab(); refreshFav();
		}
	});

	$('addr').addEventListener('input', function () { renderDetect('addr', 'detect'); });
	$('addr').addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); actions.go(); } });
	$('clearbtn').addEventListener('click', function () { $('addr').value = ''; renderDetect('addr', 'detect'); $('addr').focus(); });
	$('paddr').addEventListener('input', function () { renderDetect('paddr', 'pdetect'); });
	$('paddr').addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); actions.pgo(); } });
	$('pengine').addEventListener('change', function () { state.engine = this.value; save(LS.engine, state.engine); renderEngines(); });

	var slider = $('vol');
	slider.addEventListener('input', function () { sendVolume(Number(slider.value), false); renderVolume(); });
	slider.addEventListener('change', function () { sendVolume(Number(slider.value), true); tick(600, 0.05); });

	var ledTimer = null;
	function flashLed() {
		var led = $('rcled');
		led.classList.add('tx');
		clearTimeout(ledTimer);
		ledTimer = setTimeout(function () { led.classList.remove('tx'); }, 90);
	}

	var KEY_TONE = { power: 300, mute: 420, ok: 780, back: 460, exit: 440, menu: 620, home: 640, guide: 600 };
	function press(key, silent) {
		post('key', { key: key });
		flashLed();
		if (!silent) tick(KEY_TONE[key] || 560 + (key.length === 2 && key.charAt(0) === 'd' ? Number(key.charAt(1)) * 18 : 0), 0.05);
	}

	function lit(key, on) {
		var b = document.querySelector('.k[data-key="' + key + '"]');
		if (b) b.classList.toggle('down', on);
		return b;
	}

	var repTimer = null, repInt = null, repKey = null;
	function stopRepeat() {
		clearTimeout(repTimer); clearInterval(repInt);
		repTimer = repInt = null;
		if (repKey) { lit(repKey, false); repKey = null; }
	}

	document.addEventListener('mousedown', function (e) {
		if (e.button !== 0) return;
		var b = e.target.closest ? e.target.closest('.k[data-key]') : null;
		if (!b) return;
		e.preventDefault();
		var key = b.getAttribute('data-key');
		press(key);
		if (b.hasAttribute('data-rep')) {
			stopRepeat(); repKey = key;
			repTimer = setTimeout(function () { repInt = setInterval(function () { press(key, true); }, 140); }, 380);
		}
	});
	document.addEventListener('mouseup', stopRepeat);
	window.addEventListener('blur', stopRepeat);

	var KEYBOARD = {
		ArrowUp: 'up', ArrowDown: 'down', ArrowLeft: 'left', ArrowRight: 'right', Enter: 'ok', Backspace: 'back',
		Home: 'home', PageUp: 'ch_up', PageDown: 'ch_down', '+': 'vol_up', '=': 'vol_up', '-': 'vol_down',
		m: 'mute', M: 'mute', i: 'info', I: 'info', g: 'guide', G: 'guide', p: 'power', P: 'power'
	};

	function toggleDrawer(force) {
		state.drawer = typeof force === 'boolean' ? force : !state.drawer;
		$('drawer').hidden = !state.drawer;
		applyScale();
		tick(state.drawer ? 640 : 500, 0.05);
		if (state.drawer) setTimeout(function () { try { $('addr').focus(); } catch (e) {  } }, 120);
		else if (document.activeElement && document.activeElement.blur) document.activeElement.blur();
	}

	function typing() {
		var a = document.activeElement;
		return !!a && (a.tagName === 'INPUT' || a.tagName === 'SELECT' || a.tagName === 'TEXTAREA') && a.type !== 'range';
	}

	document.addEventListener('keydown', function (e) {
		if (!state.mode) return;
		if (e.key === 'Escape') {
			if (state.mode === 'remote' && state.drawer) { toggleDrawer(false); return; }
			if (document.activeElement && document.activeElement.blur) document.activeElement.blur();
			post(state.mode === 'pointer' ? 'pointerClose' : 'close');
			return;
		}
		if (state.mode !== 'remote') return;
		if (e.key === 'Tab') { e.preventDefault(); toggleDrawer(); return; }
		if (typing()) return;
		var key = KEYBOARD[e.key] || (/^[0-9]$/.test(e.key) ? 'd' + e.key : null);
		if (!key) return;
		e.preventDefault();
		press(key);
		var b = lit(key, true);
		if (b) setTimeout(function () { lit(key, false); }, 110);
	});

	function applyScale() {
		var rc = $('rc'), dr = $('drawer');
		if (!rc) return;
		var h = Math.max(rc.offsetHeight || 0, state.drawer ? (dr.offsetHeight || 0) : 0) || 940;
		var w = (rc.offsetWidth || 312) + (state.drawer ? (dr.offsetWidth || 430) + 22 : 0);
		var s = Math.min(1, (window.innerHeight - 20) / h, (window.innerWidth * 0.94) / w);
		$('rig').style.setProperty('--rs', String(Math.max(0.35, s)));
	}

	function renderRemote() {
		var v = state.view || {}, on = v.on !== false, playing = !!v.url;
		var rc = $('rc');
		rc.classList.toggle('on', on);
		rc.classList.toggle('off', !on);
		var st = !on ? 'ÉTEINTE' : (v.menu ? 'MENU' : (playing ? (v.paused ? 'PAUSE' : (v.kind === 'web' ? 'WEB' : 'LECTURE')) : 'ALLUMÉE'));
		var info = '—';
		if (on) {
			var names = state.cfg.channels || [], ch = null;
			for (var i = 0; i < names.length; i++) if (names[i].n === v.channel) ch = names[i];
			if (ch) info = 'CH ' + ch.n + ' ' + ch.name;
			else if (playing) info = (v.label || shortUrl(v.url)).toUpperCase();
			else if (v.menu) info = v.menu.page === 'channels' ? 'CHAÎNES' : 'ACCUEIL';
		}
		$('lcdstate').textContent = tr(st);
		$('lcdinfo').textContent = info;
		$('lcdvol').textContent = v.muted ? 'MUET' : 'VOL ' + Math.round(Number(v.volume) || 0);
		$('mutekey').classList.toggle('on', !!v.muted);
		$('streamerkey').classList.toggle('on', !!state.streamer);
	}

	window.addEventListener('resize', function () {
		if (state.mode === 'pointer') layoutStage();
		if (state.mode === 'remote') applyScale();
	});

	setInterval(function () { if (state.mode) renderTime(); }, 1000);

	function show(mode) {
		state.mode = mode;
		$('remote').hidden = mode !== 'remote';
		$('pointer').hidden = mode !== 'pointer';
	}

	window.addEventListener('message', function (event) {
		var d = event.data || {};

		if (d.type === 'remote' || d.type === 'pointer') {
			if (d.config) { state.cfg = Object.assign(state.cfg, d.config); state.streamer = !!d.config.streamer; if (window.ScrappyI18n) window.ScrappyI18n.setLocale(state.cfg.locale || 'en'); }
			state.view = d.view || {};
			state.recvAt = Date.now();
			state.engine = load(LS.engine, null) || engines()[0].id;
			renderEngines(); renderQuick(); renderAll(); renderTab();
			show(d.type);
			if (d.type === 'pointer') { layoutStage(); setTimeout(function () { try { $('paddr').focus(); } catch (e) {  } }, 150); }
			else {
					$('addr').value = ''; renderDetect('addr', 'detect');
					state.drawer = false; $('drawer').hidden = true;
					if (document.activeElement && document.activeElement.blur) document.activeElement.blur();
					applyScale();
				}
			fetchTitle(state.view.url);
		}

		if (d.type === 'state') {
			state.view = d.view || {};
			state.recvAt = Date.now();
			renderAll();
			fetchTitle(state.view.url);
		}

		if (d.type === 'streamer') { state.streamer = !!d.on; renderRemote(); toast(d.on ? 'Mode streamer activé' : 'Mode streamer désactivé'); }

		if (d.type === 'hide') { stopRepeat(); show(null); }
	});

	bindStage();
	setTab('recent');
	window.__scrappydevtvui = { normalize: normalize, detect: detect, resolveInput: resolveInput, youtubeId: youtubeId, state: state };
})();
