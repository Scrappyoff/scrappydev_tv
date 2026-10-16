
(function () {
	'use strict';

	var DRIFT_TOLERANCE = 2.0;
	var CHECK_INTERVAL = 1000;
	var MIN_RESEEK_GAP = 3500;

	var $ = function (id) { return document.getElementById(id); };
	var UI_LOCALE = new URLSearchParams(location.search).get('locale') || 'en';
	if (window.ScrappyI18n) window.ScrappyI18n.setLocale(UI_LOCALE);
	function tr(value) { return window.ScrappyI18n ? window.ScrappyI18n.t(String(value), UI_LOCALE) : value; }
	var el = {
		menu: $('menu'), menutitle: $('menutitle'), menubody: $('menubody'), menuhints: $('menuhints'), off: $('offlayer'),
		osdvol: $('osdvolume'), osdvolicon: $('osdvolicon'), osdvolfill: $('osdvolfill'), osdvolnum: $('osdvolnum'),
		osdch: $('osdchannel'), osdchnum: $('osdchnum'), osdchname: $('osdchname'),
		osdin: $('osdinfo'), osdinnum: $('osdinnum'), osdintitle: $('osdintitle'), osdinsub: $('osdinsub'), osdtoast: $('osdtoast'),
		yt: $('ytlayer'), media: $('media'), medialayer: $('medialayer'), audioart: $('audioart'),
		image: $('imagelayer'), picture: $('picture'), idle: $('idle'), spinner: $('spinner'),
		notice: $('notice'), ntitle: $('noticetitle'), ntext: $('noticetext')
	};

	var RES = (function () {
		try { return location.host.replace(/^cfx-nui-/, ''); } catch (e) { return 'scrappydev_tv'; }
	})();

	function post(name, data) {
		try {
			return fetch('https://' + RES + '/' + name, {
				method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data || {})
			}).catch(function () {});
		} catch (e) { return null; }
	}

	var S = {
		kind: null, src: null, videoId: null, mediaType: null,
		basePos: 0, baseAt: 0, paused: false, volume: 50,
		lastSeekAt: 0, ended: false, needUnmute: false,
		yt: null, ytReady: false, ytPending: null, ytApiRequested: false, ytLoadedId: null,
		hls: null, mediaSrc: null
	};

	function now() { return (window.performance && performance.now) ? performance.now() : Date.now(); }

	function target() {
		return Math.max(0, S.basePos + (S.paused ? 0 : (now() - S.baseAt) / 1000));
	}

	function showLayer(name) {
		el.yt.hidden = name !== 'youtube';
		el.medialayer.hidden = name !== 'media';
		el.image.hidden = name !== 'image';
		el.idle.hidden = name !== 'idle';
		if (name !== 'media') el.audioart.hidden = true;
	}

	function notice(title, text) {
		if (!title) { el.notice.hidden = true; return; }
		el.ntitle.textContent = tr(title); el.ntext.textContent = tr(text || ''); el.notice.hidden = false;
		el.spinner.hidden = true;
	}

	function spin(on) { el.spinner.hidden = !on; }

	function ytError(code) {
		var msg = {
			2: ['Lien invalide', "Cette vidéo YouTube n'existe pas."],
			5: ['Erreur du lecteur', 'La vidéo ne peut pas être lue ici.'],
			100: ['Vidéo introuvable', 'Elle a été supprimée ou est privée.'],
			101: ['Lecture interdite', "L'auteur n'autorise pas la lecture sur d'autres sites."],
			150: ['Lecture interdite', "L'auteur n'autorise pas la lecture sur d'autres sites."]
		}[code] || ['Erreur de lecture', 'Impossible de lire cette vidéo.'];
		notice(msg[0], msg[1]);
	}

	function ytApply(fn) {
		if (S.ytReady && S.yt) { try { fn(S.yt); } catch (e) {  } }
	}

	function ensureYouTube(cb) {
		if (S.yt) { cb(); return; }
		S.ytPending = cb;
		function build() {
			if (S.yt) return;
			S.yt = new YT.Player('ytmount', {
				width: '100%', height: '100%',
				playerVars: { autoplay: 1, controls: 0, disablekb: 1, modestbranding: 1, rel: 0, iv_load_policy: 3, playsinline: 1, fs: 0, cc_load_policy: 0 },
				events: {
					onReady: function () {
						S.ytReady = true;
						var p = S.ytPending; S.ytPending = null; if (p) p();
					},
					onStateChange: function (e) {
						var st = e.data;
						if (st === 1) { spin(false); notice(null); if (S.ytWasEnded) S.ytWasEnded = false; }
						else if (st === 3) spin(true);
						else if (st === 0) { S.ended = true; spin(false); }
						else spin(false);
					},
					onError: function (e) { ytError(e && e.data); }
				}
			});
		}
		if (window.YT && window.YT.Player) { build(); return; }
		window.onYouTubeIframeAPIReady = build;
		if (!S.ytApiRequested) {
			S.ytApiRequested = true;
			var tag = document.createElement('script');
			tag.src = 'https://www.youtube.com/iframe_api';
			tag.onerror = function () { notice('YouTube indisponible', "Impossible de contacter YouTube depuis le serveur."); };
			document.head.appendChild(tag);
		}
	}

	function ytLoad() {
		var id = S.videoId;
		if (!id) { notice('Lien invalide', 'Identifiant YouTube introuvable.'); return; }
		ensureYouTube(function () {
			var pos = target();
			S.ended = false;
			S.ytLoadedId = id;
			notice(null); spin(true);
			ytApply(function (p) {
				p.loadVideoById({ videoId: id, startSeconds: pos });
				p.setVolume(S.volume);
				if (S.volume === 0) p.mute(); else p.unMute();
				if (S.paused) setTimeout(function () { ytApply(function (q) { q.pauseVideo(); }); }, 900);
			});
			S.lastSeekAt = now();
		});
	}

	function ytEnforce() {
		ytApply(function (p) {
			var dur = 0, cur = 0, st = -1;
			try { dur = p.getDuration() || 0; cur = p.getCurrentTime() || 0; st = p.getPlayerState(); } catch (e) { return; }
			var want = target();
			if (dur > 0 && want >= dur - 0.4) { S.ended = true; return; }
			S.ended = false;

			if (S.paused) {
				if (st === 1 || st === 3) p.pauseVideo();
			} else if (st === 2 || st === 5 || st === -1) {
				p.playVideo();
			} else if (st === 0) {
				p.seekTo(want, true); p.playVideo(); S.lastSeekAt = now();
			}

			var drift = Math.abs(cur - want);
			var live = dur === 0;
			if (!live && drift > DRIFT_TOLERANCE && now() - S.lastSeekAt > MIN_RESEEK_GAP && st !== 3) {
				p.seekTo(want, true); S.lastSeekAt = now();
			}
		});
	}

	function destroyHls() {
		if (S.hls) { try { S.hls.destroy(); } catch (e) {  } S.hls = null; }
	}

	function loadHlsLib(cb) {
		if (window.Hls) { cb(); return; }
		var tag = document.createElement('script');
		tag.src = 'https://cdn.jsdelivr.net/npm/hls.js@1/dist/hls.min.js';
		tag.onload = cb;
		tag.onerror = function () { notice('Lecteur indisponible', 'Impossible de charger le flux en direct.'); };
		document.head.appendChild(tag);
	}

	function playMedia() {
		var m = el.media;
		var p;
		try { p = m.play(); } catch (e) { p = null; }
		if (p && p.catch) {
			p.catch(function () {
				m.muted = true; S.needUnmute = true;
				try { m.play().catch(function () {}); } catch (e) {  }
			});
		}
	}

	function applyMediaVolume() {
		var m = el.media;
		m.volume = Math.max(0, Math.min(1, S.volume / 100));
		if (S.volume === 0) { m.muted = true; return; }
		if (S.needUnmute) {
			m.muted = false;
			if (m.paused && !S.paused) { m.muted = true; playMedia(); } else S.needUnmute = false;
		} else {
			m.muted = false;
		}
	}

	function seekMedia(pos) {
		var m = el.media;
		try {
			if (isFinite(m.duration) && m.duration > 0) pos = Math.min(pos, Math.max(0, m.duration - 0.25));
			m.currentTime = pos;
		} catch (e) {  }
		S.lastSeekAt = now();
	}

	function mediaLoad() {
		var m = el.media;
		destroyHls();
		S.ended = false; S.needUnmute = false;
		notice(null); spin(true);
		el.audioart.hidden = S.mediaType !== 'audio';
		el.medialayer.classList.toggle('paused', S.paused);
		S.mediaSrc = S.src;

		function start() {
			var pos = target();
			var resume = function () {
				m.removeEventListener('loadedmetadata', resume);
				seekMedia(pos);
				applyMediaVolume();
				if (S.paused) m.pause(); else playMedia();
			};
			m.addEventListener('loadedmetadata', resume);
		}

		if (S.mediaType === 'hls' && !m.canPlayType('application/vnd.apple.mpegurl')) {
			loadHlsLib(function () {
				if (!window.Hls || !window.Hls.isSupported()) { notice('Lecteur indisponible', 'Ce flux ne peut pas être lu ici.'); return; }
				var hls = new window.Hls({ enableWorker: true, lowLatencyMode: true });
				S.hls = hls;
				hls.on(window.Hls.Events.ERROR, function (_, data) {
					if (data && data.fatal) notice('Flux interrompu', 'Le flux en direct est indisponible.');
				});
				start();
				hls.loadSource(S.src);
				hls.attachMedia(m);
			});
			return;
		}

		start();
		m.src = S.src;
		m.load();
	}

	function mediaEnforce() {
		var m = el.media;
		if (!S.mediaSrc || !m.src) return;
		var want = target();
		var dur = m.duration;
		var finite = isFinite(dur) && dur > 0;
		if (finite && want >= dur - 0.4) { S.ended = true; return; }
		S.ended = false;

		if (S.paused) { if (!m.paused) m.pause(); }
		else if (m.paused && m.readyState >= 2) playMedia();

		var live = !finite;
		if (!live && Math.abs(m.currentTime - want) > DRIFT_TOLERANCE && now() - S.lastSeekAt > MIN_RESEEK_GAP && m.readyState >= 2) {
			seekMedia(want);
		}
		if (S.needUnmute) applyMediaVolume();
	}

	el.media.addEventListener('waiting', function () { spin(true); });
	el.media.addEventListener('playing', function () { spin(false); notice(null); });
	el.media.addEventListener('canplay', function () { spin(false); });
	el.media.addEventListener('ended', function () { S.ended = true; spin(false); });
	el.media.addEventListener('error', function () {
		if (!S.mediaSrc) return;
		spin(false);
		notice('Lecture impossible', 'Ce fichier ou ce flux ne peut pas être lu (lien cassé, format non pris en charge ou accès refusé).');
	});

	function imageLoad() {
		notice(null); spin(true);
		el.picture.onload = function () { spin(false); };
		el.picture.onerror = function () { spin(false); notice('Image introuvable', "Le lien ne mène pas à une image lisible."); };
		el.picture.src = S.src;
	}

	function stopAll() {
		ytApply(function (p) { p.stopVideo(); });
		S.ytLoadedId = null;
		var m = el.media;
		try { m.pause(); } catch (e) {  }
		destroyHls();
		S.mediaSrc = null;
		m.removeAttribute('src');
		try { m.load(); } catch (e) {  }
		el.picture.removeAttribute('src');
		S.kind = null; S.src = null; S.videoId = null; S.ended = false; S.needUnmute = false;
		spin(false); notice(null);
	}

	function idle() {
		stopAll();
		showLayer('idle');
	}


	var ICONS = {
		tv: '<rect x="3" y="5" width="18" height="12" rx="2.5"/><path d="M8 21h8M12 17v4"/>',
		youtube: '<rect x="2.5" y="5.5" width="19" height="13" rx="4"/><path d="M10 9.5v5l4.5-2.5z"/>',
		twitch: '<path d="M4 3.5h16v10.5l-4 4h-4l-3 3v-3H4z"/><path d="M11 8v4M15 8v4"/>',
		kick: '<path d="M5 4v16M5 12l8-8M7.5 9.5 14 20"/>',
		globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18"/>',
		star: '<path d="m12 3.5 2.6 5.3 5.9.9-4.3 4.1 1 5.8-5.2-2.8-5.2 2.8 1-5.8-4.3-4.1 5.9-.9z"/>',
		film: '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M7 4v16M17 4v16M3 9h4M3 15h4M17 9h4M17 15h4"/>'
	};
	var SPEAKER = '<path d="M4 9.5v5h3.5L12 18.5v-13L7.5 9.5z"/>';
	var osdSeq = 0, osdTimer = null, uiState = { on: true };

	function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }

	function renderMenu(ui) {
		var m = ui.menu;
		if (!ui.on || !m) { el.menu.hidden = true; return; }
		el.menu.hidden = false;
		var sel = m.sel || 1, html = '';
		if (m.page === 'channels') {
			el.menutitle.textContent = tr('Chaînes');
			var list = ui.channels || [];
			if (!list.length) html = '<div class="list-empty">' + tr('Aucune chaîne configurée.') + '</div>';
			else {
				var perPage = 7, start = Math.max(0, Math.min(list.length - perPage, sel - 1 - Math.floor(perPage / 2)));
				html = '<div class="list">';
				for (var i = start; i < Math.min(list.length, start + perPage); i++) {
					html += '<div class="row' + (i + 1 === sel ? ' sel' : '') + '"><b>' + list[i].n + '</b><span>' + esc(list[i].name) + '</span>' +
						(ui.channel === list[i].n ? '<em>' + tr('En cours') + '</em>' : '') + '</div>';
				}
				html += '</div>';
			}
			el.menuhints.innerHTML = '<span><b>▲ ▼</b>' + tr('choisir') + '</span><span><b>OK</b>' + tr('regarder') + '</span><span><b>1-9</b>' + tr('numéro') + '</span><span><b>BACK</b>' + tr('retour') + '</span><span><b>EXIT</b>' + tr('quitter') + '</span>';
		} else {
			el.menutitle.textContent = tr('Accueil');
			html = '<div class="tiles">';
			(ui.apps || []).forEach(function (a, i) {
				html += '<div class="tile' + (i + 1 === sel ? ' sel' : '') + '"><svg viewBox="0 0 24 24">' + (ICONS[a.icon] || ICONS.film) + '</svg><span>' + esc(a.label) + '</span></div>';
			});
			html += '</div>';
			el.menuhints.innerHTML = '<span><b>◄ ►</b>' + tr('choisir') + '</span><span><b>OK</b>' + tr('ouvrir') + '</span><span><b>EXIT</b>' + tr('quitter') + '</span>';
		}
		el.menubody.innerHTML = html;
	}

	function hideOsd() {
		el.osdvol.hidden = el.osdch.hidden = el.osdin.hidden = el.osdtoast.hidden = true;
	}

	function showOsd(o, ui) {
		hideOsd();
		if (o.kind === 'volume' || o.kind === 'mute') {
			var muted = o.kind === 'mute' ? ui.muted : false;
			var v = Math.max(0, Math.min(100, Number(o.value) || 0));
			el.osdvol.hidden = false;
			el.osdvol.classList.toggle('muted', !!muted);
			el.osdvolfill.style.width = (muted ? 0 : v) + '%';
			el.osdvolnum.textContent = muted ? tr('Muet') : Math.round(v);
			el.osdvolicon.innerHTML = SPEAKER + (muted ? '<path d="M16 9.5l5 5M21 9.5l-5 5"/>' : '<path d="M15.5 9a4 4 0 0 1 0 6"/>' + (v > 55 ? '<path d="M18 6.5a8 8 0 0 1 0 11"/>' : ''));
		} else if (o.kind === 'channel') {
			el.osdch.hidden = false;
			el.osdchnum.textContent = o.value != null ? o.value : '';
			el.osdchname.textContent = o.text || '';
		} else if (o.kind === 'digits') {
			el.osdch.hidden = false;
			el.osdchnum.textContent = (o.text || '') + '_';
			el.osdchname.textContent = '';
		} else if (o.kind === 'info') {
			el.osdin.hidden = false;
			el.osdinnum.textContent = o.value != null ? o.value : 'TV';
			el.osdintitle.textContent = tr(o.text || 'Télévision');
			el.osdinsub.textContent = o.sub || '';
		} else if (o.kind === 'pause' || o.kind === 'seek') {
			el.osdtoast.hidden = false;
			el.osdtoast.textContent = (o.kind === 'pause' ? (o.text === 'Pause' ? '❚❚  ' : '▶  ') : (String(o.text).charAt(0) === '-' ? '◄◄  ' : '►►  ')) + o.text;
		}
	}

	function renderUi(ui) {
		uiState = ui;
		el.off.hidden = ui.on !== false;
		if (ui.on === false) { hideOsd(); el.menu.hidden = true; return; }
		renderMenu(ui);
		var o = ui.osd;
		if (o && o.seq !== osdSeq) {
			osdSeq = o.seq;
			var age = Number(o.ageMs) || 0;
			if (age < 2500) {
				showOsd(o, ui);
				clearTimeout(osdTimer);
				osdTimer = setTimeout(hideOsd, Math.max(400, 2500 - age));
			}
		}
	}

	function onSync(d) {
		var kind = d.kind;
		if (!d.src && !d.videoId) { idle(); return; }
		if (kind !== 'youtube' && kind !== 'media' && kind !== 'image') { idle(); return; }

		var pos = Number(d.position);
		S.basePos = isFinite(pos) ? pos : 0;
		S.baseAt = now();
		var wasPaused = S.paused;
		S.paused = !!d.paused;
		var vol = Number(d.volume);
		S.volume = isFinite(vol) ? Math.max(0, Math.min(100, vol)) : S.volume;

		var changed = kind !== S.kind || d.src !== S.src || (kind === 'youtube' && d.videoId !== S.videoId);
		S.mediaType = d.mediaType || null;

		if (changed) {
			var prev = S.kind;
			if (prev === 'youtube' && kind !== 'youtube') ytApply(function (p) { p.stopVideo(); });
			if (prev === 'media' && kind !== 'media') { el.media.pause(); el.media.removeAttribute('src'); destroyHls(); S.mediaSrc = null; }
			S.kind = kind; S.src = d.src; S.videoId = d.videoId;
			showLayer(kind === 'media' ? 'media' : kind);
			if (kind === 'youtube') ytLoad(); else if (kind === 'media') mediaLoad(); else imageLoad();
			return;
		}

		el.medialayer.classList.toggle('paused', S.paused);
		if (kind === 'youtube') {
			ytApply(function (p) {
				p.setVolume(S.volume); if (S.volume === 0) p.mute(); else p.unMute();
				var dur = 0; try { dur = p.getDuration() || 0; } catch (e) {  }
				var cur = 0; try { cur = p.getCurrentTime() || 0; } catch (e) {  }
				var want = target();
				if (dur > 0 && want < dur - 0.4 && Math.abs(cur - want) > DRIFT_TOLERANCE) { p.seekTo(want, true); S.lastSeekAt = now(); }
			});
			ytEnforce();
		} else if (kind === 'media') {
			applyMediaVolume();
			var m = el.media;
			if (isFinite(m.duration) && m.duration > 0 && Math.abs(m.currentTime - target()) > DRIFT_TOLERANCE && m.readyState >= 1) seekMedia(target());
			mediaEnforce();
		}
		if (wasPaused !== S.paused) spin(false);
	}

	function onVolume(d) {
		var vol = Number(d.volume);
		if (!isFinite(vol)) return;
		S.volume = Math.max(0, Math.min(100, vol));
		if (S.kind === 'youtube') ytApply(function (p) { p.setVolume(S.volume); if (S.volume === 0) p.mute(); else p.unMute(); });
		else if (S.kind === 'media') applyMediaVolume();
	}

	window.addEventListener('message', function (event) {
		var d = event.data;
		if (typeof d === 'string') { try { d = JSON.parse(d); } catch (e) { return; } }
		if (!d || typeof d !== 'object') return;
		if (d.type === 'sync') onSync(d);
		else if (d.type === 'volume') onVolume(d);
		else if (d.type === 'idle') idle();
		else if (d.type === 'ui') renderUi(d);
	});

	setInterval(function () {
		if (S.kind === 'youtube') ytEnforce();
		else if (S.kind === 'media') mediaEnforce();
	}, CHECK_INTERVAL);

	showLayer('idle');
	el.off.hidden = true;
	post('playerReady', {});

	window.__scrappydevtvplayer = { state: S, target: target, onSync: onSync, onVolume: onVolume, idle: idle, renderUi: renderUi };
})();
