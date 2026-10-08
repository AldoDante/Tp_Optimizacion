USE db_hoteles;

-- ============================================================================
-- TRABAJO PRÁCTICO: DISEÑO Y OPTIMIZACIÓN DE BASES DE DATOS
-- SCRIPT 05: BASELINE DE RENDIMIENTO - 15 CONSULTAS DEL SISTEMA (FASE 3)
-- PUNTOS 24, 25, 26, 27 Y 28 DEL TRABAJO PRÁCTICO
-- ============================================================================
-- Se ejecutan sobre la base cruda (6.6 millones de registros sin índices
-- secundarios) para capturar los tiempos base y alimentar el Slow Query Log.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- CONSULTAS COMPLEJAS DE 4 O MÁS TABLAS (PUNTO 25)
-- ----------------------------------------------------------------------------

-- Q01: Detalle de reservas confirmadas por hotel y huésped (4 tablas)
-- Une HOTEL, HABITACION, RESERVA y HUESPED.
SELECT 
    h.nombre AS hotel,
    CONCAT(hue.nombre, ' ', hue.apellido) AS huesped,
    hue.nro_documento,
    r.fecha_inicio,
    r.fecha_salida,
    r.tarifa
FROM RESERVA r
JOIN HABITACION hab ON r.id_habitacion = hab.id_habitacion
JOIN HOTEL h ON hab.id_hotel = h.id_hotel
JOIN HUESPED hue ON r.id_huesped = hue.id_huesped
WHERE r.estado = 'confirmada'
  AND h.ciudad = 'Buenos Aires'
  AND r.fecha_inicio BETWEEN '2023-01-01' AND '2023-03-31'
LIMIT 50;

-- Q02: Reporte de demanda de comodidades por tipo de habitación (5 tablas)
-- Une RESERVA, HABITACION, TIPO_HABITACION, TIPO_COMODIDAD y COMODIDAD.
SELECT 
    c.descripcion AS comodidad,
    COUNT(r.id_reserva) AS total_veces_solicitada,
    ROUND(AVG(r.tarifa), 2) AS tarifa_promedio_asociada
FROM RESERVA r
JOIN HABITACION hab ON r.id_habitacion = hab.id_habitacion
JOIN TIPO_HABITACION th ON hab.id_tipo_hab = th.id_tipo_hab
JOIN TIPO_COMODIDAD tc ON th.id_tipo_hab = tc.id_tipo_hab
JOIN COMODIDAD c ON tc.id_comodidad = c.id_comodidad
WHERE r.estado = 'confirmada'
  AND r.fecha_inicio >= '2023-01-01'
GROUP BY c.id_comodidad, c.descripcion
ORDER BY total_veces_solicitada DESC;

-- Q03: Top 10 huéspedes con mayor gasto histórico y su contacto (4 tablas)
-- Une HUESPED, HUESPED_TELEFONO, RESERVA y HABITACION.
SELECT 
    hue.id_huesped,
    CONCAT(hue.apellido, ', ', hue.nombre) AS huesped,
    tel.numero_telefono,
    COUNT(r.id_reserva) AS cantidad_estadias,
    SUM(r.tarifa) AS total_invertido
FROM HUESPED hue
JOIN HUESPED_TELEFONO tel ON hue.id_huesped = tel.id_huesped
JOIN RESERVA r ON hue.id_huesped = r.id_huesped
JOIN HABITACION hab ON r.id_habitacion = hab.id_habitacion
WHERE r.estado = 'confirmada'
GROUP BY hue.id_huesped, huesped, tel.numero_telefono
ORDER BY total_invertido DESC
LIMIT 10;

-- Q04: Demanda de hoteles vinculados a atractivos turísticos cercanos (5 tablas)
-- Une PUNTO_INTERES, HOTEL_PUNTO, HOTEL, HABITACION y RESERVA.
SELECT 
    pi.nombre AS atraccion,
    h.nombre AS hotel,
    hp.distancia_km,
    COUNT(r.id_reserva) AS total_reservas,
    SUM(r.tarifa) AS recaudacion_total
FROM PUNTO_INTERES pi
JOIN HOTEL_PUNTO hp ON pi.id_punto = hp.id_punto
JOIN HOTEL h ON hp.id_hotel = h.id_hotel
JOIN HABITACION hab ON h.id_hotel = hab.id_hotel
JOIN RESERVA r ON hab.id_habitacion = r.id_habitacion
WHERE pi.nombre LIKE '%Iguazu%'
  AND hp.distancia_km <= 15.00
  AND r.estado = 'confirmada'
GROUP BY pi.id_punto, pi.nombre, h.id_hotel, h.nombre, hp.distancia_km
ORDER BY recaudacion_total DESC;

