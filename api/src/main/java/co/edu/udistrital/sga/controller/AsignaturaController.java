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
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import co.edu.udistrital.sga.exception.RecursoNoEncontradoException;
import co.edu.udistrital.sga.exception.SolicitudInvalidaException;
import co.edu.udistrital.sga.model.Asignatura;
import co.edu.udistrital.sga.repository.AsignaturaRepository;

/**
 * CRUD de asignaturas.
 *
 * GET    /api/asignaturas        200  lista
 * GET    /api/asignaturas/{id}   200  detalle | 404 si no existe
 * POST   /api/asignaturas        201  creada  | 400 datos inválidos | 409 código repetido o FK inválida
 * PUT    /api/asignaturas/{id}   200  actualizada | 404 | 400 | 409
 * DELETE /api/asignaturas/{id}   204  eliminada | 404 | 409 si tiene grupos asociados
 */
@RestController
@RequestMapping("/api/asignaturas")
public class AsignaturaController {

    private final AsignaturaRepository repositorio;

    public AsignaturaController(AsignaturaRepository repositorio) {
        this.repositorio = repositorio;
    }

    @GetMapping
    public List<Asignatura> listar() {
        return repositorio.listar();
    }

    @GetMapping("/{id}")
    public Asignatura obtener(@PathVariable int id) {
        return repositorio.buscarPorId(id).orElseThrow(() -> noExiste(id));
    }

    @PostMapping
    public ResponseEntity<Asignatura> crear(@RequestBody Asignatura cuerpo) {
        validar(cuerpo);
        int id = repositorio.crear(cuerpo);
        Asignatura creada = repositorio.buscarPorId(id).orElseThrow(() -> noExiste(id));
        return ResponseEntity.created(URI.create("/api/asignaturas/" + id)).body(creada);
    }

    @PutMapping("/{id}")
    public Asignatura actualizar(@PathVariable int id, @RequestBody Asignatura cuerpo) {
        validar(cuerpo);
        if (!repositorio.actualizar(id, cuerpo)) {
            throw noExiste(id);
        }
        return repositorio.buscarPorId(id).orElseThrow(() -> noExiste(id));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable int id) {
        if (!repositorio.eliminar(id)) {
            throw noExiste(id);
        }
        return ResponseEntity.noContent().build();
    }

    private RecursoNoEncontradoException noExiste(int id) {
        return new RecursoNoEncontradoException("La asignatura " + id + " no existe");
    }

    /** Validaciones básicas de forma; las reglas de fondo (UNIQUE, FK, CHECK) las aplica la base. */
    private void validar(Asignatura a) {
        if (a == null) {
            throw new SolicitudInvalidaException("Debe enviar los datos de la asignatura");
        }
        if (a.codigo() == null || a.codigo().isBlank()) {
            throw new SolicitudInvalidaException("El código de la asignatura es obligatorio");
        }
        if (a.nombre() == null || a.nombre().isBlank()) {
            throw new SolicitudInvalidaException("El nombre de la asignatura es obligatorio");
        }
        if (a.creditos() == null || a.creditos() <= 0) {
            throw new SolicitudInvalidaException("Los créditos deben ser un número mayor que cero");
        }
        if (a.idDepartamento() == null) {
            throw new SolicitudInvalidaException("El departamento (idDepartamento) es obligatorio");
        }
    }
}
