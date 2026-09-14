# Documento de Alcance — GiftSquad

> Escuela Da Vinci · Analista de Sistemas · Seminario Final
> Profesora: Lic. Carina Carballido · Alumno: Diego Exequiel Maidana · Mayo 2026
>
> Este archivo es **referencia**: vive en el repo para mantener visible el alcance acordado y detectar scope creep durante la implementación. La aplicación se desarrolla en SwiftUI + Firebase (iOS nativo), lo que difiere de la "aplicación web responsiva" mencionada en el documento original; el resto del alcance se respeta.

## 6.1 Nombre y descripción

GiftSquad — Plataforma social para la coordinación inteligente de regalos. Aplicación que articula tres modalidades operativas sobre una misma base: listas de deseos compartidas, sistema de aporte grupal anónimo y modo Amigo Invisible automatizado. Toda la lógica del sistema preserva un principio rector: **el destinatario nunca conoce quién reservó qué, ni quién aportó cuánto**.

## 6.2 Pilares funcionales

- **Pilar 1 — Lista de deseos compartida.** Cada usuario crea su lista personal con productos detallados (nombre, descripción, imagen, precio, link, categoría, prioridad, variantes, alternativas, notas privadas).
- **Pilar 2 — Reserva anónima + Vaquita digital.** Los integrantes reservan ítems sin que el dueño los identifique. Para regalos costosos, varios usuarios inician una vaquita con tracker y chat privado entre compradores.
- **Pilar 3 — Modo Amigo Invisible.** Sorteo automático con presupuesto y reglas de exclusión. Cada participante ve solo su asignación.

## 6.3 Alcance del producto — Funcionalidades MVP

| Funcionalidad | Tipo |
|---|---|
| Registro y autenticación (email/password + Google) | ABM / Seguridad |
| Gestión de grupos | ABM |
| Lista de deseos personal | ABM |
| Preview automático de producto (Open Graph) | Lógica de negocio |
| Visualización de listas del grupo | Reporte |
| Reserva anónima de regalos | Lógica de negocio |
| Liberación de reserva | Lógica de negocio |
| Vaquita digital privada | Lógica de negocio |
| Modo Amigo Invisible | Lógica de negocio |
| Notificaciones | Lógica de negocio |
| Historial de regalos | Reporte |
| Acceso por link público | Lógica de negocio |

## 6.7 Fuera del alcance

- Procesamiento de pagos dentro de la app (la vaquita registra aportes, no procesa transferencias).
- Compra integrada: la app redirige a la tienda externa, no compra.
- Soporte multilenguaje: solo español.
- Aplicación Android nativa (versión inicial: iOS únicamente).
- Integración con APIs de e-commerce para sincronización de precios en tiempo real.
- Sistema de calificación de regalos recibidos.
- Panel de administración para gestión a escala empresarial.

## Riesgos identificados — scope creep

- Integración directa con MercadoLibre / Amazon para compra in-app.
- Procesamiento de pagos real dentro de la vaquita.
- Versión Android (duplicaría esfuerzo en solitario).
- Sistema de recomendaciones de productos basado en IA.
- Soporte multilenguaje.

**Estrategia de control:** todo pedido nuevo se registra en un backlog separado (`docs/BACKLOG.md` cuando aplique) y se evalúa para versiones futuras. No entra al MVP sin revisión formal de alcance.
