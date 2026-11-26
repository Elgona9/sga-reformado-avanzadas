package co.edu.udistrital.sga.controller;

import java.net.URI;
import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import co.edu.udistrital.sga.exception.RecursoNoEncontradoException;
import co.edu.udistrital.sga.exception.SolicitudInvalidaException;
import co.edu.udistrital.sga.model.Calificacion;
import co.edu.udistrital.sga.repository.CalificacionRepository;

/**
 * CRUD de calificaciones. En las escrituras, si llega la cabecera opcional
 * X-Usuario-Id, se fija app.id_usuario en la misma transaccion para que el
 * trigger AFTER RN-26 audite la accion con ese usuario; sin cabecera, la
 * bitacora queda con id_usuario NULL.
 *
 * GET    /api/calificaciones            200  lista (filtros opcionales idInscripcion, idGrupo)
 * GET    /api/calificaciones/{id}       200  detalle | 404 si no existe
 * POST   /api/calificaciones            201  creada (Location) | 400 datos invalidos o RAISE de la base | 409 restriccion
 * PUT    /api/calificaciones/{id}       200  actualizada | 404 | 400 | 409
 * DELETE /api/calificaciones/{id}       204  eliminada | 404
 *
 * Reglas de fondo en la base: RN-24 (inscripcion Inscrito) y RN-31 (tipo del
 * esquema) son RAISE EXCEPTION -> 400; CHECK de nota (RN-23), UNIQUE (RN-25) y
 * FK -> 409. El controlador solo valida la forma.
 */
@RestController
@RequestMapping("/api/calificaciones")
public class CalificacionController {

    private final CalificacionRepository repositorio;

    public CalificacionController(CalificacionRepository repositorio) {
        this.repositorio = repositorio;
    }

    /** Lista las calificaciones; idInscripcion e idGrupo filtran de forma opcional. */
    @GetMapping
    public List<Calificacion> listar(
            @RequestParam(required = false) Integer idInscripcion,
            @RequestParam(required = false) Integer idGrupo) {
        return repositorio.listar(idInscripcion, idGrupo);
    }

    /** Detalle de una calificacion; 404 si no existe. */
    @GetMapping("/{id}")
    public Calificacion obtener(@PathVariable int id) {
        return repositorio.buscarPorId(id).orElseThrow(() -> noExiste(id));
    }

    /**
     * Crea una calificacion. Valida la forma y delega el resto a la base (triggers
     * RN-24/RN-31 -> 400; CHECK/UNIQUE/FK -> 409). Si llega X-Usuario-Id, la
     * creacion se audita (RN-26) con ese usuario. Devuelve 201 con Location.
     */
    @PostMapping
    public ResponseEntity<Calificacion> crear(
            @RequestBody Calificacion cuerpo,
            @RequestHeader(value = "X-Usuario-Id", required = false) String usuario) {
        validar(cuerpo);
        Integer idUsuario = usuarioAuditoria(usuario);
        int id = repositorio.crear(cuerpo, idUsuario);
        Calificacion creada = repositorio.buscarPorId(id).orElseThrow(() -> noExiste(id));
        return ResponseEntity.created(URI.create("/api/calificaciones/" + id)).body(creada);
    }

    /**
     * Reemplaza inscripcion, tipo y nota de una calificacion (fecha_registro no se
     * toca). 404 si no existe; 400/409 los produce el manejador. Si llega
     * X-Usuario-Id, la modificacion se audita (RN-26) con ese usuario.
     */
    @PutMapping("/{id}")
    public Calificacion actualizar(
            @PathVariable int id,
            @RequestBody Calificacion cuerpo,
            @RequestHeader(value = "X-Usuario-Id", required = false) String usuario) {
        validar(cuerpo);
        Integer idUsuario = usuarioAuditoria(usuario);
        if (!repositorio.actualizar(id, cuerpo, idUsuario)) {
            throw noExiste(id);
        }
        return repositorio.buscarPorId(id).orElseThrow(() -> noExiste(id));
    }

    /** Elimina una calificacion; 404 si no existe. Si llega X-Usuario-Id, se audita (RN-26). */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(
            @PathVariable int id,
            @RequestHeader(value = "X-Usuario-Id", required = false) String usuario) {
        Integer idUsuario = usuarioAuditoria(usuario);
        if (!repositorio.eliminar(id, idUsuario)) {
            throw noExiste(id);
        }
        return ResponseEntity.noContent().build();
    }

    private RecursoNoEncontradoException noExiste(int id) {
        return new RecursoNoEncontradoException("La calificacion " + id + " no existe");
    }

    /**
     * Convierte la cabecera X-Usuario-Id a entero. Es opcional: si no viene,
     * devuelve null (la bitacora quedara con id_usuario NULL). Si viene pero no es
     * un entero, es un 400.
     */
    private Integer usuarioAuditoria(String usuario) {
        if (usuario == null || usuario.isBlank()) {
            return null;
        }
        try {
            return Integer.valueOf(usuario.trim());
        } catch (NumberFormatException e) {
            throw new SolicitudInvalidaException("La cabecera X-Usuario-Id debe ser un numero entero");
        }
    }

    /**
     * Validaciones de forma del cuerpo. El rango de la nota no se valida aqui: lo
     * hace cumplir la base (CHECK RN-23 -> 409), igual que el resto de reglas.
     */
    private void validar(Calificacion c) {
        if (c == null) {
            throw new SolicitudInvalidaException("Debe enviar los datos de la calificacion");
        }
        if (c.idInscripcion() == null) {
            throw new SolicitudInvalidaException("La inscripcion (idInscripcion) es obligatoria");
        }
        if (c.idTipoEvaluacion() == null) {
            throw new SolicitudInvalidaException("El tipo de evaluacion (idTipoEvaluacion) es obligatorio");
        }
        if (c.nota() == null) {
            throw new SolicitudInvalidaException("La nota es obligatoria");
        }
    }
}