# Trabajo Práctico: Diseño y Optimización de Bases de Datos
## Documentación Integral y Bitácora del Proyecto (52 Puntos)

Este documento reúne todo el análisis, arquitectura, decisiones de diseño, scripts de base de datos, reglas de negocio y metodología experimental del proyecto. Sirve como registro de trabajo colaborativo para el equipo y base directa para el informe final de la materia.

---

## 1. Arquitectura y Entorno de Ejecución

Para garantizar la reproducibilidad y evitar instalaciones locales invasivas en el sistema operativo, el entorno completo se gestiona mediante **Docker Compose**:

* **Motor de Base de Datos:** `MySQL Community Server 8.0` (Motor de almacenamiento transaccional **InnoDB**).
* **Gestor Visual:** `phpMyAdmin` expuesto en el puerto `8080`.
* **Parámetros del Servidor (`config/my.cnf` y contenedor):**
  * `disable_log_bin = 1`: Deshabilita los logs binarios de replicación para evitar saturar el disco rígido durante la inserción masiva de 6 millones de filas (ahorro de más de 2 GB de I/O innecesario).
  * `local_infile = 1`: Habilita la ingestión acelerada de datos.
  * `innodb_buffer_pool_size = 268435456` (256 MB): Configuración deliberadamente controlada de memoria RAM para evaluar empíricamente el comportamiento del Buffer Pool y las transiciones entre *Cold Cache* y *Warm Cache*.
* **Credenciales de Acceso:**
  * Base de datos: `db_hoteles`
  * Usuario: `admin` | Contraseña: `admin123`
  * Root: `root` | Contraseña: `admin123`
  * Acceso phpMyAdmin: `http://localhost:8080` (Servidor: `db`)

---

## 2. Metodología de Trabajo: Plan de Ataque en 6 Fases (52 Puntos)

El proyecto se estructura lógicamente por dependencias técnicas para evitar retrabajos y mediciones falsas:

1. **Fase 1: Implementación Física (Puntos 6 al 10):** Despliegue de estructura física en 3FN, selección justificada de tipos de datos (`INT UNSIGNED`, `DATE`, `DECIMAL`), claves foráneas y análisis de InnoDB.
2. **Fase 2: Carga Masiva y Benchmarking (Puntos 19 al 22):** Generación algorítmica consistente e inyección de 6.000.000 de registros en la tabla `RESERVA` sin índices secundarios. Establecimiento de la metodología experimental.
3. **Fase 3: Baseline de Rendimiento (Puntos 23 al 28, 47):** Formulación de 15 consultas complejas (disponibilidad, cruces de 4+ tablas), configuración de *Slow Query Log* y medición de *Cold vs. Warm Cache*.
4. **Fase 4: Optimización e Índices (Puntos 11 al 18, 29 al 37):** Diagnóstico con `EXPLAIN ANALYZE`, diseño de índices simples, compuestos y de cobertura, regla del prefijo izquierdo, SARGabilidad y comparativas antes/después.
5. **Fase 5: Concurrencia y Servidor (Puntos 38 al 46, 48):** Experimentos de concurrencia multihilo, bloqueos a nivel de fila (`FOR UPDATE`), generación controlada de *Deadlocks*, niveles de aislamiento y monitoreo del Buffer Pool.
6. **Fase 6: Arquitectura Avanzada (Puntos 49 al 52):** Particionamiento horizontal sobre `RESERVA`, análisis de *Partition Pruning*, desnormalización y vistas materializadas.

---

## 3. Diseño Lógico, Físico y Normalización (3FN)

