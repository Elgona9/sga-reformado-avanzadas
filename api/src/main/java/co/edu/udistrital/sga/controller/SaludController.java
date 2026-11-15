package co.edu.udistrital.sga.controller;

import java.util.Map;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class SaludController {

    private final JdbcTemplate jdbc;

    public SaludController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Comprueba que la API llega a PostgreSQL. */
    @GetMapping("/api/salud")
    public Map<String, Object> salud() {
        String base = jdbc.queryForObject("SELECT current_database()", String.class);
        String version = jdbc.queryForObject("SELECT version()", String.class);
        return Map.of("estado", "ok", "base", base, "postgres", version);
    }
}