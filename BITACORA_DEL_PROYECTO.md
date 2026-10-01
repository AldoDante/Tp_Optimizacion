# Trabajo Práctico: Diseño y Optimización de Bases de Datos
## Documentación Integral y Bitácora de Proyecto

Este documento reúne todo el análisis, arquitectura, decisiones de diseño, scripts de base de datos y reglas de negocio implementadas en el proyecto. Sirve como registro de trabajo colaborativo y base directa para el informe final de la materia.

---

## 1. Arquitectura y Entorno de Ejecución

Para garantizar la reproducibilidad y evitar instalaciones locales invasivas en el sistema operativo, el entorno completo se gestiona mediante **Docker Compose**:

* **Motor de Base de Datos:** `MySQL Community Server 8.0` (Motor de almacenamiento transaccional **InnoDB**).
* **Gestor Visual:** `phpMyAdmin` expuesto en el puerto `8080`.
* **Parámetros del Servidor (`config/my.cnf` y contenedor):**
  * `disable_log_bin = 1`: Se deshabilitaron los logs binarios de replicación para evitar saturar el disco rígido durante la inserción masiva de 6 millones de filas (ahorro de más de 2 GB).
  * `local_infile = 1`: Habilitación para ingestión acelerada de datos.
  * `innodb_buffer_pool_size = 268435456` (256 MB): Configuración inicial de memoria RAM para evaluar el comportamiento del Buffer Pool (Puntos 14, 15 y 16 del TP).
* **Credenciales de Acceso:**
  * Base de datos: `db_hoteles`
  * Usuario: `admin` | Contraseña: `admin123`
  * Root: `root` | Contraseña: `admin123`
  * Acceso phpMyAdmin: `http://localhost:8080` (Servidor: `db`)

---

## 2. Metodología de Trabajo: Resolución en 5 Fases

En lugar de seguir la numeración rígida del documento (1 al 20), el trabajo se estructuró lógicamente por dependencias técnicas:

1. **Fase 1 (Implementación Física - Punto 2):** Creación del esquema relacional DDL (tablas, PKs y FKs) con tipos de datos justificados.
2. **Fase 2 (Volumen Masivo - Punto 8):** Carga de datos maestros y generación procedural de los 6.000.000 de registros en la tabla `RESERVA` antes de crear índices secundarios (evitando penalizaciones de I/O en árboles B-Tree).
3. **Fase 3 (Carga de Trabajo - Puntos 9, 10 y 12):** Redacción de consultas progresivas, complejas y de períodos de fechas sobre la base cruda.
4. **Fase 4 (Optimización e Índices - Puntos 3, 5, 11, 17, 18 y 19):** Medición con `EXPLAIN ANALYZE`, creación de índices dirigidos, evaluación de regla del prefijo izquierdo y comparativa antes/después.
5. **Fase 5 (Análisis Teórico y Arquitectura - Puntos 4, 6, 7, 13, 14, 15, 16 y 20):** B-Tree, cardinalidad, impacto de índices en DML, Buffer Pool, memoria y bloqueos de concurrencia.

---

## 3. Diseño Lógico, Físico y Normalización (Puntos 1 y 2)

### 3.1. Tablas y Modelo Relacional
El sistema consta de 12 entidades organizadas en Tercera Forma Normal (3FN):
* `HOTEL`: Información central de los hoteles y ubicación.
* `MEDIO_CONTACTO_HOTEL`: Teléfonos, emails y webs (multivaluado 1:N).
* `PUNTO_INTERES`: Atractivos turísticos catalogados.
* `HOTEL_PUNTO`: Relación N:M que asocia hoteles con puntos cercanos e incluye el atributo propio `distancia_km`.
* `TIPO_HABITACION`: Categorías de habitaciones (Suite, Estándar, etc.).
* `COMODIDAD`: Catálogo de servicios y equipamiento.
* `HABITACION`: Habitaciones físicas por sucursal hotelera (con restricción de número único por hotel).
* `HABITACION_COMODIDAD`: Relación N:M que asocia cada habitación física con sus comodidades específicas.
* `HUESPED`: Clientes registrados con documento único.
* `HUESPED_EMAIL` y `HUESPED_TELEFONO`: Medios de contacto normalizados.
* `RESERVA`: Tabla transaccional central con fechas de estadía, tarifas y estados.

