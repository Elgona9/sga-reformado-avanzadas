package co.edu.udistrital.sga.model;

/**
 * Asignatura del catálogo. Se usa tanto para leer de la base como para recibir
 * el JSON de las peticiones POST y PUT.
 */
public record Asignatura(
        Integer id,
        String codigo,
        String nombre,
        Integer creditos,
        Integer idDepartamento) {
}
