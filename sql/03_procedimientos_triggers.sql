-- =====================================================================
-- Proyecto Final - Entrega 2 · Sistema de Gestión Académica Reformado
-- Archivo 03_procedimientos_triggers.sql
-- Ejecutar después de 01_create.sql y 02_datos.sql
-- Requiere PostgreSQL 14+ (CREATE OR REPLACE TRIGGER)
--
-- Contenido
--   A. Triggers de reglas de negocio (RN-06, 07, 15, 16, 19, 20, 21, 22, 24, 26, 27)
--      + auditoría de cambio de estado de grupo (RNF-05)
--      + reglas nuevas del esquema de evaluación (RN-28 a RN-31)
--   B. Casos de uso: RF-09 inscribir, RF-06 crear grupo, RF-03 autenticar,
--      RF-17 reporte de rendimiento ponderado y definir esquema de evaluación
--      (la vista vw_definitiva_inscripcion que usa RF-17 está en 04_vistas.sql)
--
-- Convención de auditoría: la aplicación ejecuta, al abrir la sesión de base
-- de datos de cada usuario,  SET app.id_usuario = '<id_usuario>';  y la
-- bitácora lo usa como "usuario" de cada acción.
-- =====================================================================

-- =====================================================================
-- A. TRIGGERS
-- =====================================================================

-- ---------------------------------------------------------------------
-- RN-06 / RN-07: el perfil (estudiante, docente, decano) solo puede
-- asociarse a un usuario cuyo rol coincida. BEFORE INSERT/UPDATE.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_rol_usuario()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_rol      VARCHAR(30);
    v_esperado TEXT := TG_ARGV[0];
BEGIN
    SELECT r.nombre INTO v_rol
    FROM usuario u JOIN rol r ON r.id_rol = u.id_rol
    WHERE u.id_usuario = NEW.id_usuario;

    IF v_rol IS NULL THEN
        RAISE EXCEPTION 'El usuario % no existe', NEW.id_usuario;
    END IF;
    IF v_rol <> v_esperado THEN
        RAISE EXCEPTION 'El usuario % tiene el rol "%" y no puede registrarse como %',
            NEW.id_usuario, v_rol, lower(v_esperado);
    END IF;
    RETURN NEW;
END $$;

CREATE OR REPLACE TRIGGER trg_estudiante_rn06_rol            -- RN-06
    BEFORE INSERT OR UPDATE OF id_usuario ON estudiante
    FOR EACH ROW EXECUTE FUNCTION fn_validar_rol_usuario('Estudiante');

CREATE OR REPLACE TRIGGER trg_docente_rn07_rol               -- RN-07
    BEFORE INSERT OR UPDATE OF id_usuario ON docente
    FOR EACH ROW EXECUTE FUNCTION fn_validar_rol_usuario('Docente');

CREATE OR REPLACE TRIGGER trg_decano_rn07_rol                -- misma lógica para decanos
    BEFORE INSERT OR UPDATE OF id_usuario ON decano
    FOR EACH ROW EXECUTE FUNCTION fn_validar_rol_usuario('Decano');

-- Complemento de RN-06/07: no se puede cambiar el rol de un usuario que ya
-- tiene un perfil de otro rol (RF-02).
CREATE OR REPLACE FUNCTION fn_proteger_cambio_rol()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_nuevo VARCHAR(30);
BEGIN
    SELECT nombre INTO v_nuevo FROM rol WHERE id_rol = NEW.id_rol;
    IF (v_nuevo <> 'Estudiante' AND EXISTS (SELECT 1 FROM estudiante WHERE id_usuario = NEW.id_usuario))
    OR (v_nuevo <> 'Docente'    AND EXISTS (SELECT 1 FROM docente    WHERE id_usuario = NEW.id_usuario))
    OR (v_nuevo <> 'Decano'     AND EXISTS (SELECT 1 FROM decano     WHERE id_usuario = NEW.id_usuario))
    THEN
        RAISE EXCEPTION 'No se puede cambiar el rol del usuario % a "%": tiene un perfil asociado de otro rol',
            NEW.id_usuario, v_nuevo;
    END IF;
    RETURN NEW;
END $$;

CREATE OR REPLACE TRIGGER trg_usuario_rn06_cambio_rol
    BEFORE UPDATE OF id_rol ON usuario
    FOR EACH ROW EXECUTE FUNCTION fn_proteger_cambio_rol();

-- ---------------------------------------------------------------------
-- RN-15: un docente no puede tener dos grupos con horarios traslapados en
-- el mismo periodo. Se valida al insertar/modificar un horario y al
-- reasignar docente o periodo de un grupo (RF-07).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_traslape_docente()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_conf RECORD;
BEGIN
    IF TG_TABLE_NAME = 'horario_grupo' THEN
        SELECT h2.id_grupo, h2.dia_semana, h2.hora_inicio, h2.hora_fin INTO v_conf
        FROM grupo g
        JOIN grupo g2         ON g2.id_docente = g.id_docente AND g2.id_periodo = g.id_periodo
        JOIN horario_grupo h2 ON h2.id_grupo = g2.id_grupo
        WHERE g.id_grupo = NEW.id_grupo
          AND h2.id_horario <> NEW.id_horario
          AND h2.dia_semana = NEW.dia_semana
          AND h2.hora_inicio < NEW.hora_fin AND NEW.hora_inicio < h2.hora_fin
        LIMIT 1;
    ELSE  -- grupo: cambió el docente o el periodo; se revisan todos sus horarios
        SELECT h2.id_grupo, h2.dia_semana, h2.hora_inicio, h2.hora_fin INTO v_conf
        FROM horario_grupo h
        JOIN grupo g2         ON g2.id_docente = NEW.id_docente AND g2.id_periodo = NEW.id_periodo
                             AND g2.id_grupo <> NEW.id_grupo
        JOIN horario_grupo h2 ON h2.id_grupo = g2.id_grupo
        WHERE h.id_grupo = NEW.id_grupo
          AND h2.dia_semana = h.dia_semana
          AND h2.hora_inicio < h.hora_fin AND h.hora_inicio < h2.hora_fin
        LIMIT 1;
    END IF;

    IF FOUND THEN
        RAISE EXCEPTION 'Conflicto de horario del docente: ya dicta el grupo % el día % de % a % en ese periodo',
            v_conf.id_grupo, v_conf.dia_semana, v_conf.hora_inicio, v_conf.hora_fin;
    END IF;
    RETURN NEW;
