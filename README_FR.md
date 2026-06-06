# NotchBlock

<p align="center">
  <img src="icon.png" alt="Icône NotchBlock" width="128" height="128">
</p>

<p align="center">
  <strong>Transformez l'encoche matérielle du Mac en portail de time-blocking.</strong>
</p>

<p align="center">
  <a href="https://github.com/lorenzozanee/NotchBlock/releases"><img src="https://img.shields.io/github/v/release/lorenzozanee/NotchBlock?color=blue" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="License: MIT"></a>
  <a href="#"><img src="https://img.shields.io/badge/platform-macOS%2014.0%2B-orange" alt="macOS 14.0+"></a>
  <a href="#"><img src="https://img.shields.io/badge/swift-6.1-FA7343?logo=swift" alt="Swift 6.1"></a>
</p>

<p align="center">
  <sub><a href="README.md">English</a> | <a href="README_ZH.md">中文</a> | Français | <a href="README_ES.md">Español</a> | <a href="README_JA.md">日本語</a> | <a href="README_KO.md">한국어</a></sub>
</p>

---

NotchBlock est un planificateur de time-blocking minimaliste et **strict** pour macOS. Il transforme l'encoche matérielle en point d'interaction invisible, et utilise un overlay plein écran immanquable pour vous interrompre lorsqu'une tâche se termine — vous gardant concentré de force.

> 🎯 Survolez l'encoche → voyez le planning du jour → rappel plein écran à la fin d'une tâche → confirmation obligatoire

## ✨ Fonctionnalités

| Fonctionnalité | Description |
|---|---|
| 🔲 **Panneau encoche au survol** | Survolez l'encoche pendant 0,5s — votre planning apparaît élégamment |
| 🛡️ **Détection plein écran** | Désactive automatiquement la détection pendant les vidéos, jeux et présentations |
| ⚡ **Overlay d'interruption stricte** | Superposition plein écran qui obscurcit tout à la fin d'une tâche — bloque toute autre interaction |
| ⏱️ **Timeout de 5 minutes** | Les blocs non acquittés sont marqués « manqué » avec une notification système |
| 📋 **Planificateur quotidien** | Liste chronologique minimaliste avec détection automatique des conflits horaires |
| 🔄 **Correction d'historique** | Ajustez manuellement le statut des tâches pour un suivi précis |
| 🚀 **Lancement au démarrage** | Activation en un clic depuis la barre de menus ; s'exécute silencieusement en arrière-plan |
| 💾 **Stockage local** | Toutes les données sont stockées localement — pas de réseau, totalement privé |

## 📥 Installation

Téléchargez le dernier `NotchBlock-*.dmg` depuis la page [Releases](https://github.com/lorenzozanee/NotchBlock/releases).

### Installation en 3 étapes

Après avoir ouvert le DMG, suivez les instructions affichées :

1. **Glissez dans Applications** — déposez `NotchBlock.app` dans votre dossier `Applications`
2. **Double-cliquez sur `FixQuarantine.command`** — supprime l'attribut de quarantaine et lance l'application (premier lancement : clic droit → Ouvrir)
3. **Terminé** — l'icône de la barre de menus apparaît, vous êtes prêt

> 💡 Pourquoi l'étape 2 ? NotchBlock n'est pas notarisé par Apple (nécessite un compte développeur à 99 $/an). macOS met en quarantaine les applications téléchargées. `FixQuarantine.command` exécute `xattr -cr /Applications/NotchBlock.app` pour supprimer ce drapeau.

Après le premier lancement, accordez ces permissions :

| Permission | Utilisation | Chemin des réglages |
|---|---|---|
| **Accessibilité** | Détection des apps plein écran | Réglages Système → Confidentialité et sécurité → Accessibilité |
| **Notifications** | Alertes de timeout de tâche | Réglages Système → Notifications → NotchBlock |

### Installation manuelle

```bash
# Si le script du DMG ne s'exécute pas, faites-le manuellement :
xattr -cr /Applications/NotchBlock.app
open /Applications/NotchBlock.app
```

## 🏗️ Architecture

```
macOS 14.0+ · Swift 6.1 · SwiftUI + AppKit
```

**APIs clés :**

- `NSTrackingArea` — suivi de la souris dans la zone de l'encoche
- `NSPanel` + `.nonactivatingPanel` — panneau déroulant (ne vole pas le focus)
- `CGShieldingWindowLevel()` + `.fullScreenAuxiliary` — overlay qui traverse tout
- `CGWindowList` — détection de l'état plein écran
- `SMAppService` — enregistrement de l'élément de connexion
- `UserNotifications` — alertes bannière de timeout
- `UserDefaults` / JSON ISO 8601 — persistance locale

**Structure du projet :**

```
NotchBlock/
├── Models/           TimeBlock · BlockStatus
├── Managers/         TimeBlockStore · NotchTracker · NotchPanelController
│                     OverlayWindowController · BlockScheduler
├── Views/            MainSchedulerView · TimeBlockRowView · AddEditBlockView
│                     NotchPanelView · OverlayView
└── Utilities/        DateExtensions · LaunchManager
```

## ⌨️ Raccourcis

| Raccourci | Action |
|---|---|
| `⌘O` | Ouvrir le panneau de planification |
| `⌘Q` | Quitter NotchBlock |

## 📝 Développement

```bash
# Régénérer le projet Xcode après avoir ajouté/supprimé des fichiers .swift
python3 generate_xcode_project.py

# Build en ligne de commande
xcodebuild -project NotchBlock.xcodeproj -scheme NotchBlock -configuration Release build

# Créer le DMG
./scripts/build-dmg.sh
```

## 📄 Licence

[Licence MIT](LICENSE)

---

<p align="center">
  <sub>Construit avec ❤️ pour le travail concentré · macOS Apple Silicon</sub>
</p>
