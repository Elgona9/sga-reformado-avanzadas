-- =====================================================================
-- Proyecto Final - Entrega 2 · Sistema de Gestión Académica Reformado
-- Archivo 01_create.sql · Creación de tablas y restricciones
-- Motor: PostgreSQL 14+ (probado en 16) · Se puede ejecutar varias veces
-- =====================================================================

-- pgcrypto: extensión utilizada para funciones criptográficas.
-- Permite generar hashes con sal y cifrar información sensible.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Se eliminan primero las vistas y tablas existentes para permitir
-- ejecutar nuevamente el script desde cero.
DROP VIEW IF EXISTS vw_definitiva_inscripcion;

DROP TABLE IF EXISTS bitacora, calificacion, esquema_evaluacion, tipo_evaluacion, inscripcion,
                     horario_grupo, grupo, espacio_fisico, periodo, asignatura,
                     decano, docente, estudiante, departamento, programa,
                     facultad, usuario, rol CASCADE;


-- ---------------------------------------------------------------------
-- CATÁLOGOS DE ESTRUCTURA INSTITUCIONAL
-- ---------------------------------------------------------------------

CREATE TABLE rol (
    id_rol  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- PRIMARY KEY: identifica de forma única cada rol.
    -- IDENTITY: genera automáticamente el identificador.

    nombre  VARCHAR(30) NOT NULL UNIQUE
    -- NOT NULL: obliga a registrar un nombre.
    -- UNIQUE: impide que existan dos roles con el mismo nombre.
);

CREATE TABLE facultad (
    id_facultad INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- PRIMARY KEY: identificador único de cada facultad.

    nombre      VARCHAR(80) NOT NULL UNIQUE
    -- NOT NULL: el nombre es obligatorio.
    -- UNIQUE: no permite facultades con nombres duplicados.
);

CREATE TABLE programa (
    id_programa INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- PRIMARY KEY: identificador único del programa académico.

    nombre      VARCHAR(100) NOT NULL UNIQUE,
    -- NOT NULL: el nombre del programa es obligatorio.
    -- UNIQUE: no permite nombres de programas duplicados.

    id_facultad INT NOT NULL
        REFERENCES facultad(id_facultad) ON DELETE RESTRICT
    -- FOREIGN KEY: relaciona cada programa con una facultad existente.
    -- NOT NULL: todo programa debe pertenecer a una facultad.
    -- ON DELETE RESTRICT: impide eliminar una facultad si tiene programas asociados.
);

CREATE TABLE departamento (
    id_departamento INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- PRIMARY KEY: identificador único del departamento.

    nombre          VARCHAR(100) NOT NULL UNIQUE,
    -- NOT NULL: el nombre del departamento es obligatorio.
    -- UNIQUE: impide registrar departamentos con nombres duplicados.

    id_facultad     INT NOT NULL
        REFERENCES facultad(id_facultad) ON DELETE RESTRICT
    -- FOREIGN KEY: establece a qué facultad pertenece el departamento.
    -- ON DELETE RESTRICT: impide eliminar una facultad que tenga departamentos asociados.
);

CREATE TABLE asignatura (
    id_asignatura   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- PRIMARY KEY: identificador único de la asignatura.

    codigo          VARCHAR(10) NOT NULL UNIQUE,
    -- NOT NULL: toda asignatura debe tener un código.
    -- UNIQUE: el código no puede repetirse.

    nombre          VARCHAR(100) NOT NULL,
    -- NOT NULL: obliga a registrar el nombre de la asignatura.

    creditos        SMALLINT NOT NULL CHECK (creditos > 0),
    -- NOT NULL: la asignatura debe tener créditos definidos.
    -- CHECK: garantiza que la cantidad de créditos sea mayor que cero.

    id_departamento INT NOT NULL
        REFERENCES departamento(id_departamento) ON DELETE RESTRICT
    -- FOREIGN KEY: relaciona la asignatura con un departamento existente.
    -- ON DELETE RESTRICT: impide eliminar un departamento que tenga asignaturas asociadas.
);