END $$;

CREATE OR REPLACE TRIGGER trg_horario_rn15_docente
    BEFORE INSERT OR UPDATE OF dia_semana, hora_inicio, hora_fin ON horario_grupo
    FOR EACH ROW EXECUTE FUNCTION fn_validar_traslape_docente();

CREATE OR REPLACE TRIGGER trg_grupo_rn15_docente
    BEFORE UPDATE OF id_docente, id_periodo ON grupo
    FOR EACH ROW EXECUTE FUNCTION fn_validar_traslape_docente();

-- ---------------------------------------------------------------------
-- RN-16: un espacio físico no puede asignarse a dos grupos con horarios
-- traslapados en el mismo periodo.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_traslape_espacio()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_conf RECORD;
BEGIN
    IF TG_TABLE_NAME = 'horario_grupo' THEN
        SELECT h2.id_grupo, h2.dia_semana, h2.hora_inicio, h2.hora_fin INTO v_conf
        FROM grupo g
        JOIN grupo g2         ON g2.id_espacio = g.id_espacio AND g2.id_periodo = g.id_periodo
        JOIN horario_grupo h2 ON h2.id_grupo = g2.id_grupo
        WHERE g.id_grupo = NEW.id_grupo
          AND h2.id_horario <> NEW.id_horario
          AND h2.dia_semana = NEW.dia_semana
          AND h2.hora_inicio < NEW.hora_fin AND NEW.hora_inicio < h2.hora_fin
        LIMIT 1;
    ELSE
        SELECT h2.id_grupo, h2.dia_semana, h2.hora_inicio, h2.hora_fin INTO v_conf
        FROM horario_grupo h
        JOIN grupo g2         ON g2.id_espacio = NEW.id_espacio AND g2.id_periodo = NEW.id_periodo
                             AND g2.id_grupo <> NEW.id_grupo
        JOIN horario_grupo h2 ON h2.id_grupo = g2.id_grupo
        WHERE h.id_grupo = NEW.id_grupo
          AND h2.dia_semana = h.dia_semana
          AND h2.hora_inicio < h.hora_fin AND h.hora_inicio < h2.hora_fin
        LIMIT 1;
    END IF;

    IF FOUND THEN
        RAISE EXCEPTION 'Conflicto de espacio físico: ya está asignado al grupo % el día % de % a % en ese periodo',
            v_conf.id_grupo, v_conf.dia_semana, v_conf.hora_inicio, v_conf.hora_fin;
    END IF;
    RETURN NEW;
END $$;

CREATE OR REPLACE TRIGGER trg_horario_rn16_espacio
    BEFORE INSERT OR UPDATE OF dia_semana, hora_inicio, hora_fin ON horario_grupo
    FOR EACH ROW EXECUTE FUNCTION fn_validar_traslape_espacio();

CREATE OR REPLACE TRIGGER trg_grupo_rn16_espacio
    BEFORE UPDATE OF id_espacio, id_periodo ON grupo
    FOR EACH ROW EXECUTE FUNCTION fn_validar_traslape_espacio();

-- ---------------------------------------------------------------------
-- RN-19: solo se inscribe en grupos Abiertos.
-- Este trigger también bloquea la fila del grupo (FOR UPDATE): como los
-- triggers BEFORE de una misma tabla se ejecutan en orden alfabético, es el
-- primero en correr y serializa las inscripciones concurrentes al mismo
-- grupo antes de validar fechas, cupo y horarios.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_grupo_abierto()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_estado VARCHAR(10);
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.estado = NEW.estado THEN
        RETURN NEW;       -- no cambia el estado de la inscripción: no hay nada que validar
    END IF;

    SELECT estado INTO v_estado FROM grupo WHERE id_grupo = NEW.id_grupo FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El grupo % no existe', NEW.id_grupo;
    END IF;
    IF v_estado <> 'Abierto' THEN
        RAISE EXCEPTION 'El grupo % está en estado %: solo se permiten inscripciones en grupos Abierto',
            NEW.id_grupo, v_estado;
    END IF;
    RETURN NEW;
END $$;

CREATE OR REPLACE TRIGGER trg_insc_rn19_grupo_abierto
    BEFORE INSERT OR UPDATE OF estado ON inscripcion
    FOR EACH ROW WHEN (NEW.estado IN ('Inscrito', 'EnEspera'))
    EXECUTE FUNCTION fn_validar_grupo_abierto();

-- ---------------------------------------------------------------------
-- RN-20: la fecha de inscripción debe estar dentro de la ventana del grupo.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_fecha_inscripcion()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_ini DATE;
    v_fin DATE;
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.estado = NEW.estado THEN
        RETURN NEW;
    END IF;

    SELECT fecha_inicio_inscripcion, fecha_fin_inscripcion INTO v_ini, v_fin
    FROM grupo WHERE id_grupo = NEW.id_grupo;

    IF NEW.fecha_inscripcion::date NOT BETWEEN v_ini AND v_fin THEN
        RAISE EXCEPTION 'La fecha de inscripción (%) está fuera del periodo de inscripción del grupo % (% a %)',
            NEW.fecha_inscripcion::date, NEW.id_grupo, v_ini, v_fin;
    END IF;
    RETURN NEW;
