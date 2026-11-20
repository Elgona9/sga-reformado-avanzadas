package co.edu.udistrital.sga.repository;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import co.edu.udistrital.sga.model.Grupo;
import co.edu.udistrital.sga.model.GrupoResumen;
import co.edu.udistrital.sga.model.HorarioGrupo;

/** Acceso a las tablas grupo y horario_grupo con JdbcTemplate (SQL escrito a mano, sin ORM). */
@Repository
public class GrupoRepository {

    // Columnas de la tabla grupo, usadas para el detalle (GET por id) y el PUT.
    private static final String COLUMNAS_GRUPO =
            "id_grupo, id_asignatura, id_docente, id_periodo, id_espacio, numero, cupo_maximo, "
            + "estado, fecha_inicio_inscripcion, fecha_fin_inscripcion";

    // El grupo se lee sin horarios; la lista se consulta aparte y se arma en Java.
    private static final RowMapper<Grupo> MAPEADOR_GRUPO = (rs, fila) -> new Grupo(
            rs.getInt("id_grupo"),
            rs.getInt("id_asignatura"),
            rs.getInt("id_docente"),
            rs.getInt("id_periodo"),
            rs.getInt("id_espacio"),
            rs.getInt("numero"),
            rs.getInt("cupo_maximo"),
            rs.getString("estado"),
            rs.getObject("fecha_inicio_inscripcion", java.time.LocalDate.class),
            rs.getObject("fecha_fin_inscripcion", java.time.LocalDate.class),
            null);

    private static final RowMapper<HorarioGrupo> MAPEADOR_HORARIO = (rs, fila) -> new HorarioGrupo(
            rs.getInt("id_horario"),
            rs.getInt("dia_semana"),
            rs.getObject("hora_inicio", java.time.LocalTime.class),
            rs.getObject("hora_fin", java.time.LocalTime.class));

    // Fila del listado: la vista vw_cupos_grupo unida con grupo por id_grupo para
    // traer los ids y las fechas, que la vista no expone.
    private static final RowMapper<GrupoResumen> MAPEADOR_RESUMEN = (rs, fila) -> new GrupoResumen(
            rs.getInt("id_grupo"),
            rs.getInt("id_asignatura"),
            rs.getInt("id_docente"),
            rs.getInt("id_periodo"),
            rs.getInt("id_espacio"),
            rs.getString("asignatura_codigo"),
            rs.getString("asignatura_nombre"),
            rs.getInt("numero"),
            rs.getString("periodo_codigo"),
            rs.getString("docente"),
            rs.getString("espacio_codigo"),
            rs.getString("estado"),
            rs.getInt("cupo_maximo"),
            rs.getInt("inscritos"),
            rs.getInt("cupos_disponibles"),
            rs.getDouble("porcentaje_ocupacion"),
            rs.getBoolean("inscripcion_vigente"),
            rs.getObject("fecha_inicio_inscripcion", java.time.LocalDate.class),
            rs.getObject("fecha_fin_inscripcion", java.time.LocalDate.class));

    private final JdbcTemplate jdbc;

    public GrupoRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Lista los grupos desde la vista vw_cupos_grupo unida con grupo por id_grupo.
     * Los filtros son opcionales: el WHERE se arma de forma dinámica según los
     * parámetros recibidos, para no pasar nulos sin tipo a JdbcTemplate (PostgreSQL
     * no deduce el tipo de un parámetro nulo con "? IS NULL OR ...").
     */
    public List<GrupoResumen> listar(Integer idPeriodo, Integer idAsignatura) {
        StringBuilder sql = new StringBuilder(
                "SELECT g.id_grupo, g.id_asignatura, g.id_docente, g.id_periodo, g.id_espacio, "
                + "v.asignatura_codigo, v.asignatura_nombre, v.numero, v.periodo_codigo, v.docente, "
                + "v.espacio_codigo, v.estado, v.cupo_maximo, v.inscritos, v.cupos_disponibles, "
                + "v.porcentaje_ocupacion, v.inscripcion_vigente, "
                + "g.fecha_inicio_inscripcion, g.fecha_fin_inscripcion "
                + "FROM vw_cupos_grupo v JOIN grupo g ON g.id_grupo = v.id_grupo");

        List<Object> parametros = new ArrayList<>();
        List<String> condiciones = new ArrayList<>();
        if (idPeriodo != null) {
            condiciones.add("g.id_periodo = ?");
            parametros.add(idPeriodo);
        }
        if (idAsignatura != null) {
            condiciones.add("g.id_asignatura = ?");
            parametros.add(idAsignatura);
        }
        if (!condiciones.isEmpty()) {
            sql.append(" WHERE ").append(String.join(" AND ", condiciones));
        }
        sql.append(" ORDER BY v.periodo_codigo, v.asignatura_codigo, v.numero");

        return jdbc.query(sql.toString(), MAPEADOR_RESUMEN, parametros.toArray());
    }