CREATE TABLE periodo (
    id_periodo   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- PRIMARY KEY: identificador único del periodo académico.

    codigo       VARCHAR(6) NOT NULL UNIQUE
        CHECK (codigo ~ '^[0-9]{4}-[0-9]$'),
    -- NOT NULL: el código del periodo es obligatorio.
    -- UNIQUE: no permite códigos de periodo duplicados.
    -- CHECK: valida que el código tenga el formato AAAA-S,
    -- donde AAAA representa el año y S el número del periodo.
    -- Ejemplo: 2026-1.

    fecha_inicio DATE NOT NULL,
    -- NOT NULL: todo periodo debe tener una fecha de inicio.

    fecha_fin    DATE NOT NULL,
    -- NOT NULL: todo periodo debe tener una fecha de finalización.

    es_actual    BOOLEAN NOT NULL DEFAULT false,
    -- NOT NULL: siempre debe existir un valor para indicar si es actual.
    -- DEFAULT false: los periodos se crean como no actuales por defecto.

    CONSTRAINT ck_periodo_fechas CHECK (fecha_fin > fecha_inicio)
    -- CHECK: garantiza que la fecha de finalización sea posterior
    -- a la fecha de inicio del periodo.
);

-- Índice único parcial:
-- garantiza que exista como máximo un periodo marcado como actual.
-- Los periodos cuyo es_actual sea FALSE no están sujetos a esta unicidad.
CREATE UNIQUE INDEX ux_periodo_actual ON periodo (es_actual) WHERE es_actual;

CREATE TABLE espacio_fisico (
    id_espacio INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- PRIMARY KEY: identificador único del espacio físico.

    codigo     VARCHAR(20) NOT NULL UNIQUE,
    -- NOT NULL: el espacio debe tener un código.
    -- UNIQUE: impide que dos espacios tengan el mismo código.

    sede       VARCHAR(80) NOT NULL,
    -- NOT NULL: obliga a indicar la sede donde se encuentra el espacio.

    capacidad  SMALLINT NOT NULL CHECK (capacidad > 0)
    -- NOT NULL: la capacidad es obligatoria.
    -- CHECK: la capacidad debe ser mayor que cero.
);

CREATE TABLE tipo_evaluacion (
    id_tipo_evaluacion INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- PRIMARY KEY: identificador único del tipo de evaluación.

    nombre             VARCHAR(40) NOT NULL UNIQUE
    -- NOT NULL: el nombre del tipo de evaluación es obligatorio.
    -- UNIQUE: impide registrar tipos de evaluación con nombres duplicados.
);


-- ---------------------------------------------------------------------
-- USUARIOS Y PERFILES
-- ---------------------------------------------------------------------

