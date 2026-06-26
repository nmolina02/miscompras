# MisCompras

Aplicación móvil desarrollada en Flutter para registrar y analizar compras en supermercados y comercios. Permite capturar tickets de compra mediante escaneo de códigos de barras, llevar un historial detallado y generar reportes de gastos.

---

## Características principales

- **Registro de compras** con soporte para escaneo de códigos de barras (EAN-13, UPC, etc.)
- **Productos sueltos** (sin código estándar) con generación automática de código
- **Búsqueda web de productos** por código de barras vía API externa
- **Auto-completado inteligente** basado en historial de compras previas
- **Historial completo** de tickets con detalle por ítem
- **Confirmaciones pendientes** para registrar el monto real pagado
- **Reportes y estadísticas** de gastos con filtros temporales
- **Exportación a PDF** de tickets individuales
- **Backup y restauración** de la base de datos completa
- **Temas personalizables** (6 paletas de color + modo claro/oscuro)

---

## Tecnologías utilizadas

| Categoría | Tecnología |
|---|---|
| Framework | Flutter (Dart) |
| Base de datos | SQLite via `sqflite` |
| Escaneo de códigos | `mobile_scanner` |
| Generación de PDFs | `pdf` + `printing` |
| Manejo de archivos | `file_picker` + `gallery_saver_plus` |
| HTTP | `http` |
| Gestión de rutas | `path` + `path_provider` |

---

## Arquitectura

El proyecto sigue **Clean Architecture** con separación en tres capas:

```
lib/
├── config/
│   └── theme/              # Temas y paletas de colores
├── data/
│   └── local/              # Repositorios SQLite (DAOs)
│       ├── app_database.dart
│       ├── ticket_repository.dart
│       ├── item_ticket_repository.dart
│       ├── producto_repository.dart
│       ├── comercio_repository.dart
│       ├── rubro_repository.dart
│       └── compra_repository.dart
├── domain/
│   └── entities/           # Modelos de dominio
│       ├── ticket.dart
│       ├── item_ticket.dart
│       ├── producto.dart
│       ├── comercio.dart
│       └── rubro.dart
└── presentation/
    ├── providers/          # Gestión de estado
    ├── screens/            # Pantallas
    └── widgets/            # Componentes reutilizables
```

---

## Modelo de datos

```
Ticket
├── id (YYYYMMDD_HHmmssSSSmmmm)
├── comercio → Comercio
├── fecha
├── importeTotal
├── recargoAplicado
├── importeRealPagado
├── confirmacionStatus (0=Pendiente, 1=Confirmado)
└── items → List<ItemTicket>

ItemTicket
├── id
├── ticket → Ticket
├── producto → Producto
├── cantidad
├── unidadMedida
├── precioUnitarioAplicado
├── cantidadDescuento
└── precioDescuento

Producto
├── codigoDeBarras (PK)
├── nombre
└── rubro → Rubro?

Comercio
└── nombre

Rubro
└── nombre
```

---

## Pantallas

### Home
Menú principal con acceso a todas las funciones. Incluye un drawer lateral para configuración de temas y backup.

### Nueva Compra
Flujo guiado para registrar una compra:
1. Seleccionar el comercio (con historial auto-completado)
2. Agregar ítems escaneando o ingresando el código de barras
3. Completar nombre, rubro, cantidad, precio y descuentos por ítem
4. Finalizar y guardar

El borrador se preserva automáticamente si se abandona la pantalla. Para productos sin código de barras estándar se usa el modo **producto suelto**, que genera un código numérico a partir del nombre.

### Confirmaciones Pendientes
Lista las compras sin confirmar. Permite ingresar el monto real pagado (el recargo se calcula automáticamente si difiere del estimado).

### Historial de Compras
Lista completa de todos los tickets registrados con fecha, comercio y monto. Permite ver el detalle de cada compra con sus ítems.

### Reportes y Estadísticas
Dashboard de gastos con filtros temporales (1 semana, 2 semanas, 1 mes, 2 meses, 6 meses, 1 año, todo el tiempo). Muestra:
- Gasto total y ticket promedio
- Comercio más frecuente
- Rubro con mayor gasto
- Desglose por comercio, rubro y producto

### Eliminar Compra
Selección múltiple de compras para eliminar del historial con confirmación previa.

---

## Configuración y temas

Desde el drawer lateral se puede:

- **Cambiar el tema de color:** Azul, Verde, Naranja, Rojo, Teal o Púrpura
- **Cambiar el modo:** Sistema, Claro u Oscuro

La preferencia se persiste entre sesiones.

---

## Importar / Exportar base de datos

Desde el drawer lateral:

- **Exportar BD:** genera un archivo `.db` con timestamp en el almacenamiento del dispositivo
- **Importar BD:** permite seleccionar un archivo `.db` previamente exportado para restaurar todos los datos

Útil para hacer backups o migrar datos entre dispositivos.

---

## Exportar ticket a PDF

Desde el historial, cualquier ticket puede exportarse a PDF con el desglose completo de ítems, precios y totales. Se puede previsualizar antes de guardar.

---

## Requisitos

- **Android:** 5.0 Lollipop (API 21) o superior
- **Flutter:** 3.10.7+
- **Dart SDK:** ^3.10.7

---

## Instalación y ejecución

```bash
# Clonar el repositorio
git clone <repo-url>
cd miscompras

# Instalar dependencias
flutter pub get

# Ejecutar en modo debug
flutter run

# Generar APK de release
flutter build apk --release
```

---

## Permisos requeridos (Android)

- `CAMERA` — escaneo de códigos de barras
- `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` — importar/exportar base de datos y guardar PDFs

---

## Estructura del proyecto

```
miscompras/
├── android/                # Configuración nativa Android
├── ios/                    # Configuración nativa iOS
├── lib/
│   ├── main.dart           # Punto de entrada
│   ├── config/             # Temas y configuración global
│   ├── data/               # Capa de datos (SQLite)
│   ├── domain/             # Entidades de dominio
│   └── presentation/       # UI, pantallas y providers
├── assets/                 # Recursos estáticos (imágenes, íconos)
├── pubspec.yaml
└── README.md
```

---

## Notas de desarrollo

- La aplicación funciona **completamente offline**; no requiere conexión a internet salvo para la búsqueda opcional de nombres de productos por código de barras (API go-upc.com).
- La base de datos SQLite tiene migraciones versionadas para garantizar compatibilidad entre actualizaciones.
- Toda la interfaz está en **español**.