END $$;

CREATE OR REPLACE TRIGGER trg_insc_rn20_fecha
    BEFORE INSERT OR UPDATE OF estado ON inscripcion
    FOR EACH ROW WHEN (NEW.estado IN ('Inscrito', 'EnEspera'))
    EXECUTE FUNCTION fn_validar_fecha_inscripcion();

-- ---------------------------------------------------------------------
-- RN-21: los inscritos de un grupo no pueden superar su cupo máximo.
-- El conteo se hace con la fila del grupo bloqueada por RN-19, por lo que
-- 200 intentos simultáneos sobre un cupo de 30 dejan exactamente 30 (RNF-02).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_cupo_grupo()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_cupo      SMALLINT;
    v_inscritos INT;
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.estado = NEW.estado THEN
        RETURN NEW;
    END IF;

    SELECT cupo_maximo INTO v_cupo FROM grupo WHERE id_grupo = NEW.id_grupo FOR UPDATE;
    SELECT count(*) INTO v_inscritos
    FROM inscripcion
    WHERE id_grupo = NEW.id_grupo AND estado = 'Inscrito'
      AND id_inscripcion <> NEW.id_inscripcion;

    IF v_inscritos >= v_cupo THEN
        RAISE EXCEPTION 'El grupo % no tiene cupo disponible: cupo máximo %, inscritos %',
            NEW.id_grupo, v_cupo, v_inscritos;
    END IF;
    RETURN NEW;
END $$;

CREATE OR REPLACE TRIGGER trg_insc_rn21_cupo
    BEFORE INSERT OR UPDATE OF estado ON inscripcion
    FOR EACH ROW WHEN (NEW.estado = 'Inscrito')
    EXECUTE FUNCTION fn_validar_cupo_grupo();

-- ---------------------------------------------------------------------
-- RN-22: un estudiante no puede estar inscrito en dos grupos con horarios
-- traslapados en el mismo periodo.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_traslape_estudiante()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_conf RECORD;
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.estado = NEW.estado THEN
        RETURN NEW;
    END IF;

    SELECT i.id_grupo, a.nombre AS asignatura, hi.dia_semana, hi.hora_inicio, hi.hora_fin
    INTO v_conf
    FROM grupo gn
    JOIN horario_grupo hn ON hn.id_grupo = gn.id_grupo
    JOIN inscripcion i    ON i.id_estudiante = NEW.id_estudiante
                         AND i.estado = 'Inscrito'
                         AND i.id_inscripcion <> NEW.id_inscripcion
    JOIN grupo gi         ON gi.id_grupo = i.id_grupo AND gi.id_periodo = gn.id_periodo
    JOIN horario_grupo hi ON hi.id_grupo = gi.id_grupo
                         AND hi.dia_semana = hn.dia_semana
                         AND hi.hora_inicio < hn.hora_fin AND hn.hora_inicio < hi.hora_fin
    JOIN asignatura a     ON a.id_asignatura = gi.id_asignatura
    WHERE gn.id_grupo = NEW.id_grupo
    LIMIT 1;

    IF FOUND THEN
        RAISE EXCEPTION 'Conflicto de horario: el estudiante % ya está inscrito en el grupo % (%) el día % de % a %',
            NEW.id_estudiante, v_conf.id_grupo, v_conf.asignatura,
            v_conf.dia_semana, v_conf.hora_inicio, v_conf.hora_fin;
    END IF;
    RETURN NEW;
END $$;

CREATE OR REPLACE TRIGGER trg_insc_rn22_traslape
    BEFORE INSERT OR UPDATE OF estado ON inscripcion
    FOR EACH ROW WHEN (NEW.estado = 'Inscrito')
    EXECUTE FUNCTION fn_validar_traslape_estudiante();

-- ---------------------------------------------------------------------
-- RN-24: solo se califica una inscripción en estado Inscrito.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_inscripcion_calificable()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_estado VARCHAR(10);
BEGIN
    SELECT estado INTO v_estado FROM inscripcion WHERE id_inscripcion = NEW.id_inscripcion;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La inscripción % no existe', NEW.id_inscripcion;
    END IF;
    IF v_estado <> 'Inscrito' THEN
        RAISE EXCEPTION 'No se puede registrar una calificación: la inscripción % está en estado % (debe estar Inscrito)',
            NEW.id_inscripcion, v_estado;
    END IF;
    RETURN NEW;
END $$;

CREATE OR REPLACE TRIGGER trg_calificacion_rn24_inscrito
    BEFORE INSERT OR UPDATE OF id_inscripcion ON calificacion
    FOR EACH ROW EXECUTE FUNCTION fn_validar_inscripcion_calificable();

-- ---------------------------------------------------------------------
-- RN-26 (AFTER): toda creación, modificación o eliminación de una
-- calificación queda en la bitácora con datos anteriores y nuevos.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_auditar_calificacion()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_usuario INT := NULLIF(current_setting('app.id_usuario', true), '')::INT;
    v_ip      INET := COALESCE(inet_client_addr(), '127.0.0.1'::inet);
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO bitacora (id_usuario, accion, entidad, id_entidad, datos_anteriores, datos_nuevos, ip_origen)
        VALUES (v_usuario, 'CREAR', 'calificacion', NEW.id_calificacion::text, NULL, to_jsonb(NEW), v_ip);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD IS NOT DISTINCT FROM NEW THEN
            RETURN NEW;      -- UPDATE que no cambió nada: no se audita
        END IF;
        INSERT INTO bitacora (id_usuario, accion, entidad, id_entidad, datos_anteriores, datos_nuevos, ip_origen)
        VALUES (v_usuario, 'MODIFICAR', 'calificacion', NEW.id_calificacion::text, to_jsonb(OLD), to_jsonb(NEW), v_ip);
        RETURN NEW;
    ELSE
        INSERT INTO bitacora (id_usuario, accion, entidad, id_entidad, datos_anteriores, datos_nuevos, ip_origen)
        VALUES (v_usuario, 'ELIMINAR', 'calificacion', OLD.id_calificacion::text, to_jsonb(OLD), NULL, v_ip);
        RETURN OLD;
    END IF;
