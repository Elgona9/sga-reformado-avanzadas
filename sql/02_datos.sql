-- =====================================================================
-- Proyecto Final - Entrega 2 · Sistema de Gestión Académica Reformado
-- Archivo 02_datos.sql · Datos de prueba (ejecutar después de 01_create.sql)
-- Contraseña de todos los usuarios de prueba: Sga2026*
-- Clave de cifrado/HMAC de demostración: clave-demo-sga-2026
--   (en producción debe venir de un gestor de secretos, no del script)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Catálogos
-- ---------------------------------------------------------------------
INSERT INTO rol (nombre) VALUES
    ('Administrador General'), ('Decano'), ('Docente'), ('Estudiante'), ('Administrativo');

INSERT INTO facultad (nombre) VALUES
    ('Ingeniería'),
    ('Ciencias y Educación'),
    ('Tecnológica'),
    ('Medio Ambiente y Recursos Naturales'),
    ('Artes ASAB');

INSERT INTO programa (nombre, id_facultad) VALUES
    ('Ingeniería de Sistemas', 1),
    ('Ingeniería Industrial', 1),
    ('Ingeniería Electrónica', 1),
    ('Licenciatura en Matemáticas', 2),
    ('Tecnología en Sistematización de Datos', 3),
    ('Ingeniería Forestal', 4);

INSERT INTO departamento (nombre, id_facultad) VALUES
    ('Departamento de Sistemas', 1),
    ('Departamento de Ciencias Básicas de Ingeniería', 1),
    ('Departamento de Electrónica', 1),
    ('Departamento de Ingeniería Industrial', 1),
    ('Departamento de Matemáticas', 2),
    ('Departamento de Informática y Datos', 3);

INSERT INTO asignatura (codigo, nombre, creditos, id_departamento) VALUES
    ('SIS-201', 'Estructuras de Datos', 3, 1),
    ('SIS-301', 'Bases de Datos Avanzadas', 3, 1),
    ('SIS-302', 'Ingeniería de Software', 3, 1),
    ('SIS-303', 'Redes de Computadores', 3, 1),
    ('SIS-304', 'Teoría de la Información', 2, 1),
    ('SIS-305', 'Sistemas Dinámicos', 3, 1),
    ('CBI-101', 'Cálculo Diferencial', 4, 2),
    ('CBI-201', 'Probabilidad y Estadística', 3, 2),
    ('MAT-101', 'Álgebra Lineal', 3, 5),
    ('IND-401', 'Formulación y Evaluación de Proyectos', 3, 4);

INSERT INTO periodo (codigo, fecha_inicio, fecha_fin, es_actual) VALUES
    ('2024-3', '2024-08-12', '2024-12-06', false),
    ('2025-1', '2025-02-10', '2025-06-13', false),
    ('2025-3', '2025-08-11', '2025-12-05', false),
    ('2026-1', '2026-02-09', '2026-06-12', false),
    ('2026-3', '2026-08-10', '2026-12-04', true);

INSERT INTO espacio_fisico (codigo, sede, capacidad) VALUES
    ('ING-101',  'Facultad de Ingeniería', 40),
    ('ING-102',  'Facultad de Ingeniería', 35),
    ('ING-LAB1', 'Facultad de Ingeniería', 30),
    ('ING-LAB2', 'Facultad de Ingeniería', 30),
    ('TEC-201',  'Sede Tecnológica', 45),
    ('CYE-305',  'Sede Macarena', 50);

INSERT INTO tipo_evaluacion (nombre) VALUES
    ('Parcial 1'), ('Parcial 2'), ('Quiz'), ('Taller'), ('Examen final');

-- ---------------------------------------------------------------------
-- Usuarios (ids 1-2 administradores, 3 administrativo, 4-8 decanos,
--           9-16 docentes, 17-40 estudiantes)
-- ---------------------------------------------------------------------
INSERT INTO usuario (documento_hash, documento_cifrado, nombres, apellidos,
                     correo_institucional, nombre_usuario, contrasena_hash,
                     id_rol, telefono, correo_contacto)
SELECT encode(hmac(v.doc, 'clave-demo-sga-2026', 'sha256'), 'hex'),
       pgp_sym_encrypt(v.doc, 'clave-demo-sga-2026'),
       v.nombres, v.apellidos, v.usuario || '@udistrital.edu.co', v.usuario,
       crypt('Sga2026*', gen_salt('bf')), v.id_rol, v.tel, v.usuario || '@gmail.com'
