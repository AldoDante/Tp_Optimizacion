# Trabajo Práctico: Diseño y Optimización de Bases de Datos

Este repositorio contiene la implementación completa, portable y reproducible del Trabajo Práctico de **Diseño y Optimización de Bases de Datos** para la carrera Analista Programador Universitario (APU) - Facultad de Ingeniería.

---

## 🚀 Guía Rápida para Replicar el Proyecto en Cualquier PC

Para clonar y levantar todo el entorno (Base de Datos + phpMyAdmin + Datos Masivos) en cualquier computadora de un compañero o del profesor, seguir estos pasos:

### 1. Requisitos Previos
* **Git:** Para clonar el repositorio.
* **Docker Desktop:** Instalado y en ejecución (asegurarse de que el motor esté corriendo, ícono en verde).

---

### 2. Clonar el Repositorio
Abrir una terminal (PowerShell, CMD o Bash) y ejecutar:
```bash
git clone https://github.com/AldoDante/Tp_Optimizacion.git
cd Tp_Optimizacion
```

---

### 3. Levantar el Entorno con un Solo Clic

#### Opción A (Recomendada en Windows):
Hacer doble clic sobre el archivo **`iniciar.bat`** en el explorador de archivos.

#### Opción B (Desde la Consola):
```bash
docker compose up -d
```

> **¿Qué hace este comando automáticamente?**
> 1. Descarga y levanta los contenedores oficiales de **MySQL 8.0** y **phpMyAdmin**.
> 2. Configura los parámetros óptimos del motor InnoDB (`innodb_buffer_pool_size = 256M`, `disable_log_bin`).
> 3. Ejecuta los scripts de inicialización (`01_crear_tablas.sql` y `02_poblar_datos_iniciales.sql`):
>    - Crea las 12 tablas normalizadas en **Tercera Forma Normal (3FN)**.
>    - Aplica restricciones `CHECK`, `UNIQUE` y claves foráneas.
>    - Carga los 50 hoteles, 2.500 habitaciones, comodidades y 50.000 huéspedes.

---

### 4. Acceso al Administrador Visual (phpMyAdmin)
Una vez levantado el entorno, ingresar desde cualquier navegador web a:
* **URL:** [http://localhost:8080](http://localhost:8080)
* **Servidor:** `db`
* **Usuario:** `admin` (o `root`)
* **Contraseña:** `admin123`
* **Base de Datos:** `db_hoteles`

---

### 5. Carga Masiva de 6.000.000 de Registros

Para inyectar el volumen transaccional de 6 millones de filas en la tabla `RESERVA`:

#### Vía SQL Directo (Sin requerir Java):
Ejecutar desde la consola:
```bash
docker exec -i mysql_tp_hoteles mysql -u admin -padmin123 db_hoteles -e "CALL sp_generar_6m_reservas(60);"
```
*(O ejecutar `CALL sp_generar_6m_reservas(60);` desde la pestaña SQL de phpMyAdmin).*

#### Vía Programa Java de Alto Rendimiento:
Si se dispone de Java instalado:
```bash
javac generador/GeneradorReservas.java
java generador.GeneradorReservas
```

#### Verificación de la Carga:
```bash
docker exec -i mysql_tp_hoteles mysql -u admin -padmin123 db_hoteles -e "SELECT COUNT(*) AS total_reservas FROM RESERVA;"
```

---

## 📂 Estructura del Proyecto

```text
Tp_Optimizacion/
├── docker-compose.yml              # Definición de servicios (MySQL 8.0 + phpMyAdmin)
├── iniciar.bat                     # Script de automatización de arranque
├── README.md                       # Guía de réplica e instrucciones generales
├── BITACORA_DEL_PROYECTO.md        # Bitácora técnica y registro de decisiones de diseño
├── RESUMEN_CONVERSACION_TP.md      # Registro histórico de evolución del trabajo
├── config/
│   └── my.cnf                      # Parámetros personalizados del servidor MySQL
├── scripts/
│   ├── 01_crear_tablas.sql         # DDL físico de tablas y restricciones (3FN)
│   ├── 02_poblar_datos_iniciales.sql # Inserción de catálogos y datos maestros
│   ├── 03_carga_masiva_reservas.sql  # Procedimiento de generación masiva SQL
│   └── 04_reglas_negocio_triggers.sql# Triggers de solapamiento y transacciones
└── generador/
    └── GeneradorReservas.java      # Generador Java de 6M con JDBC Batch Inserts
```

---

## 🛠️ Comandos de Mantenimiento

* **Detener los contenedores:**
  ```bash
  docker compose stop
  ```
* **Reiniciar los contenedores (para pruebas de Cold Cache):**
  ```bash
  docker compose restart db
  ```
* **Destruir el entorno y reiniciar desde cero:**
  ```bash
  docker compose down -v
  docker compose up -d
  ```