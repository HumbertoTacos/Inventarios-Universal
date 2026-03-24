# Inventarios Universal

Aplicación Flutter multi-tenant de inventarios y punto de venta, que incluye autenticación con Google y Firebase.

## 🛠 Prerrequisitos ambientales

Antes de comenzar, asegúrate de instalar lo siguiente en tu máquina de desarrollo:

1. **[Flutter SDK](https://docs.flutter.dev/get-started/install)** (Compatible con la versión indicada en el `pubspec.yaml`, actualmente `^3.11.3` o superior).
2. Un IDE (Entorno de Desarrollo Integrado) configurado para Flutter:
   - **[Visual Studio Code](https://code.visualstudio.com/)** (recomendado, instalando extensiones de Flutter y Dart)
   - **[Android Studio](https://developer.android.com/studio)** o **IntelliJ IDEA**.
3. **[Git](https://git-scm.com/)** para el control de la versión de código.
4.  Emulador de Android, Simulador de iOS (requiere macOS) o un dispositivo físico conectado.

### Opcional pero recomendado para Firebase:
- **[Node.js](https://nodejs.org/)** y **[Firebase CLI](https://firebase.google.com/docs/cli)** (para ejecutar comandos `firebase` u obtener la configuración con `flutterfire configure`).

---

## 🚀 Instalación y Configuración del Proyecto

Sigue estos pasos una vez hayas sido agregado como colaborador y vayas a bajar el proyecto por primera vez:

### 1. Clonar el Repositorio

Abre tu terminal en la carpeta donde quieras alojar el proyecto y ejecuta:

```bash
git clone <URL_DEL_REPOSITORIO>
cd Inventarios-Universal
```

### 2. Instalar las Dependencias de Flutter

Estando dentro de la carpeta del proyecto, obtén todas las librerías necesarias:

```bash
flutter pub get
```

### 3. Configuración de Firebase y Google Sign-in

El proyecto depende fuertemente de Firebase Auth, Firestore y login de Google, por lo que necesita sus credenciales de servicio:
- **No subidas al repositorio**: Normalmente los archivos como `google-services.json` (Android) y `GoogleService-Info.plist` (iOS) o `firebase_options.dart` pueden estar presentes o ignorados.
- Si faltan y el proyecto no compila, **pide a tu administrador los archivos de configuración de Firebase** para poder correr la aplicación, o en su defecto corre el comando `flutterfire configure` logueándote a la cuenta de Firebase del proyecto.
- **Login de Google en Android:** Para que el login funcione localmente durante tu desarrollo, deberás generar la firma SHA-1 y SHA-256 de tu máquina (de tu archivo debug.keystore) y enviársela al dueño del proyecto de Firebase para que pueda añadirla en la consola.

### 4. Opcional: Revisar problemas de estructura

Siempre es buena práctica asegurarte que el código está limpio de advertencias (lints) antes de desarrollar:
```bash
flutter analyze
```

### 5. Compilar y Ejecutar

Abre el proyecto en tu editor, selecciona un dispositivo/emulador activo, y corre el proyecto desde el editor (F5 en VS Code), o en la terminal:

```bash
flutter run
```

---

## 📦 Herramientas y Paquetes Principales Utilizados:
- **Backend/DB:** `firebase_core`, `cloud_firestore`, `firebase_auth`
- **Login:** `google_sign_in`
- **Manejo de códigos/scanners:** `mobile_scanner`
- **Gráficas y UI:** `fl_chart`, `cupertino_icons`