FROM (VALUES
    (1, '52418830', 'Marta Lucía',      'Cárdenas Ríos',      'mcardenas',  1, '3105550101'),
    (2, '79653214', 'Julián Esteban',   'Pardo Ruiz',         'jpardo',     1, '3105550102'),
    (3, '52876401', 'Sandra Milena',    'Torres Gil',         'storres',    5, '3105550103')
) AS v(ord, doc, nombres, apellidos, usuario, id_rol, tel)
ORDER BY v.ord;

INSERT INTO usuario (documento_hash, documento_cifrado, nombres, apellidos,
                     correo_institucional, nombre_usuario, contrasena_hash,
                     id_rol, telefono, correo_contacto)
SELECT encode(hmac(v.doc, 'clave-demo-sga-2026', 'sha256'), 'hex'),
       pgp_sym_encrypt(v.doc, 'clave-demo-sga-2026'),
       v.nombres, v.apellidos, v.usuario || '@udistrital.edu.co', v.usuario,
       crypt('Sga2026*', gen_salt('bf')), v.id_rol, v.tel, v.usuario || '@gmail.com'
FROM (VALUES
    (1, '19345678', 'Alberto José',     'Cuervo Montaña',     'acuervo',    2, '3115550201'),
    (2, '41562390', 'Rosa Elena',       'Barragán Pinzón',    'rbarragan',  2, '3115550202'),
    (3, '80123456', 'Jorge Iván',       'Camargo Neira',      'jcamargo',   2, '3115550203'),
    (4, '51789012', 'Clara Inés',       'Villamil Duque',     'cvillamil',  2, '3115550204'),
    (5, '79234567', 'Octavio',          'Santamaría Rey',     'osantamaria',2, '3115550205')
) AS v(ord, doc, nombres, apellidos, usuario, id_rol, tel)
ORDER BY v.ord;

INSERT INTO usuario (documento_hash, documento_cifrado, nombres, apellidos,
                     correo_institucional, nombre_usuario, contrasena_hash,
                     id_rol, telefono, correo_contacto)
SELECT encode(hmac(v.doc, 'clave-demo-sga-2026', 'sha256'), 'hex'),
       pgp_sym_encrypt(v.doc, 'clave-demo-sga-2026'),
       v.nombres, v.apellidos, v.usuario || '@udistrital.edu.co', v.usuario,
       crypt('Sga2026*', gen_salt('bf')), 3, v.tel, v.usuario || '@gmail.com'
FROM (VALUES
    (1, '79456123', 'Ricardo Alonso',    'Bermúdez Cifuentes', 'rbermudez', '3125550301'),
    (2, '52345987', 'Gloria Patricia',   'Sandoval Ortiz',     'gsandoval', '3125550302'),
    (3, '80987654', 'Hernán Darío',      'Lozano Prieto',      'hlozano',   '3125550303'),
    (4, '51234876', 'Martha Isabel',     'Quiroga Salamanca',  'mquiroga',  '3125550304'),
    (5, '79876543', 'Édgar Fabián',      'Ruiz Calderón',      'eruiz',     '3125550305'),
    (6, '52678901', 'Liliana',           'Vega Mahecha',       'lvega',     '3125550306'),
    (7, '19876543', 'Fernando Augusto',  'Mesa Ladino',        'fmesa',     '3125550307'),
    (8, '53098765', 'Adriana Marcela',   'Poveda Leal',        'apoveda',   '3125550308')
) AS v(ord, doc, nombres, apellidos, usuario, tel)
ORDER BY v.ord;

-- 24 estudiantes con nombres y apellidos combinados de forma determinista
INSERT INTO usuario (documento_hash, documento_cifrado, nombres, apellidos,
                     correo_institucional, nombre_usuario, contrasena_hash,
                     id_rol, telefono, correo_contacto)
SELECT encode(hmac(b.doc, 'clave-demo-sga-2026', 'sha256'), 'hex'),
       pgp_sym_encrypt(b.doc, 'clave-demo-sga-2026'),
       b.nombres, b.apellidos,
       b.usuario || '@udistrital.edu.co', b.usuario,
       crypt('Sga2026*', gen_salt('bf')), 4,
       '3135550' || lpad(b.i::text, 3, '0'), b.usuario || '@gmail.com'
