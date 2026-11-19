package co.edu.udistrital.sga.exception;

import java.sql.SQLException;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * Manejador global de errores: traduce excepciones a códigos HTTP y a un cuerpo
 * JSON uniforme {"error": "mensaje"}.
 *
 *   RecursoNoEncontradoException ................ 404
 *   SolicitudInvalidaException / JSON ilegible .. 400
 *   Violación de restricción (SQLState 23xxx) ... 409  (UNIQUE, FK, CHECK, NOT NULL)
 *   RAISE EXCEPTION de la base (SQLState P0001) . 400  (regla de negocio: se muestra su mensaje)
 *   Cualquier otro error ........................ 500
 */
@RestControllerAdvice
public class ManejadorErrores {

    private static final Logger LOG = LoggerFactory.getLogger(ManejadorErrores.class);

    @ExceptionHandler(RecursoNoEncontradoException.class)
    public ResponseEntity<Map<String, String>> noEncontrado(RecursoNoEncontradoException e) {
        return responder(HttpStatus.NOT_FOUND, e.getMessage());
    }

    @ExceptionHandler(SolicitudInvalidaException.class)
    public ResponseEntity<Map<String, String>> solicitudInvalida(SolicitudInvalidaException e) {
        return responder(HttpStatus.BAD_REQUEST, e.getMessage());
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<Map<String, String>> jsonIlegible(HttpMessageNotReadableException e) {
        return responder(HttpStatus.BAD_REQUEST, "El cuerpo de la solicitud no es un JSON válido");
    }

    /** UNIQUE, llave foránea, CHECK o NOT NULL violados: conflicto con el estado de los datos. */
    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<Map<String, String>> violacionDeRestriccion(DataIntegrityViolationException e) {
        return responder(HttpStatus.CONFLICT, mensajeDeLaBase(e));
    }

    /** Errores de la base: un RAISE EXCEPTION (P0001) es una regla de negocio; el resto es un fallo interno. */
    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<Map<String, String>> errorDeBaseDeDatos(DataAccessException e) {
        if ("P0001".equals(sqlState(e))) {
            return responder(HttpStatus.BAD_REQUEST, mensajeDeLaBase(e));
        }
        LOG.error("Error de acceso a datos", e);
        return responder(HttpStatus.INTERNAL_SERVER_ERROR, "Error interno al acceder a la base de datos");
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, String>> inesperado(Exception e) {
        LOG.error("Error no controlado", e);
        return responder(HttpStatus.INTERNAL_SERVER_ERROR, "Error interno del servidor");
    }

    private ResponseEntity<Map<String, String>> responder(HttpStatus estado, String mensaje) {
        return ResponseEntity.status(estado).body(Map.of("error", mensaje));
    }

    /** Busca en la cadena de causas el SQLException y devuelve su SQLState (p. ej. "23505", "P0001"). */
    private String sqlState(Throwable e) {
        for (Throwable t = e; t != null; t = t.getCause()) {
            if (t instanceof SQLException sql) {
                return sql.getSQLState();
            }
        }
        return null;
    }

    /**
     * Extrae un mensaje legible del error de PostgreSQL: la primera línea sin el
     * prefijo "ERROR:" y, si existe, la línea de detalle ("Detail:" / "Detalle:").
     */
    private String mensajeDeLaBase(Throwable e) {
        for (Throwable t = e; t != null; t = t.getCause()) {
            if (t instanceof SQLException sql && sql.getMessage() != null) {
                String[] lineas = sql.getMessage().split("\\R");
                StringBuilder mensaje = new StringBuilder(lineas[0].replaceFirst("^ERROR:\\s*", "").trim());
                for (String linea : lineas) {
                    String l = linea.trim();
                    if (l.startsWith("Detail:") || l.startsWith("Detalle:")) {
                        mensaje.append(" ").append(l);
                    }
                }
                return mensaje.toString();
            }
        }
        return "Operación rechazada por la base de datos";
    }
}
