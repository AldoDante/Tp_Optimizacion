# Resumen Detallado de la Conversación y Desarrollo del Trabajo Práctico
## Trabajo Práctico: Diseño y Optimización de Bases de Datos
**Repositorio del Proyecto:** `https://github.com/AldoDante/Tp_Optimizacion.git`  
**Entorno Local:** `C:\Users\dante\OneDrive\Escritorio\Tp_DyO_Bd`

---

## 1. Introducción y Pregunta Inicial de Reproducibilidad

### Consulta del Usuario:
> *¿En la situación hipotética que se cree un proyecto, es posible crear un archivo que lo replique en otra PC?*

### Respuesta y Fundamentación Técnica:
Sí, es completamente viable y representa la práctica estándar en la ingeniería de bases de datos mediante:
1. **Docker Compose (`docker-compose.yml`):** Define el motor exacto (`MySQL 8.0`) con sus dependencias, variables de entorno, puertos y volumen de persistencia.
2. **Scripts DDL y DML:** Scripts SQL de inicialización ordenados que el contenedor ejecuta automáticamente al crearse.
3. **Procedimientos de Ingestión Automatizada:** Procedimientos almacenados para generar los millones de filas de prueba localmente en cualquier PC sin necesidad de transferir gigabytes de volcados (*dumps*) a través de internet.

---

## 2. Análisis Metodológico: La Estrategia en 5 Fases

Se evaluó la propuesta de resolver el TP alterando el orden secuencial (1 al 20) para organizarlo según dependencias lógicas:

### ¿Por qué seguir el orden 1 al 20 hubiera sido contraproducente?
* **Sobrecarga de índices en carga masiva:** Si se crean todos los índices secundarios en el Punto 3, la inserción de 6 millones de registros en el Punto 8 tardaría horas por la continua reestructuración de árboles B+Tree (lección empírica del Punto 7).
* **Ausencia de mediciones "Antes y Después":** Para optimizar consultas en los Puntos 18 y 19 con `EXPLAIN ANALYZE`, primero debe existir la foto de la consulta lenta por escaneo completo de tabla (*Full Table Scan*).
* **Comportamiento engañoso del optimizador:** En tablas vacías o chicas, el motor de base de datos ignora los índices porque leer toda la tabla secuencialmente cabe en una sola página de memoria.

### Fases adoptadas para el desarrollo:
* **Fase 1 (Implementación Física - Punto 2):** Creación de tablas, claves primarias y foráneas con tipos de datos justificados.
* **Fase 2 (Volumen de Datos - Punto 8):** Carga masiva de 6.000.000 de registros en la tabla `RESERVA` antes de crear índices secundarios.
* **Fase 3 (Carga de Trabajo - Puntos 9, 10 y 12):** Desarrollo de las consultas SQL base sin índices adicionales.
* **Fase 4 (Optimización e Índices - Puntos 3, 5, 11, 17, 18 y 19):** Medición con `EXPLAIN ANALYZE`, creación de índices dirigidos, prueba de prefijo izquierdo y comparativas de rendimiento.
* **Fase 5 (Análisis Teórico y Servidor - Puntos 4, 6, 7, 13, 14, 15, 16 y 20):** B-Tree, cardinalidad, costo DML, InnoDB Buffer Pool y bloqueos de concurrencia.

---

## 3. Infraestructura y Entorno de Ejecución

### 3.1. Estimación de Almacenamiento en Disco
El usuario contaba con 10 GB libres. Se realizó el cálculo preventivo de espacio:
* Imagen Docker de MySQL 8.0: ~600 MB.
* Tabla `RESERVA` con 6 millones de filas en InnoDB: ~650 MB.
* Índices secundarios experimentales: ~600 MB - 800 MB.
* Redo logs, Undo logs y tablas temporales: ~1.5 GB.
* **Espacio total estimado requerido:** ~3.5 GB a 4.5 GB (dejando un amplio margen operativo en los 10 GB).

