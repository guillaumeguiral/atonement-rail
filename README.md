# AtonementRail

Addon WoW Retail pour afficher une barre d'Expiation sur les frames Blizzard de groupe.

## Installation

Copier le dossier `AtonementRail` dans :

```text
World of Warcraft\_retail_\Interface\AddOns\
```

Le chemin final doit ressembler a :

```text
World of Warcraft\_retail_\Interface\AddOns\AtonementRail\AtonementRail.toc
```

## Configuration

- Ouvrir `Options > AddOns > AtonementRail`.
- Ajuster l'epaisseur de la barre entre `4px` et `30px` (`8px` par defaut).
- Choisir ou placer la barre quand le groupe est vertical : `Droite` par defaut, ou `Gauche`.
- Choisir ou placer la barre quand le groupe est horizontal : `Haut` par defaut, ou `Bas`.
- Choisir la texture de la barre. `Aucune / pleine` utilise une barre solide sans texture.
- Activer `Mode test` pour afficher les barres sans Expiation active.
- Commandes slash : `/atonementrail` ou `/arail`.

## Notes

- Supporte les frames Blizzard natives de groupe.
- Ne s'active pas en raid.
- Suit l'aura Expiation avec le spell ID `194384`.
