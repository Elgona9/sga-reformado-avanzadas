package co.edu.udistrital.sga.model;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * Calificacion de una inscripcion (tabla calificacion). Se usa para leer y para
 * recibir el JSON del POST y el PUT. fechaRegistro es de solo lectura: la fija
 * la base y se ignora al recibir el cuerpo.
 */
public record Calificacion(
        Integer id,
        Integer idInscripcion,
        Integer idTipoEvaluacion,
        BigDecimal nota,
        LocalDateTime fechaRegistro) {
}