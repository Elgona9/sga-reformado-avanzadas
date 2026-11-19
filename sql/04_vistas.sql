-- =====================================================================
-- Proyecto Final - Entrega 2 · Sistema de Gestión Académica Reformado
-- Archivo 04_vistas.sql
-- Ejecutar después de 01_create.sql, 02_datos.sql y 03_procedimientos_triggers.sql
-- Requiere PostgreSQL 14+
--
-- Contenido
--   V01. vw_definitiva_inscripcion · notas definitivas ponderadas por
--        inscripción (trasladada desde 03_procedimientos_triggers.sql)
--   V02. vw_cupos_grupo · ocupación de cupos por grupo (RF-09, RN-12,
--        RN-19, RN-20)
--   V03. vw_horario_grupo · horario completo por grupo, con datos de
--        asignatura, docente y espacio (apoya RN-15, RN-16, RN-22)
-- =====================================================================


-- =====================================================================
-- V01 · vw_definitiva_inscripcion
-- =====================================================================
-- Vista trasladada desde 03_procedimientos_triggers.sql sin cambios.
-- La utiliza fn_reporte_rendimiento_asignatura (RF-17).
-- ---------------------------------------------------------------------
-- Notas definitivas ponderadas por inscripción
--   porcentaje_evaluado : suma de los porcentajes de las evaluaciones ya calificadas
--   nota_acumulada      : suma de nota × porcentaje / 100 (puntos ya ganados)
--   promedio_ponderado  : nota_acumulada / porcentaje_evaluado (nota de lo evaluado hasta hoy)
--   definitiva          : nota_acumulada, solo cuando ya se evaluó el 100 % del esquema
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_definitiva_inscripcion AS
SELECT i.id_inscripcion, i.id_estudiante, i.id_grupo,
       COALESCE(SUM(e.porcentaje) FILTER (WHERE c.id_calificacion IS NOT NULL), 0)  AS porcentaje_evaluado,
       ROUND(COALESCE(SUM(c.nota * e.porcentaje / 100), 0), 2)                      AS nota_acumulada,
       ROUND(SUM(c.nota * e.porcentaje)
             / NULLIF(SUM(e.porcentaje) FILTER (WHERE c.id_calificacion IS NOT NULL), 0), 2) AS promedio_ponderado,
       CASE WHEN SUM(e.porcentaje) FILTER (WHERE c.id_calificacion IS NOT NULL) = 100
            THEN ROUND(SUM(c.nota * e.porcentaje / 100), 2) END                      AS definitiva
FROM inscripcion i
JOIN esquema_evaluacion e ON e.id_grupo = i.id_grupo
LEFT JOIN calificacion c  ON c.id_inscripcion = i.id_inscripcion
                         AND c.id_tipo_evaluacion = e.id_tipo_evaluacion
WHERE i.estado = 'Inscrito'
GROUP BY i.id_inscripcion, i.id_estudiante, i.id_grupo;


