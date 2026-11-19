package co.edu.udistrital.sga.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import co.edu.udistrital.sga.model.Asignatura;

/** Acceso a la tabla asignatura con JdbcTemplate (SQL escrito a mano, sin ORM). */
@Repository
public class AsignaturaRepository {

    private static final String COLUMNAS = "id_asignatura, codigo, nombre, creditos, id_departamento";

    private static final RowMapper<Asignatura> MAPEADOR = (rs, fila) -> new Asignatura(
            rs.getInt("id_asignatura"),
            rs.getString("codigo"),
            rs.getString("nombre"),
            rs.getInt("creditos"),
            rs.getInt("id_departamento"));

    private final JdbcTemplate jdbc;

    public AsignaturaRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<Asignatura> listar() {
        return jdbc.query("SELECT " + COLUMNAS + " FROM asignatura ORDER BY codigo", MAPEADOR);
    }

    public Optional<Asignatura> buscarPorId(int id) {
        return jdbc.query("SELECT " + COLUMNAS + " FROM asignatura WHERE id_asignatura = ?", MAPEADOR, id)
                .stream().findFirst();
    }

    /** Inserta y devuelve el id generado por la base (RETURNING). */
    public int crear(Asignatura a) {
        Integer id = jdbc.queryForObject(
                "INSERT INTO asignatura (codigo, nombre, creditos, id_departamento) "
                        + "VALUES (?, ?, ?, ?) RETURNING id_asignatura",
                Integer.class,
                a.codigo(), a.nombre(), a.creditos(), a.idDepartamento());
        return id;
    }

    /** @return true si la asignatura existía y se actualizó */
    public boolean actualizar(int id, Asignatura a) {
        return jdbc.update(
                "UPDATE asignatura SET codigo = ?, nombre = ?, creditos = ?, id_departamento = ? "
                        + "WHERE id_asignatura = ?",
                a.codigo(), a.nombre(), a.creditos(), a.idDepartamento(), id) > 0;
    }

    /** @return true si la asignatura existía y se eliminó */
    public boolean eliminar(int id) {
        return jdbc.update("DELETE FROM asignatura WHERE id_asignatura = ?", id) > 0;
    }
}