END $$;

CREATE OR REPLACE TRIGGER trg_calificacion_rn26_auditoria
    AFTER INSERT OR UPDATE OR DELETE ON calificacion
    FOR EACH ROW EXECUTE FUNCTION fn_auditar_calificacion();

-- ---------------------------------------------------------------------
-- RNF-05 (AFTER): todo cambio de estado de un grupo queda en la bitácora.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_auditar_estado_grupo()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO bitacora (id_usuario, accion, entidad, id_entidad, datos_anteriores, datos_nuevos, ip_origen)
    VALUES (NULLIF(current_setting('app.id_usuario', true), '')::INT,
            'CAMBIO_ESTADO', 'grupo', NEW.id_grupo::text,
            jsonb_build_object('estado', OLD.estado),
            jsonb_build_object('estado', NEW.estado),
            COALESCE(inet_client_addr(), '127.0.0.1'::inet));
    RETURN NEW;
END $$;

CREATE OR REPLACE TRIGGER trg_grupo_auditoria_estado
    AFTER UPDATE OF estado ON grupo
    FOR EACH ROW WHEN (OLD.estado IS DISTINCT FROM NEW.estado)
    EXECUTE FUNCTION fn_auditar_estado_grupo();

-- ---------------------------------------------------------------------
-- RN-27: la bitácora no se puede modificar, eliminar ni vaciar (BEFORE).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_bitacora_inmutable()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'La bitácora es inmutable: no se permite % sobre sus registros', TG_OP;
END $$;

CREATE OR REPLACE TRIGGER trg_bitacora_rn27_inmutable
    BEFORE UPDATE OR DELETE ON bitacora
    FOR EACH ROW EXECUTE FUNCTION fn_bitacora_inmutable();

CREATE OR REPLACE TRIGGER trg_bitacora_rn27_sin_truncate
    BEFORE TRUNCATE ON bitacora
    FOR EACH STATEMENT EXECUTE FUNCTION fn_bitacora_inmutable();


-- ---------------------------------------------------------------------
-- RN-28 (nueva): los porcentajes del esquema de evaluación de un grupo no
-- pueden sumar más de 100. AFTER, para que la suma incluya la fila que cambió.
-- Bloquea la fila del grupo para que dos cambios simultáneos no se pasen de 100.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_suma_esquema()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_grupo INT := CASE WHEN TG_OP = 'DELETE' THEN OLD.id_grupo ELSE NEW.id_grupo END;
    v_suma  NUMERIC;
BEGIN
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;                       -- quitar una evaluación nunca excede 100
    END IF;
    PERFORM 1 FROM grupo WHERE id_grupo = v_grupo FOR UPDATE;
    SELECT COALESCE(SUM(porcentaje), 0) INTO v_suma FROM esquema_evaluacion WHERE id_grupo = v_grupo;
    IF v_suma > 100 THEN
        RAISE EXCEPTION 'Los porcentajes del esquema del grupo % suman % y no pueden superar 100', v_grupo, v_suma;
    END IF;
    RETURN NEW;
END $$;

CREATE OR REPLACE TRIGGER trg_esquema_rn28_suma
    AFTER INSERT OR UPDATE ON esquema_evaluacion
    FOR EACH ROW EXECUTE FUNCTION fn_validar_suma_esquema();

-- ---------------------------------------------------------------------
-- RN-29 (nueva): el esquema solo se puede cambiar mientras el grupo está
-- Abierto o Cerrado; una vez EnCurso o Finalizado los porcentajes son fijos.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_esquema_grupo_modificable()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_grupo  INT := CASE WHEN TG_OP = 'DELETE' THEN OLD.id_grupo ELSE NEW.id_grupo END;
    v_estado VARCHAR(10);
BEGIN
    SELECT estado INTO v_estado FROM grupo WHERE id_grupo = v_grupo;
    IF v_estado IN ('EnCurso', 'Finalizado') THEN
        RAISE EXCEPTION 'El esquema de evaluación del grupo % no se puede modificar: el grupo está %', v_grupo, v_estado;
    END IF;
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END $$;

CREATE OR REPLACE TRIGGER trg_esquema_rn29_modificable
    BEFORE INSERT OR UPDATE OR DELETE ON esquema_evaluacion
    FOR EACH ROW EXECUTE FUNCTION fn_esquema_grupo_modificable();

-- ---------------------------------------------------------------------
-- RN-30 (nueva): un grupo solo puede pasar a EnCurso o Finalizado si su
-- esquema de evaluación suma exactamente 100.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_esquema_completo()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_suma NUMERIC;
BEGIN
    SELECT COALESCE(SUM(porcentaje), 0) INTO v_suma FROM esquema_evaluacion WHERE id_grupo = NEW.id_grupo;
    IF v_suma <> 100 THEN
        RAISE EXCEPTION 'El grupo % no puede pasar a % porque su esquema de evaluación suma % (debe sumar 100)',
            NEW.id_grupo, NEW.estado, v_suma;
    END IF;
    RETURN NEW;
END $$;

CREATE OR REPLACE TRIGGER trg_grupo_rn30_esquema_completo
    BEFORE UPDATE OF estado ON grupo
    FOR EACH ROW WHEN (NEW.estado IN ('EnCurso', 'Finalizado') AND OLD.estado IS DISTINCT FROM NEW.estado)
    EXECUTE FUNCTION fn_validar_esquema_completo();

