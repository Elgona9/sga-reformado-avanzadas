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
import co.edu.udistrital.sga.model.Grupo;
import co.edu.udistrital.sga.model.GrupoNuevo;
import co.edu.udistrital.sga.model.GrupoResumen;
import co.edu.udistrital.sga.model.HorarioGrupo;
import co.edu.udistrital.sga.repository.GrupoRepository;

/**
 * CRUD de grupos academicos con sus horarios.
 *
 * GET    /api/grupos                       200  lista (filtros opcionales idPeriodo, idAsignatura)
 * GET    /api/grupos/{id}                  200  detalle con horarios | 404 si no existe
 * POST   /api/grupos                       201  creado (Location) | 400 datos invalidos o RAISE del procedimiento | 409 restriccion
 * PUT    /api/grupos/{id}                  200  actualizado | 404 | 400 datos invalidos o RAISE de la base | 409 restriccion
 * DELETE /api/grupos/{id}                  204  eliminado | 404 | 409 si tiene inscripciones
 *
 * El POST llama al procedimiento pr_crear_grupo (R3): el numero de grupo lo
 * calcula el procedimiento y no se envia. Cabecera opcional X-Usuario-Id en el
 * PUT: si viene, se audita el cambio de estado en bitacora (RNF-05); si no, NULL.
 */
@RestController
@RequestMapping("/api/grupos")
public class GrupoController {

    private final GrupoRepository repositorio;

    public GrupoController(GrupoRepository repositorio) {
        this.repositorio = repositorio;
    }

    /** Lista los grupos; idPeriodo e idAsignatura filtran de forma opcional. */
    @GetMapping
    public List<GrupoResumen> listar(
            @RequestParam(required = false) Integer idPeriodo,
            @RequestParam(required = false) Integer idAsignatura) {
        return repositorio.listar(idPeriodo, idAsignatura);
    }

    /** Detalle de un grupo con su lista de horarios; 404 si no existe. */
    @GetMapping("/{id}")
    public Grupo obtener(@PathVariable int id) {
        return repositorio.buscarPorId(id).orElseThrow(() -> noExiste(id));
    }

    /**
     * Crea un grupo con el procedimiento pr_crear_grupo. Valida la forma y delega
     * el resto al procedimiento, cuyos RAISE EXCEPTION llegan como 400. Devuelve
     * 201 con Location y el grupo creado, igual que GET /api/grupos/{id}.
     */
    @PostMapping
    public ResponseEntity<Grupo> crear(@RequestBody GrupoNuevo cuerpo) {
        validar(cuerpo);
        int id = repositorio.crear(cuerpo);
        Grupo creado = repositorio.buscarPorId(id).orElseThrow(() -> noExiste(id));
        return ResponseEntity.created(URI.create("/api/grupos/" + id)).body(creado);
    }

    /**
     * Reemplaza el grupo y sus horarios. Valida la forma y delega el resto a la
     * base (restricciones y triggers). Si llega X-Usuario-Id, el cambio de estado
     * se audita (RNF-05). 404 si no existe; 400/409 los produce el manejador.
     */
    @PutMapping("/{id}")
    public Grupo actualizar(
            @PathVariable int id,
            @RequestBody Grupo cuerpo,
            @RequestHeader(value = "X-Usuario-Id", required = false) Integer idUsuario) {
        validar(cuerpo);
        if (!repositorio.actualizar(id, cuerpo, idUsuario)) {
            throw noExiste(id);
        }
        return repositorio.buscarPorId(id).orElseThrow(() -> noExiste(id));
    }

