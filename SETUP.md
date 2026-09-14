# Setup — Primer arranque

Pasos para abrir el scaffold en Xcode, conectar Firebase y correr la app por primera vez.

## 1. Crear el proyecto Xcode sobre esta carpeta

1. Abrir Xcode → **File → New → Project…**
2. iOS → **App** → Next
3. Completar:
   - **Product Name:** `GiftSquad`
   - **Team:** tu Apple ID personal (alcanza con cuenta gratuita para correr en simulador)
   - **Organization Identifier:** `com.diegomaidana` (o el que prefieras)
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Storage:** None
   - **Include Tests:** activado
4. En el diálogo de guardado, navegar hasta `~/Desktop/GiftSquad` y **guardar ahí mismo** (Xcode va a crear `GiftSquad.xcodeproj` adentro).
5. Cuando termine, en el navegador de Xcode vas a ver duplicado `GiftSquadApp.swift` y `ContentView.swift` generados por Xcode. **Borralos** (Move to Trash), porque los reemplazamos por los del scaffold.
6. Arrastrar al navegador de Xcode las carpetas `App`, `Features`, `Models`, `Services`, `Components`, `Utils` desde Finder. En el diálogo elegir:
   - **Copy items if needed:** desactivado (los archivos ya están en la carpeta)
   - **Create groups:** activado
   - **Add to targets:** GiftSquad

## 2. Agregar Firebase via Swift Package Manager

1. En Xcode: **File → Add Package Dependencies…**
2. URL: `https://github.com/firebase/firebase-ios-sdk`
3. **Dependency Rule:** Up to Next Major Version, desde `11.0.0`
4. Productos a agregar al target `GiftSquad`:
   - `FirebaseAuth`
   - `FirebaseFirestore`
   - `FirebaseFunctions`
   - `FirebaseMessaging`
5. Agregar también Google Sign-In:
   - **File → Add Package Dependencies…**
   - URL: `https://github.com/google/GoogleSignIn-iOS`
   - Producto: `GoogleSignInSwift`

## 3. Conectar el proyecto Firebase

1. Ir a [console.firebase.google.com](https://console.firebase.google.com) → **Add project** → `GiftSquad`.
2. Dentro del proyecto: **Add app → iOS**.
   - **Bundle ID:** el que usaste en Xcode (ej. `com.diegomaidana.GiftSquad`).
3. Descargar `GoogleService-Info.plist` y arrastrarlo a Xcode dentro del grupo `Resources/`. Marcar **Copy items if needed** y agregar al target.
4. Habilitar en consola:
   - **Authentication → Sign-in method:** Email/Password y Google.
   - **Firestore Database → Create database** en modo **producción**. Región `southamerica-east1` (São Paulo) o `nam5`.
   - **Cloud Functions:** se habilita más tarde al hacer el primer deploy (requiere plan Blaze con cap).
   - **Cloud Messaging:** habilitar y registrar APNs Key cuando se quiera probar push en device físico.

## 4. URL Scheme para Google Sign-In

1. Abrir `GoogleService-Info.plist` y copiar el valor de `REVERSED_CLIENT_ID`.
2. En el target → **Info → URL Types → +** y pegar el reversed client id en **URL Schemes**.

## 5. Reglas y CLI de Firebase

```bash
# instalar CLI
npm install -g firebase-tools

# desde la raíz del repo
cd ~/Desktop/GiftSquad
firebase login
firebase init firestore
# elegir el proyecto que creaste, aceptar firestore/firestore.rules y firestore/firestore.indexes.json

# deploy de reglas
firebase deploy --only firestore:rules,firestore:indexes
```

## 6. Correr

`Cmd + R` con el simulador de iPhone 15 (o el que tengas). La primera vez vas a ver la pantalla de login. Crear una cuenta con email y entrar.

## Pendiente para más adelante

- Cloud Functions del sorteo Amigo Invisible (requiere upgrade a plan Blaze con presupuesto cap).
- Notificaciones push reales (necesita APNs key del Apple Developer Program).
- App Check para evitar uso de Firestore desde fuera de la app.