FROM (
    SELECT i,
           (1000100000 + i * 37)::text AS doc,
           (ARRAY['Camila Andrea','Santiago','Valentina','Juan Sebastián','Mariana','Daniel Felipe',
                  'Laura Sofía','Andrés Camilo','Isabela','Nicolás','Daniela','Carlos Eduardo',
                  'Paula Andrea','Sergio Alejandro','Natalia','Julián David','Karen Lorena','Miguel Ángel',
                  'Luisa Fernanda','Cristian Camilo','María José','Esteban','Tatiana','Brayan Stiven'])[i] AS nombres,
           (ARRAY['Montoya','Rojas','Gómez','Castillo','Vargas','Herrera','Moreno','Sánchez',
                  'Pineda','Quintero','Ramírez','Ortiz','Cárdenas','Beltrán','Acosta','Salazar',
                  'Cortés','Medina','Aguirre','Velásquez','Peña','Duarte','Franco','Mejía'])[i]
           || ' ' ||
           (ARRAY['López','Díaz','Torres','Martínez','Rincón','Suárez','Gutiérrez','Ríos',
                  'Castro','Parra','Jiménez','Ruiz','Mora','Cruz','Navarro','Cely',
                  'Bernal','Forero','Ávila','Cano','Lozano','Patiño','Santos','Niño'])[i] AS apellidos,
           translate(lower(left((ARRAY['Camila Andrea','Santiago','Valentina','Juan Sebastián','Mariana','Daniel Felipe',
                  'Laura Sofía','Andrés Camilo','Isabela','Nicolás','Daniela','Carlos Eduardo',
                  'Paula Andrea','Sergio Alejandro','Natalia','Julián David','Karen Lorena','Miguel Ángel',
                  'Luisa Fernanda','Cristian Camilo','María José','Esteban','Tatiana','Brayan Stiven'])[i], 1)
                  || (ARRAY['Montoya','Rojas','Gómez','Castillo','Vargas','Herrera','Moreno','Sánchez',
                  'Pineda','Quintero','Ramírez','Ortiz','Cárdenas','Beltrán','Acosta','Salazar',
                  'Cortés','Medina','Aguirre','Velásquez','Peña','Duarte','Franco','Mejía'])[i]),
                  'áéíóúñ', 'aeioun') AS usuario
    FROM generate_series(1, 24) AS i
) AS b
ORDER BY b.i;

-- ---------------------------------------------------------------------
-- Perfiles: decanos, docentes y estudiantes
-- ---------------------------------------------------------------------
INSERT INTO decano (id_usuario, id_facultad)
SELECT u.id_usuario, f.id_facultad
FROM (VALUES ('acuervo', 'Ingeniería'),
             ('rbarragan', 'Ciencias y Educación'),
             ('jcamargo', 'Tecnológica'),
             ('cvillamil', 'Medio Ambiente y Recursos Naturales'),
             ('osantamaria', 'Artes ASAB')) AS m(usuario, facultad)
JOIN usuario  u ON u.nombre_usuario = m.usuario
JOIN facultad f ON f.nombre = m.facultad
ORDER BY f.id_facultad;

INSERT INTO docente (id_usuario, id_departamento)
SELECT u.id_usuario, m.dep
FROM (VALUES ('rbermudez',1), ('gsandoval',1), ('hlozano',1), ('mquiroga',2),
             ('eruiz',2), ('lvega',5), ('fmesa',4), ('apoveda',3)) AS m(usuario, dep)
JOIN usuario u ON u.nombre_usuario = m.usuario
ORDER BY u.id_usuario;

INSERT INTO estudiante (id_usuario, codigo, id_programa, semestre_actual)
SELECT u.id_usuario,
       '20241020' || lpad((u.id_usuario - 16)::text, 3, '0'),
       CASE WHEN (u.id_usuario - 16) % 4  = 0 THEN 2
            WHEN (u.id_usuario - 16) % 7  = 0 THEN 3
            WHEN (u.id_usuario - 16) % 9  = 0 THEN 4
            WHEN (u.id_usuario - 16) % 11 = 0 THEN 5
            WHEN (u.id_usuario - 16) = 24     THEN 6
            ELSE 1 END,
       1 + ((u.id_usuario - 16) * 3) % 10
FROM usuario u
WHERE u.id_rol = 4
ORDER BY u.id_usuario;

