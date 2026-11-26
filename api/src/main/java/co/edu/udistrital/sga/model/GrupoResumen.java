package co.edu.udistrital.sga.model;

import java.time.LocalDate;

/**
 * Fila del listado de grupos (GET /api/grupos). Combina las columnas de la
 * vista vw_cupos_grupo (asignatura, periodo, docente, espacio y conteos de
 * ocupación) con los ids y las fechas tomados de la tabla grupo.
 *
 * Es de solo lectura: no se recibe en ninguna petición, únicamente se devuelve.
 */
public record GrupoResumen(
        Integer idGrupo,
        Integer idAsignatura,
        Integer idDocente,
        Integer idPeriodo,
        Integer idEspacio,
        String asignaturaCodigo,
        String asignaturaNombre,
        Integer numero,
        String periodoCodigo,
        String docente,
        String espacioCodigo,
        String estado,
        Integer cupoMaximo,
        Integer inscritos,
        Integer cuposDisponibles,
        Double porcentajeOcupacion,
        Boolean inscripcionVigente,
        LocalDate fechaInicioInscripcion,
        LocalDate fechaFinInscripcion) {
}
