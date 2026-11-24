package co.edu.udistrital.sga.model;

import java.time.LocalDate;
import java.util.List;

/**
 * Cuerpo del POST /api/grupos. Lo recibe el procedimiento pr_crear_grupo.
 *
 * No incluye numero ni estado: el número lo calcula el procedimiento como
 * consecutivo dentro de (asignatura, periodo) y el estado queda 'Abierto'. Si el
 * cliente los envía, Jackson los ignora por no estar en el record. idDecano viaja
 * en el cuerpo porque el procedimiento valida la facultad del decano y lo audita.
 */
public record GrupoNuevo(
        Integer idDecano,
        Integer idAsignatura,
        Integer idDocente,
        Integer idPeriodo,
        Integer idEspacio,
        Integer cupoMaximo,
        LocalDate fechaInicioInscripcion,
        LocalDate fechaFinInscripcion,
        List<HorarioGrupo> horarios) {
}