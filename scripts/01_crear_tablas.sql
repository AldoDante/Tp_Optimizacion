USE db_hoteles;

-- 1. HOTEL
CREATE TABLE HOTEL (
    id_hotel INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    calle VARCHAR(100) NOT NULL,
    numero VARCHAR(20) NOT NULL,
    ciudad VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

-- 2. MEDIO_CONTACTO_HOTEL
CREATE TABLE MEDIO_CONTACTO_HOTEL (
    id_contacto INT AUTO_INCREMENT PRIMARY KEY,
    id_hotel INT NOT NULL,
    tipo VARCHAR(30) NOT NULL,
    valor VARCHAR(150) NOT NULL,
    CONSTRAINT fk_contacto_hotel FOREIGN KEY (id_hotel) 
        REFERENCES HOTEL(id_hotel) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 3. PUNTO_INTERES
CREATE TABLE PUNTO_INTERES (
    id_punto INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT
) ENGINE=InnoDB;

-- 4. HOTEL_PUNTO (Relación N:M)
CREATE TABLE HOTEL_PUNTO (
    id_hotel INT NOT NULL,
    id_punto INT NOT NULL,
    distancia_km DECIMAL(5,2) NOT NULL,
    PRIMARY KEY (id_hotel, id_punto),
    CONSTRAINT fk_hp_hotel FOREIGN KEY (id_hotel) 
        REFERENCES HOTEL(id_hotel) ON DELETE CASCADE,
    CONSTRAINT fk_hp_punto FOREIGN KEY (id_punto) 
        REFERENCES PUNTO_INTERES(id_punto) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 5. TIPO_HABITACION
CREATE TABLE TIPO_HABITACION (
    id_tipo_hab INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    descripcion VARCHAR(255)
) ENGINE=InnoDB;

-- 6. COMODIDAD
CREATE TABLE COMODIDAD (
    id_comodidad INT AUTO_INCREMENT PRIMARY KEY,
    descripcion VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

-- 7. HABITACION
CREATE TABLE HABITACION (
    id_habitacion INT AUTO_INCREMENT PRIMARY KEY,
    id_hotel INT NOT NULL,
    id_tipo_hab INT NOT NULL,
    numero_habitacion VARCHAR(10) NOT NULL,
    CONSTRAINT fk_hab_hotel FOREIGN KEY (id_hotel) 
        REFERENCES HOTEL(id_hotel) ON DELETE RESTRICT,
    CONSTRAINT fk_hab_tipo FOREIGN KEY (id_tipo_hab) 
        REFERENCES TIPO_HABITACION(id_tipo_hab) ON DELETE RESTRICT,
    CONSTRAINT uq_hotel_habitacion UNIQUE (id_hotel, numero_habitacion)
) ENGINE=InnoDB;

-- 8. HABITACION_COMODIDAD (Relación N:M)
CREATE TABLE HABITACION_COMODIDAD (
    id_habitacion INT NOT NULL,
    id_comodidad INT NOT NULL,
    PRIMARY KEY (id_habitacion, id_comodidad),
    CONSTRAINT fk_hc_hab FOREIGN KEY (id_habitacion) 
        REFERENCES HABITACION(id_habitacion) ON DELETE CASCADE,
    CONSTRAINT fk_hc_comodidad FOREIGN KEY (id_comodidad) 
        REFERENCES COMODIDAD(id_comodidad) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 9. HUESPED
CREATE TABLE HUESPED (
    id_huesped INT AUTO_INCREMENT PRIMARY KEY,
    tipo_doc VARCHAR(10) NOT NULL,
    nro_documento VARCHAR(20) NOT NULL,
    nombre VARCHAR(60) NOT NULL,
    apellido VARCHAR(60) NOT NULL,
    domicilio VARCHAR(150),
    CONSTRAINT uq_huesped_documento UNIQUE (tipo_doc, nro_documento)
) ENGINE=InnoDB;

-- 10. HUESPED_EMAIL (Multivaluado)
CREATE TABLE HUESPED_EMAIL (
    id_huesped INT NOT NULL,
    email VARCHAR(120) NOT NULL,
    PRIMARY KEY (id_huesped, email),
    CONSTRAINT fk_hemail_huesped FOREIGN KEY (id_huesped) 
        REFERENCES HUESPED(id_huesped) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 11. HUESPED_TELEFONO (Multivaluado)
CREATE TABLE HUESPED_TELEFONO (
    id_huesped INT NOT NULL,
    numero_telefono VARCHAR(30) NOT NULL,
    PRIMARY KEY (id_huesped, numero_telefono),
    CONSTRAINT fk_htel_huesped FOREIGN KEY (id_huesped) 
        REFERENCES HUESPED(id_huesped) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 12. RESERVA (Tabla masiva transaccional)
CREATE TABLE RESERVA (
    id_reserva BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_huesped INT NOT NULL,
    id_habitacion INT NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_salida DATE NOT NULL,
    tarifa DECIMAL(10,2) NULL,
    estado VARCHAR(20) NOT NULL,
    CONSTRAINT fk_reserva_huesped FOREIGN KEY (id_huesped) 
        REFERENCES HUESPED(id_huesped) ON DELETE RESTRICT,
    CONSTRAINT fk_reserva_habitacion FOREIGN KEY (id_habitacion) 
        REFERENCES HABITACION(id_habitacion) ON DELETE RESTRICT,
    CONSTRAINT chk_tarifa_estado CHECK (
        (estado = 'PENDIENTE' AND tarifa IS NULL) OR
        (estado IN ('CONFIRMADA', 'FINALIZADA', 'CANCELADA') AND tarifa IS NOT NULL AND tarifa >= 0)
    ),
    CONSTRAINT chk_fechas_coherentes CHECK (fecha_salida > fecha_inicio)
) ENGINE=InnoDB;
