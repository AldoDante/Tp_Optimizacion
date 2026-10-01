USE db_hoteles;

-- ============================================================================
-- SCRIPT 02: CARGA DE DATOS MAESTROS Y CATÁLOGOS (PREPARACIÓN PARA PUNTO 8)
-- ============================================================================

-- 1. TIPOS DE HABITACIÓN
INSERT IGNORE INTO TIPO_HABITACION (id_tipo_hab, nombre, descripcion) VALUES
(1, 'Individual Estándar', 'Habitación para una persona con cama individual y escritorio.'),
(2, 'Individual Superior', 'Habitación individual amplia con cama queen y cafetera.'),
(3, 'Doble Estándar', 'Habitación para dos personas con dos camas individuales o una matrimonial.'),
(4, 'Doble Superior', 'Habitación matrimonial con balcón y vista al exterior.'),
(5, 'Triple Estándar', 'Habitación con tres camas individuales para grupos o familias.'),
(6, 'Cuádruple Familiar', 'Habitación espaciosa con cama matrimonial y dos individuales.'),
(7, 'Suite Junior', 'Suite con sala de estar integrada y comodidades ejecutivas.'),
(8, 'Suite Ejecutiva', 'Suite con despacho de trabajo, sala de reuniones y minibar premium.'),
(9, 'Suite Presidencial', 'Máximo lujo con terraza privada, jacuzzi y dos dormitorios.'),
(10, 'Penthouse', 'Último piso con vista panorámica exclusiva y servicio personalizado.');

-- 2. COMODIDADES
INSERT IGNORE INTO COMODIDAD (id_comodidad, descripcion) VALUES
(1, 'Wi-Fi de Alta Velocidad'),
(2, 'Aire Acondicionado Frío/Calor'),
(3, 'Smart TV 55 Pulgadas'),
(4, 'Frigobar'),
(5, 'Caja Fuerte Digital'),
(6, 'Vista Panorámica'),
(7, 'Hidromasaje / Jacuzzi'),
(8, 'Cafetera de Cápsulas'),
(9, 'Balcón Privado'),
(10, 'Desayuno Buffet Incluido'),
(11, 'Servicio a la Habitación 24hs'),
(12, 'Acceso a Spa & Sauna');

-- 3. ASIGNACIÓN DE COMODIDADES A TIPOS DE HABITACIÓN (TIPO_COMODIDAD)
INSERT IGNORE INTO TIPO_COMODIDAD (id_tipo_hab, id_comodidad)
SELECT th.id_tipo_hab, c.id_comodidad 
FROM TIPO_HABITACION th 
CROSS JOIN COMODIDAD c 
WHERE c.id_comodidad IN (1, 2);

INSERT IGNORE INTO TIPO_COMODIDAD (id_tipo_hab, id_comodidad)
SELECT th.id_tipo_hab, c.id_comodidad 
FROM TIPO_HABITACION th 
CROSS JOIN COMODIDAD c 
WHERE th.id_tipo_hab >= 2 AND c.id_comodidad IN (3, 4, 10);

INSERT IGNORE INTO TIPO_COMODIDAD (id_tipo_hab, id_comodidad)
SELECT th.id_tipo_hab, c.id_comodidad 
FROM TIPO_HABITACION th 
CROSS JOIN COMODIDAD c 
WHERE th.id_tipo_hab >= 7 AND c.id_comodidad IN (5, 6, 7, 8, 9, 11, 12);