### 3.2. Configuración de Contenedores y Servidor
* **`docker-compose.yml`:** Levanta los servicios `db` (MySQL 8.0) y `phpmyadmin` (puerto 8080).
* **Parámetros aplicados al motor:**
  * `disable_log_bin = 1`: Desactiva los logs binarios de replicación para evitar que 6 millones de inserts generen gigabytes de logs innecesarios.
  * `local_infile = 1`: Habilita la ingesta acelerada de datos.
  * `innodb_buffer_pool_size = 268435456` (256 MB): Configuración controlada para estudiar la tasa de aciertos de caché en memoria RAM (Puntos 14 y 15).
* **Credenciales configuradas:**
  * Usuario: `admin` | Clave: `admin123`
  * Root: `root` | Clave: `admin123`
  * Base de datos: `db_hoteles`
  * Administrador visual: `http://localhost:8080`

---

## 4. Evolución del Modelo Relacional y Diseño Físico (Puntos 1 y 2)

### 4.1. Esquema de Entidades Final (12 Tablas en 3FN)
1. `HOTEL`: Sucursales de la cadena, ubicación geográfica.
2. `MEDIO_CONTACTO_HOTEL`: Medios de contacto por sucursal (1:N multivaluado).
3. `PUNTO_INTERES`: Atractivos turísticos catalogados.
4. `HOTEL_PUNTO`: Relación N:M que registra distancias en kilómetros.
5. `TIPO_HABITACION`: Categorías de habitaciones (Suite, Estándar, etc.).
6. `COMODIDAD`: Catálogo de amenidades y servicios.
7. `HABITACION`: Cuartos físicos con restricción `UNIQUE(id_hotel, numero_habitacion)` ("Único por hotel").
8. `HABITACION_COMODIDAD`: Relación N:M que asocia amenidades directamente a cada habitación física.
9. `HUESPED`: Clientes con restricción `UNIQUE(tipo_doc, nro_documento)`.
10. `HUESPED_EMAIL`: Correos electrónicos de huéspedes (multivaluado).
11. `HUESPED_TELEFONO`: Teléfonos de contacto (multivaluado).
12. `RESERVA`: Tabla transaccional masiva con claves foráneas hacia huésped y habitación.

### 4.2. Justificación Técnica de Tipos de Datos (Punto 2)
* **`INT` vs `BIGINT`:** Se usó `BIGINT` (8 bytes) únicamente en `RESERVA(id_reserva)` para evitar desbordes en un historial con millones de transacciones. En tablas maestras se empleó `INT` (4 bytes) para reducir al 50% el espacio ocupado por punteros de claves foráneas e índices.
* **`CHAR` vs `VARCHAR` vs `TEXT`:** Se descartó `CHAR` por el desperdicio de almacenamiento en campos de longitud variable. Se utilizó `VARCHAR` acotado para nombres y estados, y `TEXT` para descripciones extensas de hoteles y atractivos turísticos.
* **`DATE` vs `DATETIME`:** Se utilizó `DATE` (3 bytes) para `fecha_inicio` y `fecha_salida`. Como el modelo hotelero opera por días y noches calendario, almacenar horas/minutos con `DATETIME` (5 bytes) hubiera implicado un sobrecosto inútil de 12 MB de memoria en 6 millones de filas.
* **`DECIMAL` vs `FLOAT`:** Se seleccionó `DECIMAL(10,2)` para `tarifa` debido a que operaciones contables y monetarias prohíben los desvíos por redondeo de coma flotante binario (estándar IEEE 754 de `FLOAT`).

---

## 5. Reglas de Negocio Críticas Implementadas

Durante el intercambio se analizaron e incorporaron requerimientos específicos del enunciado:

### 5.1. Tarifa según Confirmación
* **Enunciado:** *"La tarifa será establecida únicamente cuando la reserva sea confirmada."*
* **Implementación:**
  * `tarifa DECIMAL(10,2) NULL`.
  * Se actualizaron las **1.500.622 reservas pendientes** a `tarifa = NULL`.
  * Restricción a nivel de motor:
    ```sql
    CONSTRAINT chk_tarifa_estado CHECK (
        (estado = 'PENDIENTE' AND tarifa IS NULL) OR
        (estado IN ('CONFIRMADA', 'FINALIZADA', 'CANCELADA') AND tarifa IS NOT NULL AND tarifa >= 0)
    );
    ```

