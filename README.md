# GiftSquad

App para iPhone que sirve para coordinar regalos entre familia, amigos o pareja.
Proyecto del Seminario Final de Analista de Sistemas (Escuela Da Vinci), Diego Maidana, 2026.

Disponible en la App Store.

## Qué hace

La idea principal es que **quien recibe un regalo nunca sepa quién se lo reservó**.

- **Lista de deseos:** cada usuario arma su lista con productos (nombre, foto, precio, link, prioridad). Al pegar el link de un producto, la app completa los datos sola.
- **Grupos:** se crean grupos y se invita a otras personas con un código. Cada miembro ve las listas de los demás.
- **Reserva anónima:** un miembro reserva un regalo de la lista de otro. El resto del grupo lo ve como reservado, pero el dueño de la lista no.
- **Amigo Invisible:** sorteo automático con tope de gasto y exclusiones. Cada participante ve solo a quién le regala.
- **Historial y avisos:** los regalos entregados quedan en el historial del grupo, y la app manda notificaciones.

## Tecnologías

- **App:** Swift y SwiftUI, iOS 17.6 o superior.
- **Backend:** Firebase
  - Authentication (Sign in with Apple y Google)
  - Cloud Firestore, con reglas de seguridad que garantizan el anonimato
  - Cloud Functions en TypeScript (sorteo, bloqueo de reservas, historial, avisos, unirse con código y eliminar cuenta)
  - Cloud Storage (fotos de los ítems)
  - Cloud Messaging (notificaciones push)
  - App Check con App Attest
- **Idiomas:** español e inglés.

## Estructura

```
GiftSquad/GiftSquad/
├── GiftSquad.xcodeproj
└── GiftSquad/
    ├── App/           # arranque y navegación
    ├── Features/      # pantallas, una carpeta por módulo
    ├── Models/        # modelos de datos
    ├── Services/      # acceso a Firebase y a las tiendas
    ├── Components/    # componentes visuales reutilizables
    └── Utils/
firestore/
├── firestore.rules    # reglas de seguridad de la base
├── storage.rules      # reglas de las fotos
└── functions/         # Cloud Functions
docs/
└── ALCANCE.md         # alcance del proyecto
```

## Historial del proyecto

| Fecha | Etapa |
|---|---|
| Mayo 2026 | Idea, alcance y entrega del TP1 |
| Junio 2026 | Requisitos, casos de uso y propuesta final |
| Julio – agosto 2026 | Diseño de pantallas y modelo de datos |
| Agosto – septiembre 2026 | Desarrollo de la app y del backend |
| 27/09/2026 | Primera versión (1.0) subida a App Store Connect |
| 10/10/2026 | Versión 1.0.2 con correcciones |
| 13/10/2026 | App aprobada y publicada en la App Store |
| Noviembre 2026 | Versión 1.0.3 y documentación final |

## Cómo correrlo

Ver [SETUP.md](./SETUP.md).