-- ---------------------------------------------------------------------
-- Grupos (todos nacen Abiertos; el estado final se fija al terminar la carga)
--   g1-g4: 2025-3 · g5-g9: 2026-1 · g10-g17: 2026-3 (periodo actual)
-- ---------------------------------------------------------------------
INSERT INTO grupo (id_asignatura, id_docente, id_periodo, id_espacio, numero, cupo_maximo,
                   fecha_inicio_inscripcion, fecha_fin_inscripcion) VALUES
    ( 1, 1, 3, 1, 1, 30, '2025-08-04', '2025-08-15'),   -- g1  Estructuras de Datos
    ( 7, 4, 3, 5, 1, 35, '2025-08-04', '2025-08-15'),   -- g2  Cálculo Diferencial
    ( 9, 6, 3, 6, 1, 35, '2025-08-04', '2025-08-15'),   -- g3  Álgebra Lineal
    ( 8, 5, 3, 2, 1, 30, '2025-08-04', '2025-08-15'),   -- g4  Probabilidad y Estadística
    ( 2, 2, 4, 3, 1, 30, '2026-02-02', '2026-02-13'),   -- g5  Bases de Datos Avanzadas
    ( 3, 3, 4, 2, 1, 30, '2026-02-02', '2026-02-13'),   -- g6  Ingeniería de Software
    ( 4, 1, 4, 1, 1, 30, '2026-02-02', '2026-02-13'),   -- g7  Redes de Computadores
    ( 8, 5, 4, 5, 1, 30, '2026-02-02', '2026-02-13'),   -- g8  Probabilidad y Estadística
    ( 5, 3, 4, 2, 1, 30, '2026-02-02', '2026-02-13'),   -- g9  Teoría de la Información
    ( 2, 2, 5, 3, 1, 30, '2026-08-03', '2026-08-14'),   -- g10 Bases de Datos Avanzadas
    ( 6, 3, 5, 2, 1, 30, '2026-08-03', '2026-08-14'),   -- g11 Sistemas Dinámicos
    ( 5, 1, 5, 1, 1, 30, '2026-08-03', '2026-08-14'),   -- g12 Teoría de la Información
    (10, 7, 5, 6, 1, 30, '2026-08-03', '2026-08-14'),   -- g13 Formulación y Evaluación de Proyectos
    ( 3, 3, 5, 1, 1, 30, CURRENT_DATE - 3, CURRENT_DATE + 30),  -- g14 Ingeniería de Software (Abierto)
    ( 4, 1, 5, 2, 1,  3, CURRENT_DATE - 3, CURRENT_DATE + 30),  -- g15 Redes (cupo 3, para probar cupo lleno)
    ( 1, 2, 5, 4, 1, 30, CURRENT_DATE - 3, CURRENT_DATE + 30),  -- g16 Estructuras de Datos (vacío)
    ( 2, 3, 5, 4, 2, 30, CURRENT_DATE - 3, CURRENT_DATE + 30);  -- g17 Bases de Datos Avanzadas gr. 2

-- Horarios (1 = lunes ... 5 = viernes). Los grupos de un mismo periodo no se traslapan
-- entre sí, salvo g17 con g10 (Lun 07-09) para poder probar RN-22.
INSERT INTO horario_grupo (id_grupo, dia_semana, hora_inicio, hora_fin) VALUES
    ( 1, 1, '07:00', '09:00'), ( 1, 3, '07:00', '09:00'),
    ( 2, 2, '07:00', '09:00'), ( 2, 4, '07:00', '09:00'),
    ( 3, 1, '09:00', '11:00'), ( 3, 3, '09:00', '11:00'),
    ( 4, 2, '09:00', '11:00'), ( 4, 4, '09:00', '11:00'),
    ( 5, 1, '07:00', '09:00'), ( 5, 3, '07:00', '09:00'),
    ( 6, 2, '07:00', '09:00'), ( 6, 4, '07:00', '09:00'),
    ( 7, 1, '09:00', '11:00'), ( 7, 3, '09:00', '11:00'),
    ( 8, 2, '09:00', '11:00'), ( 8, 4, '09:00', '11:00'),
    ( 9, 5, '07:00', '09:00'), ( 9, 5, '09:00', '11:00'),
    (10, 1, '07:00', '09:00'), (10, 3, '07:00', '09:00'),
    (11, 2, '07:00', '09:00'), (11, 4, '07:00', '09:00'),
    (12, 1, '09:00', '11:00'), (12, 3, '09:00', '11:00'),
    (13, 2, '09:00', '11:00'), (13, 4, '09:00', '11:00'),
    (14, 1, '11:00', '13:00'), (14, 3, '11:00', '13:00'),
    (15, 5, '07:00', '09:00'), (15, 5, '09:00', '11:00'),
    (16, 2, '11:00', '13:00'), (16, 4, '11:00', '13:00'),
    (17, 1, '07:00', '09:00'), (17, 4, '14:00', '16:00');