-- ---------------------------------------------------------------------
-- RN-31 (nueva): solo se califican tipos de evaluación que hacen parte del
-- esquema del grupo de la inscripción.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_tipo_en_esquema()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_grupo INT;
BEGIN
    SELECT id_grupo INTO v_grupo FROM inscripcion WHERE id_inscripcion = NEW.id_inscripcion;
    IF NOT EXISTS (SELECT 1 FROM esquema_evaluacion
                   WHERE id_grupo = v_grupo AND id_tipo_evaluacion = NEW.id_tipo_evaluacion) THEN
        RAISE EXCEPTION 'El tipo de evaluación % no hace parte del esquema de evaluación del grupo %',
            NEW.id_tipo_evaluacion, v_grupo;
    END IF;
    RETURN NEW;
END $$;

CREATE OR REPLACE TRIGGER trg_calificacion_rn31_esquema
    BEFORE INSERT OR UPDATE OF id_inscripcion, id_tipo_evaluacion ON calificacion
    FOR EACH ROW EXECUTE FUNCTION fn_validar_tipo_en_esquema();


-- =====================================================================
-- B. CASOS DE USO
-- =====================================================================

-- ---------------------------------------------------------------------
-- RF-09 · Inscribirse en un grupo con cupo disponible
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE pr_inscribir_estudiante(p_id_estudiante INT, p_id_grupo INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_grupo     RECORD;
    v_est       RECORD;
    v_insc      RECORD;
    v_inscritos INT;
    v_id_insc   INT;
BEGIN
    IF p_id_estudiante IS NULL OR p_id_grupo IS NULL THEN
        RAISE EXCEPTION 'Debe indicar el estudiante y el grupo';
    END IF;

    -- 1) Se bloquea la fila del grupo: desde aquí las inscripciones al mismo
    --    grupo se atienden de a una (evita sobrecupo).
    SELECT g.estado, g.cupo_maximo, g.fecha_inicio_inscripcion, g.fecha_fin_inscripcion,
           g.numero, a.nombre AS asignatura
    INTO v_grupo
    FROM grupo g JOIN asignatura a ON a.id_asignatura = g.id_asignatura
    WHERE g.id_grupo = p_id_grupo
    FOR UPDATE OF g;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El grupo % no existe', p_id_grupo;
    END IF;

    -- 2) Validaciones del estudiante
    --    La fila del estudiante se bloquea (FOR NO KEY UPDATE) después de la del grupo, siempre en
    --    ese orden: así dos inscripciones simultáneas del MISMO estudiante en grupos distintos se
    --    atienden de a una y el trigger RN-22 ve los horarios ya confirmados.
    SELECT e.id_usuario, u.estado INTO v_est
    FROM estudiante e JOIN usuario u ON u.id_usuario = e.id_usuario
    WHERE e.id_estudiante = p_id_estudiante
    FOR NO KEY UPDATE OF e;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El estudiante % no existe', p_id_estudiante;
    END IF;
    IF v_est.estado <> 'Activo' THEN
        RAISE EXCEPTION 'La cuenta del estudiante % está %: no puede inscribirse', p_id_estudiante, v_est.estado;
    END IF;

    -- 3) Validaciones del grupo
    IF v_grupo.estado <> 'Abierto' THEN
        RAISE EXCEPTION 'El grupo % (%) está en estado %: solo se permiten inscripciones en grupos Abierto',
            p_id_grupo, v_grupo.asignatura, v_grupo.estado;
    END IF;
    IF CURRENT_DATE NOT BETWEEN v_grupo.fecha_inicio_inscripcion AND v_grupo.fecha_fin_inscripcion THEN
        RAISE EXCEPTION 'Fuera del periodo de inscripción del grupo %: va del % al % y hoy es %',
            p_id_grupo, v_grupo.fecha_inicio_inscripcion, v_grupo.fecha_fin_inscripcion, CURRENT_DATE;
    END IF;

    -- 4) Duplicados (RN-17); un retiro previo permite reactivar la misma fila
    SELECT * INTO v_insc FROM inscripcion
    WHERE id_estudiante = p_id_estudiante AND id_grupo = p_id_grupo;
    IF FOUND AND v_insc.estado = 'Inscrito' THEN
        RAISE EXCEPTION 'El estudiante % ya está inscrito en el grupo %', p_id_estudiante, p_id_grupo;
    END IF;

    -- 5) Cupo
    SELECT count(*) INTO v_inscritos
    FROM inscripcion WHERE id_grupo = p_id_grupo AND estado = 'Inscrito';
    IF v_inscritos >= v_grupo.cupo_maximo THEN
        RAISE EXCEPTION 'El grupo % (%) no tiene cupo disponible: cupo máximo %, inscritos %',
            p_id_grupo, v_grupo.asignatura, v_grupo.cupo_maximo, v_inscritos;
    END IF;

    -- 6) Escritura (los triggers RN-19, 20, 21 y 22 vuelven a validar y RN-22 revisa
    --    los traslapes de horario del estudiante)
    IF v_insc.id_inscripcion IS NOT NULL THEN
        UPDATE inscripcion
        SET estado = 'Inscrito', fecha_inscripcion = now()
        WHERE id_inscripcion = v_insc.id_inscripcion
        RETURNING id_inscripcion INTO v_id_insc;
    ELSE
        INSERT INTO inscripcion (id_estudiante, id_grupo)
        VALUES (p_id_estudiante, p_id_grupo)
        RETURNING id_inscripcion INTO v_id_insc;
    END IF;

    -- 7) Auditoría de la inscripción (RNF-05)
    INSERT INTO bitacora (id_usuario, accion, entidad, id_entidad, datos_anteriores, datos_nuevos, ip_origen)
    SELECT v_est.id_usuario, 'INSCRIPCION', 'inscripcion', i.id_inscripcion::text,
           CASE WHEN v_insc.id_inscripcion IS NULL THEN NULL ELSE to_jsonb(v_insc) END,
           to_jsonb(i), COALESCE(inet_client_addr(), '127.0.0.1'::inet)
    FROM inscripcion i WHERE i.id_inscripcion = v_id_insc;

    RAISE NOTICE 'Inscripción % registrada: estudiante % en el grupo % (%). Cupos restantes: %',
        v_id_insc, p_id_estudiante, p_id_grupo, v_grupo.asignatura,
        v_grupo.cupo_maximo - v_inscritos - 1;