### 3.2. Justificación de Normalización (3FN) y Restricciones
* **1FN (Atomicidad):** Cada campo contiene valores atómicos individuales. Se aislaron los atributos multivaluados (teléfonos y correos) en tablas hijas vinculadas por clave foránea.
* **2FN (Dependencia Funcional Completa):** En las tablas con clave primaria compuesta (`HOTEL_PUNTO`, `HABITACION_COMODIDAD`), los atributos o relaciones dependen de la totalidad de la clave y no de una parte de ella.
* **3FN (Ausencia de Dependencias Transitivas):** Ningún atributo no clave depende de otro atributo no clave. Por ejemplo, los datos geográficos del hotel no se repiten en `HABITACION` ni en `RESERVA`.
* **Restricciones de Unicidad y Coherencia:**
  * `uq_hotel_habitacion`: `UNIQUE(id_hotel, numero_habitacion)` asegura que no haya duplicados de numeración dentro de la misma sucursal.
  * `chk_fechas_coherentes`: `CHECK(fecha_salida > fecha_inicio)` garantiza que la fecha de check-out sea estrictamente posterior al check-in.

### 3.3. Justificación de Tipos de Datos (Punto 2)
* **`INT` vs `BIGINT`:** Se utilizó `BIGINT` (8 bytes) únicamente en `RESERVA(id_reserva)` por tratarse de la tabla transaccional masiva (6 millones de filas en prueba y escalable). Para catálogos y entidades maestras se eligió `INT` (4 bytes) para reducir el tamaño de las páginas de índices foráneos a la mitad.
* **`CHAR` vs `VARCHAR` vs `TEXT`:** Se descartó `CHAR` por el desperdicio de almacenamiento en longitudes variables. Se usó `VARCHAR` con longitudes acotadas para nombres, estados y domicilios, y `TEXT` para descripciones extensas de hoteles y atracciones.
* **`DATE` vs `DATETIME`:** Se utilizó `DATE` (3 bytes) para `fecha_inicio` y `fecha_salida` de reservas, ya que el negocio hotelero computa noches y días calendario, ahorrando hasta un 40% de espacio frente a `DATETIME` (5 bytes) en 6 millones de filas.
* **`DECIMAL` vs `FLOAT`:** Se seleccionó `DECIMAL(10,2)` para `tarifa` debido a que valores monetarios requieren precisión matemática exacta, descartando `FLOAT` para evitar imprecisiones por redondeo binario IEEE 754.

---

## 4. Reglas de Negocio Críticas Implementadas

### 4.1. Tarifa según Confirmación
* **Regla:** *"La tarifa será establecida únicamente cuando la reserva sea confirmada."*
* **Implementación:**
  * Columna definida como `tarifa DECIMAL(10,2) NULL`.
  * Reservas `PENDIENTE` poseen obligatoriamente `tarifa = NULL`.
  * Restricción `CHECK` a nivel de motor:
    ```sql
    CONSTRAINT chk_tarifa_estado CHECK (
        (estado = 'PENDIENTE' AND tarifa IS NULL) OR
        (estado IN ('CONFIRMADA', 'FINALIZADA', 'CANCELADA') AND tarifa IS NOT NULL AND tarifa >= 0)
    );
    ```

### 4.2. Prevención de Períodos Superpuestos
* **Regla:** *"Una misma habitación no puede ser reservada para períodos que se superpongan."*
* **Condición matemática:** `existente.fecha_inicio < nueva.fecha_salida AND existente.fecha_salida > nueva.fecha_inicio`
* **Implementación:**
  * **Triggers de validación:** `trg_reserva_no_superposicion_insert` y `trg_reserva_no_superposicion_update` bloquean colisiones para estados `CONFIRMADA` y `PENDIENTE`.
  * **Procedimiento con Bloqueo Exclusivo:** `sp_crear_reserva_segura` implementa concurrencia pesimista con `SELECT ... FOR UPDATE` sobre la habitación antes de la inserción.

---

## 5. Carga Masiva de Datos de Prueba (Punto 8)

* **Volumen alcanzado:** **6.000.000 de registros** en la tabla `RESERVA`.
* **Datos maestros:** 50 Hoteles, 2.500 Habitaciones, 50.000 Huéspedes únicos con correos y teléfonos.
* **Espacio en disco:** ~655 MB en la tabla `RESERVA`.
* **Procedimiento:** Realizado mediante el script `scripts/03_carga_masiva_reservas.sql` (`sp_generar_6m_reservas`), utilizando producto cartesiano procedural en bloques de 100.000 filas con control transaccional explícito.

---

## 6. Guía de Trabajo Colaborativo (Para tu compañero de equipo)

Para trabajar juntos sin que el segundo integrante deba descargar los 6 millones de registros ni instalar Docker:

1. **Host (Dueño del proyecto):**
   * En VS Code, abrir la extensión **Live Share** e iniciar sesión.
   * Hacer clic en **"Share"** y copiar el enlace de invitación.
   * En el menú de Live Share, ir a **"Shared Servers"** y agregar el puerto `8080`.
2. **Invitado (Compañero de equipo):**
   * Abrir el enlace de Live Share en su VS Code o navegador web (`vscode.dev`).
   * Para consultar la base de datos en tiempo real, abrir su navegador e ingresar a `http://localhost:8080`. Se conectará automáticamente al contenedor Docker del Host.