-- ---------------------------------------------------------------------
-- Esquemas de evaluación (cada grupo suma exactamente 100 %)
--   A: Parcial 1 25 · Parcial 2 25 · Taller 20 · Examen final 30   (mayoría de grupos)
--   B: Parcial 1 20 · Quiz 10 · Parcial 2 20 · Taller 20 · Examen final 30   (g10-g13, en curso)
--   C: Parcial 1 20 · Parcial 2 20 · Taller 30 · Examen final 30   (g5, Bases de Datos Avanzadas 2026-1)
-- tipo_evaluacion: 1 Parcial 1 · 2 Parcial 2 · 3 Quiz · 4 Taller · 5 Examen final
-- ---------------------------------------------------------------------
INSERT INTO esquema_evaluacion (id_grupo, id_tipo_evaluacion, porcentaje)
SELECT g.id_grupo, v.tipo, v.pct
FROM grupo g
JOIN (VALUES (1,25.0),(2,25.0),(4,20.0),(5,30.0)) AS v(tipo, pct) ON true
WHERE g.id_grupo IN (1,2,3,4,6,7,8,9,14,15,16,17)
ORDER BY g.id_grupo, v.tipo;

INSERT INTO esquema_evaluacion (id_grupo, id_tipo_evaluacion, porcentaje)
SELECT g.id_grupo, v.tipo, v.pct
FROM grupo g
JOIN (VALUES (1,20.0),(3,10.0),(2,20.0),(4,20.0),(5,30.0)) AS v(tipo, pct) ON true
WHERE g.id_grupo BETWEEN 10 AND 13
ORDER BY g.id_grupo, v.tipo;

INSERT INTO esquema_evaluacion (id_grupo, id_tipo_evaluacion, porcentaje) VALUES
    (5, 1, 20.0), (5, 2, 20.0), (5, 4, 30.0), (5, 5, 30.0);

-- ---------------------------------------------------------------------
-- Inscripciones (tabla de mayor movimiento)
-- Grupos g1-g13: cada estudiante se inscribe en ~3 de cada 4 grupos,
-- dentro de la ventana de inscripción del grupo.
-- ---------------------------------------------------------------------
INSERT INTO inscripcion (id_estudiante, id_grupo, fecha_inscripcion)
SELECT e.id_estudiante, g.id_grupo,
       (g.fecha_inicio_inscripcion + ((e.id_estudiante * 3 + g.id_grupo) % 10))::timestamp
         + interval '9 hours'
FROM grupo g
CROSS JOIN estudiante e
WHERE g.id_grupo BETWEEN 1 AND 13
  AND (e.id_estudiante + g.id_grupo) % 4 <> 0
ORDER BY g.id_grupo, e.id_estudiante;

-- Grupos abiertos de hoy: g14 con 6 inscritos, g15 llena (cupo 3) y un estudiante en espera
INSERT INTO inscripcion (id_estudiante, id_grupo) VALUES
    (1, 14), (2, 14), (3, 14), (4, 14), (5, 14), (6, 14),
    (2, 15), (3, 15), (4, 15);
INSERT INTO inscripcion (id_estudiante, id_grupo, estado) VALUES (20, 15, 'EnEspera');

-- Algunos retiros (antes de calificar)
UPDATE inscripcion SET estado = 'Retirado'
WHERE id_grupo IN (10, 11) AND id_estudiante IN (5, 9, 14, 18);

-- ---------------------------------------------------------------------
-- Calificaciones
-- g1-g9: Parcial 1, Parcial 2, Taller y Examen final · g10-g13: Parcial 1 y Quiz
-- ---------------------------------------------------------------------
INSERT INTO calificacion (id_inscripcion, id_tipo_evaluacion, nota)
SELECT i.id_inscripcion, t.id_tipo_evaluacion,
       round((1.8 + ((abs(hashtext(i.id_inscripcion::text)) % 17)
                   + (abs(hashtext(i.id_inscripcion::text || '-' || t.id_tipo_evaluacion)) % 17)) / 10.0)::numeric, 1)