END $$;

-- ---------------------------------------------------------------------
-- RF-06 · Crear un grupo con sus horarios
--   p_horarios: arreglo JSON, p. ej.
--   [{"dia":1,"inicio":"07:00","fin":"09:00"},{"dia":3,"inicio":"07:00","fin":"09:00"}]
--   p_id_grupo es de salida: devuelve el id del grupo creado.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE pr_crear_grupo(
    p_id_decano        INT,
    p_id_asignatura    INT,
    p_id_docente       INT,
    p_id_periodo       INT,
    p_id_espacio       INT,
    p_cupo_maximo      INT,
    p_fecha_inicio_ins DATE,
    p_fecha_fin_ins    DATE,
    p_horarios         JSONB,
    INOUT p_id_grupo   INT DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE
    v_dec_usuario  INT;
    v_dec_facultad INT;
    v_asig_facultad INT;
    v_capacidad    INT;
    v_numero       INT;
    v_h            JSONB;
    v_dia          INT;
    v_ini          TIME;
    v_fin          TIME;
BEGIN
    IF p_id_decano IS NULL OR p_id_asignatura IS NULL OR p_id_docente IS NULL OR p_id_periodo IS NULL
       OR p_id_espacio IS NULL OR p_cupo_maximo IS NULL OR p_fecha_inicio_ins IS NULL OR p_fecha_fin_ins IS NULL THEN
        RAISE EXCEPTION 'Todos los parámetros del grupo son obligatorios';
    END IF;
    IF p_cupo_maximo <= 0 THEN
        RAISE EXCEPTION 'El cupo máximo debe ser mayor que cero (recibido: %)', p_cupo_maximo;
    END IF;
    IF p_fecha_fin_ins < p_fecha_inicio_ins THEN
        RAISE EXCEPTION 'La fecha de fin de inscripción (%) no puede ser anterior a la de inicio (%)',
            p_fecha_fin_ins, p_fecha_inicio_ins;
    END IF;
    IF p_horarios IS NULL OR jsonb_typeof(p_horarios) <> 'array' OR jsonb_array_length(p_horarios) = 0 THEN
        RAISE EXCEPTION 'Debe indicar al menos un horario como arreglo JSON [{"dia":1,"inicio":"07:00","fin":"09:00"}]';
    END IF;

    -- Decano y facultad
    SELECT d.id_usuario, d.id_facultad INTO v_dec_usuario, v_dec_facultad
    FROM decano d WHERE d.id_decano = p_id_decano;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El decano % no existe', p_id_decano;
    END IF;

    -- Se bloquea la asignatura: dos decanos creando grupos de la misma
    -- asignatura se atienden de a uno y no repiten el número de grupo.
    SELECT dep.id_facultad INTO v_asig_facultad
    FROM asignatura a JOIN departamento dep ON dep.id_departamento = a.id_departamento
    WHERE a.id_asignatura = p_id_asignatura
    FOR UPDATE OF a;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La asignatura % no existe', p_id_asignatura;
    END IF;
    IF v_asig_facultad <> v_dec_facultad THEN
        RAISE EXCEPTION 'La asignatura % no pertenece a la facultad del decano %', p_id_asignatura, p_id_decano;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM docente WHERE id_docente = p_id_docente) THEN
        RAISE EXCEPTION 'El docente % no existe', p_id_docente;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM periodo WHERE id_periodo = p_id_periodo) THEN
        RAISE EXCEPTION 'El periodo % no existe', p_id_periodo;
    END IF;
    SELECT capacidad INTO v_capacidad FROM espacio_fisico WHERE id_espacio = p_id_espacio;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El espacio físico % no existe', p_id_espacio;
    END IF;
    IF p_cupo_maximo > v_capacidad THEN
        RAISE EXCEPTION 'El cupo (%) supera la capacidad del espacio % (%)', p_cupo_maximo, p_id_espacio, v_capacidad;
    END IF;

    -- Número consecutivo del grupo dentro de asignatura y periodo
    SELECT COALESCE(max(numero), 0) + 1 INTO v_numero
    FROM grupo WHERE id_asignatura = p_id_asignatura AND id_periodo = p_id_periodo;

    INSERT INTO grupo (id_asignatura, id_docente, id_periodo, id_espacio, numero,
                       cupo_maximo, fecha_inicio_inscripcion, fecha_fin_inscripcion)
    VALUES (p_id_asignatura, p_id_docente, p_id_periodo, p_id_espacio, v_numero,
            p_cupo_maximo, p_fecha_inicio_ins, p_fecha_fin_ins)
    RETURNING id_grupo INTO p_id_grupo;

    -- Horarios: los triggers RN-15 y RN-16 rechazan cualquier traslape y, como todo
    -- ocurre dentro de la misma transacción, también se deshace el grupo recién creado.
    FOR v_h IN SELECT * FROM jsonb_array_elements(p_horarios) LOOP
        IF v_h->>'dia' IS NULL OR v_h->>'inicio' IS NULL OR v_h->>'fin' IS NULL THEN
            RAISE EXCEPTION 'Cada horario debe indicar dia, inicio y fin: %', v_h;
        END IF;
        v_dia := (v_h->>'dia')::INT;
        v_ini := (v_h->>'inicio')::TIME;
        v_fin := (v_h->>'fin')::TIME;
        IF v_dia NOT BETWEEN 1 AND 7 THEN
            RAISE EXCEPTION 'Día de la semana inválido (%): use 1 (lunes) a 7 (domingo)', v_dia;
        END IF;
        IF v_fin <= v_ini THEN
            RAISE EXCEPTION 'La hora de fin (%) debe ser posterior a la de inicio (%)', v_fin, v_ini;
        END IF;
        INSERT INTO horario_grupo (id_grupo, dia_semana, hora_inicio, hora_fin)
        VALUES (p_id_grupo, v_dia, v_ini, v_fin);
    END LOOP;

    -- Auditoría (RNF-05)
    INSERT INTO bitacora (id_usuario, accion, entidad, id_entidad, datos_nuevos, ip_origen)
    SELECT v_dec_usuario, 'CREAR', 'grupo', g.id_grupo::text, to_jsonb(g),
           COALESCE(inet_client_addr(), '127.0.0.1'::inet)
    FROM grupo g WHERE g.id_grupo = p_id_grupo;

    RAISE NOTICE 'Grupo % creado (asignatura %, grupo número %) con % horario(s)',
        p_id_grupo, p_id_asignatura, v_numero, jsonb_array_length(p_horarios);
