# Contribuer à Scrappy.Dev TV

Les suggestions et signalements sont suivis dans les [issues](https://github.com/Scrappyoff/scrappydev_tv/issues).

## Signaler un bug

Indiquez la version de la ressource, le framework et l'inventaire utilisés, les étapes de reproduction, le résultat attendu et le résultat constaté. Ajoutez les erreurs des consoles serveur et F8 ainsi que le modèle de télévision ou l'identifiant d'écran concerné.

Retirez les tokens, mots de passe, adresses privées et informations personnelles avant de publier des journaux ou une configuration. Pour un problème lié à un média, utilisez un lien public sans identifiant secret.

## Proposer une modification

1. Décrivez le problème ou la fonctionnalité dans une issue lorsqu'un changement important est envisagé.
2. Travaillez sur une branche dédiée et gardez la modification centrée sur un objectif.
3. Mettez à jour `locales/en.lua`, `locales/fr.lua` et les textes NUI concernés si l'interface change.
4. Documentez les nouvelles options dans `config.lua` et dans la documentation.
5. Ouvrez une pull request en expliquant le comportement et les vérifications réalisées.

## Vérifications utiles

Sans serveur FiveM, vérifiez au minimum la syntaxe des JavaScript modifiés avec `node --check chemin/du/fichier.js`. Avec Lua 5.4 installé, `luac -p chemin/du/fichier.lua` permet de vérifier la syntaxe des fichiers Lua. Ces commandes n'exécutent pas les natives FiveM.

Pour un changement de comportement en jeu, vérifiez les actions concernées sur votre serveur, idéalement avec deux joueurs : ouverture de la télécommande, changement de média, pause, déplacement, arrivée tardive et isolation entre routing buckets si applicable. Testez les restrictions d'objet et de permissions lorsque la modification les concerne.

Ne présentez pas une vérification de syntaxe comme un test de fonctionnement en jeu. Précisez les frameworks et fournisseurs effectivement testés.

## Organisation

- `server/` gère l'état partagé, la validation et les exports.
- `client/` gère le rendu FiveM, la proximité et les contrôles.
- `shared/urls.lua` classe et filtre les liens.
- `html/` contient le lecteur DUI et la télécommande NUI.
- `docs/` contient la documentation autonome et sa version GitHub Pages.