FROM inscripcion i
CROSS JOIN tipo_evaluacion t
WHERE i.estado = 'Inscrito'
  AND ((i.id_grupo BETWEEN 1 AND 9  AND t.id_tipo_evaluacion IN (1, 2, 4, 5))
    OR (i.id_grupo BETWEEN 10 AND 13 AND t.id_tipo_evaluacion IN (1, 3)))
ORDER BY i.id_inscripcion, t.id_tipo_evaluacion;

-- Bitácora RN-26: creación de cada calificación, a nombre del docente del grupo
INSERT INTO bitacora (id_usuario, accion, entidad, id_entidad, datos_nuevos, fecha_hora, ip_origen)
SELECT d.id_usuario, 'CREAR', 'calificacion', c.id_calificacion::text, to_jsonb(c),
       c.fecha_registro, '127.0.0.1'::inet
FROM calificacion c
JOIN inscripcion i ON i.id_inscripcion = c.id_inscripcion
JOIN grupo g       ON g.id_grupo = i.id_grupo
JOIN docente d     ON d.id_docente = g.id_docente
ORDER BY c.id_calificacion;

-- ---------------------------------------------------------------------
-- Correcciones de notas hechas por docentes y cambios de estado de los grupos
-- (cada UPDATE guarda en la bitácora la nota anterior y la nueva; ver nota más abajo)
-- ---------------------------------------------------------------------
-- Docente 2 corrige 6 notas del Parcial 1 de su grupo 10 (+0,3)
-- Docente 3 corrige 2 quices de su grupo 11 (+0,2)
WITH objetivo AS (
    (SELECT c2.id_calificacion, 2 AS id_docente, 0.3 AS delta
       FROM calificacion c2 JOIN inscripcion i ON i.id_inscripcion = c2.id_inscripcion
      WHERE i.id_grupo = 10 AND c2.id_tipo_evaluacion = 1
      ORDER BY c2.id_calificacion LIMIT 6)
    UNION ALL
    (SELECT c2.id_calificacion, 3, 0.2
       FROM calificacion c2 JOIN inscripcion i ON i.id_inscripcion = c2.id_inscripcion
      WHERE i.id_grupo = 11 AND c2.id_tipo_evaluacion = 3
      ORDER BY c2.id_calificacion LIMIT 2)
), antes AS (
    SELECT c.id_calificacion, to_jsonb(c) AS fila
    FROM calificacion c JOIN objetivo o ON o.id_calificacion = c.id_calificacion
), despues AS (
    UPDATE calificacion c SET nota = LEAST(5.0, c.nota + o.delta)
    FROM objetivo o WHERE c.id_calificacion = o.id_calificacion
    RETURNING c.id_calificacion, to_jsonb(c) AS fila
)
INSERT INTO bitacora (id_usuario, accion, entidad, id_entidad, datos_anteriores, datos_nuevos, fecha_hora, ip_origen)
SELECT d.id_usuario, 'MODIFICAR', 'calificacion', n.id_calificacion::text,
       a.fila, n.fila, now(), '127.0.0.1'::inet
FROM despues n
JOIN antes a    ON a.id_calificacion = n.id_calificacion
JOIN objetivo o ON o.id_calificacion = n.id_calificacion
JOIN docente d  ON d.id_docente = o.id_docente
WHERE a.fila <> n.fila;

-- Estado final de los grupos
UPDATE grupo SET estado = 'Finalizado' WHERE id_grupo BETWEEN 1  AND 9;
UPDATE grupo SET estado = 'EnCurso'    WHERE id_grupo BETWEEN 10 AND 13;

-- ---------------------------------------------------------------------
-- Bitácora de los cambios de estado de los grupos
-- (nota: los triggers de auditoría se crean en 03_procedimientos_triggers.sql, después
--  de esta carga; por eso la bitácora de los datos iniciales se escribe aquí, con el
--  mismo formato que usarán los triggers a partir de ese momento)
-- ---------------------------------------------------------------------
-- RNF-05: cambios de estado de los grupos, a nombre del decano de Ingeniería
INSERT INTO bitacora (id_usuario, accion, entidad, id_entidad, datos_anteriores, datos_nuevos, fecha_hora, ip_origen)
SELECT dc.id_usuario, 'CAMBIO_ESTADO', 'grupo', g.id_grupo::text,
       jsonb_build_object('estado', 'Abierto'), jsonb_build_object('estado', g.estado),
       now(), '127.0.0.1'::inet
FROM grupo g
JOIN decano dc ON dc.id_facultad = 1
WHERE g.id_grupo BETWEEN 1 AND 13
ORDER BY g.id_grupo;