-- 4. HOTELES (50 hoteles distribuidos en polos turísticos)
INSERT IGNORE INTO HOTEL (id_hotel, nombre, descripcion, calle, numero, ciudad) VALUES
(1, 'Grand Hotel Buenos Aires', 'Hotel histórico 5 estrellas en pleno microcentro porteño.', 'Av. Corrientes', '1250', 'Buenos Aires'),
(2, 'Palermo Soho Suites', 'Hotel boutique de diseño contemporáneo y gastronomía de autor.', 'Honduras', '4820', 'Buenos Aires'),
(3, 'Recoleta Palace', 'Elegante hotel clásico cerca de museos y parques.', 'Av. Alvear', '1890', 'Buenos Aires'),
(4, 'Puerto Madero Tower', 'Vistas increíbles al río y amenities de máxima categoría.', 'Juana Manso', '1100', 'Buenos Aires'),
(5, 'San Telmo Colonial', 'Casona restaurada del siglo XIX con patio andaluz.', 'Defensa', '750', 'Buenos Aires'),
(6, 'Hotel Sierras de Córdoba', 'Complejo vacacional con piscinas y vistas a las sierras.', 'Av. San Martín', '350', 'Villa Carlos Paz'),
(7, 'Córdoba Centro Plaza', 'Ideal para turismo corporativo en el centro financiero.', 'San Jerónimo', '220', 'Córdoba'),
(8, 'La Cumbre Golf Resort', 'Paz, golf y spa en el valle de Punilla.', 'Av. Los Tilos', '102', 'La Cumbre'),
(9, 'Mendoza Wine Lodge', 'Rodeado de viñedos y vistas a la Cordillera de los Andes.', 'Ruta 40', 'Km 25', 'Mendoza'),
(10, 'Aconcagua Grand Hotel', 'Hotel céntrico con cava subterránea de degustación.', 'San Lorenzo', '445', 'Mendoza'),
(11, 'Valle de Uco Eco-Resort', 'Arquitectura sustentable entre viñedos de altura.', 'Ruta Provincial 89', 'S/N', 'Tupungato'),
(12, 'Bariloche Ski & Lake', 'Frente al lago Nahuel Huapi con acceso a las pistas.', 'Av. Bustillo', 'Km 4.5', 'San Carlos de Bariloche'),
(13, 'Llao Llao Panoramic', 'Resort de montaña tradicional rodeado de bosques andinos.', 'Av. Pañuelo', '120', 'San Carlos de Bariloche'),
(14, 'Catedral Mountain Inn', 'Base del cerro con guardaesquíes y gastronomía alpina.', 'Base Catedral', 'S/N', 'San Carlos de Bariloche'),
(15, 'Mar del Plata Ocean View', 'Frente a Playa Grande con terraza y piscina infinita.', 'Boulevard Marítimo', '3200', 'Mar del Plata'),
(16, 'Costa Galana Royal', 'Lujo tradicional marplatense en la costa atlántica.', 'Av. Patricio Peralta Ramos', '5720', 'Mar del Plata'),
(17, 'Iguazú Rainforest Hotel', 'Inmerso en la selva misionera a minutos del Parque Nacional.', 'Ruta 12', 'Km 5', 'Puerto Iguazú'),
(18, 'Cataratas Eco-Lodge', 'Contacto directo con la flora y fauna subtropical.', 'Selva Iryapú', 'Lote 14', 'Puerto Iguazú'),
(19, 'Salta Colonial Heritage', 'Arquitectura neocolonial frente a la Plaza 9 de Julio.', 'Mitre', '23', 'Salta'),
(20, 'Cafayate Wine & Spa', 'Ubicado en los Valles Calchaquíes con spa temático de uvas.', 'Ruta 40', 'Km 4340', 'Cafayate'),
(21, 'Ushuaia Fin del Mundo', 'Vistas directas al Canal Beagle y cordillera fueguina.', 'Av. Malvinas Argentinas', '198', 'Ushuaia'),
(22, 'Glaciar Calafate Hotel', 'Base estratégica para visitar el Parque Nacional Los Glaciares.', 'Av. Libertador', '1020', 'El Calafate'),
(23, 'Rosario River Plaza', 'Frente al Río Paraná y el Monumento a la Bandera.', 'Av. Belgrano', '550', 'Rosario'),
(24, 'Termas de Río Hondo Resort', 'Aguas termales curativas y spa de primer nivel.', 'Av. San Martín', '150', 'Termas de Río Hondo'),
(25, 'Madryn Whale Watching', 'A metros del golfo Nuevo con excursiones marinas.', 'Boulevard Brown', '890', 'Puerto Madryn');

-- Agregamos sucursales Express para llegar a 50 hoteles
INSERT IGNORE INTO HOTEL (id_hotel, nombre, descripcion, calle, numero, ciudad)
SELECT 
    id_hotel + 25,
    CONCAT(nombre, ' Express'), 
    CONCAT('Sucursal secundaria de ', nombre), 
    calle, 
    CONCAT(numero, ' Bis'), 
    ciudad 
FROM HOTEL 
WHERE id_hotel <= 25;

-- 5. MEDIOS DE CONTACTO PARA HOTELES (2 por hotel)
INSERT IGNORE INTO MEDIO_CONTACTO_HOTEL (id_hotel, tipo, valor)
SELECT id_hotel, 'telefono', CONCAT('+54 11 4', LPAD(id_hotel * 37, 7, '0')) FROM HOTEL;

INSERT IGNORE INTO MEDIO_CONTACTO_HOTEL (id_hotel, tipo, valor)
SELECT id_hotel, 'email', CONCAT('reservas@hotel', id_hotel, '.com.ar') FROM HOTEL;

