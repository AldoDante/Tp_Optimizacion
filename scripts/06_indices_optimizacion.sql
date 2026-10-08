USE db_hoteles;

-- ============================================================================
-- TRABAJO PRÁCTICO: DISEÑO Y OPTIMIZACIÓN DE BASES DE DATOS
-- SCRIPT 06: ESTRATEGIA DE ÍNDICES Y OPTIMIZACIÓN (FASE 4)
-- PUNTOS 11 AL 18 Y 29 AL 37 DEL TRABAJO PRÁCTICO
-- ============================================================================

-- 1. ÍNDICES DE CLAVE FORÁNEA (Optimizan JOINs y eliminan Full Scans cruzados)
CREATE INDEX IF NOT EXISTS idx_hab_hotel ON HABITACION(id_hotel);
CREATE INDEX IF NOT EXISTS idx_reserva_habitacion ON RESERVA(id_habitacion);
CREATE INDEX IF NOT EXISTS idx_reserva_huesped ON RESERVA(id_huesped);

-- 2. ÍNDICE COMPUESTO TEMPORAL (Regla del Prefijo Izquierdo - Punto 14)
-- Permite búsquedas directas por fecha_inicio o por (fecha_inicio, estado).
CREATE INDEX IF NOT EXISTS idx_reserva_fecha_estado ON RESERVA(fecha_inicio, estado);

-- 3. ÍNDICE COMPUESTO PARA DISPONIBILIDAD (Puntos 14 y 26)
-- Optimiza la verificación de intervalos de fechas no superpuestas por habitación.
CREATE INDEX IF NOT EXISTS idx_reserva_disponibilidad ON RESERVA(id_habitacion, estado, fecha_inicio, fecha_salida);

-- 4. ÍNDICE DE COBERTURA PARA REPORTES DE HUÉSPEDES (Punto 15)
-- Resuelve la consulta sin tocar la tabla principal (Using index).
CREATE INDEX IF NOT EXISTS idx_reserva_huesped_tarifa ON RESERVA(id_huesped, estado, tarifa);

-- 5. ÍNDICE DE COBERTURA PARA RECAUDACIÓN (Punto 15)
CREATE INDEX IF NOT EXISTS idx_reserva_cobertura_ingresos ON RESERVA(estado, fecha_inicio, id_habitacion, tarifa);

-- 6. ÍNDICE FUNCIONAL / BASADO EN EXPRESIONES (Punto 16)
-- Permite acelerar filtros que utilicen YEAR(fecha_inicio).
CREATE INDEX IF NOT EXISTS idx_funcional_anio ON RESERVA((YEAR(fecha_inicio)));