### 3.1. Esquema de Entidades (12 Tablas Definitivas)
* `HOTEL`: Información central de las sucursales hoteleras y su ubicación geográfica.
* `MEDIO_CONTACTO_HOTEL`: Teléfonos, correos y webs por hotel (1:N multivaluado desacoplado).
* `PUNTO_INTERES`: Atractivos turísticos catalogados.
* `HOTEL_PUNTO`: Relación N:M que asocia hoteles con puntos cercanos e incluye el atributo `distancia_km`.
* `TIPO_HABITACION`: Categorías de habitaciones (Suite, Estándar, Doble, etc.).
* `COMODIDAD`: Catálogo de amenidades y servicios ofrecidos.
* `TIPO_COMODIDAD`: Relación N:M que vincula amenidades a cada categoría de habitación en 3FN (evita dependencias transitivas).
* `HABITACION`: Cuartos físicos con restricción `UNIQUE(id_hotel, numero_habitacion)` ("Único por hotel").
* `HUESPED`: Clientes registrados con clave subrogada y restricción `UNIQUE(tipo_doc, nro_documento)`.
* `HUESPED_EMAIL` y `HUESPED_TELEFONO`: Medios de contacto normalizados (1:N multivaluados).
* `RESERVA`: Tabla transaccional central con fechas de estadía, tarifas y estados.
* `REPORTE_RECAUDACION_MENSUAL`: Tabla auxiliar desnormalizada para reportes analíticos de alta velocidad (Punto 5).

### 3.2. Justificación Técnica de Tipos de Datos (Punto 7)
* **`INT UNSIGNED` (4 bytes):** Soporta hasta $4.29 \times 10^9$ registros positivos. Utilizado para claves primarias y foráneas, ahorrando 50% de memoria frente a `BIGINT` en árboles B-Tree del Buffer Pool.
* **`DATE` (3 bytes):** Ahorra 2 bytes por columna frente a `DATETIME` (5 bytes). En 6 millones de filas con dos fechas, ahorra **24 MB** en disco y memoria.
* **`DECIMAL(10,2)` (5 bytes):** Utilizado en `tarifa` para evitar errores de redondeo binario IEEE 754 de `FLOAT`.
* **`VARCHAR` vs `TEXT`:** Se acotaron los campos de búsqueda y se reservó `TEXT` para descripciones largas que InnoDB almacena fuera de la página (*off-page*).

---

## 4. Reglas de Negocio Críticas Implementadas

### 4.1. Tarifa según Confirmación
* **Enunciado:** *"La tarifa será establecida únicamente cuando la reserva sea confirmada."*
* **Implementación:**
  * `tarifa DECIMAL(10,2) NULL`.
  * Restricción `CHECK`:
    ```sql
    CONSTRAINT chk_tarifa_estado CHECK (
        (LOWER(estado) = 'pendiente' AND tarifa IS NULL) OR
        (LOWER(estado) IN ('confirmada', 'cancelada') AND tarifa IS NOT NULL AND tarifa >= 0)
    );
    ```

### 4.2. Prevención de Períodos Superpuestos
* **Enunciado:** *"Una misma habitación no puede ser reservada para períodos que se superpongan."*
* **Condición matemática:** `existente.fecha_inicio < nueva.fecha_salida AND existente.fecha_salida > nueva.fecha_inicio`
* **Implementación:**
  * **Triggers de validación:** `trg_reserva_no_superposicion_insert` y `trg_reserva_no_superposicion_update` abortan transacciones con error `45000` si se detecta colisión temporal para la misma habitación.
  * **Procedimiento con Bloqueo Exclusivo:** `sp_crear_reserva_segura` implementa bloqueo pesimista `SELECT ... FOR UPDATE` sobre la habitación antes de evaluar e insertar.

---

## 5. Guía de Replicación del Proyecto

Cualquier miembro del equipo puede clonar y levantar el proyecto en su PC ejecutando:
1. `git clone https://github.com/AldoDante/Tp_Optimizacion.git`
2. Abrir Docker Desktop.
3. Ejecutar `iniciar.bat` (o `docker compose up -d`).
4. Ejecutar la carga masiva:
   * Por consola: `docker exec -i mysql_tp_hoteles mysql -u admin -padmin123 db_hoteles -e "CALL sp_generar_6m_reservas(60);"`
   * O mediante Java: `java generador.GeneradorReservas`
5. Abrir phpMyAdmin en `http://localhost:8080`.
