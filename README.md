# App Tienda 🛍️

Tienda en línea en Flutter con roles (admin, editor y comprador), verificación en 2 pasos,
recuperación de cuenta, notificaciones, mapa, catálogo sin conexión, personalización,
seguridad (PBKDF2 + AES-GCM), pagos simulados y pagos manuales con PayPal.Me.
Interfaz en español (México).

## Estructura

```
lib/
  config/       app_config.dart (lee config/env.json al compilar)
  models/       usuario, producto, item_carrito, compra, notificacion, resultado_pago
  repository/   SQLite seguridad.db v5 con migraciones + repositorios
  services/     seguridad, OTP, correo, SMS, auth, biometría, Google, notificaciones,
                catálogo offline, recomendaciones, utilidades de pago
  controllers/  sesión, carrito, administración de usuarios
  views/        login, 2FA, registro, recuperación, home, tienda, carrito, pago,
                historial, mapa, perfil, usuarios, notificaciones
  widgets/      componentes comunes (aviso demo, requisitos, campana, imágenes…)
  theme/        tema con 5 colores de acento (Océano por defecto) y modo claro/oscuro/sistema
test/           pruebas de PoliticaRol, OTP, pagos y nombres
config/         env.example.json, README.md (env.json va en .gitignore)
```

PayPal.Me se configura con `PAYPAL_ME_URL` en `config/env.json`. Es un pago manual:
la app abre el enlace y registra el pedido como pendiente; confirma el pago desde tu
cuenta PayPal antes de preparar o enviar el pedido. Consulta [config/README.md](config/README.md).

## Diseño

Sigue el estilo de la versión anterior del proyecto: color de acento Océano (`#0284C7`)
con Esmeralda, Púrpura, Ámbar y Rubí como alternativas, modo claro/oscuro/sistema,
fondos slate, AppBar de color sólido, tarjetas elevadas, encabezados con degradado,
menú lateral, insignias de rol en mayúsculas (admin rojo, editor naranja, comprador azul)
y el aviso ámbar para los códigos en modo demostración.

## 1. Configuración

1. Copia `config/env.example.json` como `config/env.json` y llénalo
   (detalle de cada clave en `config/README.md`).
2. **Correo (Gmail):** activa la verificación en 2 pasos y crea una
   *contraseña de aplicación* en <https://myaccount.google.com/apppasswords>.
   Ponla en `SMTP_PASSWORD` y tu correo en `SMTP_USUARIO`.
3. **SMS (opcional):** llena `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN` y `TWILIO_NUMERO`.
4. **Google Sign-In:** obtén el SHA-1 de depuración y regístralo en Firebase/Google Cloud
   (cliente OAuth Android, paquete `com.example.pruebas`):
   ```
   cd android
   gradlew signingReport
   ```

Si dejas vacío el correo o el SMS, la app entra en **modo demostración**: el código aparece
en un aviso amarillo con el botón **Usar**, y el SMS se simula con una notificación local.

## 2. Ejecutar y probar

```
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=config/env.json
```

En VS Code usa la configuración **"App Tienda (debug)"** de `.vscode/launch.json`.

### Usuarios de prueba (contraseña `password123`)

| Usuario | Rol |
|---|---|
| juan | Administrador |
| pedro | Editor |
| ana | Comprador (lector) |

En modo debug aparecen en una tarjeta del login; tócalos para autocompletar.
Nota: `password123` cumple la política de lector; si cambias la contraseña de juan o pedro,
la nueva debe cumplir la política de su rol.

### Tarjetas de prueba

| Número | Resultado |
|---|---|
| 4242 4242 4242 4242 | Aprobada |
| 4000 0000 0000 0002 | Rechazada (fondos insuficientes) |

## Nota de seguridad

Los valores de `--dart-define` quedan **dentro del APK** y se pueden extraer. Esto sirve para
una demostración o tarea escolar, pero en producción real el envío de correos y SMS y el
cobro de pagos deben hacerse en un **backend propio**, y la app solo debe hablar con ese backend.
