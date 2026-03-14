# nico-renamer (zig)

Version Zig de `nico-renamer`, alignée sur le comportement de la version Node.

## Fonctionnement

- Si `rename.xlsx` n'existe pas dans le dossier cible, le programme le crée à partir des fichiers `.txt`.
- Si `rename.xlsx` existe, le programme lit chaque ligne et:
  - renomme le fichier `nom` en remplaçant la concentration entre `[]` par `maj`
  - met à jour le contenu du fichier renommé (`Sample concentration: ...`) avec `maj`

Le format attendu dans la feuille Excel (1ere feuille) est:

- `nom`
- `concentration`
- `maj`

## Exécution

Depuis le dossier `zig`:

```bash
zig build run -- ../test-data
```

Ou sans argument (répertoire courant):

```bash
zig build run
```

## Build binaire

```bash
zig build -Doptimize=ReleaseSafe
```

Le binaire est installé dans `zig-out/bin/nico-renamer`.