END $$;

-- ---------------------------------------------------------------------
-- RF-03 · Autenticar a un usuario y registrar su último acceso
-- Devuelve una fila con los datos básicos de la sesión.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_autenticar_usuario(p_nombre_usuario TEXT, p_contrasena TEXT)
RETURNS TABLE (id_usuario INT, nombre_completo TEXT, rol VARCHAR, ultimo_acceso TIMESTAMPTZ)
LANGUAGE plpgsql AS $$
#variable_conflict use_column
DECLARE
    v_user RECORD;
BEGIN
    IF p_nombre_usuario IS NULL OR btrim(p_nombre_usuario) = '' OR p_contrasena IS NULL OR p_contrasena = '' THEN
        RAISE EXCEPTION 'Debe indicar el nombre de usuario y la contraseña';
    END IF;

    SELECT u.id_usuario, u.nombres || ' ' || u.apellidos AS nombre_completo,
           u.contrasena_hash, u.estado, r.nombre AS rol
    INTO v_user
    FROM usuario u JOIN rol r ON r.id_rol = u.id_rol
    WHERE u.nombre_usuario = p_nombre_usuario;

    -- Mismo mensaje si el usuario no existe o la contraseña es incorrecta
    -- (no se revela cuál de las dos falló).
    IF NOT FOUND OR v_user.contrasena_hash <> crypt(p_contrasena, v_user.contrasena_hash) THEN
        RAISE EXCEPTION 'Usuario o contraseña incorrectos';
    END IF;
    IF v_user.estado <> 'Activo' THEN
        RAISE EXCEPTION 'La cuenta de "%" está en estado %: no puede iniciar sesión',
            p_nombre_usuario, v_user.estado;
    END IF;

    UPDATE usuario SET ultimo_acceso = now() WHERE usuario.id_usuario = v_user.id_usuario;

    RETURN QUERY
    SELECT u.id_usuario, v_user.nombre_completo, v_user.rol, u.ultimo_acceso
    FROM usuario u WHERE u.id_usuario = v_user.id_usuario;
END $$;

-- ---------------------------------------------------------------------
-- RF-17 · Reporte de rendimiento de una asignatura propia del docente
-- Una fila por periodo: estudiantes con notas, promedio, aprobados (>= 3,0)
-- y reprobados. La nota de un estudiante es su promedio ponderado según el
-- esquema de evaluación del grupo (igual a la definitiva cuando ya se evaluó el
-- 100 %; en grupos en curso es la nota de lo evaluado hasta hoy).
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_reporte_rendimiento_asignatura(INT, INT, INT);
CREATE FUNCTION fn_reporte_rendimiento_asignatura(
    p_id_docente INT, p_id_asignatura INT, p_id_periodo INT DEFAULT NULL)
RETURNS TABLE (periodo VARCHAR, estudiantes BIGINT, promedio NUMERIC,
               aprobados BIGINT, reprobados BIGINT, tasa_aprobacion NUMERIC,
               evaluado_pct NUMERIC)
LANGUAGE plpgsql AS $$
BEGIN
    IF p_id_docente IS NULL OR p_id_asignatura IS NULL THEN
        RAISE EXCEPTION 'Debe indicar el docente y la asignatura';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM docente d WHERE d.id_docente = p_id_docente) THEN
        RAISE EXCEPTION 'El docente % no existe', p_id_docente;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM asignatura a WHERE a.id_asignatura = p_id_asignatura) THEN
        RAISE EXCEPTION 'La asignatura % no existe', p_id_asignatura;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM grupo g
                   WHERE g.id_docente = p_id_docente AND g.id_asignatura = p_id_asignatura
                     AND (p_id_periodo IS NULL OR g.id_periodo = p_id_periodo)) THEN
        RAISE EXCEPTION '%', format('El docente %s no dicta grupos de la asignatura %s%s',
            p_id_docente, p_id_asignatura,
            CASE WHEN p_id_periodo IS NULL THEN '' ELSE ' en el periodo ' || p_id_periodo END);
    END IF;

    RETURN QUERY
    SELECT p.codigo,
           COUNT(*),
           ROUND(AVG(v.promedio_ponderado), 2),
           COUNT(*) FILTER (WHERE v.promedio_ponderado >= 3.0),
           COUNT(*) FILTER (WHERE v.promedio_ponderado <  3.0),
           ROUND(100.0 * COUNT(*) FILTER (WHERE v.promedio_ponderado >= 3.0) / COUNT(*), 1),
           ROUND(AVG(v.porcentaje_evaluado), 1)
    FROM grupo g
    JOIN vw_definitiva_inscripcion v ON v.id_grupo = g.id_grupo AND v.promedio_ponderado IS NOT NULL
    JOIN periodo p ON p.id_periodo = g.id_periodo
    WHERE g.id_docente = p_id_docente
      AND g.id_asignatura = p_id_asignatura
      AND (p_id_periodo IS NULL OR g.id_periodo = p_id_periodo)
    GROUP BY p.codigo
    ORDER BY p.codigo;