CREATE TABLE usuario (
    id_usuario           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- PRIMARY KEY: identificador único de cada usuario.

    documento_hash       CHAR(64) NOT NULL UNIQUE,
    -- NOT NULL: todo usuario debe tener un documento representado mediante hash.
    -- UNIQUE: impide registrar dos usuarios con el mismo documento.
    -- RN-01: utiliza HMAC-SHA256 para representar el documento sin almacenarlo directamente.

    documento_cifrado    BYTEA NOT NULL,
    -- NOT NULL: obliga a almacenar el documento cifrado.
    -- RNF-03: utiliza pgp_sym_encrypt para proteger el documento original.

    nombres              VARCHAR(80) NOT NULL,
    -- NOT NULL: los nombres del usuario son obligatorios.

    apellidos            VARCHAR(80) NOT NULL,
    -- NOT NULL: los apellidos del usuario son obligatorios.

    correo_institucional VARCHAR(120) NOT NULL UNIQUE
        CHECK (correo_institucional LIKE '%@udistrital.edu.co'),
    -- NOT NULL: el correo institucional es obligatorio.
    -- UNIQUE: cada usuario debe tener un correo institucional diferente.
    -- CHECK: valida que el correo pertenezca al dominio institucional.
    -- RN-03: restringe el registro al dominio @udistrital.edu.co.

    nombre_usuario       VARCHAR(40) NOT NULL UNIQUE,
    -- NOT NULL: el nombre de usuario es obligatorio.
    -- UNIQUE: no pueden existir dos cuentas con el mismo nombre de usuario.
    -- RN-02: garantiza que cada cuenta tenga un identificador de acceso único.

    contrasena_hash      TEXT NOT NULL,
    -- NOT NULL: toda cuenta debe tener una contraseña almacenada como hash.
    -- RNF-03: almacena la contraseña mediante un mecanismo de hash seguro
    -- (bcrypt con sal), sin guardar la contraseña en texto plano.

    estado               VARCHAR(10) NOT NULL DEFAULT 'Activo'
        CHECK (estado IN ('Activo', 'Inactivo', 'Bloqueado')),
    -- NOT NULL: todo usuario debe tener un estado.
    -- DEFAULT: los usuarios se crean activos por defecto.
    -- CHECK: solamente admite los estados Activo, Inactivo y Bloqueado.
    -- RN-04: controla los estados permitidos para las cuentas.

    id_rol               INT NOT NULL
        REFERENCES rol(id_rol) ON DELETE RESTRICT,
    -- FOREIGN KEY: relaciona al usuario con un rol registrado en la tabla rol.
    -- NOT NULL: todo usuario debe tener un rol asignado.
    -- ON DELETE RESTRICT: impide eliminar un rol que esté siendo utilizado.
    -- RN-05: garantiza la asignación de un rol a cada usuario.

    telefono             VARCHAR(20),
    -- RF-05: almacena el teléfono de contacto. Es opcional porque permite NULL.

    correo_contacto      VARCHAR(120),
    -- RF-05: almacena un correo adicional de contacto. Es opcional.

    ultimo_acceso        TIMESTAMPTZ,
    -- RF-03: registra la fecha y hora del último acceso del usuario.
    -- Es opcional porque una cuenta nueva puede no haber iniciado sesión.

    fecha_creacion       TIMESTAMPTZ NOT NULL DEFAULT now()
    -- NOT NULL: toda cuenta debe registrar su fecha de creación.
    -- DEFAULT now(): asigna automáticamente la fecha y hora del registro.
);

CREATE TABLE estudiante (
    id_estudiante   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- PRIMARY KEY: identificador único del estudiante.

    id_usuario      INT NOT NULL UNIQUE
        REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
    -- FOREIGN KEY: relaciona el perfil de estudiante con un usuario existente.
    -- NOT NULL: todo estudiante debe estar asociado a un usuario.
    -- UNIQUE: un usuario no puede tener dos perfiles de estudiante.
    -- ON DELETE RESTRICT: impide eliminar un usuario que tenga este perfil.
    -- La combinación de FK y UNIQUE establece una relación 1:1
    -- entre usuario y estudiante, en el sentido usuario-perfil.
    -- RN-06: la validación adicional del perfil se realiza mediante trigger.

    codigo          VARCHAR(11) NOT NULL UNIQUE
        CHECK (codigo ~ '^[0-9]{11}$'),
    -- NOT NULL: el código estudiantil es obligatorio.
    -- UNIQUE: cada estudiante debe tener un código diferente.
    -- CHECK: exige exactamente 11 caracteres numéricos.
    -- RN-08: valida el formato del código estudiantil.

    id_programa     INT NOT NULL
        REFERENCES programa(id_programa) ON DELETE RESTRICT,
    -- FOREIGN KEY: relaciona al estudiante con un programa académico existente.
    -- NOT NULL: todo estudiante debe estar matriculado en un programa.
    -- ON DELETE RESTRICT: impide eliminar un programa que tenga estudiantes asociados.
    -- RN-09: garantiza la vinculación del estudiante con un programa.

    semestre_actual SMALLINT NOT NULL CHECK (semestre_actual > 0)
    -- NOT NULL: el semestre actual es obligatorio.
    -- CHECK: el semestre debe ser mayor que cero.
    -- RN-10: evita registrar semestres inválidos.
);