-- Q05: Recaudación y volumen por categoría de habitación en ciudad turística (4 tablas)
-- Une HOTEL, HABITACION, TIPO_HABITACION y RESERVA.
SELECT 
    h.ciudad,
    th.nombre AS categoria,
    COUNT(r.id_reserva) AS cantidad_reservas,
    ROUND(AVG(r.tarifa), 2) AS tarifa_media,
    SUM(r.tarifa) AS ingresos_totales
FROM HOTEL h
JOIN HABITACION hab ON h.id_hotel = hab.id_hotel
JOIN TIPO_HABITACION th ON hab.id_tipo_hab = th.id_tipo_hab
JOIN RESERVA r ON hab.id_habitacion = r.id_habitacion
WHERE h.ciudad = 'San Carlos de Bariloche'
  AND r.estado = 'confirmada'
GROUP BY h.ciudad, th.id_tipo_hab, th.nombre
ORDER BY ingresos_totales DESC;

-- ----------------------------------------------------------------------------
-- CONSULTAS DE DISPONIBILIDAD Y SUPERPOSICIÓN DE FECHAS (PUNTO 26)
-- ----------------------------------------------------------------------------

-- Q06: Habitaciones disponibles en Bariloche para un período mediante NOT EXISTS
SELECT 
    h.nombre AS hotel,
    hab.numero_habitacion,
    th.nombre AS tipo
FROM HABITACION hab
JOIN HOTEL h ON hab.id_hotel = h.id_hotel
JOIN TIPO_HABITACION th ON hab.id_tipo_hab = th.id_tipo_hab
WHERE h.ciudad = 'San Carlos de Bariloche'
  AND NOT EXISTS (
      SELECT 1 
      FROM RESERVA r
      WHERE r.id_habitacion = hab.id_habitacion
        AND r.estado IN ('confirmada', 'pendiente')
        AND r.fecha_inicio < '2024-07-20'
        AND r.fecha_salida > '2024-07-10'
  )
LIMIT 20;

-- Q07: Alternativa de disponibilidad con LEFT JOIN excluyente (para comparar plan de ejecución)
SELECT 
    hab.id_habitacion,
    hab.numero_habitacion,
    h.nombre AS hotel
FROM HABITACION hab
JOIN HOTEL h ON hab.id_hotel = h.id_hotel
LEFT JOIN RESERVA r ON hab.id_habitacion = r.id_habitacion
    AND r.estado IN ('confirmada', 'pendiente')
    AND r.fecha_inicio < '2024-07-20'
    AND r.fecha_salida > '2024-07-10'
WHERE h.ciudad = 'San Carlos de Bariloche'
  AND r.id_reserva IS NULL
LIMIT 20;

-- ----------------------------------------------------------------------------
-- CONSULTAS TEMPORALES, HISTÓRICAS Y RANKINGS (PUNTO 27)
-- ----------------------------------------------------------------------------

-- Q08: Top 5 hoteles con mayor recaudación anual (filtro temporal de rango cerrado)
SELECT 
    h.nombre AS hotel,
    COUNT(r.id_reserva) AS total_reservas,
    SUM(r.tarifa) AS ingresos_totales
FROM HOTEL h
JOIN HABITACION hab ON h.id_hotel = hab.id_hotel
JOIN RESERVA r ON hab.id_habitacion = r.id_habitacion
WHERE r.estado = 'confirmada'
  AND r.fecha_inicio >= '2023-01-01' 
  AND r.fecha_inicio <= '2023-12-31'
GROUP BY h.id_hotel, h.nombre
ORDER BY ingresos_totales DESC
LIMIT 5;

