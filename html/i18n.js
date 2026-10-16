(function (global) {
    'use strict';

    var en = {
        'Lien': 'Link', 'Éteinte': 'Off', 'Aucune lecture en cours': 'Nothing is playing',
        'Tape une adresse ou une recherche ci-dessous': 'Enter a URL or search below',
        'Lecture / pause': 'Play / pause', 'Adresse ou recherche': 'Address or search',
        'Colle un lien (YouTube, vidéo MP4, image, site web…) ou écris ce que tu cherches.': 'Paste a link (YouTube, MP4 video, image, website...) or enter a search.',
        'youtube.com/watch?v=… ou un mot à chercher': 'youtube.com/watch?v=... or a search term',
        'Ce lien semble incorrect.': 'This link looks incorrect.',
        'Site navigable avec le mode souris.': 'Browse this site in mouse mode.',
        'Fichier audio direct.': 'Direct audio file.', 'Audio': 'Audio', 'Site web': 'Website',
        'Télévision': 'Television', 'Utiliser la télévision': 'Use television', 'Utiliser l’écran': 'Use screen',
        'Lancer sur la télé': 'Play on TV', 'Récents': 'Recent', 'Favoris': 'Favorites',
        'Couper / rétablir le son': 'Mute / unmute', 'Arrêter la lecture': 'Stop playback',
        'Fermer le tiroir': 'Close panel', 'Fermer (Tab)': 'Close (Tab)', 'Effacer': 'Clear',
        'Ajouter aux favoris': 'Add to favorites', 'Favori': 'Favorite', 'Volume': 'Volume',
        'Fermer (Échap)': 'Close (Esc)', 'Mode souris : naviguer sur un site': 'Mouse mode: browse a website',
        'Chaînes': 'Channels', 'Liste des chaînes': 'Channel list', 'Retour': 'Back',
        'Quitter le menu': 'Exit menu', 'Accueil': 'Home', 'Haut': 'Up', 'Bas': 'Down',
        'Gauche': 'Left', 'Droite': 'Right', 'Mode streamer : couper le son des télés pour toi': 'Streamer mode: mute TV audio for yourself',
        'Allumer / éteindre': 'Power on / off', 'Adresse ou recherche, puis Entrée': 'Address or search, then press Enter',
        'Retour à la télécommande (Échap)': 'Return to remote (Esc)', 'Télécommande': 'Remote',
        'Tout fermer': 'Close everything', 'Aucun contenu sur l’écran': 'No content on screen',
        "Aucun contenu sur l'écran": 'No content on screen',
        'Chaîne +': 'Channel +', 'Chaîne −': 'Channel −',
        "Tape une adresse ou une recherche dans la barre du haut.": 'Enter a URL or search in the top bar.',
        'Molette': 'Scroll wheel', 'défiler': 'scroll', 'Échap': 'Esc', 'retour': 'back',
        'Recherche': 'Search', 'Ce texte sera cherché avec le moteur sélectionné.': 'This text will be searched with the selected search engine.',
        'Invalide': 'Invalid', 'Seuls les liens http(s) sont acceptés.': 'Only http(s) links are allowed.',
        'Lecture synchronisée pour tous les joueurs proches.': 'Synchronized playback for nearby players.',
        'Vidéo': 'Video', 'Vidéo directe : lecture synchronisée.': 'Direct video: synchronized playback.',
        'Flux HLS': 'HLS stream', 'Flux en direct : lecture synchronisée.': 'Live stream: synchronized playback.',
        'Image': 'Image', "Affiche l'image sur l'écran.": 'Displays the image on screen.', 'Lien': 'Link',
        'Retiré des favoris': 'Removed from favorites', 'Ajouté aux favoris': 'Added to favorites',
        'Éteinte': 'Off', 'En pause': 'Paused', 'En lecture': 'Playing', 'Allumée': 'On',
        'En cours de lecture': 'Playing', 'Aucune chaîne configurée.': 'No channels configured.',
        'En cours': 'Now playing', 'choisir': 'select', 'regarder': 'watch', 'numéro': 'number',
        'quitter': 'exit', 'ouvrir': 'open', 'Muet': 'Muted', 'Télévision': 'Television',
        'Aucun lien récent.': 'No recent links.', 'Ce que tu lances apparaîtra ici.': 'Items you play will appear here.',
        'Écris une adresse ou une recherche': 'Enter a URL or search', 'Envoi à la télévision…': 'Sending to the television...',
        'Rechargé pour tout le monde': 'Reloaded for everyone', 'Mode streamer activé': 'Streamer mode enabled',
        'Mode streamer désactivé': 'Streamer mode disabled', 'CHAÎNES': 'CHANNELS', 'ACCUEIL': 'HOME',
        'LECTURE': 'PLAYING', 'ALLUMÉE': 'ON', 'ÉTEINTE': 'OFF', 'PAUSE': 'PAUSED',
        'WEB': 'WEB', 'CHAÎNE': 'CHANNEL', 'Aucun contenu': 'No content',
        'Appuie sur MENU': 'Press MENU',
        'Pilote : ': 'Controller: ', 'Retiré des favoris': 'Removed from favorites',
        'Ajouté aux favoris': 'Added to favorites', 'Rien ne joue': 'Nothing is playing',
        'WEB': 'WEB', 'MENU': 'MENU', 'Aucune télévision': 'No television',
        'YouTube indisponible': 'YouTube unavailable',
        'Impossible de contacter YouTube depuis le serveur.': 'Could not reach YouTube from the server.',
        'Lien invalide': 'Invalid link', "Cette vidéo YouTube n'existe pas.": 'This YouTube video does not exist.',
        'Erreur du lecteur': 'Player error', 'La vidéo ne peut pas être lue ici.': 'This video cannot be played here.',
        'Vidéo introuvable': 'Video not found', 'Elle a été supprimée ou est privée.': 'It may have been removed or made private.',
        'Lecture interdite': 'Playback blocked', "L'auteur n'autorise pas la lecture sur d'autres sites.": 'The author does not allow playback on other websites.',
        'Erreur de lecture': 'Playback error', 'Impossible de lire cette vidéo.': 'This video could not be played.',
        'Identifiant YouTube introuvable': 'YouTube video ID not found', 'Lecteur indisponible': 'Player unavailable',
        'Impossible de charger le flux en direct.': 'Could not load the live stream.',
        'Ce flux ne peut pas être lu ici.': 'This stream cannot be played here.',
        'Flux interrompu': 'Stream interrupted', 'Le flux en direct est indisponible.': 'The live stream is unavailable.',
        'Lecture impossible': 'Playback failed',
        'Ce fichier ou ce flux ne peut pas être lu (lien cassé, format non pris en charge ou accès refusé).': 'This file or stream cannot be played (broken link, unsupported format, or access denied).',
        'Image introuvable': 'Image not found', 'Le lien ne mène pas à une image lisible.': 'The link does not point to a readable image.',
        'Press MENU': 'Press MENU', 'Chaîne': 'Channel', 'Scrappy.Dev remote': 'Scrappy.Dev remote'
    };

    var locale = 'en';
    var originalText = new WeakMap();
    var originalAttrs = new WeakMap();

    function translate(text, language) {
        language = language || locale;
        if (language !== 'en') return text;
        return en[text] || text;
    }

    function apply(language, root) {
        locale = language === 'fr' ? 'fr' : 'en';
        root = root || document;
        document.documentElement.lang = locale;
        var walker = document.createTreeWalker(root.body || root, NodeFilter.SHOW_TEXT);
        var nodes = [];
        while (walker.nextNode()) nodes.push(walker.currentNode);
        nodes.forEach(function (node) {
            if (!originalText.has(node)) originalText.set(node, node.nodeValue);
            var source = originalText.get(node);
            var trimmed = source.trim();
            if (!trimmed) return;
            var translated = translate(trimmed, locale);
            node.nodeValue = source.replace(trimmed, translated);
        });
        var attrs = ['title', 'aria-label', 'placeholder'];
        (root.querySelectorAll ? root.querySelectorAll('*') : []).forEach(function (element) {
            attrs.forEach(function (attr) {
                if (!element.hasAttribute(attr)) return;
                var key = attr + ':' + element.tagName + ':' + attr;
                var values = originalAttrs.get(element) || {};
                if (values[attr] === undefined) values[attr] = element.getAttribute(attr);
                originalAttrs.set(element, values);
                element.setAttribute(attr, translate(values[attr], locale));
            });
        });
        return locale;
    }

    global.ScrappyI18n = { t: translate, setLocale: apply, getLocale: function () { return locale; } };
})(window);