CREATE TABLE docente (
    id_docente      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- PRIMARY KEY: identificador único del docente.

    id_usuario      INT NOT NULL UNIQUE
        REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
    -- FOREIGN KEY: relaciona el perfil docente con un usuario existente.
    -- NOT NULL: todo docente debe estar asociado a un usuario.
    -- UNIQUE: un usuario no puede tener dos perfiles de docente.
    -- ON DELETE RESTRICT: impide eliminar el usuario mientras tenga este perfil.
    -- La combinación de FK y UNIQUE establece una relación 1:1
    -- entre usuario y docente, en el sentido usuario-perfil.
    -- RN-07: la validación adicional del perfil se realiza mediante trigger.

    id_departamento INT NOT NULL
        REFERENCES departamento(id_departamento) ON DELETE RESTRICT
    -- FOREIGN KEY: asigna al docente a un departamento existente.
    -- NOT NULL: todo docente debe pertenecer a un departamento.
    -- ON DELETE RESTRICT: impide eliminar un departamento con docentes asociados.
);

CREATE TABLE decano (
    id_decano   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- PRIMARY KEY: identificador único del decano.

    id_usuario  INT NOT NULL UNIQUE
        REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
    -- FOREIGN KEY: relaciona al decano con un usuario existente.
    -- NOT NULL: todo decano debe estar asociado a un usuario.
    -- UNIQUE: un usuario no puede tener dos perfiles de decano.
    -- ON DELETE RESTRICT: impide eliminar un usuario que tenga este perfil.

    id_facultad INT NOT NULL UNIQUE
        REFERENCES facultad(id_facultad) ON DELETE RESTRICT
    -- FOREIGN KEY: relaciona al decano con una facultad existente.
    -- NOT NULL: todo decano debe estar asignado a una facultad.
    -- UNIQUE: impide asignar más de un decano a la misma facultad.
    -- ON DELETE RESTRICT: impide eliminar una facultad que tenga un decano asociado.
);


-- ---------------------------------------------------------------------
-- GRUPOS Y HORARIOS
-- ---------------------------------------------------------------------

