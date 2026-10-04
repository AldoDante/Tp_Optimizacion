USE db_hoteles;

-- ============================================================================
-- TRABAJO PRÁCTICO: DISEÑO Y OPTIMIZACIÓN DE BASES DE DATOS
-- SCRIPT 01: CREACIÓN DE ESTRUCTURA FÍSICA Y RESTRICCIONES (FASE 1)
-- MOTOR: MySQL 8.0 / MariaDB (InnoDB) - CHARSET: utf8mb4
-- ============================================================================

SET foreign_key_checks = 0;
DROP TABLE IF EXISTS REPORTE_RECAUDACION_MENSUAL;
DROP TABLE IF EXISTS RESERVA;
DROP TABLE IF EXISTS HUESPED_TELEFONO;
DROP TABLE IF EXISTS HUESPED_EMAIL;
DROP TABLE IF EXISTS HUESPED;
DROP TABLE IF EXISTS HABITACION_COMODIDAD; -- Eliminada por normalización 3FN
DROP TABLE IF EXISTS HABITACION;
DROP TABLE IF EXISTS TIPO_COMODIDAD;
DROP TABLE IF EXISTS COMODIDAD;
DROP TABLE IF EXISTS TIPO_HABITACION;
DROP TABLE IF EXISTS HOTEL_PUNTO;
DROP TABLE IF EXISTS PUNTO_INTERES;
DROP TABLE IF EXISTS MEDIO_CONTACTO_HOTEL;
DROP TABLE IF EXISTS HOTEL;
SET foreign_key_checks = 1;