-- Q09: Evolución temporal de reservas por estado y mes (Uso de CASE WHEN y agregación)
SELECT 
    DATE_FORMAT(r.fecha_inicio, '%Y-%m') AS periodo,
    COUNT(r.id_reserva) AS total_operaciones,
    SUM(CASE WHEN r.estado = 'confirmada' THEN 1 ELSE 0 END) AS confirmadas,
    SUM(CASE WHEN r.estado = 'cancelada' THEN 1 ELSE 0 END) AS canceladas,
    SUM(CASE WHEN r.estado = 'pendiente' THEN 1 ELSE 0 END) AS pendientes,
    ROUND(SUM(CASE WHEN r.estado = 'cancelada' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS tasa_cancelacion_pct
FROM RESERVA r
WHERE r.fecha_inicio BETWEEN '2023-01-01' AND '2023-12-31'
GROUP BY periodo
ORDER BY periodo ASC;

-- Q10: Duración promedio de estadías (noches) por ciudad y temporada (DATEDIFF)
SELECT 
    h.ciudad,
    YEAR(r.fecha_inicio) AS anio,
    ROUND(AVG(DATEDIFF(r.fecha_salida, r.fecha_inicio)), 1) AS promedio_noches,
    MAX(DATEDIFF(r.fecha_salida, r.fecha_inicio)) AS maxima_estadia
FROM HOTEL h
JOIN HABITACION hab ON h.id_hotel = hab.id_hotel
JOIN RESERVA r ON hab.id_habitacion = r.id_habitacion
WHERE r.estado = 'confirmada'
GROUP BY h.ciudad, anio
HAVING anio >= 2022
ORDER BY h.ciudad, anio;

-- ----------------------------------------------------------------------------
-- CONSULTAS DE DIFICULTAD PROGRESIVA Y SUBQUERIES (PUNTOS 24 Y 25)
-- ----------------------------------------------------------------------------

-- Q11: Huéspedes frecuentes que se alojaron en 3 o más hoteles distintos (HAVING COUNT DISTINCT)
SELECT 
    hue.id_huesped,
    hue.apellido,
    hue.nombre,
    COUNT(DISTINCT hab.id_hotel) AS hoteles_distintos_visitados,
    COUNT(r.id_reserva) AS total_estadias
FROM HUESPED hue
JOIN RESERVA r ON hue.id_huesped = r.id_huesped
JOIN HABITACION hab ON r.id_habitacion = hab.id_habitacion
WHERE r.estado = 'confirmada'
GROUP BY hue.id_huesped, hue.apellido, hue.nombre
HAVING COUNT(DISTINCT hab.id_hotel) >= 3
ORDER BY hoteles_distintos_visitados DESC, total_estadias DESC
LIMIT 25;

-- Q12: Habitaciones de alta ocupación sin ninguna cancelación histórica (Subconsulta NOT EXISTS)
SELECT 
    hab.id_habitacion,
    h.nombre AS hotel,
    hab.numero_habitacion,
    COUNT(r.id_reserva) AS total_reservas_exitosas
FROM HABITACION hab
JOIN HOTEL h ON hab.id_hotel = h.id_hotel
JOIN RESERVA r ON hab.id_habitacion = r.id_habitacion
WHERE r.estado = 'confirmada'
  AND NOT EXISTS (
      SELECT 1 
      FROM RESERVA sub_r 
      WHERE sub_r.id_habitacion = hab.id_habitacion 
        AND sub_r.estado = 'cancelada'
  )
GROUP BY hab.id_habitacion, h.nombre, hab.numero_habitacion
HAVING total_reservas_exitosas > 500
ORDER BY total_reservas_exitosas DESC
LIMIT 15;

-- Q13: Hoteles cuya tarifa promedio por noche supera la media general de la cadena
SELECT 
    h.id_hotel,
    h.nombre AS hotel,
    ROUND(AVG(r.tarifa), 2) AS tarifa_promedio_hotel
FROM HOTEL h
JOIN HABITACION hab ON h.id_hotel = hab.id_hotel
JOIN RESERVA r ON hab.id_habitacion = r.id_habitacion
WHERE r.estado = 'confirmada'
GROUP BY h.id_hotel, h.nombre
HAVING AVG(r.tarifa) > (
    SELECT AVG(tarifa) 
    FROM RESERVA 
    WHERE estado = 'confirmada'
)
ORDER BY tarifa_promedio_hotel DESC;

-- ----------------------------------------------------------------------------
-- TRANSPORTE DE DATOS Y PAGINACIÓN (PUNTO 28)
-- ----------------------------------------------------------------------------

-- Q14: Impacto del transporte de datos (SELECT * vs SELECT columnas necesarias)
-- Versión A: Transporte masivo de columnas innecesarias
SELECT * 
FROM RESERVA 
WHERE estado = 'confirmada' AND fecha_inicio BETWEEN '2023-01-01' AND '2023-03-31'
LIMIT 10000;

-- Versión B: Proyección selectiva de atributos estrictamente requeridos
SELECT id_reserva, id_habitacion, fecha_inicio, fecha_salida, tarifa 
FROM RESERVA 
WHERE estado = 'confirmada' AND fecha_inicio BETWEEN '2023-01-01' AND '2023-03-31'
LIMIT 10000;

-- Q15: Paginación profunda con alto desplazamiento (OFFSET) vs Keyset Pagination
-- Versión A: Desplazamiento costoso con OFFSET (el motor procesa 1.000.020 filas para descartar 1.000.000)
SELECT id_reserva, id_huesped, fecha_inicio, tarifa
FROM RESERVA
WHERE estado = 'confirmada'
ORDER BY id_reserva
LIMIT 20 OFFSET 1000000;

-- Versión B: Keyset Pagination / Cursor (acceso indexado directo al punto exacto)
SELECT id_reserva, id_huesped, fecha_inicio, tarifa
FROM RESERVA
WHERE estado = 'confirmada' AND id_reserva > 1000000
ORDER BY id_reserva
LIMIT 20;