CREATE TABLE grupo (
    id_grupo                 INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- PRIMARY KEY: identificador único de cada grupo académico.

    id_asignatura            INT NOT NULL
        REFERENCES asignatura(id_asignatura) ON DELETE RESTRICT,
    -- FOREIGN KEY: vincula el grupo con una asignatura existente.
    -- NOT NULL: todo grupo debe corresponder a una asignatura.
    -- ON DELETE RESTRICT: impide eliminar una asignatura que tenga grupos asociados.
    -- RN-11: garantiza que el grupo tenga una asignatura válida.

    id_docente               INT NOT NULL
        REFERENCES docente(id_docente) ON DELETE RESTRICT,
    -- FOREIGN KEY: asigna el grupo a un docente existente.
    -- NOT NULL: todo grupo debe tener un docente responsable.
    -- ON DELETE RESTRICT: impide eliminar un docente que tenga grupos asignados.
    -- RN-11: garantiza que el grupo tenga un docente válido.

    id_periodo               INT NOT NULL
        REFERENCES periodo(id_periodo) ON DELETE RESTRICT,
    -- FOREIGN KEY: vincula el grupo con un periodo académico existente.
    -- NOT NULL: todo grupo debe pertenecer a un periodo.
    -- ON DELETE RESTRICT: impide eliminar un periodo que tenga grupos asociados.
    -- RN-11: garantiza que el grupo tenga un periodo académico válido.

    id_espacio               INT NOT NULL
        REFERENCES espacio_fisico(id_espacio) ON DELETE RESTRICT,
    -- FOREIGN KEY: asigna el grupo a un espacio físico existente.
    -- NOT NULL: todo grupo debe tener un espacio físico asignado.
    -- ON DELETE RESTRICT: impide eliminar un espacio que tenga grupos asociados.

    numero                   SMALLINT NOT NULL CHECK (numero > 0),
    -- NOT NULL: el número del grupo es obligatorio.
    -- CHECK: el número del grupo debe ser positivo.

    cupo_maximo              SMALLINT NOT NULL CHECK (cupo_maximo > 0),
    -- NOT NULL: todo grupo debe definir su capacidad máxima.
    -- CHECK: el cupo máximo debe ser mayor que cero.
    -- RN-12: evita grupos con capacidad nula o negativa.

    estado                   VARCHAR(10) NOT NULL DEFAULT 'Abierto',
    -- NOT NULL: todo grupo debe tener un estado.
    -- DEFAULT: el grupo se crea abierto por defecto.

    fecha_inicio_inscripcion DATE NOT NULL,
    -- NOT NULL: establece la fecha inicial del proceso de inscripción.

    fecha_fin_inscripcion    DATE NOT NULL,
    -- NOT NULL: establece la fecha final del proceso de inscripción.

    CONSTRAINT ck_grupo_estado
        CHECK (estado IN ('Abierto', 'Cerrado', 'EnCurso', 'Finalizado')),
    -- CHECK: restringe el estado del grupo a los cuatro valores permitidos.
    -- RN-13: controla los estados válidos de un grupo.

    CONSTRAINT ck_grupo_fechas_inscripcion
        CHECK (fecha_fin_inscripcion >= fecha_inicio_inscripcion),
    -- CHECK: garantiza que la fecha de finalización de inscripciones
    -- sea igual o posterior a la fecha de inicio.
    -- RN-14: evita rangos de inscripción con fechas invertidas.

    CONSTRAINT uq_grupo_asignatura_periodo_numero
        UNIQUE (id_asignatura, id_periodo, numero)
    -- UNIQUE compuesto: impide registrar dos grupos con el mismo número
    -- para una misma asignatura dentro del mismo periodo académico.
);

CREATE TABLE horario_grupo (
    id_horario  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- PRIMARY KEY: identificador único de cada horario.

    id_grupo    INT NOT NULL
        REFERENCES grupo(id_grupo) ON DELETE CASCADE,
    -- FOREIGN KEY: relaciona el horario con un grupo existente.
    -- NOT NULL: todo horario debe pertenecer a un grupo.
    -- ON DELETE CASCADE: si se elimina un grupo, se eliminan automáticamente
    -- sus horarios asociados, porque no tienen sentido sin el grupo.

    dia_semana  SMALLINT NOT NULL CHECK (dia_semana BETWEEN 1 AND 7),
    -- NOT NULL: el día de la semana es obligatorio.
    -- CHECK: solamente admite valores entre 1 y 7.
    -- Convención: 1 = lunes y 7 = domingo.

    hora_inicio TIME NOT NULL,
    -- NOT NULL: todo horario debe tener una hora de inicio.

    hora_fin    TIME NOT NULL,
    -- NOT NULL: todo horario debe tener una hora de finalización.

    CONSTRAINT ck_horario_horas CHECK (hora_fin > hora_inicio),
    -- CHECK: garantiza que la hora de finalización sea posterior
    -- a la hora de inicio.

    CONSTRAINT uq_horario_grupo_dia_hora
        UNIQUE (id_grupo, dia_semana, hora_inicio)
    -- UNIQUE compuesto: impide registrar dos horarios de un mismo grupo
    -- que comiencen el mismo día a la misma hora.
);


-- ---------------------------------------------------------------------
-- ESQUEMA DE EVALUACIÓN DE CADA GRUPO
-- Define los tipos de evaluación y su porcentaje dentro de la nota final.
-- Extensión de la Entrega 1: reglas RN-28 a RN-31 por trigger, sección 03.
-- ---------------------------------------------------------------------

