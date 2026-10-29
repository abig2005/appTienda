# Configuración de App Tienda

La app no guarda contraseñas en el código. Todo se lee al compilar desde
`config/env.json`:

```bash
flutter run --dart-define-from-file=config/env.json
```

1. Copia `env.example.json` como `env.json` (ya está en `.gitignore`).
2. Llena las claves que quieras usar. Las que dejes vacías activan el
   **modo demostración**: el código se muestra en un aviso amarillo dentro de la app.

| Clave | Para qué sirve |
|---|---|
| `APP_NAME` | Nombre visible de la app. |
| `PRODUCTOS_API_URL` | API del catálogo. Por defecto `https://fakestoreapi.com/products`. |
| `LADA_POR_DEFECTO` | Lada que se antepone a teléfonos de 10 dígitos (`+52`). |
| `PAYPAL_ME_URL` | Enlace público de tu perfil PayPal.Me, por ejemplo `https://paypal.me/tuusuario`. |
| `SMTP_USUARIO` | Tu cuenta de Gmail que envía los correos. |
| `SMTP_PASSWORD` | **Contraseña de aplicación** de Gmail (16 letras), no tu contraseña normal. |
| `SMTP_REMITENTE` | Nombre que verá quien recibe el correo. |
| `TWILIO_ACCOUNT_SID` | SID de tu cuenta de Twilio (opcional, para SMS). |
| `TWILIO_AUTH_TOKEN` | Token de Twilio. |
| `TWILIO_NUMERO` | Número de Twilio que envía los SMS, en formato `+1...`. |
| `DEMO_ADMIN_EMAIL` | Correo del usuario de prueba **juan** (admin). |
| `DEMO_EDITOR_EMAIL` | Correo del usuario de prueba **pedro** (editor). |
| `DEMO_LECTOR_EMAIL` | Correo del usuario de prueba **ana** (lector). |
| `DEMO_*_TELEFONO` | Teléfono de cada usuario de prueba (10 dígitos o E.164). |

**Tip:** con alias de Gmail (`tu+admin@gmail.com`, `tu+editor@gmail.com`,
`tu+lector@gmail.com`) los tres correos llegan a una sola bandeja.

## Contraseña de aplicación de Gmail

1. Activa la verificación en 2 pasos en tu cuenta de Google.
2. Entra a <https://myaccount.google.com/apppasswords>.
3. Crea una con el nombre "App Tienda" y copia las 16 letras en `SMTP_PASSWORD`.

## Twilio (opcional)

Crea una cuenta de prueba en <https://www.twilio.com>, copia el SID, el token y
el número. En cuentas de prueba solo puedes enviar SMS a números verificados.

## PayPal.Me

1. Crea o consulta tu enlace en <https://www.paypal.com/paypalme/>.
2. Sustituye el ejemplo de `PAYPAL_ME_URL` en `config/env.json` por tu enlace base,
   sin agregar el monto (por ejemplo, `https://paypal.me/tuusuario`).
3. Ejecuta de nuevo la app con `--dart-define-from-file=config/env.json`.

La app abrirá ese enlace con el total en MXN y guardará el pedido como **pendiente**.
PayPal.Me no informa a la app si el destinatario recibió el dinero, así que debes
verificar el pago en tu cuenta PayPal antes de marcar el pedido como pagado o enviarlo.
El enlace es público; no configures ni compartas contraseñas o claves de API en Flutter.

## Google Sign-In

Necesita el SHA-1 de tu firma de depuración registrado en Firebase o en Google Cloud:

```bash
cd android
gradlew signingReport
```

Copia el `SHA1` de la variante `debug`, crea un cliente OAuth de Android con el
paquete `com.example.pruebas` y ese SHA-1.
