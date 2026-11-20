package co.edu.udistrital.sga.exception;

/** El recurso pedido no existe. El manejador de errores la convierte en HTTP 404. */
public class RecursoNoEncontradoException extends RuntimeException {

    public RecursoNoEncontradoException(String mensaje) {
        super(mensaje);
    }
}