CREATE TABLE esquema_evaluacion (
    id_esquema         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- PRIMARY KEY: identificador único de cada componente de evaluación.

    id_grupo           INT NOT NULL
        REFERENCES grupo(id_grupo) ON DELETE CASCADE,
    -- FOREIGN KEY: vincula el esquema de evaluación con un grupo existente.
    -- NOT NULL: todo esquema debe estar asociado a un grupo.
    -- ON DELETE CASCADE: al eliminar un grupo se eliminan sus componentes
    -- de evaluación, ya que dependen de él.

    id_tipo_evaluacion INT NOT NULL
        REFERENCES tipo_evaluacion(id_tipo_evaluacion) ON DELETE RESTRICT,
    -- FOREIGN KEY: indica qué tipo de evaluación se utiliza.
    -- NOT NULL: todo componente debe tener un tipo de evaluación.
    -- ON DELETE RESTRICT: impide eliminar un tipo de evaluación
    -- que esté siendo utilizado en un esquema.

    porcentaje         NUMERIC(5,2) NOT NULL
        CHECK (porcentaje > 0 AND porcentaje <= 100),
    -- NOT NULL: todo componente debe tener un porcentaje definido.
    -- CHECK: el porcentaje debe ser mayor que cero y menor o igual a 100.

    CONSTRAINT uq_esquema_grupo_tipo
        UNIQUE (id_grupo, id_tipo_evaluacion)
    -- UNIQUE compuesto: impide registrar dos componentes del mismo tipo
    -- de evaluación para un mismo grupo.
);


-- ---------------------------------------------------------------------
-- INSCRIPCIONES Y CALIFICACIONES
-- ---------------------------------------------------------------------

CREATE TABLE inscripcion (
    id_inscripcion    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- PRIMARY KEY: identificador único de cada inscripción.

    id_estudiante     INT NOT NULL
        REFERENCES estudiante(id_estudiante) ON DELETE RESTRICT,
    -- FOREIGN KEY: relaciona la inscripción con un estudiante existente.
    -- NOT NULL: toda inscripción debe tener un estudiante asociado.
    -- ON DELETE RESTRICT: impide eliminar un estudiante que tenga inscripciones.

    id_grupo          INT NOT NULL
        REFERENCES grupo(id_grupo) ON DELETE RESTRICT,
    -- FOREIGN KEY: relaciona la inscripción con un grupo existente.
    -- NOT NULL: toda inscripción debe pertenecer a un grupo.
    -- ON DELETE RESTRICT: impide eliminar un grupo que tenga inscripciones.

    fecha_inscripcion TIMESTAMP NOT NULL DEFAULT now(),
    -- NOT NULL: toda inscripción debe registrar su fecha.
    -- DEFAULT now(): asigna automáticamente la fecha y hora del registro.

    estado            VARCHAR(10) NOT NULL DEFAULT 'Inscrito',
    -- NOT NULL: toda inscripción debe tener un estado.
    -- DEFAULT: las nuevas inscripciones comienzan en estado Inscrito.

    CONSTRAINT ck_inscripcion_estado
        CHECK (estado IN ('Inscrito', 'Retirado', 'EnEspera')),
    -- CHECK: restringe el estado a Inscrito, Retirado o EnEspera.
    -- RN-18: garantiza que las inscripciones utilicen estados válidos.

    CONSTRAINT uq_inscripcion_estudiante_grupo
        UNIQUE (id_estudiante, id_grupo)
    -- UNIQUE compuesto: impide que un estudiante se inscriba más de una vez
    -- en el mismo grupo.
    -- RN-17: garantiza una única inscripción por estudiante y grupo.
);

