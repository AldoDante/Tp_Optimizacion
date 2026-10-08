USE db_hoteles;

-- ============================================================================
-- TRABAJO PRÁCTICO: DISEÑO Y OPTIMIZACIÓN DE BASES DE DATOS
-- SCRIPT 03: PROCEDIMIENTO DE CARGA MASIVA SQL (FASE 2 - PUNTOS 19 Y 20)
-- Genera 6.000.000 de registros en la tabla RESERVA en lotes transaccionales.
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_generar_6m_reservas;

DELIMITER $$

CREATE PROCEDURE sp_generar_6m_reservas(IN total_lotes INT)
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE lote_tamano INT DEFAULT 100000;
    
    -- Optimizaciones de sesión para máxima velocidad de ingesta
    SET autocommit = 0;
    SET foreign_key_checks = 0;
    SET unique_checks = 0;

    WHILE i <= total_lotes DO
        START TRANSACTION;
        
        INSERT INTO RESERVA (id_huesped, id_habitacion, fecha_inicio, fecha_salida, tarifa, estado)
        SELECT 
            1 + (((d1.d + d2.d*10 + d3.d*100 + d4.d*1000 + d5.d*10000) * 7 + i * 13) % 50000) AS id_huesped,
            1 + (((d1.d + d2.d*10 + d3.d*100 + d4.d*1000 + d5.d*10000) * 11 + i * 17) % 2500) AS id_habitacion,
            DATE_ADD('2018-01-01', INTERVAL (((d1.d + d2.d*10 + d3.d*100 + d4.d*1000 + d5.d*10000) * 31 + i * 101) % 2900) DAY) AS fecha_inicio,
            DATE_ADD('2018-01-01', INTERVAL ((((d1.d + d2.d*10 + d3.d*100 + d4.d*1000 + d5.d*10000) * 31 + i * 101) % 2900) + 1 + ((d1.d + i) % 7)) DAY) AS fecha_salida,
            CASE 
                WHEN ((d1.d + d2.d*10 + i) % 10) >= 7 AND ((d1.d + d2.d*10 + i) % 10) < 9 THEN NULL
                ELSE ROUND(45.00 + (((d1.d + d2.d*10 + d3.d*100 + i * 37) % 455)), 2)
            END AS tarifa,
            CASE 
                WHEN ((d1.d + d2.d*10 + i) % 10) < 7 THEN 'confirmada'
                WHEN ((d1.d + d2.d*10 + i) % 10) < 9 THEN 'pendiente'
                ELSE 'cancelada'
            END AS estado
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