-- =====================================================================
-- V02 · vw_cupos_grupo
-- =====================================================================
-- Ocupación de cupos de cada grupo. Una fila por grupo con su asignatura,
-- periodo, docente, espacio físico y el conteo de inscripciones.
--   asignatura_codigo    : código de la asignatura del grupo
--   asignatura_nombre    : nombre de la asignatura
--   numero               : número del grupo dentro de la asignatura y el periodo
--   periodo_codigo        : código del periodo académico (AAAA-S)
--   docente              : nombre completo del docente (nombres y apellidos)
--   espacio_codigo       : código del espacio físico asignado
--   estado               : estado del grupo (Abierto, Cerrado, EnCurso, Finalizado)
--   cupo_maximo          : capacidad máxima del grupo
--   inscritos            : inscripciones en estado 'Inscrito'
--   en_espera            : inscripciones en estado 'EnEspera'
--   cupos_disponibles    : GREATEST(cupo_maximo - inscritos, 0), nunca negativo
--   porcentaje_ocupacion : 100 × inscritos / cupo_maximo, redondeado a 1 decimal
--   inscripcion_vigente  : TRUE si el grupo está 'Abierto' y CURRENT_DATE cae
--                          dentro de la ventana de inscripción
-- Apoya RF-09 (inscribir), RN-12 (cupo máximo del grupo) y RN-19/RN-20
-- (grupo abierto y ventana de inscripción, validadas por trigger en 03).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_cupos_grupo AS
SELECT g.id_grupo,
       a.codigo                                                           AS asignatura_codigo,
       a.nombre                                                           AS asignatura_nombre,
       g.numero,
       p.codigo                                                           AS periodo_codigo,
       u.nombres || ' ' || u.apellidos                                    AS docente,
       ef.codigo                                                          AS espacio_codigo,
       g.estado,
       g.cupo_maximo,
       COUNT(i.id_inscripcion) FILTER (WHERE i.estado = 'Inscrito')       AS inscritos,
       COUNT(i.id_inscripcion) FILTER (WHERE i.estado = 'EnEspera')       AS en_espera,
       GREATEST(g.cupo_maximo
                - COUNT(i.id_inscripcion) FILTER (WHERE i.estado = 'Inscrito'), 0) AS cupos_disponibles,
       ROUND(100.0 * COUNT(i.id_inscripcion) FILTER (WHERE i.estado = 'Inscrito')
             / g.cupo_maximo, 1)                                          AS porcentaje_ocupacion,
       (g.estado = 'Abierto'
        AND CURRENT_DATE BETWEEN g.fecha_inicio_inscripcion
                             AND g.fecha_fin_inscripcion)                 AS inscripcion_vigente
FROM grupo g
JOIN asignatura a ON a.id_asignatura = g.id_asignatura
JOIN periodo p ON p.id_periodo = g.id_periodo
JOIN docente d ON d.id_docente = g.id_docente
JOIN usuario u ON u.id_usuario = d.id_usuario
JOIN espacio_fisico ef ON ef.id_espacio = g.id_espacio
LEFT JOIN inscripcion i ON i.id_grupo = g.id_grupo
GROUP BY g.id_grupo, a.codigo, a.nombre, g.numero, p.codigo,
         u.nombres, u.apellidos, ef.codigo, g.estado, g.cupo_maximo,
         g.fecha_inicio_inscripcion, g.fecha_fin_inscripcion;


-- =====================================================================
-- V03 · vw_horario_grupo
-- =====================================================================
-- Horario completo por grupo. Una fila por cada registro de horario_grupo,
-- con los datos de asignatura, periodo, docente y espacio ya resueltos,
-- para no repetir estos JOIN en cada consulta.
--   id_horario        : identificador del bloque horario
--   id_grupo          : grupo al que pertenece el bloque
--   asignatura_codigo : código de la asignatura del grupo
--   asignatura_nombre : nombre de la asignatura
--   numero            : número del grupo
--   periodo_codigo    : código del periodo académico (AAAA-S)
--   docente           : nombre completo del docente (nombres y apellidos)
--   espacio_codigo    : código del espacio físico asignado
--   dia_semana        : día como número (1 = lunes ... 7 = domingo)
--   dia               : nombre del día en español
--   hora_inicio       : hora de inicio del bloque
--   hora_fin          : hora de finalización del bloque
-- Apoya la verificación de traslapes RN-15 (docente), RN-16 (espacio) y
-- RN-22 (estudiante) al reunir en un solo lugar grupo, asignatura, docente,
-- usuario, espacio físico y periodo.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_horario_grupo AS
SELECT h.id_horario,
       g.id_grupo,
       a.codigo AS asignatura_codigo,
       a.nombre AS asignatura_nombre,
       g.numero,
       p.codigo  AS periodo_codigo,
       u.nombres || ' ' || u.apellidos AS docente,
       ef.codigo AS espacio_codigo,
       h.dia_semana,
       CASE h.dia_semana
            WHEN 1 THEN 'Lunes'
            WHEN 2 THEN 'Martes'
            WHEN 3 THEN 'Miércoles'
            WHEN 4 THEN 'Jueves'
            WHEN 5 THEN 'Viernes'
            WHEN 6 THEN 'Sábado'
            WHEN 7 THEN 'Domingo'
       END                                                AS dia,
       h.hora_inicio,
       h.hora_fin