-- 1. HOTEL
CREATE TABLE HOTEL (
    id_hotel INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    calle VARCHAR(100) NOT NULL,
    numero VARCHAR(20) NOT NULL,
    ciudad VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

-- 2. MEDIO_CONTACTO_HOTEL (1:N desacoplado)
CREATE TABLE MEDIO_CONTACTO_HOTEL (
    id_contacto INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_hotel INT UNSIGNED NOT NULL,
    tipo VARCHAR(30) NOT NULL,
    valor VARCHAR(150) NOT NULL,
    CONSTRAINT fk_contacto_hotel FOREIGN KEY (id_hotel) 
        REFERENCES HOTEL(id_hotel) ON DELETE CASCADE,
    CONSTRAINT chk_contacto_tipo CHECK (LOWER(tipo) IN ('telefono', 'email', 'web', 'whatsapp'))
) ENGINE=InnoDB;

-- 3. PUNTO_INTERES
CREATE TABLE PUNTO_INTERES (
    id_punto INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT
) ENGINE=InnoDB;

-- 4. HOTEL_PUNTO (Relación N:M)
CREATE TABLE HOTEL_PUNTO (
    id_hotel INT UNSIGNED NOT NULL,
    id_punto INT UNSIGNED NOT NULL,
    distancia_km DECIMAL(5,2) NOT NULL,
    PRIMARY KEY (id_hotel, id_punto),
    CONSTRAINT fk_hp_hotel FOREIGN KEY (id_hotel) 
        REFERENCES HOTEL(id_hotel) ON DELETE CASCADE,
    CONSTRAINT fk_hp_punto FOREIGN KEY (id_punto) 
        REFERENCES PUNTO_INTERES(id_punto) ON DELETE CASCADE,
    CONSTRAINT chk_distancia_positiva CHECK (distancia_km >= 0)
) ENGINE=InnoDB;

-- 5. TIPO_HABITACION
CREATE TABLE TIPO_HABITACION (
    id_tipo_hab INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    descripcion VARCHAR(255)
) ENGINE=InnoDB;

-- 6. COMODIDAD
CREATE TABLE COMODIDAD (
    id_comodidad INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    descripcion VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

-- 7. TIPO_COMODIDAD (Relación N:M en 3FN según Modelo Definitivo)
CREATE TABLE TIPO_COMODIDAD (
    id_tipo_hab INT UNSIGNED NOT NULL,
    id_comodidad INT UNSIGNED NOT NULL,
    PRIMARY KEY (id_tipo_hab, id_comodidad),
    CONSTRAINT fk_tc_tipo FOREIGN KEY (id_tipo_hab) 
        REFERENCES TIPO_HABITACION(id_tipo_hab) ON DELETE CASCADE,
    CONSTRAINT fk_tc_comodidad FOREIGN KEY (id_comodidad) 
        REFERENCES COMODIDAD(id_comodidad) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 8. HABITACION
CREATE TABLE HABITACION (
    id_habitacion INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_hotel INT UNSIGNED NOT NULL,
    id_tipo_hab INT UNSIGNED NOT NULL,
    numero_habitacion VARCHAR(10) NOT NULL,
    CONSTRAINT fk_hab_hotel FOREIGN KEY (id_hotel) 
        REFERENCES HOTEL(id_hotel) ON DELETE RESTRICT,
    CONSTRAINT fk_hab_tipo FOREIGN KEY (id_tipo_hab) 
        REFERENCES TIPO_HABITACION(id_tipo_hab) ON DELETE RESTRICT,
    CONSTRAINT uq_hotel_habitacion UNIQUE (id_hotel, numero_habitacion)
) ENGINE=InnoDB;

-- 9. HUESPED
CREATE TABLE HUESPED (
    id_huesped INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tipo_doc VARCHAR(10) NOT NULL,
    nro_documento VARCHAR(20) NOT NULL,
    nombre VARCHAR(60) NOT NULL,
    apellido VARCHAR(60) NOT NULL,
    domicilio VARCHAR(150),
    CONSTRAINT uq_huesped_documento UNIQUE (tipo_doc, nro_documento)
) ENGINE=InnoDB;

-- 10. HUESPED_EMAIL (Multivaluado)
CREATE TABLE HUESPED_EMAIL (
    id_huesped INT UNSIGNED NOT NULL,
    email VARCHAR(120) NOT NULL,
    PRIMARY KEY (id_huesped, email),
    CONSTRAINT fk_hemail_huesped FOREIGN KEY (id_huesped) 
        REFERENCES HUESPED(id_huesped) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 11. HUESPED_TELEFONO (Multivaluado)
CREATE TABLE HUESPED_TELEFONO (
    id_huesped INT UNSIGNED NOT NULL,
    numero_telefono VARCHAR(30) NOT NULL,
    PRIMARY KEY (id_huesped, numero_telefono),
    CONSTRAINT fk_htel_huesped FOREIGN KEY (id_huesped) 
        REFERENCES HUESPED(id_huesped) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 12. RESERVA (Tabla masiva transaccional de 6.000.000 de registros)
CREATE TABLE RESERVA (
    id_reserva INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_huesped INT UNSIGNED NOT NULL,
    id_habitacion INT UNSIGNED NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_salida DATE NOT NULL,
    tarifa DECIMAL(10,2) NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'pendiente',
    CONSTRAINT fk_reserva_huesped FOREIGN KEY (id_huesped) 
        REFERENCES HUESPED(id_huesped) ON DELETE RESTRICT,
    CONSTRAINT fk_reserva_habitacion FOREIGN KEY (id_habitacion) 
        REFERENCES HABITACION(id_habitacion) ON DELETE RESTRICT,
    CONSTRAINT chk_fechas_coherentes CHECK (fecha_salida > fecha_inicio),
    CONSTRAINT chk_estado_dominio CHECK (LOWER(estado) IN ('pendiente', 'confirmada', 'cancelada')),
    CONSTRAINT chk_tarifa_estado CHECK (
        (LOWER(estado) = 'pendiente' AND tarifa IS NULL) OR
        (LOWER(estado) IN ('confirmada', 'cancelada') AND tarifa IS NOT NULL AND tarifa >= 0)
    )
) ENGINE=InnoDB;

-- 13. REPORTE_RECAUDACION_MENSUAL (Desnormalización controlada - Punto 5)
CREATE TABLE REPORTE_RECAUDACION_MENSUAL (
    id_hotel INT UNSIGNED NOT NULL,
    anio_mes CHAR(7) NOT NULL, -- Formato YYYY-MM
    cantidad_reservas INT UNSIGNED NOT NULL DEFAULT 0,
    total_recaudado DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    PRIMARY KEY (id_hotel, anio_mes),
    CONSTRAINT fk_rep_hotel FOREIGN KEY (id_hotel) 
        REFERENCES HOTEL(id_hotel) ON DELETE CASCADE
) ENGINE=InnoDB;
