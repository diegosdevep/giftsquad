# Cómo correr el proyecto

## Requisitos

- Mac con Xcode 26 o superior.
- Un proyecto de Firebase con Authentication (Apple y Google), Firestore, Storage, Functions y Messaging.
- Node.js 22 y Firebase CLI (`npm install -g firebase-tools`) para publicar las reglas y las funciones.

## App iOS

1. Clonar el repositorio.
2. Descargar el archivo `GoogleService-Info.plist` desde la consola de Firebase y copiarlo en `GiftSquad/GiftSquad/GiftSquad/`. No está en el repo porque tiene datos privados del proyecto.
3. Abrir `GiftSquad/GiftSquad/GiftSquad.xcodeproj` en Xcode. Las dependencias (Firebase y Google Sign-In) se descargan solas con Swift Package Manager.
4. Elegir un simulador o un iPhone y correr con `Cmd + R`.

En las compilaciones de desarrollo, App Check usa el proveedor de depuración. Hay que registrar el token que aparece en la consola de Xcode en **Firebase → App Check → Administrar tokens de depuración**.

## Backend (Firebase)

Desde la carpeta `firestore/`:

```bash
firebase login
firebase use <id-del-proyecto>

# reglas e índices
firebase deploy --only firestore:rules,firestore:indexes,storage

# Cloud Functions
cd functions && npm install && cd ..
firebase deploy --only functions
```
