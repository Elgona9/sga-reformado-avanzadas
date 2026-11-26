package co.edu.udistrital.sga.repository;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import co.edu.udistrital.sga.model.Calificacion;

/** Acceso a la tabla calificacion con JdbcTemplate (SQL escrito a mano, sin ORM). */
@Repository
public class CalificacionRepository {

    private static final String COLUMNAS =
            "id_calificacion, id_inscripcion, id_tipo_evaluacion, nota, fecha_registro";

    private static final RowMapper<Calificacion> MAPEADOR = (rs, fila) -> new Calificacion(
            rs.getInt("id_calificacion"),
            rs.getInt("id_inscripcion"),
            rs.getInt("id_tipo_evaluacion"),
            rs.getBigDecimal("nota"),
            rs.getObject("fecha_registro", java.time.LocalDateTime.class));

    private final JdbcTemplate jdbc;

    public CalificacionRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Lista las calificaciones. Los filtros son opcionales y el WHERE se arma de
     * forma dinamica (no se pasan nulos sin tipo a JdbcTemplate). El filtro por
     * idGrupo une con inscripcion, ya que calificacion no guarda el grupo.
     */
    public List<Calificacion> listar(Integer idInscripcion, Integer idGrupo) {
        StringBuilder sql = new StringBuilder(
                "SELECT c.id_calificacion, c.id_inscripcion, c.id_tipo_evaluacion, c.nota, c.fecha_registro "
                + "FROM calificacion c");
        List<Object> parametros = new ArrayList<>();
        List<String> condiciones = new ArrayList<>();
        if (idGrupo != null) {
            sql.append(" JOIN inscripcion i ON i.id_inscripcion = c.id_inscripcion");
            condiciones.add("i.id_grupo = ?");
            parametros.add(idGrupo);
        }
        if (idInscripcion != null) {
            condiciones.add("c.id_inscripcion = ?");
            parametros.add(idInscripcion);
        }
        if (!condiciones.isEmpty()) {
            sql.append(" WHERE ").append(String.join(" AND ", condiciones));
        }
        sql.append(" ORDER BY c.id_calificacion");
        return jdbc.query(sql.toString(), MAPEADOR, parametros.toArray());
    }

    /** Devuelve la calificacion por id, o vacio si no existe (para 404). */
    public Optional<Calificacion> buscarPorId(int id) {
        return jdbc.query("SELECT " + COLUMNAS + " FROM calificacion WHERE id_calificacion = ?", MAPEADOR, id)
                .stream().findFirst();
    }

    /** @return true si la calificacion existe (para distinguir 404 antes de PUT o DELETE). */
    public boolean existe(int id) {
        Integer n = jdbc.queryForObject(
                "SELECT COUNT(*) FROM calificacion WHERE id_calificacion = ?", Integer.class, id);
        return n != null && n > 0;
    }

    /**
     * Crea una calificacion. Antes del INSERT fija app.id_usuario si llega la
     * cabecera, para que el trigger AFTER RN-26 audite la accion CREAR con ese
     * usuario. Los triggers BEFORE RN-24 (inscripcion en estado Inscrito) y RN-31
     * (tipo dentro del esquema del grupo) validan y, si fallan, revierten.
     *
     * @Transactional: set_config(..., true) solo vive en esta transaccion y
     * conexion, asi que debe compartir transaccion con el INSERT; si la auditoria
     * falla (usuario inexistente), toda la operacion se deshace.
     *
     * @return id de la calificacion creada (RETURNING).
     */
    @Transactional
    public int crear(Calificacion c, Integer idUsuarioAuditoria) {
        fijarUsuarioAuditoria(idUsuarioAuditoria);
        Integer id = jdbc.queryForObject(
                "INSERT INTO calificacion (id_inscripcion, id_tipo_evaluacion, nota) "
                        + "VALUES (?, ?, ?) RETURNING id_calificacion",
                Integer.class, c.idInscripcion(), c.idTipoEvaluacion(), c.nota());
        return id;
    }

    /**
     * Reemplaza inscripcion, tipo y nota de una calificacion; fecha_registro no se
     * toca. Fija app.id_usuario antes del UPDATE para la auditoria RN-26 (accion
     * MODIFICAR). Un UPDATE que no cambia nada no se audita. Los triggers RN-24 y
     * RN-31 vuelven a validar.
     *
     * @return true si la calificacion existia y se actualizo.
     */
    @Transactional
    public boolean actualizar(int id, Calificacion c, Integer idUsuarioAuditoria) {
        if (!existe(id)) {
            return false;
        }
        fijarUsuarioAuditoria(idUsuarioAuditoria);
        jdbc.update(
                "UPDATE calificacion SET id_inscripcion = ?, id_tipo_evaluacion = ?, nota = ? "
                        + "WHERE id_calificacion = ?",
                c.idInscripcion(), c.idTipoEvaluacion(), c.nota(), id);
        return true;
    }

    /**
     * Elimina una calificacion. Fija app.id_usuario antes del DELETE para que la
     * auditoria RN-26 (accion ELIMINAR) registre el usuario; sin cabecera queda
     * NULL en la bitacora.
     *
     * @return true si la calificacion existia y se elimino.
     */
    @Transactional
    public boolean eliminar(int id, Integer idUsuarioAuditoria) {
        if (!existe(id)) {
            return false;
        }
        fijarUsuarioAuditoria(idUsuarioAuditoria);
        jdbc.update("DELETE FROM calificacion WHERE id_calificacion = ?", id);
        return true;
    }

    /**
     * Fija app.id_usuario en la transaccion actual (tercer parametro true = solo
     * esta transaccion y conexion) para que el trigger AFTER RN-26 lo lea. Si no
     * llega la cabecera no se fija y la bitacora queda con id_usuario NULL.
     */
    private void fijarUsuarioAuditoria(Integer idUsuario) {
        if (idUsuario != null) {
            jdbc.queryForObject("SELECT set_config('app.id_usuario', ?, true)",
                    String.class, String.valueOf(idUsuario));
        }
    }
}