package co.edu.udistrital.sga.model;

import java.time.LocalTime;

/**
 * Bloque de horario de un grupo (tabla horario_grupo). Sirve para leer de la
 * base y para recibir cada horario dentro del JSON del PUT.
 *
 * diaSemana: 1 = lunes ... 7 = domingo. horaInicio y horaFin son horas del día.
 */
public record HorarioGrupo(
        Integer idHorario,
        Integer diaSemana,
        LocalTime horaInicio,
        LocalTime horaFin) {
}