    /**
     * Devuelve el grupo con su lista de horarios, o vacío si no existe.
     * Hace dos consultas (grupo y horarios); readOnly = true las agrupa en una
     * sola transacción de solo lectura para que vean un estado consistente.
     */
    @Transactional(readOnly = true)
    public Optional<Grupo> buscarPorId(int id) {
        Optional<Grupo> grupo = jdbc.query(
                "SELECT " + COLUMNAS_GRUPO + " FROM grupo WHERE id_grupo = ?", MAPEADOR_GRUPO, id)
                .stream().findFirst();
        if (grupo.isEmpty()) {
            return Optional.empty();
        }
        List<HorarioGrupo> horarios = listarHorarios(id);
        Grupo g = grupo.get();
        return Optional.of(new Grupo(
                g.idGrupo(), g.idAsignatura(), g.idDocente(), g.idPeriodo(), g.idEspacio(),
                g.numero(), g.cupoMaximo(), g.estado(),
                g.fechaInicioInscripcion(), g.fechaFinInscripcion(), horarios));
    }

    /** Horarios de un grupo, ordenados por día y hora de inicio (para el detalle y el PUT). */
    private List<HorarioGrupo> listarHorarios(int idGrupo) {
        return jdbc.query(
                "SELECT id_horario, dia_semana, hora_inicio, hora_fin FROM horario_grupo "
                        + "WHERE id_grupo = ? ORDER BY dia_semana, hora_inicio",
                MAPEADOR_HORARIO, idGrupo);
    }

    /** @return true si el grupo existe (para distinguir 404 de 409 antes de actualizar o borrar). */
    public boolean existe(int id) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM grupo WHERE id_grupo = ?", Integer.class, id);
        return n != null && n > 0;
    }

    /**
     * Reemplaza el grupo y toda su lista de horarios en una sola transacción.
     * Pasos: (1) fijar app.id_usuario si llega la cabecera, (2) UPDATE del grupo,
     * (3) borrar los horarios actuales, (4) insertar los nuevos.
     *
     * @Transactional es imprescindible: set_config(..., true) solo vale dentro de
     * la misma transacción y conexión, así que el cambio de estado (RNF-05) y los
     * INSERT de horarios deben compartir transacción con el set_config. Además, si
     * un trigger falla (RN-15/RN-16 traslape, RN-30 esquema incompleto) toda la
     * operación revierte y el grupo y sus horarios quedan como estaban.
     *
     * Triggers que puede disparar: RN-15/RN-16 (traslape de docente o espacio al
     * cambiar docente/periodo/espacio y al insertar horarios), RN-30 (BEFORE
     * UPDATE OF estado hacia EnCurso/Finalizado) y RNF-05 (AFTER UPDATE OF estado:
     * registra CAMBIO_ESTADO en bitacora con app.id_usuario).
     *
     * @return true si el grupo existía y se actualizó.
     */
    @Transactional
    public boolean actualizar(int id, Grupo g, Integer idUsuarioAuditoria) {
        if (!existe(id)) {
            return false;
        }
        // Auditoría: fija app.id_usuario en la transacción actual para que el
        // trigger RNF-05 lo lea. El tercer parámetro true limita el valor a esta
        // transacción (is_local), por eso debe ir dentro de @Transactional.
        if (idUsuarioAuditoria != null) {
            jdbc.queryForObject("SELECT set_config('app.id_usuario', ?, true)",
                    String.class, String.valueOf(idUsuarioAuditoria));
        }

        jdbc.update(
                "UPDATE grupo SET id_asignatura = ?, id_docente = ?, id_periodo = ?, id_espacio = ?, "
                        + "numero = ?, cupo_maximo = ?, estado = ?, "
                        + "fecha_inicio_inscripcion = ?, fecha_fin_inscripcion = ? WHERE id_grupo = ?",
                g.idAsignatura(), g.idDocente(), g.idPeriodo(), g.idEspacio(),
                g.numero(), g.cupoMaximo(), g.estado(),
                g.fechaInicioInscripcion(), g.fechaFinInscripcion(), id);

        // Reemplazo completo de los horarios: borrar los actuales e insertar los
        // nuevos. Cada INSERT dispara RN-15/RN-16 (traslape de docente y espacio).
        jdbc.update("DELETE FROM horario_grupo WHERE id_grupo = ?", id);
        for (HorarioGrupo h : g.horarios()) {
            jdbc.update(
                    "INSERT INTO horario_grupo (id_grupo, dia_semana, hora_inicio, hora_fin) "
                            + "VALUES (?, ?, ?, ?)",
                    id, h.diaSemana(), h.horaInicio(), h.horaFin());
        }
        return true;
    }

    /**
     * Elimina un grupo. Sus horarios y su esquema_evaluacion se borran en cascada
     * (ON DELETE CASCADE). Si el grupo tiene inscripciones, la FK con ON DELETE
     * RESTRICT lo impide y la base lanza una violación 23503, que el manejador
     * traduce a 409.
     *
     * @return true si el grupo existía y se eliminó.
     */
    @Transactional
    public boolean eliminar(int id) {
        return jdbc.update("DELETE FROM grupo WHERE id_grupo = ?", id) > 0;
    }
}
