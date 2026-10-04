package generador;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.Connection;
import java.sql.Date;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.time.LocalDate;
import java.util.Random;

/**
 * ============================================================================
 * TRABAJO PRÁCTICO: DISEÑO Y OPTIMIZACIÓN DE BASES DE DATOS
 * GENERADOR MASIVO DE DATOS EN JAVA (FASE 2 - PUNTOS 19 Y 20)
 * ============================================================================
 * Inserta 6.000.000 de registros en la tabla RESERVA garantizando por
 * construcción algorítmica la NO superposición de fechas en cada habitación.
 *
 * Utiliza JDBC Batch Inserts y rewriteBatchedStatements=true para maximizar
 * el rendimiento del motor InnoDB.
 */
public class GeneradorReservas {

    private static final String URL = "jdbc:mysql://localhost:3306/db_hoteles?rewriteBatchedStatements=true&useServerPrepStmts=true&cachePrepStmts=true&allowPublicKeyRetrieval=true&useSSL=false";
    private static final String USER = "admin";
    private static final String PASSWORD = "admin123";

    private static final int TOTAL_REGISTROS = 6_000_000;
    private static final int BATCH_SIZE = 10_000;
    private static final int TOTAL_HUESPEDES = 50_000;
    private static final int TOTAL_HABITACIONES = 2_500;

    public static void main(String[] args) {
        System.out.println("=================================================================");
        System.out.println("INICIANDO GENERADOR MASIVO DE RESERVAS (OBJETIVO: 6.000.000)");
        System.out.println("=================================================================");

        long tiempoInicio = System.currentTimeMillis();
        Random random = new Random(42); // Semilla fija para reproducibilidad científica

        // Punteros de fecha por cada habitación para evitar superposición por diseño
        LocalDate[] calendarioHabitacion = new LocalDate[TOTAL_HABITACIONES + 1];
        LocalDate fechaBase = LocalDate.of(2018, 1, 1);
        for (int h = 1; h <= TOTAL_HABITACIONES; h++) {
            calendarioHabitacion[h] = fechaBase.plusDays(random.nextInt(30));
        }

        String sql = "INSERT INTO RESERVA (id_huesped, id_habitacion, fecha_inicio, fecha_salida, tarifa, estado) " +
                     "VALUES (?, ?, ?, ?, ?, ?)";

        try (Connection conn = DriverManager.getConnection(URL, USER, PASSWORD)) {
            conn.setAutoCommit(false);

            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                int contador = 0;

                for (int i = 1; i <= TOTAL_REGISTROS; i++) {
                    int idHuesped = 1 + random.nextInt(TOTAL_HUESPEDES);
                    int idHabitacion = 1 + random.nextInt(TOTAL_HABITACIONES);

                    // Avanzar la fecha de la habitación elegida (evita solapamiento estricto)
                    LocalDate fechaInicio = calendarioHabitacion[idHabitacion].plusDays(random.nextInt(2));
                    int duracionNoches = 1 + random.nextInt(7);
                    LocalDate fechaSalida = fechaInicio.plusDays(duracionNoches);
                    calendarioHabitacion[idHabitacion] = fechaSalida; // Próxima reserva arranca después

                    // Distribución de estados: 70% confirmada, 20% pendiente, 10% cancelada
                    int rndEstado = random.nextInt(100);
                    String estado;
                    BigDecimal tarifa = null;

                    if (rndEstado < 70) {
                        estado = "confirmada";
                        double valorTarifa = 45.0 + (random.nextDouble() * 455.0);
                        tarifa = BigDecimal.valueOf(valorTarifa).setScale(2, RoundingMode.HALF_UP);
                    } else if (rndEstado < 90) {
                        estado = "pendiente";
                        tarifa = null; // Cumple regla de negocio: pendiente => tarifa NULL
                    } else {
                        estado = "cancelada";
                        double valorTarifa = 45.0 + (random.nextDouble() * 455.0);
                        tarifa = BigDecimal.valueOf(valorTarifa).setScale(2, RoundingMode.HALF_UP);
                    }

                    ps.setInt(1, idHuesped);
                    ps.setInt(2, idHabitacion);
                    ps.setDate(3, Date.valueOf(fechaInicio));
                    ps.setDate(4, Date.valueOf(fechaSalida));
                    if (tarifa != null) {
                        ps.setBigDecimal(5, tarifa);
                    } else {
                        ps.setNull(5, java.sql.Types.DECIMAL);
                    }
                    ps.setString(6, estado);

                    ps.addBatch();
                    contador++;

                    if (contador % BATCH_SIZE == 0) {
                        ps.executeBatch();
                        conn.commit();
                        
                        if (contador % 500_000 == 0) {
                            long parcialMs = System.currentTimeMillis() - tiempoInicio;
                            double seg = parcialMs / 1000.0;
                            double tasa = contador / seg;
                            System.out.printf("-> Insertados %,d / %,d registros (%.2f seg | %.0f reg/seg)%n",
                                    contador, TOTAL_REGISTROS, seg, tasa);
                        }
                    }
                }

                // Ejecutar lote remanente si existiera
                if (contador % BATCH_SIZE != 0) {
                    ps.executeBatch();
                    conn.commit();
                }

                long tiempoTotalMs = System.currentTimeMillis() - tiempoInicio;
                double tiempoTotalSeg = tiempoTotalMs / 1000.0;
                System.out.println("=================================================================");
                System.out.printf("CARGA MASIVA FINALIZADA CON ÉXITO: %,d registros en %.2f segundos.%n", 
                        TOTAL_REGISTROS, tiempoTotalSeg);
                System.out.printf("Rendimiento promedio: %.0f inserciones/segundo.%n", 
                        TOTAL_REGISTROS / tiempoTotalSeg);
                System.out.println("=================================================================");

            } catch (Exception ex) {
                conn.rollback();
                throw ex;
            }

        } catch (Exception e) {
            System.err.println("Error durante la carga masiva: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
