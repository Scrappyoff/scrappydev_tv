<p align="center">
  <img src="docs/assets/banner.svg" alt="Scrappy.Dev TV — Télévisions synchronisées pour FiveM" width="100%">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/FiveM-GTA_V-F58025?style=flat-square" alt="FiveM / GTA V">
  <img src="https://img.shields.io/badge/version-1.0.0-ff4257?style=flat-square" alt="Version 1.0.0">
  <img src="https://img.shields.io/badge/Lua-5.4-2C2D72?style=flat-square" alt="Lua 5.4">
  <img src="https://img.shields.io/badge/interface-FR_%2F_EN-35d07f?style=flat-square" alt="Interface français et anglais">
</p>

<p align="center">
  <b>Une télécommande. Un écran. Une expérience partagée.</b><br>
  Télévisions en jeu, vidéos synchronisées, navigation à la souris et écrans personnalisés pour votre serveur FiveM.
</p>

<p align="center">
  <a href="#installation">Installation</a> ·
  <a href="https://scrappyoff.github.io/scrappydev_tv/">Documentation interactive FR / EN</a> ·
  <a href="https://github.com/Scrappyoff/scrappydev_tv/releases/latest">Télécharger</a> ·
  <a href="README.en.md">English</a>
</p>

---

## Ce que propose Scrappy.Dev TV

Transformez les télévisions de votre map en écrans utilisables : les joueurs ouvrent la télécommande, choisissent une chaîne ou collent un lien, puis regardent le contenu ensemble. Le serveur conserve l'état de lecture et l'horloge des médias pris en charge, y compris pour les joueurs qui arrivent en cours de diffusion.

| Fonctionnalité | Détails |
| --- | --- |
| **Lecture partagée** | YouTube et médias directs avec lecture, pause, avance et volume synchronisés. |
| **Télécommande NUI** | Touches numériques, guide des chaînes, applications, raccourcis couleur, favoris et historique local. |
| **Navigation web** | Mode souris avec clics et défilement ; un joueur prend le contrôle de l'écran. |
| **Audio de proximité** | Atténuation selon la distance et la pièce pour les lecteurs contrôlés par le script. |
| **Écrans sur mesure** | Props de télévision, écrans libres pour les MLO, présélections et calibrage en jeu. |
| **Accès configurable** | Commande, `ox_target`, objet télécommande et permissions ACE ou métier. |
| **Intégration serveur** | Adaptateurs QBCore, QBX, ESX, ox_core et mode standalone. |
| **FR / EN** | Interface et documentation disponibles en français et en anglais. |

L'état des télévisions reste en mémoire : aucune base de données propre au script n'est nécessaire. Il est réinitialisé au redémarrage de la ressource ; les présélections configurées sont alors rejouées.

## Installation

### 1. Préparer les dépendances

| Composant | Utilisation |
| --- | --- |
| **Serveur FiveM avec OneSync** | Coordonnées des joueurs et routing buckets utilisés côté serveur. |
| **`ox_lib`** | Obligatoire, même en standalone : callbacks et notifications de secours. |
| QBCore / QBX / ESX / ox_core | Facultatif ; détection automatique ou sélection dans `Config.Framework`. |
| `ox_target` | Facultatif ; uniquement pour l'interaction target. |
| `ox_inventory`, inventaire QBCore ou ESX | Facultatif ; uniquement pour l'objet télécommande. |

### 2. Installer la ressource

