package co.edu.udistrital.sga.exception;

/** Los datos enviados no son válidos. El manejador de errores la convierte en HTTP 400. */
public class SolicitudInvalidaException extends RuntimeException {

    public SolicitudInvalidaException(String mensaje) {
        super(mensaje);
    }
}
