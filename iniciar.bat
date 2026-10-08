@echo off
echo =====================================================================
echo  TRABAJO PRACTICO: DISENO Y OPTIMIZACION DE BASES DE DATOS
echo  Iniciando entorno Docker (MySQL 8.0 + phpMyAdmin)
echo =====================================================================

docker info > nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Docker no esta ejecutandose.
    echo Por favor abra Docker Desktop y espere a que inicie el motor.
    pause
    exit /b 1
)

echo [1/3] Levantando contenedores con Docker Compose...
docker compose up -d

echo [2/3] Esperando que MySQL este listo para recibir conexiones...
:wait_mysql
docker exec mysql_tp_hoteles mysqladmin ping -h localhost -u root -padmin123 --silent > nul 2>&1
if %errorlevel% neq 0 (
    timeout /t 2 /nobreak > nul
    goto wait_mysql
)
echo      -> MySQL esta activo y listo.

echo [3/3] Verificando tablas del sistema...
docker exec -i mysql_tp_hoteles mysql -u admin -padmin123 db_hoteles -e "SHOW TABLES;"

echo =====================================================================
echo  ENTORNO LISTO Y OPERATIVO
echo  - phpMyAdmin: http://localhost:8080
echo  - MySQL: localhost:3306 (db_hoteles)
echo  - Usuario: admin / Clave: admin123
echo =====================================================================
pause