USE db_hoteles;

-- ============================================================================
-- TRABAJO PRÁCTICO: DISEÑO Y OPTIMIZACIÓN DE BASES DE DATOS
-- SCRIPT 08: PARTICIONAMIENTO HORIZONTAL, PRUNING Y VISTAS (FASE 6)
-- PUNTOS 49 AL 52 DEL TRABAJO PRÁCTICO
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. PARTICIONAMIENTO HORIZONTAL POR RANGO DE FECHAS (PUNTO 50)
-- En MySQL InnoDB, para particionar por fecha, la clave primaria DEBE incluir
-- la columna de particionamiento: PRIMARY KEY (id_reserva, fecha_inicio).
-- ----------------------------------------------------------------------------

DROP TABLE IF EXISTS RESERVA_PARTICIONADA;

CREATE TABLE RESERVA_PARTICIONADA (
    id_reserva INT UNSIGNED NOT NULL,
    id_huesped INT UNSIGNED NOT NULL,
    id_habitacion INT UNSIGNED NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_salida DATE NOT NULL,
    tarifa DECIMAL(10,2) NULL,
    estado VARCHAR(20) NOT NULL,
    PRIMARY KEY (id_reserva, fecha_inicio)
) ENGINE=InnoDB
PARTITION BY RANGE (YEAR(fecha_inicio)) (
    PARTITION p_antiguas VALUES LESS THAN (2020),
    PARTITION p2020 VALUES LESS THAN (2021),
    PARTITION p2021 VALUES LESS THAN (2022),
    PARTITION p2022 VALUES LESS THAN (2023),
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION p_futuras VALUES LESS THAN MAXVALUE
);

-- Cargar muestra representativa desde la tabla transaccional masiva
INSERT INTO RESERVA_PARTICIONADA 
SELECT id_reserva, id_huesped, id_habitacion, fecha_inicio, fecha_salida, tarifa, estado 
FROM RESERVA 
LIMIT 500000;

-- ----------------------------------------------------------------------------
-- 2. DEMOSTRACIÓN DE PARTITION PRUNING (PUNTO 51)
-- ----------------------------------------------------------------------------

-- A. Consulta con Partition Pruning activo (Solo escanea partición p2023):
EXPLAIN 
SELECT * 
FROM RESERVA_PARTICIONADA 
WHERE fecha_inicio BETWEEN '2023-01-01' AND '2023-12-31';

-- B. Consulta sin clave de partición (Obligada a escanear todas las particiones):
EXPLAIN 
SELECT * 
FROM RESERVA_PARTICIONADA 
WHERE estado = 'confirmada';

-- ----------------------------------------------------------------------------
-- 3. VISTAS ESTÁNDAR VS VISTAS MATERIALIZADAS (PUNTO 52)
-- ----------------------------------------------------------------------------

-- Vista Dinámica Estándar (Re-computa agregaciones en cada invocación):
CREATE OR REPLACE VIEW v_recaudacion_mensual_dinamica AS
SELECT 
    hab.id_hotel,
    DATE_FORMAT(r.fecha_inicio, '%Y-%m') AS anio_mes,
    COUNT(r.id_reserva) AS cantidad_reservas,
    SUM(r.tarifa) AS total_recaudado
FROM HABITACION hab
JOIN RESERVA r ON hab.id_habitacion = r.id_habitacion
WHERE r.estado = 'confirmada'
GROUP BY hab.id_hotel, anio_mes;

-- Comparativa de costo en ejecución:
-- 1. Vista Dinámica (Ejecuta JOIN y agregación en memoria):
EXPLAIN SELECT * FROM v_recaudacion_mensual_dinamica WHERE id_hotel = 1 AND anio_mes = '2023-05';

-- 2. Tabla Materializada con Triggers (Lectura indexada directa O(1)):
EXPLAIN SELECT * FROM REPORTE_RECAUDACION_MENSUAL WHERE id_hotel = 1 AND anio_mes = '2023-05';
