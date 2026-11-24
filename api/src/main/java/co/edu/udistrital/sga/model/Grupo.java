package co.edu.udistrital.sga.model;

import java.time.LocalDate;
import java.util.List;

/**
 * Grupo académico (tabla grupo) con su lista de horarios. Se usa tanto para
 * leer de la base (GET por id) como para recibir el JSON del PUT.
 *
 * El campo horarios solo se llena en el detalle y en el cuerpo del PUT; en el
 * listado se usa el record GrupoResumen.
 */
public record Grupo(
        Integer idGrupo,
        Integer idAsignatura,
        Integer idDocente,
        Integer idPeriodo,
        Integer idEspacio,
        Integer numero,
        Integer cupoMaximo,
        String estado,
        LocalDate fechaInicioInscripcion,
        LocalDate fechaFinInscripcion,
        List<HorarioGrupo> horarios) {
}
