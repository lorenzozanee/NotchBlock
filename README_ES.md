# NotchBlock

<p align="center">
  <img src="icon.png" alt="Icono de NotchBlock" width="128" height="128">
</p>

<p align="center">
  <strong>Convierte la muesca del hardware Mac en una puerta de entrada para el time-blocking.</strong>
</p>

<p align="center">
  <a href="https://github.com/lorenzozanee/NotchBlock/releases"><img src="https://img.shields.io/github/v/release/lorenzozanee/NotchBlock?color=blue" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="License: MIT"></a>
  <a href="#"><img src="https://img.shields.io/badge/platform-macOS%2014.0%2B-orange" alt="macOS 14.0+"></a>
  <a href="#"><img src="https://img.shields.io/badge/swift-6.1-FA7343?logo=swift" alt="Swift 6.1"></a>
</p>

<p align="center">
  <sub><a href="README.md">English</a> | <a href="README_ZH.md">中文</a> | <a href="README_FR.md">Français</a> | Español | <a href="README_JA.md">日本語</a> | <a href="README_KO.md">한국어</a></sub>
</p>

---

NotchBlock es un planificador de time-blocking minimalista y **estricto** para macOS. Transforma la muesca del hardware en un punto de interacción invisible, y usa una superposición a pantalla completa imposible de ignorar para interrumpirte cuando una tarea termina — manteniéndote concentrado a la fuerza.

> 🎯 Pasa el cursor sobre la muesca → ve tu agenda del día → recordatorio a pantalla completa al finalizar la tarea → debes confirmar la finalización

## ✨ Funcionalidades

| Funcionalidad | Descripción |
|---|---|
| 🔲 **Panel emergente en la muesca** | Pasa el cursor sobre la muesca durante 0,5s — tu agenda se desliza elegantemente |
| 🛡️ **Detección de pantalla completa** | Pausa automáticamente la detección durante videos, juegos y presentaciones |
| ⚡ **Superposición de interrupción estricta** | Oscurecimiento completo de la pantalla al finalizar la tarea — bloquea toda otra interacción |
| ⏱️ **Timeout de 5 minutos** | Los bloques no reconocidos se marcan como «perdido» con una notificación del sistema |
| 📋 **Planificador diario** | Lista cronológica minimalista con detección automática de conflictos horarios |
| 🔄 **Corrección de historial** | Ajusta manualmente el estado de las tareas para un seguimiento preciso |
| 🚀 **Inicio al arrancar** | Activación con un clic desde la barra de menús; se ejecuta silenciosamente en segundo plano |
| 💾 **Almacenamiento local** | Todos los datos se almacenan localmente — sin red, totalmente privado |

## 📥 Instalación

Descarga el último `NotchBlock-*.dmg` desde la página de [Releases](https://github.com/lorenzozanee/NotchBlock/releases).

### Configuración en 3 pasos

Después de abrir el DMG, sigue las instrucciones en pantalla:

1. **Arrastra a Aplicaciones** — suelta `NotchBlock.app` en tu carpeta `Aplicaciones`
2. **Doble clic en `FixQuarantine.command`** — elimina el atributo de cuarentena e inicia la aplicación (primer inicio: clic derecho → Abrir)
3. **Listo** — el icono de la barra de menús aparece, ya puedes empezar

> 💡 ¿Por qué el paso 2? NotchBlock no está notarizado por Apple (requiere una cuenta de desarrollador de $99/año). macOS pone en cuarentena las aplicaciones descargadas. `FixQuarantine.command` ejecuta `xattr -cr /Applications/NotchBlock.app` para eliminar esta marca.

Después del primer inicio, concede estos permisos:

| Permiso | Uso | Ruta de configuración |
|---|---|---|
| **Accesibilidad** | Detectar apps en pantalla completa | Configuración del Sistema → Privacidad y seguridad → Accesibilidad |
| **Notificaciones** | Alertas de timeout de tareas | Configuración del Sistema → Notificaciones → NotchBlock |

### Instalación manual

```bash
# Si el script del DMG no se ejecuta, hazlo manualmente:
xattr -cr /Applications/NotchBlock.app
open /Applications/NotchBlock.app
```

## 🏗️ Arquitectura

```
macOS 14.0+ · Swift 6.1 · SwiftUI + AppKit
```

**APIs clave:**

- `NSTrackingArea` — seguimiento del ratón en la región de la muesca
- `NSPanel` + `.nonactivatingPanel` — panel desplegable (no roba el foco)
- `CGShieldingWindowLevel()` + `.fullScreenAuxiliary` — superposición que lo atraviesa todo
- `CGWindowList` — detección de estado de pantalla completa
- `SMAppService` — registro de elemento de inicio
- `UserNotifications` — alertas de banner por timeout
- `UserDefaults` / JSON ISO 8601 — persistencia local

**Estructura del proyecto:**

```
NotchBlock/
├── Models/           TimeBlock · BlockStatus
├── Managers/         TimeBlockStore · NotchTracker · NotchPanelController
│                     OverlayWindowController · BlockScheduler
├── Views/            MainSchedulerView · TimeBlockRowView · AddEditBlockView
│                     NotchPanelView · OverlayView
└── Utilities/        DateExtensions · LaunchManager
```

## ⌨️ Atajos

| Atajo | Acción |
|---|---|
| `⌘O` | Abrir el panel del planificador |
| `⌘Q` | Salir de NotchBlock |

## 📝 Desarrollo

```bash
# Regenerar el proyecto Xcode después de añadir/eliminar archivos .swift
python3 generate_xcode_project.py

# Build por línea de comandos
xcodebuild -project NotchBlock.xcodeproj -scheme NotchBlock -configuration Release build

# Crear DMG
./scripts/build-dmg.sh
```

## 📄 Licencia

[Licencia MIT](LICENSE)

---

<p align="center">
  <sub>Construido con ❤️ para el trabajo concentrado · macOS Apple Silicon</sub>
</p>