END $$;

-- ---------------------------------------------------------------------
-- Definir el esquema de evaluación de un grupo (actor: Docente; apoya RF-13 y RF-17)
--   p_esquema: arreglo JSON, p. ej.
--   [{"tipo":"Parcial 1","porcentaje":30},{"tipo":"Examen final","porcentaje":70}]
-- Reemplaza por completo el esquema anterior del grupo, en una sola transacción.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE pr_definir_esquema_evaluacion(p_id_docente INT, p_id_grupo INT, p_esquema JSONB)
LANGUAGE plpgsql AS $$
DECLARE
    v_grupo     RECORD;
    v_usuario   INT;
    v_item      JSONB;
    v_nombre    TEXT;
    v_pct       NUMERIC;
    v_tipo      INT;
    v_tipos     INT[] := '{}';
    v_suma      NUMERIC := 0;
    v_anterior  JSONB;
BEGIN
    IF p_id_docente IS NULL OR p_id_grupo IS NULL THEN
        RAISE EXCEPTION 'Debe indicar el docente y el grupo';
    END IF;
    IF p_esquema IS NULL OR jsonb_typeof(p_esquema) <> 'array' OR jsonb_array_length(p_esquema) = 0 THEN
        RAISE EXCEPTION 'Debe indicar el esquema como arreglo JSON [{"tipo":"Parcial 1","porcentaje":30}, ...]';
    END IF;

    SELECT g.id_docente, g.estado INTO v_grupo FROM grupo g WHERE g.id_grupo = p_id_grupo FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El grupo % no existe', p_id_grupo;
    END IF;
    SELECT id_usuario INTO v_usuario FROM docente WHERE id_docente = p_id_docente;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El docente % no existe', p_id_docente;
    END IF;
    IF v_grupo.id_docente <> p_id_docente THEN
        RAISE EXCEPTION 'El grupo % no es del docente %: solo el docente del grupo define su esquema', p_id_grupo, p_id_docente;
    END IF;
    IF v_grupo.estado IN ('EnCurso', 'Finalizado') THEN
        RAISE EXCEPTION 'El esquema del grupo % no se puede modificar: el grupo está %', p_id_grupo, v_grupo.estado;
    END IF;

    -- Validar cada elemento antes de escribir
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_esquema) LOOP
        v_nombre := v_item->>'tipo';
        IF v_nombre IS NULL OR v_item->>'porcentaje' IS NULL THEN
            RAISE EXCEPTION 'Cada evaluación debe indicar tipo y porcentaje: %', v_item;
        END IF;
        v_pct := (v_item->>'porcentaje')::NUMERIC;
        IF v_pct <= 0 OR v_pct > 100 THEN
            RAISE EXCEPTION 'El porcentaje de "%" debe estar entre 0 (exclusivo) y 100 (recibido: %)', v_nombre, v_pct;
        END IF;
        SELECT id_tipo_evaluacion INTO v_tipo FROM tipo_evaluacion WHERE nombre = v_nombre;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'El tipo de evaluación "%" no existe', v_nombre;
        END IF;
        IF v_tipo = ANY (v_tipos) THEN
            RAISE EXCEPTION 'El tipo de evaluación "%" está repetido en el esquema', v_nombre;
        END IF;
        v_tipos := v_tipos || v_tipo;
        v_suma  := v_suma + v_pct;
    END LOOP;
    IF v_suma <> 100 THEN
        RAISE EXCEPTION 'Los porcentajes del esquema deben sumar 100 (suman %)', v_suma;
    END IF;
    IF EXISTS (SELECT 1 FROM calificacion c JOIN inscripcion i ON i.id_inscripcion = c.id_inscripcion
               WHERE i.id_grupo = p_id_grupo AND NOT (c.id_tipo_evaluacion = ANY (v_tipos))) THEN
        RAISE EXCEPTION 'El grupo % ya tiene calificaciones de tipos que el nuevo esquema no incluye', p_id_grupo;
    END IF;

    -- Reemplazo del esquema
    SELECT COALESCE(jsonb_agg(jsonb_build_object('id_tipo_evaluacion', id_tipo_evaluacion, 'porcentaje', porcentaje)), '[]'::jsonb)
    INTO v_anterior FROM esquema_evaluacion WHERE id_grupo = p_id_grupo;

    DELETE FROM esquema_evaluacion WHERE id_grupo = p_id_grupo;
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_esquema) LOOP
        INSERT INTO esquema_evaluacion (id_grupo, id_tipo_evaluacion, porcentaje)
        SELECT p_id_grupo, t.id_tipo_evaluacion, (v_item->>'porcentaje')::NUMERIC
        FROM tipo_evaluacion t WHERE t.nombre = v_item->>'tipo';
    END LOOP;

    INSERT INTO bitacora (id_usuario, accion, entidad, id_entidad, datos_anteriores, datos_nuevos, ip_origen)
    SELECT v_usuario, 'MODIFICAR', 'esquema_evaluacion', p_id_grupo::text, v_anterior,
           COALESCE(jsonb_agg(jsonb_build_object('id_tipo_evaluacion', e.id_tipo_evaluacion, 'porcentaje', e.porcentaje)), '[]'::jsonb),
           COALESCE(inet_client_addr(), '127.0.0.1'::inet)
    FROM esquema_evaluacion e WHERE e.id_grupo = p_id_grupo;

    RAISE NOTICE 'Esquema del grupo % definido con % evaluaciones (suma 100)', p_id_grupo, jsonb_array_length(p_esquema);
END $$;
