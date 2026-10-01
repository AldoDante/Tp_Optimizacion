USE db_hoteles;

-- ============================================================================
-- SCRIPT 04: REGLAS DE NEGOCIO - VALIDACIÓN DE SUPERPOSICIÓN DE RESERVAS
-- Enunciado: "El sistema deberá contemplar que una misma habitación no pueda 
-- ser reservada para períodos que se superpongan."
-- Regla aplicada: Bloquean reservas 'CONFIRMADA' y 'PENDIENTE'. Las 'CANCELADA' no.
-- ============================================================================

DROP TRIGGER IF EXISTS trg_reserva_no_superposicion_insert;
DROP TRIGGER IF EXISTS trg_reserva_no_superposicion_update;

DELIMITER $$

-- 1. TRIGGER PARA NUEVAS INSERCIONES
CREATE TRIGGER trg_reserva_no_superposicion_insert
BEFORE INSERT ON RESERVA
FOR EACH ROW
BEGIN
    -- Solo validamos colisiones si la nueva reserva es PENDIENTE o CONFIRMADA
    IF NEW.estado IN ('CONFIRMADA', 'PENDIENTE') THEN
        IF EXISTS (
            SELECT 1 
            FROM RESERVA
            WHERE id_habitacion = NEW.id_habitacion
              AND estado IN ('CONFIRMADA', 'PENDIENTE')
              AND fecha_inicio < NEW.fecha_salida
              AND fecha_salida > NEW.fecha_inicio
            LIMIT 1
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Regla de negocio violada: La habitación ya se encuentra reservada para un período superpuesto.';
        END IF;
    END IF;
END$$

-- 2. TRIGGER PARA MODIFICACIONES DE RESERVAS EXISTENTES
CREATE TRIGGER trg_reserva_no_superposicion_update
BEFORE UPDATE ON RESERVA
FOR EACH ROW
BEGIN
    IF NEW.estado IN ('CONFIRMADA', 'PENDIENTE') THEN
        IF EXISTS (
            SELECT 1 
            FROM RESERVA
            WHERE id_habitacion = NEW.id_habitacion
              AND id_reserva != NEW.id_reserva
              AND estado IN ('CONFIRMADA', 'PENDIENTE')
              AND fecha_inicio < NEW.fecha_salida
              AND fecha_salida > NEW.fecha_inicio
            LIMIT 1
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Regla de negocio violada: El cambio de fechas genera un período superpuesto en la habitación.';
        END IF;
    END IF;
END$$

-- 3. PROCEDIMIENTO TRANSACCIONAL CON BLOQUEO EXCLUSIVO (CONCURRENCIA - PUNTO 20)
-- Demuestra el uso de transacciones con SELECT ... FOR UPDATE para evitar colisiones concurrentes
DROP PROCEDURE IF EXISTS sp_crear_reserva_segura$$

CREATE PROCEDURE sp_crear_reserva_segura(
    IN p_id_huesped INT,
    IN p_id_habitacion INT,
    IN p_fecha_inicio DATE,
    IN p_fecha_salida DATE,
    IN p_tarifa DECIMAL(10,2),
    IN p_estado VARCHAR(20)
)
BEGIN
    DECLARE v_solapada INT DEFAULT 0;

    -- Inicio de transacción segura
    START TRANSACTION;

    -- Bloqueo pesimista a nivel de fila sobre la habitación (Punto 20)
    -- Evita que otra transacción concurrente evalúe disponibilidad al mismo milisegundo
    SELECT id_habitacion 
    FROM HABITACION 
    WHERE id_habitacion = p_id_habitacion 
    FOR UPDATE;

    -- Verificar solapamiento
    SELECT COUNT(*) INTO v_solapada
    FROM RESERVA
    WHERE id_habitacion = p_id_habitacion
      AND estado IN ('CONFIRMADA', 'PENDIENTE')
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