-- 6. PUNTOS DE INTERÉS
INSERT IGNORE INTO PUNTO_INTERES (id_punto, nombre, descripcion) VALUES
(1, 'Obelisco de Buenos Aires', 'Monumento histórico ícono de la Ciudad Autónoma de Buenos Aires.'),
(2, 'Teatro Colón', 'Uno de los teatros de ópera con mejor acústica del mundo.'),
(3, 'Cataratas del Iguazú', 'Maravilla natural del mundo dentro del Parque Nacional Iguazú.'),
(4, 'Cerro Catedral', 'Centro de esquí más grande de Sudamérica.'),
(5, 'Parque Nacional Los Glaciares', 'Hogar del majestuoso Glaciar Perito Moreno.'),
(6, 'Canal Beagle', 'Paso marítimo emblemático en el extremo sur de Ushuaia.'),
(7, 'Cerro de los Siete Colores', 'Montaña famosa por sus capas geológicas en Purmamarca.'),
(8, 'Tren a las Nubes', 'Recorrido ferroviario a más de 4000 metros de altura.'),
(9, 'Monumento Histórico Nacional a la Bandera', 'Símbolo histórico a orillas del río Paraná en Rosario.'),
(10, 'Península Valdés', 'Reserva natural de pingüinos, elefantes marinos y ballenas francas.');

-- 7. VINCULACIÓN HOTEL_PUNTO (Relación N:M)
INSERT IGNORE INTO HOTEL_PUNTO (id_hotel, id_punto, distancia_km)
SELECT h.id_hotel, p.id_punto, ROUND(0.5 + ((h.id_hotel * p.id_punto) % 30), 2)
FROM HOTEL h
CROSS JOIN PUNTO_INTERES p
WHERE (h.id_hotel + p.id_punto) % 3 = 0;

-- 8. HABITACIONES (2.500 habitaciones: 50 por cada uno de los 50 hoteles)
CREATE TABLE IF NOT EXISTS aux_digits (d INT PRIMARY KEY);
INSERT IGNORE INTO aux_digits VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);

-- Generador de 50 habitaciones por hotel (n de 1 a 50)
INSERT IGNORE INTO HABITACION (id_hotel, id_tipo_hab, numero_habitacion)
SELECT 
    h.id_hotel,
    1 + ((d1.d + d2.d*10) % 10) AS id_tipo_hab,
    CONCAT(LPAD(1 + (d1.d + d2.d*10), 3, '1')) AS numero_habitacion
FROM HOTEL h
CROSS JOIN aux_digits d1
CROSS JOIN (SELECT d FROM aux_digits WHERE d < 5) d2;

-- 9. GENERACIÓN DE 50.000 HUÉSPEDES REALISTAS
-- nro_documento va de 20.000.000 a 20.049.999
INSERT IGNORE INTO HUESPED (id_huesped, tipo_doc, nro_documento, nombre, apellido, domicilio)
SELECT 
    1 + (d1.d + d2.d*10 + d3.d*100 + d4.d*1000 + d5.d*10000) AS id_huesped,
    'DNI' AS tipo_doc,
    CONCAT(20000000 + (d1.d + d2.d*10 + d3.d*100 + d4.d*1000 + d5.d*10000)) AS nro_documento,
    ELT(1 + ((d1.d + d2.d*10 + d3.d*100) % 50),
        'Agustín','Alan','Alejandro','Ana','Andrea','Andrés','Antonella',
        'Bruno','Camila','Carlos','Carolina','Claudio','Daniel','Diego',
        'Eduardo','Eliana','Emiliano','Facundo','Federico','Florencia',
        'Franco','Gabriel','Gonzalo','Ignacio','Javier','Joaquín','Jorge',
        'Juan','Julieta','Lucas','Lucía','Manuel','Marcos','María',
        'Mariana','Martín','Mateo','Matías','Maximiliano','Micaela',
        'Nicolás','Paula','Ramiro','Rodrigo','Santiago','Sebastián',
        'Sofía','Tomás','Valentina','Victoria') AS nombre,
    ELT(1 + ((d3.d + d4.d*10 + d5.d*100) % 35),
        'Álvarez','Benítez','Castro','Díaz','Domínguez','Fernández','Flores',
        'García','Gómez','González','Gutiérrez','Hernández','López','Martínez',
        'Medina','Morales','Moreno','Navarro','Ortiz','Pérez','Pereyra',
        'Ramírez','Ramos','Rodríguez','Romero','Rossi','Russo','Sánchez',
        'Silva','Sosa','Suárez','Torres','Vázquez','Vega','Vera') AS apellido,
    CONCAT('Av. San Martín ', 100 + (d1.d + d2.d*10)) AS domicilio
FROM aux_digits d1
CROSS JOIN aux_digits d2
CROSS JOIN aux_digits d3
CROSS JOIN aux_digits d4
CROSS JOIN (SELECT d FROM aux_digits WHERE d < 5) d5;

-- 10. GENERACIÓN DE CONTACTOS PARA HUÉSPEDES
INSERT IGNORE INTO HUESPED_EMAIL (id_huesped, email)
SELECT id_huesped, CONCAT('huesped_', id_huesped, '@correo.com')
FROM HUESPED;

INSERT IGNORE INTO HUESPED_TELEFONO (id_huesped, numero_telefono)
SELECT id_huesped, CONCAT('+54 9 11 ', 40000000 + id_huesped)
FROM HUESPED;