CREATE TABLE calificacion (
    id_calificacion    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- PRIMARY KEY: identificador único de cada calificación.

    id_inscripcion     INT NOT NULL
        REFERENCES inscripcion(id_inscripcion) ON DELETE RESTRICT,
    -- FOREIGN KEY: relaciona la calificación con una inscripción existente.
    -- NOT NULL: toda calificación debe pertenecer a una inscripción.
    -- ON DELETE RESTRICT: impide eliminar una inscripción que tenga calificaciones.

    id_tipo_evaluacion INT NOT NULL
        REFERENCES tipo_evaluacion(id_tipo_evaluacion) ON DELETE RESTRICT,
    -- FOREIGN KEY: identifica el tipo de evaluación al que corresponde la nota.
    -- NOT NULL: toda calificación debe tener un tipo de evaluación.
    -- ON DELETE RESTRICT: impide eliminar un tipo de evaluación que tenga notas registradas.

    nota               NUMERIC(3,1) NOT NULL
        CHECK (nota BETWEEN 0.0 AND 5.0),
    -- NOT NULL: toda calificación debe tener una nota.
    -- CHECK: restringe las notas al rango de 0.0 a 5.0.
    -- RN-23: valida que las calificaciones estén dentro de la escala permitida.

    fecha_registro     TIMESTAMP NOT NULL DEFAULT now(),
    -- NOT NULL: toda calificación debe registrar su fecha.
    -- DEFAULT now(): asigna automáticamente la fecha y hora de registro.

    CONSTRAINT uq_calificacion_inscripcion_tipo
        UNIQUE (id_inscripcion, id_tipo_evaluacion)
    -- UNIQUE compuesto: impide registrar más de una calificación
    -- del mismo tipo de evaluación para una misma inscripción.
    -- RN-25: garantiza una única nota por inscripción y tipo de evaluación.
);


-- ---------------------------------------------------------------------
-- BITÁCORA DE AUDITORÍA
-- Almacena las operaciones realizadas sobre el sistema.
-- La inmutabilidad se implementa mediante un trigger (RN-27).
-- ---------------------------------------------------------------------

CREATE TABLE bitacora (
    id_bitacora      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- PRIMARY KEY: identificador único de cada registro de auditoría.

    id_usuario       INT
        REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
    -- FOREIGN KEY: relaciona el registro de auditoría con el usuario
    -- que realizó la operación.
    -- Puede ser NULL cuando no exista un usuario asociado a la operación.
    -- ON DELETE RESTRICT: impide eliminar usuarios que tengan registros
    -- asociados en la bitácora.

    accion           VARCHAR(20) NOT NULL
        CHECK (accion IN ('CREAR', 'MODIFICAR', 'ELIMINAR', 'CAMBIO_ESTADO',
                          'INSCRIPCION', 'CAMBIO_CLAVE')),
    -- NOT NULL: toda entrada de auditoría debe indicar una acción.
    -- CHECK: restringe las acciones a las operaciones permitidas.
    -- Evita registrar tipos de operación no contemplados.

    entidad          VARCHAR(40) NOT NULL,
    -- NOT NULL: identifica obligatoriamente la entidad afectada.

    id_entidad       VARCHAR(40),
    -- Identificador del registro afectado en la entidad correspondiente.
    -- Es opcional porque puede no existir un registro específico asociado.

    datos_anteriores JSONB,
    -- Almacena los datos anteriores a una modificación o eliminación.
    -- JSONB permite guardar información estructurada en formato JSON.
    -- Es opcional cuando no existen datos anteriores.

    datos_nuevos     JSONB,
    -- Almacena los datos resultantes de una creación o modificación.
    -- Es opcional cuando no existen datos nuevos.

    fecha_hora       TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- NOT NULL: todo evento debe tener una fecha y hora.
    -- DEFAULT now(): registra automáticamente el momento de la operación.

    ip_origen        INET
    -- Almacena la dirección IP desde la cual se realizó la operación.
    -- INET: tipo de dato de PostgreSQL para direcciones IPv4 e IPv6.
    -- Es opcional cuando no se dispone de la dirección de origen.
);