Téléchargez **`scrappydev_tv-v1.0.0.zip`** depuis les [releases](https://github.com/Scrappyoff/scrappydev_tv/releases/latest), puis extrayez le dossier dans vos ressources :

```text
resources/
└── [scrappy]/
    └── scrappydev_tv/
        ├── fxmanifest.lua
        ├── config.lua
        ├── client/
        ├── server/
        └── html/
```

Vous pouvez aussi cloner le dépôt depuis votre dossier de ressources :

```bash
git clone https://github.com/Scrappyoff/scrappydev_tv.git scrappydev_tv
```

> Avec le ZIP automatique **Code → Download ZIP** de GitHub, renommez `scrappydev_tv-main` en **`scrappydev_tv`**. Les exemples d'inventaire et d'exports utilisent ce nom.

### 3. Configurer le démarrage

Dans `server.cfg`, démarrez votre framework et vos intégrations avant la ressource :

```cfg
ensure ox_lib
# Démarrez ici votre framework et votre inventaire, si utilisés.
# ensure ox_target       # si Config.Access.target = true
ensure scrappydev_tv
```

Un exemple est fourni dans [`install/server.cfg.example`](install/server.cfg.example).

### 4. Choisir la langue et tester

Dans [`config.lua`](config.lua), modifiez les valeurs existantes :

```lua
Config.Locale = 'fr'       -- 'en' par défaut
Config.Framework = 'auto'  -- auto, qb, qbx, esx, ox, standalone
```

Redémarrez la ressource, approchez-vous d'une télévision compatible, puis utilisez **`/tv`**. Lancez une vidéo YouTube autorisant l'intégration ou un fichier vidéo public. Faites rejoindre un second joueur pour vérifier la lecture partagée sur votre serveur.

## Configuration rapide

Les blocs ci-dessous remplacent les entrées correspondantes de `config.lua`. Les coordonnées et liens d'exemple sont à adapter à votre serveur.

### Télécommande en inventaire et target

```lua
Config.Access = {
    command = true,
    target = true,       -- nécessite ox_target
    item = 'tv_remote',
    itemRequired = true, -- exige l'objet pour contrôler une télévision
}
```

| Inventaire | Fichier à utiliser |
| --- | --- |
| ox_inventory | [`install/ox_items.snippet.txt`](install/ox_items.snippet.txt) |
| QBCore / QBX | [`install/qb_items.snippet.txt`](install/qb_items.snippet.txt), à adapter à l'inventaire choisi |
| ESX natif | [`install/esx_items.sql`](install/esx_items.sql), uniquement pour le schéma `items(name, label, weight)` |
| Icône | [`install/images/tv_remote.png`](install/images/tv_remote.png) |

Ajoutez la définition à votre inventaire et copiez l'icône dans son dossier d'images. **N'importez pas le SQL ESX si vous utilisez ox_inventory.** Pour conserver une utilisation sans objet, laissez `item = false` et `itemRequired = false`.

### Guide des chaînes

```lua
Config.Channels = {
    { name = 'Cinéma', url = 'https://media.example.com/cinema.mp4' },
    { name = 'Direct', url = 'https://media.example.com/live.m3u8' },
}
```

L'ordre du tableau détermine le numéro des chaînes. Le guide est vide par défaut. Remplacez les liens `example.com` par vos propres médias publics.

### Écran libre pour un MLO

```lua
Config.Screens = {
    {
        id = 'lobby_screen',
        coords = vec3(0.0, 0.0, 0.0), -- position de votre écran
        width = 4.0,
        height = 2.25,
        heading = 0.0,
        pitch = 0.0,
        maxdistance = 40.0,
        controldistance = 15.0,
        renderer = 'poly',
    },
}
```

Le rendu polygonal est fourni. Le rendu Scaleform est facultatif et aucun fichier `.gfx` tiers n'est inclus. Utilisez `/tvcalib` près de l'écran pour ajuster sa position, puis recopiez les valeurs affichées dans F8 vers `config.lua` : le calibrage ne sauvegarde pas le fichier automatiquement.

### Permissions de contrôle

```lua
Config.Permissions = {
    enabled = true,
    ace = 'scrappydev_tv.control',
    jobs = { 'police', 'cinema' },
}
```

```cfg
add_ace group.admin scrappydev_tv.control allow
```

L'ACE **ou** l'un des métiers autorise le contrôle. L'objet reste nécessaire si `itemRequired` est activé.

## Commandes et raccourcis

| Commande | Rôle |
| --- | --- |
| `/tv` | Ouvrir la télécommande de la télévision proche. |
| `/streamermode` | Basculer la coupure locale du son des lecteurs contrôlés par le script. |
| `/tvcalib` | Afficher les réglages de l'écran libre actif. |
| `/tvcalib width 4.0` | Régler sa largeur à 4 mètres. |
| `/tvcalib z +0.05` | Monter l'écran de 5 centimètres. |

`/tv` et `/streamermode` sont renommables dans la configuration. Le calibrage est un outil client ; il modifie le rendu local jusqu'au redémarrage.

| Touche dans la télécommande | Action |
| --- | --- |
| `Échap` | Fermer le panneau actif ou quitter le mode souris. |
| `Tab` | Afficher / masquer le panneau d'adresse. |
| Flèches / `Entrée` | Naviguer / valider. |
| `Page Up` / `Page Down` | Changer de chaîne. |
| `+` / `-` / `M` | Volume / muet. |
| `P` / `G` / `I` | Marche-arrêt / guide / informations. |

## Médias et limites

| Source | Comportement |
| --- | --- |
| YouTube | Lecteur dédié ; l'auteur doit autoriser l'intégration de la vidéo. |
| Vidéo / audio directs | URL publique vers un fichier ; lecture selon les codecs disponibles dans FiveM. |
| HLS `.m3u8` | Lecture native si disponible, sinon chargement de hls.js depuis `cdn.jsdelivr.net`. Le flux doit autoriser les requêtes nécessaires. |
| Images | Affichage d'images publiques, notamment PNG, JPEG, WebP et GIF. |
| Vimeo / Dailymotion | Transformation des liens reconnus en liens de lecteur web intégré. |
| Twitch et autres sites | Navigation web ; disponibilité et lecture dépendent du site. Aucun lecteur dédié Twitch n'est inclus. |

La synchronisation de lecture, le volume et le mode streamer concernent les lecteurs contrôlés par le script. Les pages web externes peuvent gérer leur propre audio et leur propre session ; leur comportement n'est pas identique à celui d'un média direct. Les services avec DRM ne sont pas pris en charge.

Le filtre d'URL refuse notamment les adresses IP littérales, plusieurs suffixes locaux et les domaines de `Config.BlacklistedHosts`. Il ne résout pas les DNS et ne contrôle pas toutes les redirections des sites externes. Ne placez pas de secret dans les liens partagés.

## Intégration développeur

Ouvrir la télécommande depuis un autre script **client** :

```lua
exports['scrappydev_tv']:OpenTelevision()
```

Lancer un média depuis un script **serveur**, sur une télévision ou un écran déjà déclaré à ces coordonnées :

```lua
local coords = vector3(0.0, 0.0, 0.0) -- à remplacer
local bucket = 0
local success = exports['scrappydev_tv']:PlayVideoOnTelevision(
    coords, bucket, 50, 'https://media.example.com/cinema.mp4'
)

if success then
    exports['scrappydev_tv']:ChangeVolumeTelevision(coords, 35, bucket)
end

-- Pour arrêter la diffusion :
-- exports['scrappydev_tv']:StopTelevision(coords, bucket)
```

La [documentation interactive](https://scrappyoff.github.io/scrappydev_tv/#dev-api) décrit les signatures complètes, `StartTelevision`, `useRemote` et les événements de compatibilité. `HasVehicleTV()` est un export de compatibilité qui renvoie `false` : les télévisions embarquées ne sont pas implémentées.

## Structure du projet

```text
scrappydev_tv/
├── client/        Détection, rendu, télécommande et adaptateurs client
├── server/        État des TV, validation, exports et vérification de version
├── shared/        Normalisation et classification des URL
├── html/          Lecteur DUI et interface NUI
├── locales/       Traductions anglaises et françaises
├── install/       Exemples d'inventaire, SQL, icône et server.cfg
├── docs/          Documentation interactive autonome
├── config.lua     Configuration du serveur
└── fxmanifest.lua Déclaration de la ressource FiveM
```

## Aide et mises à jour

- **Aucune télévision détectée :** vérifiez le modèle dans `Config.Models` et la distance de contrôle, ou déclarez un écran dans `Config.Screens`.
- **Écran noir :** vérifiez l'alimentation, le média, les erreurs F8 et les conflits avec une autre ressource TV.
- **Target ou objet absent :** vérifiez la configuration, la définition d'inventaire et l'ordre de démarrage.
- **Site muet, bloqué ou non synchronisé :** essayez un média direct ; les lecteurs web externes ont leurs propres restrictions.

Pour signaler un problème, ouvrez une [issue](https://github.com/Scrappyoff/scrappydev_tv/issues) avec votre framework, les erreurs serveur / F8, le modèle de TV et les étapes de reproduction. Retirez les identifiants et données privées des journaux.

Consultez le [changelog](CHANGELOG.md) et les [releases](https://github.com/Scrappyoff/scrappydev_tv/releases). Avant une mise à jour, sauvegardez `config.lua` et vos traductions, remplacez les fichiers, reportez les nouvelles options puis exécutez `restart scrappydev_tv`.

La vérification de version est **désactivée par défaut**. Pour l'activer, utilisez `Config.VersionCheck.enabled = true` et l'URL `https://raw.githubusercontent.com/Scrappyoff/scrappydev_tv/main/version.json`. Elle affiche une notification dans la console serveur sans télécharger ni remplacer les fichiers.

La documentation fonctionne aussi hors ligne : ouvrez [`docs/index.html`](docs/index.html) dans votre navigateur après téléchargement. Pour proposer une amélioration, consultez [CONTRIBUTING.md](CONTRIBUTING.md).

---

<p align="center">Créé par <b>Scrappy.Dev</b> · Code source publié par <a href="https://github.com/Scrappyoff">Scrappyoff</a></p>

Le dépôt contient le code source lisible. Aucune licence open source n'est déclarée dans cette version.
