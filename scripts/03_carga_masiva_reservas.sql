USE db_hoteles;

-- ============================================================================
-- SCRIPT 03: PROCEDIMIENTO DE CARGA MASIVA (PUNTO 8 DEL TRABAJO PRÁCTICO)
-- Genera 6.000.000 de registros en la tabla RESERVA en lotes transaccionales.
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_generar_6m_reservas;

DELIMITER $$

CREATE PROCEDURE sp_generar_6m_reservas(IN total_lotes INT)
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE lote_tamano INT DEFAULT 100000;
    
    -- Optimizaciones de sesión para carga masiva ultra rápida
    SET autocommit = 0;
    SET foreign_key_checks = 0;
    SET unique_checks = 0;

    WHILE i <= total_lotes DO
        START TRANSACTION;
        
        INSERT INTO RESERVA (id_huesped, id_habitacion, fecha_inicio, fecha_salida, tarifa, estado)
        SELECT 
            1 + FLOOR(RAND() * 50000) AS id_huesped,
            1 + FLOOR(RAND() * 2500)  AS id_habitacion,
            DATE_ADD('2022-01-01', INTERVAL FLOOR(RAND() * 1825) DAY) AS fecha_inicio,
            DATE_ADD('2022-01-01', INTERVAL (FLOOR(RAND() * 1825) + 1 + FLOOR(RAND() * 14)) DAY) AS fecha_salida,
            IF(@e := ELT(1 + FLOOR(RAND() * 4), 'CONFIRMADA', 'PENDIENTE', 'FINALIZADA', 'CANCELADA') = 'PENDIENTE', NULL, ROUND(45.00 + (RAND() * 455.00), 2)) AS tarifa,
            @e AS estado
        FROM aux_digits d1
        CROSS JOIN aux_digits d2
        CROSS JOIN aux_digits d3
        CROSS JOIN aux_digits d4
        CROSS JOIN aux_digits d5;
        
        COMMIT;
        
        SET i = i + 1;
    END WHILE;

    -- Restaurar configuraciones de seguridad
    SET foreign_key_checks = 1;
    SET unique_checks = 1;
    SET autocommit = 1;
    
    SELECT CONCAT('¡Carga completada exitosamente! Total registros generados: ', (total_lotes * lote_tamano)) AS Resultado;
END$$

DELIMITER ;