### 5.2. Prevención de Períodos Superpuestos
* **Enunciado:** *"Una misma habitación no puede ser reservada para períodos que se superpongan."*
* **Condición matemática:** `existente.fecha_inicio < nueva.fecha_salida AND existente.fecha_salida > nueva.fecha_inicio`
* **Implementación:**
  * Se crearon los triggers `trg_reserva_no_superposicion_insert` y `trg_reserva_no_superposicion_update` en `RESERVA` que evalúan si la habitación ya posee una reserva `CONFIRMADA` o `PENDIENTE` en dicho intervalo, abortando la transacción mediante `SIGNAL SQLSTATE '45000'`.
  * Procedimiento `sp_crear_reserva_segura` para transacciones concurrentes con `SELECT ... FOR UPDATE` (Punto 20).

### 5.3. Coherencia Temporal de Fechas
* Se corrigió una inconsistencia en la generación aleatoria que producía salidas anteriores al inicio.
* Se garantizó que el 100% de las reservas cumplan con `fecha_salida > fecha_inicio` y se documentó la restricción `chk_fechas_coherentes`.

---

## 6. Generación de los 6 Millones de Registros (Punto 8)

* **Script ejecutado:** `scripts/03_carga_masiva_reservas.sql` (`sp_generar_6m_reservas`).
* **Mecanismo:** Procedimiento almacenado puramente en SQL que utilizó el producto cartesiano de una tabla auxiliar de dígitos para generar lotes de 100.000 filas.
* **Técnicas de optimización:**
  * Inserción en bloques transaccionales (`START TRANSACTION ... COMMIT`) para evitar desbordar el *undo log*.
  * Desactivación temporal de comprobaciones de claves foráneas y restricciones únicas durante la carga masiva.
  * Inserción previa a la creación de índices secundarios no agrupados.
* **Resultado:** 6.000.000 de filas en `RESERVA`, ocupando ~655 MB en disco.

---

## 7. Metodología de Trabajo Colaborativo y Control de Versiones

### 7.1. VS Code Live Share (Colaboración en Tiempo Real)
Permite trabajar en simultáneo tipo Google Docs:
* **Edición simultánea de scripts SQL** viendo los cursores de ambos integrantes.
* **Servidor compartido (*Shared Port 8080*):** El compañero puede acceder desde su navegador a phpMyAdmin y a la base de datos de 6 millones de filas que corre en la PC anfitriona sin instalar Docker ni consumir espacio en su disco.

### 7.2. Git y Volúmenes de Docker
Se aclaró que los volúmenes de Docker (`db_data`) **nunca deben versionarse en Git**:
* Git versiona los scripts de construcción y código fuente (`01_crear_tablas.sql`, `docker-compose.yml`, `my.cnf`).
* Al clonar el repositorio, Docker recrea el volumen localmente y los scripts cargan la base de datos de forma limpia e idéntica.
* Se agregó el archivo `.gitignore` para omitir temporales y volcados.

---

## 8. Estructura Actual de Archivos del Proyecto

```text
Tp_DyO_Bd/
├── .gitignore                           <-- Exclusión de temporales y logs
├── BITACORA_DEL_PROYECTO.md             <-- Documentación y guía de trabajo
├── RESUMEN_CONVERSACION_TP.md           <-- Este documento detallado
├── README.md                            <-- Presentación general
├── docker-compose.yml                   <-- Servicios MySQL 8.0 y phpMyAdmin
├── config/
│   └── my.cnf                           <-- Ajustes del servidor e InnoDB
└── scripts/
    ├── 01_crear_tablas.sql              <-- DDL del modelo físico con 3FN y restricciones
    ├── 02_poblar_datos_iniciales.sql    <-- Ingesta de catálogos, 50 hoteles y 50k huéspedes
    ├── 03_carga_masiva_reservas.sql     <-- Procedimiento de generación de 6M de filas
    └── 04_reglas_negocio_triggers.sql   <-- Triggers de no-superposición y procedimiento seguro
```

---

## 9. Próximo Paso a Ejecutar

* **Fase 3: Desarrollo de la Carga de Trabajo (Puntos 9, 10 y 12):**
  * Redacción del script `scripts/05_consultas_tp.sql` con las consultas progresivas, las 15 consultas complejas del negocio y las consultas temporales de períodos sobre los 6 millones de registros.
