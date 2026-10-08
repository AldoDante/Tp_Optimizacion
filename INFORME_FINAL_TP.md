# TRABAJO PRÁCTICO: DISEÑO Y OPTIMIZACIÓN DE BASES DE DATOS
## Memoria Técnica e Informe Final de Ingeniería (52 Puntos)

**Institución:** Universidad Nacional de Jujuy – Facultad de Ingeniería  
**Carrera:** Analista Programador Universitario (APU)  
**Cátedra:** Herramientas Informáticas Avanzadas  
**Docente:** Prof. Casasola  
**Autores:** Aldo Dante Antivilo y Equipo de Trabajo  
**Fecha de Presentación:** Jueves 15 de Octubre de 2026  
**Fecha de Defensa:** Viernes 16 de Octubre de 2026  
**Repositorio Oficial:** `https://github.com/AldoDante/Tp_Optimizacion.git`  
**Entorno de Experimentación:** Docker Compose (MySQL 8.0 Community Server – Motor InnoDB)

---

## TABLA DE CONTENIDOS

1. [Parte I — Análisis del Problema y Diseño de Datos (Puntos 1 al 5)](#parte-i--análisis-del-problema-y-diseño-de-datos)
2. [Parte II — Diseño Físico y Almacenamiento (Puntos 6 al 10)](#parte-ii--diseño-físico-y-almacenamiento)
3. [Parte III — Índices y Estructuras de Acceso (Puntos 11 al 18)](#parte-iii--índices-y-estructuras-de-acceso)
4. [Parte IV — Datos, Carga Masiva y Metodología Experimental (Puntos 19 al 22)](#parte-iv--datos-carga-masiva-y-metodología-experimental)
5. [Parte V — SQL y Consultas del Sistema (Puntos 23 al 28)](#parte-v--sql-y-consultas-del-sistema)
6. [Parte VI — Optimizador, SARGabilidad y Planes de Ejecución (Puntos 29 al 33)](#parte-vi--optimizador-sargabilidad-y-planes-de-ejecución)
7. [Parte VII — Optimización de Consultas y Comparativa Antes/Después (Puntos 34 al 37)](#parte-vii--optimización-de-consultas)
8. [Parte VIII — Transacciones y Concurrencia (Puntos 38 al 42)](#parte-viii--transacciones-y-concurrencia)
9. [Parte IX — Memoria, Servidor y Rendimiento (Puntos 43 al 48)](#parte-ix--memoria-servidor-y-rendimiento)
10. [Parte X — Escalabilidad, Particionamiento y Estructuras Avanzadas (Puntos 49 al 52)](#parte-x--escalabilidad-particionamiento-y-estructuras-avanzadas)
11. [Conclusiones Finales](#conclusiones-finales)

---

# PARTE I — ANÁLISIS DEL PROBLEMA Y DISEÑO DE DATOS

### Punto 1: Análisis del Dominio
El dominio modela una cadena hotelera distribuida geográficamente que opera exclusivamente bajo un sistema de reservas previas.
* **Entidades Clave:** Hoteles, Puntos de Interés cercanos, Medios de Contacto, Categorías de Habitaciones, Comodidades, Habitaciones físicas, Huéspedes y Reservas.
* **Reglas de Negocio Centrales:**
  1. Imposibilidad estricta de superponer reservas para una misma habitación en períodos solapados.
  2. La tarifa de una reserva se establece únicamente cuando la misma pasa al estado de `confirmada` (debe permanecer en `NULL` mientras esté `pendiente`).
  3. Los huéspedes y hoteles pueden disponer de múltiples canales de comunicación (teléfonos, emails, sitios web) sin restricciones rígidas de cantidad.

### Punto 2: Modelo Relacional y Justificación de Transformaciones
Se transformó el Diagrama Entidad-Relación conceptual en un esquema relacional con las siguientes decisiones arquitectónicas:
* **Uso de Claves Subrogadas (`INT UNSIGNED AUTO_INCREMENT`):** Se descartó el uso de claves naturales (como el DNI del huésped o el número de puerta de la habitación). Las claves subrogadas proporcionan inmutabilidad, compacidad física (4 bytes) y alta eficiencia en árboles B+Tree, evitando la propagación de actualizaciones en cascada a lo largo de los millones de filas de `RESERVA`.
* **Resolución de Relaciones N:M:**
  * `HOTEL_PUNTO`: Vincula hoteles y puntos turísticos, incorporando el atributo de la relación `distancia_km`.
  * `TIPO_COMODIDAD`: Asocia amenidades a tipos de cuartos, con clave primaria compuesta `(id_tipo_hab, id_comodidad)`.
* **Desacople de Habitación Física y Tipo:** `HABITACION` modela la unidad física (`id_hotel`, `numero_habitacion`), mientras que `TIPO_HABITACION` describe la categoría comercial. Se definió la restricción `UNIQUE(id_hotel, numero_habitacion)` garantizando que el número de cuarto sea único por sucursal.

### Punto 3: Normalización (1FN, 2FN y 3FN)
* **Primera Forma Normal (1FN):** Eliminación de atributos multivaluados. Se aislaron teléfonos y correos en las tablas dependientes `HUESPED_TELEFONO`, `HUESPED_EMAIL` y `MEDIO_CONTACTO_HOTEL`. Se evitan listas separadas por comas y anomalías de longitud fija.
* **Segunda Forma Normal (2FN):** En tablas con PK compuesta (`HOTEL_PUNTO`), los atributos no clave (`distancia_km`) dependen de la clave en su totalidad y no de una parte de ella. Los datos del punto de interés residen exclusivamente en `PUNTO_INTERES`.
* **Tercera Forma Normal (3FN):** Eliminación de dependencias transitivas. Las comodidades se asignan a la categoría (`TIPO_HABITACION`) a través de `TIPO_COMODIDAD`. Si un hotel demuele sus habitaciones de tipo "Suite", el catálogo de comodidades y características de la Suite no se destruye del sistema (prevención de anomalía de eliminación).

### Punto 4: Integridad y Reglas de Negocio
* **Restricciones Declarativas:**
  * `NOT NULL` en atributos obligatorios para la operativa.
  * `UNIQUE(tipo_doc, nro_documento)` en `HUESPED`.
  * `CHECK (fecha_salida > fecha_inicio)` en `RESERVA`.
  * `CHECK (LOWER(estado) IN ('pendiente', 'confirmada', 'cancelada'))`.
  * `CHECK ((LOWER(estado) = 'pendiente' AND tarifa IS NULL) OR (LOWER(estado) IN ('confirmada', 'cancelada') AND tarifa IS NOT NULL AND tarifa > 0))`.
* **Integridad Referencial:**
  * `ON DELETE CASCADE`: Para entidades débiles (`HUESPED_EMAIL`, `HUESPED_TELEFONO`, `MEDIO_CONTACTO_HOTEL`).
  * `ON DELETE RESTRICT`: Para entidades transaccionales (`HOTEL`, `HABITACION`, `HUESPED` vinculados a `RESERVA`), impidiendo borrados accidentales de historiales contables.
* **Límites Declarativos y Triggers:** Como el estándar SQL en MySQL no soporta restricciones de exclusión temporal (*Exclusion Constraints* nativas de PostgreSQL), la regla de no superposición se garantiza mediante los disparadores `BEFORE INSERT` y `BEFORE UPDATE` en la base de datos (`trg_reserva_no_superposicion`).

### Punto 5: Normalización versus Desnormalización
* **Problema en 3FN:** Obtener el reporte mensual de facturación por hotel en un modelo puramente normalizado obliga a cruzar `HOTEL`, `HABITACION` y `RESERVA`, aplicando `GROUP BY` y `SUM(tarifa)` sobre más de 8 millones de registros, saturando el Buffer Pool.
* **Estrategia Desnormalizada:** Creación de la tabla agregada `REPORTE_RECAUDACION_MENSUAL (id_hotel, anio_mes, cantidad_reservas, total_recaudado)`.
* **Mantenimiento de Integridad:** Se programaron triggers `AFTER INSERT` y `AFTER UPDATE` que sincronizan automáticamente los acumuladores mensuales ante reservas confirmadas o canceladas, trasladando el costo computacional al momento de la escritura (un registro por vez) y reduciendo la lectura a tiempo $O(1)$.

---

# PARTE II — DISEÑO FÍSICO Y ALMACENAMIENTO

### Punto 6: Implementación Física (Script DDL Definitivo)
El esquema físico se implementó en MySQL 8.0 bajo el motor transaccional InnoDB con juego de caracteres `utf8mb4`:
* Archivo de despliegue: `scripts/01_crear_tablas.sql`.
* Total de tablas desplegadas: 13 (12 normalizadas en 3FN + 1 tabla agregada de desnormalización).

### Punto 7: Selección Justificada de Tipos de Datos
* **`INT UNSIGNED` vs `BIGINT`:** Ocupa 4 bytes y cubre hasta 4.294.967.295 valores positivos. Se utilizó para todas las claves foráneas e identificadores, ahorrando un 50% de memoria frente a `BIGINT` (8 bytes) en las hojas de los árboles B+Tree.
* **`DATE` vs `DATETIME`:** Las reservas operan por noches calendario. `DATE` consume exactamente 3 bytes frente a los 5 bytes de `DATETIME`. En más de 8 millones de registros y 2 columnas de fechas, esto significó un ahorro neto superior a **32 MB** en disco y memoria RAM.
* **`DECIMAL(10,2)` vs `FLOAT`:** El tipo de coma flotante IEEE 754 de `FLOAT`/`DOUBLE` presenta errores de redondeo binario inaceptables en liquidaciones financieras. `DECIMAL(10,2)` ofrece precisión decimal fija ocupando solo 5 bytes por valor.
* **`VARCHAR` vs `TEXT`:** Se utilizó `VARCHAR` acotado para atributos indexables y `TEXT` para descripciones largas de hoteles y atracciones turísticas, permitiendo a InnoDB almacenar estos bloques en páginas desbordadas (*off-page storage*).

### Punto 8: Claves y Restricciones Físicas
Se aplicaron claves primarias sobre todas las tablas, foráneas con índices automáticos en InnoDB y restricciones de chequeo a nivel de motor.

### Punto 9: Motor y Estructuras de Almacenamiento (InnoDB)
* **Clustered Index (Índice Agrupado):** En InnoDB, los datos de la tabla residen físicamente ordenados por su clave primaria dentro de un árbol B+Tree. Las filas completas están guardadas en las páginas hoja del índice primario.
* **MVCC (Multi-Version Concurrency Control):** Permite que las lecturas consistentes no bloqueen las operaciones de escritura y viceversa, utilizando punteros a versiones previas almacenadas en el *Undo Tablespace*.

### Punto 10: Estrategias de Almacenamiento y Entorno
* **Entorno Experimental:** Contenedor Docker `mysql:8.0` corriendo sobre Windows con WSL2.
* **Páginas de 16 KB:** Unidad básica de I/O de InnoDB.
* **Configuración del Servidor:** Parámetro `innodb_buffer_pool_size = 268435456` (256 MB) deliberadamente controlado para estudiar empíricamente el intercambio de páginas LRU y la latencia física de disco.

---

# PARTE III — ÍNDICES Y ESTRUCTURAS DE ACCESO

### Punto 11: Estrategia General de Índices
Se diseñó una estrategia integral de índices para eliminar escaneos de tabla completa:
1. `PRIMARY` en `RESERVA(id_reserva)` (Índice Clustered).
2. Claves foráneas: `idx_reserva_habitacion` y `idx_reserva_huesped`.
3. Índice compuesto temporal: `idx_reserva_fecha_estado(fecha_inicio, estado)`.
4. Índice compuesto de disponibilidad: `idx_reserva_disponibilidad(id_habitacion, estado, fecha_inicio, fecha_salida)`.
5. Índice de cobertura de reportes: `idx_reserva_cobertura_ingresos(estado, fecha_inicio, id_habitacion, tarifa)`.
6. Índice funcional: `idx_funcional_anio((YEAR(fecha_inicio)))`.

### Punto 12: Árboles B-Tree y B+Tree
* **Estructura Interna:** InnoDB utiliza árboles **B+Tree**. A diferencia de un B-Tree tradicional (que guarda datos en todos los niveles), el B+Tree almacena datos exclusivamente en los nodos hoja. Los nodos internos contienen únicamente claves y punteros a páginas hijas, maximizando el factor de ramificación (*fan-out*).
* **Escaneo de Rangos:** Las hojas están unidas secuencialmente mediante punteros bidireccionales, permitiendo que una consulta por rango (`BETWEEN`) encuentre el extremo inicial en $O(\log N)$ y luego avance de forma puramente secuencial sin re-navegar desde la raíz.
* **Cálculo de Altura:** Con páginas de 16 KB y 8.100.000 de registros, el árbol alcanza una altura de apenas **3 niveles**, limitando el costo de búsqueda a un máximo de 3 accesos a página.

### Punto 13: Otros Tipos de Índices
* **Hash Index:** Búsqueda en $O(1)$ solo para comparaciones de igualdad estricta (`=`). No soporta rangos ni ordenamientos.
* **Full-Text Index:** Índice invertido diseñado para tokenización y búsqueda de palabras clave en campos `TEXT`.
* **Spatial (R-Tree):** Índices basados en cajas delimitadoras mínimas (*MBR*) para datos geoespaciales.
* **Bitmap Index:** Utilizado en data warehouses para columnas de muy baja cardinalidad; inviable en InnoDB transaccional por bloqueos masivos en modificaciones.

### Punto 14: Índices Compuestos y Regla del Prefijo Izquierdo
* **Fundamento Teórico:** Un índice compuesto `(A, B)` está ordenado primero por `A` y, en caso de empate, por `B`. Por ende, solo puede utilizarse si la consulta filtra por la columna más a la izquierda (*Leftmost Prefix*).
* **Evidencia Empírica Obtenida:**
  * Consulta filtrando por `fecha_inicio` y `estado`: MySQL utilizó `idx_reserva_fecha_estado` con un plan `Covering index range scan` en **0,42 segundos**.
  * Consulta filtrando únicamente por `estado`: El optimizador no pudo usar el índice y recurrió a un `Table scan on RESERVA` de 8 millones de filas tardando **9,3 segundos** en Warm Cache.

### Punto 15: Índices de Cobertura (Covering Index)
* **Concepto:** Un índice cubre una consulta cuando todas las columnas solicitadas en el `SELECT`, `WHERE` y `GROUP BY` forman parte del índice.
* **Impacto en Rendimiento:** Elimina el paso de *Bookmark Lookup* (acceso al índice agrupado para traer las demás columnas). En el plan de ejecución de MySQL se evidencia mediante la etiqueta **`Using index`**.

### Punto 16: Índices Funcionales en MySQL 8.0
* **Problema:** Consultas que filtran por `YEAR(fecha_inicio) = 2023` no pueden usar un índice convencional sobre `fecha_inicio`.
* **Solución Aplicada:**
  ```sql
  CREATE INDEX idx_funcional_anio ON RESERVA ((YEAR(fecha_inicio)));
  ```
* **Validación:** El plan de ejecución pasó de `type: index` escaneando 7,8 millones de filas a `type: ref` con costo instantáneo y acceso indexado directo por constante.

### Punto 17: Cardinalidad y Selectividad
* **Fórmula:** $\text{Selectividad} = \frac{\text{Cardinalidad}}{\text{Total de Filas}}$.
* **Comportamiento del Optimizador:**
  * `id_huesped` (Selectividad $0.0083$): Alta selectividad; el optimizador siempre elige usar el índice.
  * `estado` (Selectividad $0.0000003$): Baja selectividad extrema. Como el 70% de las filas son `'confirmada'`, el optimizador determina que hacer millones de accesos aleatorios a disco para buscar los punteros cuesta más que leer secuencialmente toda la tabla, descartando deliberadamente el índice.

### Punto 18: ¿Por Qué No Indexar Todos los Campos? (Costo DML)
* **Evidencia Experimental:** La creación de 6 índices secundarios sobre los 8.1 millones de registros demoró más de **4 minutos de uso continuo de CPU y disco**.
* **Impacto en Escrituras:** Cada operación `INSERT`, `UPDATE` o `DELETE` debe rebalancear sincrónicamente los 6 árboles B+Tree en disco, degradando el rendimiento de escritura por un factor de 5x a 10x y duplicando el espacio consumido por la base de datos.

---

# PARTE IV — DATOS, CARGA MASIVA Y METODOLOGÍA EXPERIMENTAL

### Punto 19: Generación de Datos de Prueba
* **Mecanismo:** Generador algorítmico determinista con semilla fija (`Random(42)`) para asegurar total reproducibilidad científica entre diferentes computadoras.
* **Criterios de Distribución:**
  * 50 Hoteles distribuidos en nodos turísticos de Argentina.
  * 2.500 Habitaciones físicas (50 por hotel).
  * 50.000 Huéspedes con documentos en rango `20.000.000` a `20.049.999`.
  * Algoritmo de calendario progresivo por habitación que **garantiza por construcción cero superposiciones de fechas**.
  * 70% confirmadas (con tarifa), 20% pendientes (`tarifa = NULL`), 10% canceladas.

### Punto 20: Carga Masiva (8.100.000 de Registros)
* **Procedimiento:** Ejecución en lotes de 100.000 filas mediante el script `scripts/03_carga_masiva_reservas.sql`.
* **Volumen Final Alcanzado:** **8.100.000 de registros** en la tabla `RESERVA`.
* **Optimizaciones de Sesión Aplicadas:**
  * Desactivación de autocommit (`SET autocommit = 0`).
  * Desactivación temporal de chequeos (`foreign_key_checks = 0`, `unique_checks = 0`).
  * Desactivación de logs binarios de replicación (`disable_log_bin`).

### Punto 21: Distribución y Sesgos de Datos
Se evaluó la dispersión uniforme de fechas y clientes, evitando concentraciones anómalas que distorsionen los árboles de búsqueda.

### Punto 22: Metodología de Benchmarking
* **Entorno:** Host Windows 10/11 con WSL2, Docker 29.7.2, MySQL 8.0.
* **Hardware:** SSD NVMe, CPU multi-core, `innodb_buffer_pool_size = 256M`.
* **Condiciones:** Registro obligatorio de métricas bajo estado *Cold Cache* y *Warm Cache*.

---

# PARTE V — SQL Y CONSULTAS DEL SISTEMA

### Punto 23: Cold Cache y Warm Cache
* **Cold Cache (Caché Fría):** Servidor recién reiniciado; la memoria RAM no contiene páginas de datos. La consulta Q08 tardó **67,64 segundos** dominada por la latencia de I/O de disco (`Innodb_buffer_pool_reads`).
* **Warm Cache (Caché Caliente):** Segunda ejecución consecutiva; las páginas residen en el Buffer Pool. La misma consulta tardó **18,20 segundos** sin índices y **6,84 segundos** con índices.
* **Conclusión Metodológica:** Evaluar sistemas de bases de datos únicamente en Warm Cache produce falsos positivos, ocultando cuellos de botella de disco.

### Puntos 24 al 28: Las 15 Consultas del Sistema
El archivo ejecutable completo reside en `scripts/05_consultas_baseline.sql`.

* **Consultas Multi-Tabla Complejas (Punto 25):**
  * **Q01 (4 tablas):** Detalle de reservas confirmadas por hotel y huésped (`HOTEL`, `HABITACION`, `RESERVA`, `HUESPED`).
  * **Q02 (5 tablas):** Demanda de comodidades por tipo de habitación (`RESERVA`, `HABITACION`, `TIPO_HABITACION`, `TIPO_COMODIDAD`, `COMODIDAD`).
  * **Q03 (4 tablas):** Top 10 huéspedes con mayor gasto y sus teléfonos (`HUESPED`, `HUESPED_TELEFONO`, `RESERVA`, `HABITACION`).
  * **Q04 (5 tablas):** Hoteles cercanos a puntos turísticos de interés a menos de 15 km (`PUNTO_INTERES`, `HOTEL_PUNTO`, `HOTEL`, `HABITACION`, `RESERVA`).
  * **Q05 (4 tablas):** Recaudación por categoría de habitación en Bariloche (`HOTEL`, `HABITACION`, `TIPO_HABITACION`, `RESERVA`).
* **Disponibilidad y No Superposición (Punto 26):**
  * **Q06 (NOT EXISTS):** Búsqueda de cuartos libres en rango de fechas excluyendo solapamientos.
  * **Q07 (LEFT JOIN excluyente):** Alternativa para contraste del optimizador.
* **Consultas Temporales e Históricas (Punto 27):**
  * **Q08:** Ranking de hoteles con mayor recaudación en el año 2023.
  * **Q09:** Tasa de cancelación mensual mediante `CASE WHEN` y `GROUP BY`.
  * **Q10:** Duración media de estadías en días (`DATEDIFF`) por ciudad y año.
* **Consultas Progresivas y Subqueries (Punto 24 y 25):**
  * **Q11:** Huéspedes frecuentes en 3+ hoteles distintos (`HAVING COUNT(DISTINCT)`).
  * **Q12:** Habitaciones sin ninguna cancelación histórica (`NOT EXISTS`).
  * **Q13:** Hoteles con tarifa media superior al promedio global de la cadena.
* **Transporte de Datos y Paginación (Punto 28):**
  * **Q14:** `SELECT *` vs proyección acotada (`id_reserva, fecha_inicio, tarifa`).
  * **Q15:** Paginación con `LIMIT 20 OFFSET 1000000` (52,6 segundos) vs Keyset Pagination `WHERE id_reserva > 1000000 LIMIT 20` (0,2 milisegundos).

---

# PARTE VI — OPTIMIZADOR, SARGABILIDAD Y PLANES DE EJECUCIÓN

### Puntos 29 al 33: Diagnóstico con EXPLAIN ANALYZE
* **Indicadores Evaluados:** Tipo de acceso (`ALL`, `index`, `range`, `ref`, `eq_ref`), ordenamientos en disco (`Using filesort`), y tablas temporales (`Using temporary`).
* **Costo de JOINs:** El optimizador utiliza *Nested Loop Join*. Sin índices en claves foráneas, cada fila de `HABITACION` provocaba un escaneo completo de 8.1M filas de `RESERVA`. La creación de `idx_reserva_habitacion` transformó el acceso a `ref` en tiempo logarítmico.

---

# PARTE VII — OPTIMIZACIÓN DE CONSULTAS (TABLA ANTES VS. DESPUÉS)

### Puntos 34 al 37: Resultados Experimentales de las 8 Consultas Críticas

| Consulta | Descripción / Cuello de Botella Inicial | Plan Inicial (Sin Índices) | Tiempo Antes | Estrategia de Optimización / Índices Creados | Plan Optimizado | Tiempo Después | Reducción de Tiempo |
| :---: | :--- | :--- | :---: | :--- | :--- | :---: | :---: |
| **Q08** | Ranking Top 5 hoteles por recaudación anual | Full Table Scan (8.1M filas) | **67,64 s** | `idx_hab_hotel` + `idx_reserva_disponibilidad` | Index lookup en claves foráneas | **6,84 s** | **89,9%** |
| **Q06** | Disponibilidad con `NOT EXISTS` en Bariloche | Table scan por cada habitación candidata | **62,10 s** | `idx_reserva_disponibilidad(id_hab, estado, inicio, fin)` | Covering index lookup en Antijoin | **0,31 s** | **99,5%** |
| **Q01** | Detalle de reservas por hotel y huésped (4 tablas) | Full Table Scan en `RESERVA` | **48,20 s** | Claves foráneas indexadas `idx_res_hab` e `idx_res_huesped` | Nested Loop Join por `ref` | **0,85 s** | **98,2%** |
| **Q03** | Top 10 huéspedes con mayor gasto histórico | Full scan + Sort en disco | **54,30 s** | `idx_reserva_huesped_tarifa(id_huesped, estado, tarifa)` | Covering index aggregation | **1,20 s** | **97,8%** |
| **Q09** | Evolución mensual por estados (`CASE WHEN`) | Table scan completo | **26,40 s** | `idx_reserva_fecha_estado(fecha_inicio, estado)` | Covering index range scan | **0,78 s** | **97,0%** |
| **Q11** | Clientes frecuentes en 3+ hoteles (`HAVING`) | Full scan + Temporary table | **41,50 s** | `idx_reserva_huesped` | Direct index lookup por cliente | **1,95 s** | **95,3%** |
| **Q14** | Transporte masivo: `SELECT *` vs proyección | Lectura de fila completa en disco | **12,40 s** | Proyección acotada de atributos estrictos | Reducción drástica de serialización | **1,80 s** | **85,5%** |
| **Q15** | Paginación profunda (1.000.000 filas de salto) | `OFFSET 1000000` (procesa 5.6M filas) | **52,67 s** | Keyset Pagination (`WHERE id_reserva > 1000000`) | Index range scan directo por `PRIMARY` | **0,0002 s (0.2 ms)** | **99,9996%** |

---

# PARTE VIII — TRANSACCIONES Y CONCURRENCIA

### Puntos 38 al 42: Bloqueos, Aislamiento y Deadlocks
* **Bloqueos Compartidos y Exclusivos (Punto 38 y 39):** Verificación de esperas de bloqueo con `SELECT ... FOR UPDATE` entre dos sesiones concurrentes bajo el timeout de `innodb_lock_wait_timeout = 50s`.
* **Niveles de Aislamiento (Punto 40):** Análisis de consistencia en `REPEATABLE READ` mediante vistas consistentes MVCC y prevención de lecturas fantasmas con *Next-Key Locking*.
* **Simulación Controlada de Deadlock (Punto 41):**
  * Transacción A bloquea fila 1 y solicita fila 2.
  * Transacción B bloquea fila 2 y solicita fila 1.
  * **Respuesta de InnoDB:** Detección automática del ciclo mediante `innodb_deadlock_detect = ON`, abortando la transacción B con el mensaje oficial:
    ```text
    ERROR 1213 (40001): Deadlock found when trying to get lock; try restarting transaction
    ```
* **Diagnóstico (Punto 42):** Inspección del grafo de bloqueos mediante `performance_schema.data_locks`, `data_lock_waits` y el reporte forense en `SHOW ENGINE INNODB STATUS\G` (sección `LATEST DETECTED DEADLOCK`).

---

# PARTE IX — MEMORIA, SERVIDOR Y RENDIMIENTO

### Puntos 43 al 48: Configuración y Arquitectura del Servidor
* **Configuración del Servidor (Punto 43):** Archivo `config/my.cnf` y parámetros de memoria del contenedor.
* **Telemetría Real del InnoDB Buffer Pool (Punto 44):**
  * Capacidad Total: **16.384 páginas** de 16 KB = **256 MB** (`innodb_buffer_pool_size`).
  * Peticiones lógicas de lectura en RAM: **32.004.858 lecturas** (*Buffer Pool Read Requests*).
  * Lecturas físicas en disco SSD: **4.444.634 lecturas** (*Buffer Pool Reads*).
  * **Tasa de Aciertos de Caché (Hit Ratio):**
    $$\text{Hit Ratio} = \frac{32.004.858 - 4.444.634}{32.004.858} = \mathbf{86,11\%}$$
* **Identificación de Cuellos de Botella (Punto 45):**
  * *I/O-Bound:* Consultas en Cold Cache limitadas por la tasa de transferencia del almacenamiento.
  * *CPU-Bound:* Agregaciones en memoria sobre páginas residentes en el Buffer Pool.
  * *Network-Bound:* Transporte no filtrado de datos masivos con `SELECT *`.
* **Connection Pool (Punto 46):** Justificación de frameworks como HikariCP para eliminar la latencia recurrente del handshake TCP, cifrado TLS y asignación de memoria de sesión (`sort_buffer`).
* **Slow Query Log (Punto 47):** Configuración con `long_query_time = 1.0s` y evidencia de registro automático de la consulta de **67,64 segundos**.
* **Mantenimiento Preventivo (Punto 48):** Ejecución de `ANALYZE TABLE` para actualización de estadísticas y `OPTIMIZE TABLE` para desfragmentación de páginas B+Tree.

---

# PARTE X — ESCALABILIDAD, PARTICIONAMIENTO Y ESTRUCTURAS AVANZADAS

### Punto 49: Escalabilidad Vertical vs. Horizontal
* **Vertical (*Scale-Up*):** Ampliación de hardware en un solo nodo. Mantiene garantías ACID puras pero tiene un techo físico y económico.
* **Horizontal (*Scale-Out*):** Distribución de datos en múltiples nodos (*Sharding* o *Read Replicas*). Requiere gestionar la coherencia eventual y la complejidad del Teorema CAP.

### Punto 50: Particionamiento Horizontal por Rangos
Implementación física sobre la tabla transaccional mediante `PARTITION BY RANGE (YEAR(fecha_inicio))` en particiones anuales independientes (`p_antiguas`, `p2020`, `p2021`, `p2022`, `p2023`, `p2024`, `p2025`, `p_futuras`), requiriendo clave primaria compuesta `(id_reserva, fecha_inicio)` según la arquitectura de InnoDB.

### Punto 51: Demostración Empírica de Partition Pruning
* **Consulta con Pruning (Filtro por año 2023):**
  * Salida de `EXPLAIN`: `partitions: p2023`, examinando únicamente **62.933 filas**.
* **Consulta sin Pruning (Filtro por estado):**
  * Salida de `EXPLAIN`: `partitions: p_antiguas,p2020,p2021,p2022,p2023,p2024,p2025,p_futuras`, obligada a escanear todas las particiones del disco (**500.041 filas**).

### Punto 52: Vistas Estándar vs. Vistas Materializadas
* **Vistas Dinámicas:** Evaluadas en tiempo de ejecución. Cada llamada re-ejecuta costosas agregaciones sobre millones de filas.
* **Vistas Materializadas / Tablas Sumarias con Triggers:** Almacenan físicamente los acumuladores calculados (`REPORTE_RECAUDACION_MENSUAL`), transformando reportes pesados en búsquedas indexadas directas en tiempo **$O(1)$** (microsegundos).

---

# CONCLUSIONES FINALES

1. **La Indexación como Eje de Desempeño:** La correcta elección de índices simples, compuestos y de cobertura redujo los tiempos de consulta de más de **60 segundos a fracciones de segundo**, alcanzando mejoras superiores al **99%**.
2. **El Costo Oculto de la Sobre-Indexación:** Los índices no son gratuitos; cada índice secundario incrementa linealmente el tiempo de inserción y modificación de datos, demandando un equilibrio estratégico entre lectura y escritura.
3. **Reproducibilidad y Arquitectura:** La combinación de Docker Compose, scripts SQL modulares y la comprensión profunda de los algoritmos de InnoDB permitieron construir un laboratorio de experimentación robusto, reproducible y académicamente irreprochable para la defensa del trabajo práctico.
