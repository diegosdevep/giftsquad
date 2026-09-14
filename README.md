# GiftSquad

Aplicación iOS nativa para la coordinación inteligente de regalos.
Seminario Final — Escuela Da Vinci — Diego Maidana, 2026.

## Propuesta

GiftSquad articula tres modalidades sobre una misma base, preservando un principio rector: **el destinatario nunca sabe quién reservó qué, ni quién aportó cuánto**.

- **Pilar 1 — Lista de deseos compartida.** Cada usuario crea su lista con productos detallados y la comparte con su grupo.
- **Pilar 2 — Reserva anónima + Vaquita digital.** Los integrantes reservan ítems sin que el dueño los identifique. Para regalos costosos varios usuarios juntan plata vía vaquita con chat privado.
- **Pilar 3 — Amigo Invisible.** Sorteo automático con presupuesto y reglas de exclusión; cada participante ve solo su asignación.

## Stack

- **iOS:** SwiftUI, iOS 17+, Swift 5.10
- **Backend:** Firebase
  - Auth (email/password + Sign in with Google)
  - Cloud Firestore (modelo de datos + reglas que sostienen el anonimato)
  - Cloud Functions (sorteo Amigo Invisible, lógica sensible)
  - Cloud Messaging (notificaciones push)
- **Dependencias:** vía Swift Package Manager
- **Open Graph fetch:** `URLSession` + parser HTML mínimo en `LinkPreviewService`

## Estructura

```
GiftSquad/
├── GiftSquad/                    # código fuente Swift
│   ├── App/                      # entry point + navegación raíz
│   ├── Features/                 # una carpeta por pilar / módulo
│   ├── Models/                   # modelos Codable alineados a Firestore
│   ├── Services/                 # wrappers de Firebase y APIs externas
│   ├── Components/               # vistas reutilizables
│   ├── Utils/
│   └── Resources/                # Assets.xcassets, Info.plist, GoogleService-Info.plist
├── firestore/                    # reglas de seguridad + índices
│   ├── firestore.rules
│   └── firestore.indexes.json
├── docs/
│   └── ALCANCE.md                # documento de alcance del seminario (referencia)
└── SETUP.md                      # pasos para abrir el proyecto en Xcode la primera vez
```

## Primer arranque

Ver [SETUP.md](./SETUP.md) — pasos para crear el target en Xcode, agregar el Firebase SDK por SPM, descargar `GoogleService-Info.plist` y correr la app por primera vez.

## Estado

Scaffold inicial. Modelos, servicios y vistas creados como esqueleto; falta cablear Firestore listeners, completar UI de cada pilar y desplegar Cloud Functions.