    /** Elimina un grupo; 404 si no existe, 409 si tiene inscripciones (FK RESTRICT). */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable int id) {
        if (!repositorio.existe(id)) {
            throw noExiste(id);
        }
        repositorio.eliminar(id);
        return ResponseEntity.noContent().build();
    }

    private RecursoNoEncontradoException noExiste(int id) {
        return new RecursoNoEncontradoException("El grupo " + id + " no existe");
    }

    /**
     * Validaciones de forma del POST. No se piden numero ni estado: los fija el
     * procedimiento. Las reglas de fondo (decano, facultad, existencia de
     * docente/periodo/espacio, cupo vs. capacidad y traslapes RN-15/RN-16) las
     * aplica pr_crear_grupo y su mensaje llega tal cual (400).
     */
    private void validar(GrupoNuevo g) {
        if (g == null) {
            throw new SolicitudInvalidaException("Debe enviar los datos del grupo");
        }
        if (g.idDecano() == null) {
            throw new SolicitudInvalidaException("El decano (idDecano) es obligatorio");
        }
        if (g.idAsignatura() == null) {
            throw new SolicitudInvalidaException("La asignatura (idAsignatura) es obligatoria");
        }
        if (g.idDocente() == null) {
            throw new SolicitudInvalidaException("El docente (idDocente) es obligatorio");
        }
        if (g.idPeriodo() == null) {
            throw new SolicitudInvalidaException("El periodo (idPeriodo) es obligatorio");
        }
        if (g.idEspacio() == null) {
            throw new SolicitudInvalidaException("El espacio fisico (idEspacio) es obligatorio");
        }
        if (g.cupoMaximo() == null || g.cupoMaximo() <= 0) {
            throw new SolicitudInvalidaException("El cupo maximo debe ser mayor que cero");
        }
        if (g.fechaInicioInscripcion() == null || g.fechaFinInscripcion() == null) {
            throw new SolicitudInvalidaException("Las fechas de inscripcion son obligatorias");
        }
        if (g.fechaFinInscripcion().isBefore(g.fechaInicioInscripcion())) {
            throw new SolicitudInvalidaException(
                    "La fecha de fin de inscripcion no puede ser anterior a la de inicio");
        }
        if (g.horarios() == null || g.horarios().isEmpty()) {
            throw new SolicitudInvalidaException("El grupo debe tener al menos un horario");
        }
        for (HorarioGrupo h : g.horarios()) {
            validarHorario(h);
        }
    }

    /**
     * Validaciones de forma del cuerpo del PUT. Las reglas de fondo (UNIQUE de
     * numero, FK de docente/espacio, CHECK de estado, traslapes RN-15/RN-16 y
     * esquema completo RN-30) las aplica la base; aqui no se duplican.
     */
    private void validar(Grupo g) {
        if (g == null) {
            throw new SolicitudInvalidaException("Debe enviar los datos del grupo");
        }
        if (g.idAsignatura() == null) {
            throw new SolicitudInvalidaException("La asignatura (idAsignatura) es obligatoria");
        }
        if (g.idDocente() == null) {
            throw new SolicitudInvalidaException("El docente (idDocente) es obligatorio");
        }
        if (g.idPeriodo() == null) {
            throw new SolicitudInvalidaException("El periodo (idPeriodo) es obligatorio");
        }
        if (g.idEspacio() == null) {
            throw new SolicitudInvalidaException("El espacio fisico (idEspacio) es obligatorio");
        }
        if (g.numero() == null || g.numero() <= 0) {
            throw new SolicitudInvalidaException("El numero del grupo debe ser mayor que cero");
        }
        if (g.cupoMaximo() == null || g.cupoMaximo() <= 0) {
            throw new SolicitudInvalidaException("El cupo maximo debe ser mayor que cero");
        }
        if (g.estado() == null || g.estado().isBlank()) {
            throw new SolicitudInvalidaException("El estado del grupo es obligatorio");
        }
        if (g.fechaInicioInscripcion() == null || g.fechaFinInscripcion() == null) {
            throw new SolicitudInvalidaException("Las fechas de inscripcion son obligatorias");
        }
        if (g.horarios() == null || g.horarios().isEmpty()) {
            throw new SolicitudInvalidaException("El grupo debe tener al menos un horario");
        }
        for (HorarioGrupo h : g.horarios()) {
            validarHorario(h);
        }
    }

    /** Valida la forma de un bloque de horario: dia 1..7 y hora fin posterior a inicio. */
    private void validarHorario(HorarioGrupo h) {
        if (h == null) {
            throw new SolicitudInvalidaException("Hay un horario vacio en la lista");
        }
        if (h.diaSemana() == null || h.diaSemana() < 1 || h.diaSemana() > 7) {
            throw new SolicitudInvalidaException("El dia de cada horario debe estar entre 1 y 7");
        }
        if (h.horaInicio() == null || h.horaFin() == null) {
            throw new SolicitudInvalidaException("Cada horario debe tener hora de inicio y de fin");
        }
        if (!h.horaFin().isAfter(h.horaInicio())) {
            throw new SolicitudInvalidaException("La hora de fin debe ser posterior a la de inicio");
        }
    }
}