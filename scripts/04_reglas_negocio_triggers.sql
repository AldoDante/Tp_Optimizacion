USE db_hoteles;

-- ============================================================================
-- TRABAJO PRÁCTICO: DISEÑO Y OPTIMIZACIÓN DE BASES DE DATOS
-- SCRIPT 04: REGLAS DE NEGOCIO, TRIGGERS Y TRANSACCIONES SEGURAS (PUNTOS 4, 5 Y 8)
-- ============================================================================

DROP TRIGGER IF EXISTS trg_reserva_no_superposicion_insert;
DROP TRIGGER IF EXISTS trg_reserva_no_superposicion_update;
DROP TRIGGER IF EXISTS trg_recaudacion_insert;
DROP TRIGGER IF EXISTS trg_recaudacion_update;

DELIMITER $$

-- ----------------------------------------------------------------------------
-- 1. TRIGGER PARA EVITAR SUPERPOSICIÓN DE FECHAS (INSERCIÓN)
-- Enunciado: "El sistema deberá contemplar que una misma habitación no pueda 
-- ser reservada para períodos que se superpongan."
-- ----------------------------------------------------------------------------
CREATE TRIGGER trg_reserva_no_superposicion_insert
BEFORE INSERT ON RESERVA
FOR EACH ROW
BEGIN
    IF LOWER(NEW.estado) IN ('confirmada', 'pendiente') THEN
        IF EXISTS (
            SELECT 1 
            FROM RESERVA
            WHERE id_habitacion = NEW.id_habitacion
              AND LOWER(estado) IN ('confirmada', 'pendiente')
              AND fecha_inicio < NEW.fecha_salida
              AND fecha_salida > NEW.fecha_inicio
            LIMIT 1
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Regla de negocio violada: La habitación ya se encuentra reservada para un período superpuesto.';
        END IF;
    END IF;
END$$

-- ----------------------------------------------------------------------------
-- 2. TRIGGER PARA EVITAR SUPERPOSICIÓN DE FECHAS (MODIFICACIÓN)
-- ----------------------------------------------------------------------------
CREATE TRIGGER trg_reserva_no_superposicion_update
BEFORE UPDATE ON RESERVA
FOR EACH ROW
BEGIN
    IF LOWER(NEW.estado) IN ('confirmada', 'pendiente') THEN
        IF EXISTS (
            SELECT 1 
            FROM RESERVA
            WHERE id_habitacion = NEW.id_habitacion
              AND id_reserva != NEW.id_reserva
              AND LOWER(estado) IN ('confirmada', 'pendiente')
              AND fecha_inicio < NEW.fecha_salida
              AND fecha_salida > NEW.fecha_inicio
            LIMIT 1
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Regla de negocio violada: La modificación genera un solapamiento de fechas para la habitación.';
        END IF;
    END IF;
END$$

-- ----------------------------------------------------------------------------
-- 3. TRIGGERS PARA TABLA DESNORMALIZADA (REPORTE_RECAUDACION_MENSUAL - PUNTO 5)
-- Mantiene sincronizado el resumen mensual de recaudación por hotel automáticamente.
-- ----------------------------------------------------------------------------
CREATE TRIGGER trg_recaudacion_insert
AFTER INSERT ON RESERVA
FOR EACH ROW
BEGIN
    DECLARE v_id_hotel INT UNSIGNED;
    DECLARE v_periodo CHAR(7);
    
    IF LOWER(NEW.estado) = 'confirmada' AND NEW.tarifa IS NOT NULL THEN
        SELECT id_hotel INTO v_id_hotel FROM HABITACION WHERE id_habitacion = NEW.id_habitacion;
        SET v_periodo = DATE_FORMAT(NEW.fecha_inicio, '%Y-%m');
        
        INSERT INTO REPORTE_RECAUDACION_MENSUAL (id_hotel, anio_mes, cantidad_reservas, total_recaudado)
        VALUES (v_id_hotel, v_periodo, 1, NEW.tarifa)
        ON DUPLICATE KEY UPDATE 
            cantidad_reservas = cantidad_reservas + 1,
            total_recaudado = total_recaudado + NEW.tarifa;
    END IF;
END$$

CREATE TRIGGER trg_recaudacion_update
AFTER UPDATE ON RESERVA
FOR EACH ROW
BEGIN
    DECLARE v_id_hotel INT UNSIGNED;
    DECLARE v_periodo CHAR(7);
    
    -- Caso 1: Pasa a confirmada
    IF LOWER(OLD.estado) != 'confirmada' AND LOWER(NEW.estado) = 'confirmada' AND NEW.tarifa IS NOT NULL THEN
        SELECT id_hotel INTO v_id_hotel FROM HABITACION WHERE id_habitacion = NEW.id_habitacion;
        SET v_periodo = DATE_FORMAT(NEW.fecha_inicio, '%Y-%m');
        
        INSERT INTO REPORTE_RECAUDACION_MENSUAL (id_hotel, anio_mes, cantidad_reservas, total_recaudado)
        VALUES (v_id_hotel, v_periodo, 1, NEW.tarifa)
        ON DUPLICATE KEY UPDATE 
            cantidad_reservas = cantidad_reservas + 1,
            total_recaudado = total_recaudado + NEW.tarifa;
            
    -- Caso 2: Se cancela una que estaba confirmada
    ELSEIF LOWER(OLD.estado) = 'confirmada' AND LOWER(NEW.estado) = 'cancelada' AND OLD.tarifa IS NOT NULL THEN
        SELECT id_hotel INTO v_id_hotel FROM HABITACION WHERE id_habitacion = OLD.id_habitacion;
        SET v_periodo = DATE_FORMAT(OLD.fecha_inicio, '%Y-%m');
        
        UPDATE REPORTE_RECAUDACION_MENSUAL
        SET cantidad_reservas = GREATEST(0, cantidad_reservas - 1),
            total_recaudado = GREATEST(0.00, total_recaudado - OLD.tarifa)
        WHERE id_hotel = v_id_hotel AND anio_mes = v_periodo;
    END IF;
END$$

-- ----------------------------------------------------------------------------
-- 4. PROCEDIMIENTO TRANSACCIONAL CON BLOQUEO PESIMISTA (PUNTO 38 AL 42)
-- Demuestra el uso de transacciones con SELECT ... FOR UPDATE para evitar race conditions
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_crear_reserva_segura$$

CREATE PROCEDURE sp_crear_reserva_segura(
    IN p_id_huesped INT UNSIGNED,
    IN p_id_habitacion INT UNSIGNED,
    IN p_fecha_inicio DATE,
    IN p_fecha_salida DATE,
    IN p_tarifa DECIMAL(10,2),
    IN p_estado VARCHAR(20)
)
BEGIN
    DECLARE v_solapada INT DEFAULT 0;

    START TRANSACTION;

    -- Bloqueo pesimista a nivel de fila sobre la habitación
    SELECT id_habitacion 
    FROM HABITACION 
    WHERE id_habitacion = p_id_habitacion 
    FOR UPDATE;

    -- Verificar solapamiento
    SELECT COUNT(*) INTO v_solapada
    FROM RESERVA
    WHERE id_habitacion = p_id_habitacion
      AND LOWER(estado) IN ('confirmada', 'pendiente')
      AND fecha_inicio < p_fecha_salida
      AND fecha_salida > p_fecha_inicio;

    IF v_solapada > 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Transacción abortada: La habitación ya no se encuentra disponible para esas fechas.';
    ELSE
        INSERT INTO RESERVA (id_huesped, id_habitacion, fecha_inicio, fecha_salida, tarifa, estado)
        VALUES (p_id_huesped, p_id_habitacion, p_fecha_inicio, p_fecha_salida, p_tarifa, p_estado);
        COMMIT;
    END IF;
END$$

DELIMITER ;
