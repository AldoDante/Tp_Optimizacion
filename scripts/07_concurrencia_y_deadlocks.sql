USE db_hoteles;

-- ============================================================================
-- TRABAJO PRÁCTICO: DISEÑO Y OPTIMIZACIÓN DE BASES DE DATOS
-- SCRIPT 07: CONCURRENCIA, BLOQUEOS Y DEADLOCKS (FASE 5)
-- PUNTOS 38 AL 42 DEL TRABAJO PRÁCTICO
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. TIPOS DE BLOQUEOS EN INNODB (PUNTO 38)
-- ----------------------------------------------------------------------------

-- A. Bloqueo Compartido (Shared Lock - S): Permite que otros lean, pero nadie modifique.
-- START TRANSACTION;
-- SELECT * FROM RESERVA WHERE id_reserva = 100 FOR SHARE; -- O LOCK IN SHARE MODE
-- COMMIT;

-- B. Bloqueo Exclusivo (Exclusive Lock - X): Impide que otros lean con bloqueo o modifiquen.
-- START TRANSACTION;
-- SELECT * FROM RESERVA WHERE id_reserva = 100 FOR UPDATE;
-- COMMIT;

-- C. Bloqueo a nivel de Tabla (Evitado en OLTP moderno):
-- LOCK TABLES RESERVA WRITE; -- Bloquea la tabla entera (nadie más puede leer ni escribir)
-- UNLOCK TABLES;

-- ----------------------------------------------------------------------------
-- 2. GUÍA DE EXPERIMENTACIÓN: FORZAR UN DEADLOCK EN VIVO (PUNTO 41)
-- Ejecutar en DOS terminales o pestañas simultáneas de phpMyAdmin / PowerShell:
-- ----------------------------------------------------------------------------

/*
================== CONEXIÓN 1 ==================
PASO 1:
USE db_hoteles;
START TRANSACTION;
UPDATE RESERVA SET tarifa = 111.00 WHERE id_reserva = 1;
-- (Bloquea id_reserva = 1 con Lock X)

PASO 3 (Ejecutar DESPUÉS de que Conexión 2 haga su Paso 2):
UPDATE RESERVA SET tarifa = 111.00 WHERE id_reserva = 2;
-- (Queda congelada / en espera porque Conexión 2 retiene id_reserva = 2)

================== CONEXIÓN 2 ==================
PASO 2:
USE db_hoteles;
START TRANSACTION;
UPDATE RESERVA SET tarifa = 222.00 WHERE id_reserva = 2;
-- (Bloquea id_reserva = 2 con Lock X)

PASO 4 (Ejecutar MIENTRAS Conexión 1 está en espera):
UPDATE RESERVA SET tarifa = 222.00 WHERE id_reserva = 1;
-- (INTENTA bloquear id_reserva = 1 -> SE PRODUCE CICLO DE ESPERA CIRCULAR)
-- ¡¡SALTA ERROR 1213 (40001): Deadlock found when trying to get lock!!
*/

-- ----------------------------------------------------------------------------
-- 3. DIAGNÓSTICO Y MONITOREO DE BLOQUEOS (PUNTO 42)
-- ----------------------------------------------------------------------------

-- A. Ver qué transacciones están bloqueadas y quién las bloquea:
SELECT 
    r.trx_id AS trx_esperando,
    r.trx_mysql_thread_id AS hilo_esperando,
    r.trx_query AS consulta_bloqueada,
    b.trx_id AS trx_bloqueadora,
    b.trx_mysql_thread_id AS hilo_bloqueador,
    b.trx_query AS consulta_bloqueadora
FROM performance_schema.data_lock_waits w
JOIN information_schema.innodb_trx r ON w.requesting_engine_transaction_id = r.trx_id
JOIN information_schema.innodb_trx b ON w.blocking_engine_transaction_id = b.trx_id;

-- B. Detalle de todos los bloqueos actuales en memoria:
SELECT 
    engine_transaction_id,
    object_name,
    index_name,
    lock_type,
    lock_mode,
    lock_status,
    lock_data
FROM performance_schema.data_locks;

-- C. Reporte del último Deadlock detectado por el motor:
-- SHOW ENGINE INNODB STATUS\G
-- (Buscar la sección "LATEST DETECTED DEADLOCK")

-- ----------------------------------------------------------------------------
-- 4. NIVELES DE AISLAMIENTO Y FENÓMENOS (PUNTO 40)
-- ----------------------------------------------------------------------------

-- Para cambiar de nivel en la sesión actual:
-- SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
-- SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ; -- Default en MySQL
-- SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;