FROM horario_grupo h
JOIN grupo g ON g.id_grupo = h.id_grupo
JOIN asignatura a ON a.id_asignatura = g.id_asignatura
JOIN periodo p ON p.id_periodo = g.id_periodo
JOIN docente d ON d.id_docente = g.id_docente
JOIN usuario u ON u.id_usuario = d.id_usuario
JOIN espacio_fisico ef ON ef.id_espacio = g.id_espacio;


-- =====================================================================
-- Consultas de comprobación (ejecutar manualmente, no son parte del esquema)
-- =====================================================================
-- [V01] Notas definitivas ponderadas de las inscripciones del grupo 1.
--       Con los datos de 02_datos.sql, g1 (Estructuras de Datos) tiene el
--       esquema completo evaluado, por lo que 'definitiva' no es NULL.
-- SELECT * FROM vw_definitiva_inscripcion
-- WHERE id_grupo = 1
-- ORDER BY id_inscripcion;

-- [V01] Resumen: por grupo, cuántas inscripciones ya tienen definitiva.
-- SELECT id_grupo,
--        COUNT(*)                                       AS inscripciones,
--        COUNT(definitiva)                              AS con_definitiva,
--        ROUND(AVG(promedio_ponderado), 2)              AS prom_ponderado
-- FROM vw_definitiva_inscripcion
-- GROUP BY id_grupo
-- ORDER BY id_grupo;

-- [V02] Ocupación de todos los grupos, los más llenos primero.
--       g15 (Redes, cupo 3) sirve para ver un grupo cerca del cupo lleno.
-- SELECT id_grupo, asignatura_codigo, numero, periodo_codigo, estado,
--        cupo_maximo, inscritos, en_espera, cupos_disponibles,
--        porcentaje_ocupacion, inscripcion_vigente
-- FROM vw_cupos_grupo
-- ORDER BY porcentaje_ocupacion DESC, id_grupo;

-- [V02] Grupos con inscripción vigente hoy (estado 'Abierto' y dentro de la
--       ventana). En 02_datos.sql, g14..g17 usan CURRENT_DATE.
-- SELECT id_grupo, asignatura_codigo, periodo_codigo, estado, cupos_disponibles
-- FROM vw_cupos_grupo
-- WHERE inscripcion_vigente
-- ORDER BY id_grupo;

-- [V03] Horario del periodo 2025-3 ordenado por día y hora de inicio.
-- SELECT id_grupo, asignatura_codigo, numero, docente, espacio_codigo,
--        dia, hora_inicio, hora_fin
-- FROM vw_horario_grupo
-- WHERE periodo_codigo = '2025-3'
-- ORDER BY periodo_codigo, dia_semana, hora_inicio;

-- [V03] Posibles traslapes del mismo docente dentro de un periodo: dos bloques
--       el mismo día que se solapan en horas (apoya la revisión de RN-15).
-- SELECT h1.docente, h1.periodo_codigo, h1.dia,
--        h1.id_grupo AS grupo_a, h1.hora_inicio AS ini_a, h1.hora_fin AS fin_a,
--        h2.id_grupo AS grupo_b, h2.hora_inicio AS ini_b, h2.hora_fin AS fin_b
-- FROM vw_horario_grupo h1
-- JOIN vw_horario_grupo h2
--   ON h2.docente = h1.docente
--  AND h2.periodo_codigo = h1.periodo_codigo
--  AND h2.dia_semana = h1.dia_semana
--  AND h2.id_grupo > h1.id_grupo
--  AND h1.hora_inicio < h2.hora_fin
--  AND h2.hora_inicio < h1.hora_fin
-- ORDER BY h1.docente, h1.periodo_codigo, h1.dia_semana;
