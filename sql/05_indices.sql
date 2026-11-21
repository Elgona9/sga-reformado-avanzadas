-- =====================================================================
-- Proyecto Final - Bases de Datos Avanzadas
-- Archivo: 05_indices.sql
-- Objetivo: crear índices para apoyar las búsquedas, los JOIN y las
--           validaciones que se realizan con mayor frecuencia.
-- Motor: PostgreSQL
-- =====================================================================

-- Los índices B-tree de este archivo buscan reducir la cantidad de filas
-- que PostgreSQL debe revisar cuando se filtra o se relacionan registros
-- por las columnas indicadas. Su utilidad efectiva depende de los datos,
-- la selectividad de los filtros y el plan elegido por el optimizador.
-- No reemplazan las restricciones PRIMARY KEY ni UNIQUE.

-- ---------------------------------------------------------------------
-- Índices relacionados con estudiantes y grupos
-- ---------------------------------------------------------------------

-- Facilita localizar los estudiantes asociados a un programa. Es útil
-- para consultas que filtren por id_programa o relacionen estudiantes
-- con programas, por ejemplo, en listados y reportes académicos.
CREATE INDEX ix_estudiante_programa
    ON estudiante (id_programa);

-- Apoya la búsqueda de grupos de un docente dentro de un periodo.
-- También puede ayudar a las consultas de validación de traslapes que
-- necesitan revisar los grupos asignados al mismo docente y periodo.
-- El orden de las columnas favorece primero los filtros por id_docente
-- y, adicionalmente, por id_periodo.
CREATE INDEX ix_grupo_docente_periodo
    ON grupo (id_docente, id_periodo);

-- Apoya la localización de grupos que utilizan un espacio en un periodo.
-- Es especialmente pertinente para las validaciones de disponibilidad
-- y de posibles traslapes de espacio, que relacionan ambas columnas.
CREATE INDEX ix_grupo_espacio_periodo
    ON grupo (id_espacio, id_periodo);

-- Facilita encontrar los grupos pertenecientes a una asignatura. Puede
-- apoyar los listados de grupos por asignatura y las consultas que
-- relacionan grupo con asignatura.
CREATE INDEX ix_grupo_asignatura
    ON grupo (id_asignatura);

-- Facilita obtener los horarios asociados a un grupo y realizar el JOIN
-- entre horario_grupo y grupo. También ayuda cuando se consultan los
-- horarios de un grupo específico.
CREATE INDEX ix_horario_grupo
    ON horario_grupo (id_grupo);

-- Apoya la consulta de inscripciones de un grupo filtradas por estado.
-- Es útil para revisar las inscripciones de un grupo y para operaciones
-- que deban contabilizar o consultar registros según su estado.
-- Al ser compuesto, resulta más adecuado para filtros que comienzan
-- por id_grupo y pueden añadir estado.
CREATE INDEX ix_inscripcion_grupo
    ON inscripcion (id_grupo, estado);

-- Facilita localizar las calificaciones asociadas a una inscripción.
-- Apoya el JOIN entre calificacion e inscripcion y las consultas que
-- recuperan las notas de una inscripción determinada.
CREATE INDEX ix_calificacion_insc
    ON calificacion (id_inscripcion);

-- Facilita consultar los componentes del esquema de evaluación por tipo
-- de evaluación. Puede apoyar los JOIN y filtros que utilizan
-- id_tipo_evaluacion para obtener la configuración correspondiente.
CREATE INDEX ix_esquema_tipo
    ON esquema_evaluacion (id_tipo_evaluacion);

-- ---------------------------------------------------------------------
-- Índices de auditoría
-- ---------------------------------------------------------------------

-- Apoya la consulta de eventos de bitácora asociados a un usuario,
-- especialmente cuando se filtra por id_usuario y se ordenan o acotan
-- los resultados por fecha_hora (por ejemplo, el historial de actividad
-- de un usuario en un intervalo de tiempo).
CREATE INDEX ix_bitacora_usuario
    ON bitacora (id_usuario, fecha_hora);

-- Facilita recuperar los eventos de una entidad y de un registro concreto.
-- Es útil para consultar la trazabilidad de los cambios realizados sobre
-- una fila identificada por la combinación entidad + id_entidad.
CREATE INDEX ix_bitacora_entidad
    ON bitacora (entidad, id_entidad);

