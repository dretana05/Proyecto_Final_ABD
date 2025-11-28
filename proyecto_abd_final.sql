-- Proyecto de catedra: GimnasioReserva --
-- 1. Preparación de la base de datos.

-- Creando base de datos. --
USE MASTER;

CREATE DATABASE GimnasioReservas
CONTAINMENT = PARTIAL;

USE GimnasioReservas;

-- Creando esquemas. --

CREATE SCHEMA Negocio;
CREATE SCHEMA Auditoria;
CREATE SCHEMA Reportes;
CREATE SCHEMA Config;

-- Creando tablas principales. --

-- Tabla: SOCIO
CREATE TABLE Negocio.SOCIO (
id INT IDENTITY(1,1) PRIMARY KEY,
nombre NVARCHAR(100) NOT NULL,
telefono NVARCHAR(20) NOT NULL,
email NVARCHAR(100) NOT NULL UNIQUE,
genero CHAR(1) NOT NULL CHECK (genero IN ('M', 'F')),
fecha_registro DATE NOT NULL DEFAULT GETDATE(),
estado NVARCHAR(20) NOT NULL DEFAULT 'activo' CHECK (estado IN ('activo', 'inactivo')),
dui NVARCHAR(10) UNIQUE
);

-- Tabla: MEMBRESIA
CREATE TABLE Negocio.MEMBRESIA (
id INT IDENTITY(1,1) PRIMARY KEY,
tipo NVARCHAR(50) NOT NULL CHECK (tipo IN ('Básica', 'Premium', 'VIP')),
duracion NVARCHAR(20) NOT NULL CHECK (duracion IN ('Mensual', 'Trimestral', 'Anual')),
precio DECIMAL(10,2) NOT NULL CHECK (precio > 0),
CONSTRAINT UQ_MEMBRESIA_TIPO_DURACION UNIQUE (tipo, duracion)
);

-- Tabla: ENTRENADOR
CREATE TABLE Negocio.ENTRENADOR (
id INT IDENTITY(1,1) PRIMARY KEY,
nombre NVARCHAR(100) NOT NULL,
telefono NVARCHAR(20) NOT NULL,
email NVARCHAR(100) NOT NULL UNIQUE,
fecha_inicio_inscripcion DATE NOT NULL,
fecha_final_inscripcion DATE NULL,
salario DECIMAL(10,2) NOT NULL CHECK (salario > 0),
especialidad NVARCHAR(100) NOT NULL CHECK (especialidad IN ('Yoga', 'Spinning', 'CrossFit', 'Musculación', 'Calistenia','Pilates'))
);

-- Tabla: FACTURA
CREATE TABLE Negocio.FACTURA (
id INT IDENTITY(1,1) PRIMARY KEY,
metodo_pago NVARCHAR(50) NOT NULL CHECK (metodo_pago IN ('efectivo', 'tarjeta', 'transferencia')),
monto DECIMAL(10,2) NOT NULL CHECK (monto > 0),
fecha_pago DATETIME NOT NULL DEFAULT GETDATE(),
id_socio INT NOT NULL,
id_membresia INT NOT NULL,
CONSTRAINT FK_FACTURA_SOCIO FOREIGN KEY (id_socio) REFERENCES Negocio.SOCIO(id) ON DELETE CASCADE,
CONSTRAINT FK_FACTURA_MEMBRESIA FOREIGN KEY (id_membresia) REFERENCES Negocio.MEMBRESIA(id) ON DELETE CASCADE
);

-- Tabla: CLASE
CREATE TABLE Negocio.CLASE (
id INT IDENTITY(1,1) PRIMARY KEY,
tipo NVARCHAR(50) NOT NULL,
horario TIME NOT NULL,
duracion_minutos INT NOT NULL CHECK (duracion_minutos BETWEEN 30 AND 120),
cupo INT NOT NULL CHECK (cupo > 0),
id_entrenador INT NOT NULL,
CONSTRAINT FK_CLASE_ENTRENADOR FOREIGN KEY (id_entrenador) REFERENCES Negocio.ENTRENADOR(id) ON DELETE CASCADE
);

-- Tabla: RESERVA
CREATE TABLE Negocio.RESERVA (
id INT IDENTITY(1,1) PRIMARY KEY,
fecha_reserva DATE NOT NULL DEFAULT GETDATE(),
fecha_clase DATE NOT NULL,
id_socio INT NOT NULL,
id_clase INT NOT NULL,
CONSTRAINT FK_RESERVA_SOCIO FOREIGN KEY (id_socio) REFERENCES Negocio.SOCIO(id) ON DELETE CASCADE,
CONSTRAINT FK_RESERVA_CLASE FOREIGN KEY (id_clase) REFERENCES Negocio.CLASE(id),
CONSTRAINT UQ_RESERVA_SOCIO_CLASE_FECHA UNIQUE (id_socio, id_clase, fecha_clase),
CONSTRAINT CK_RESERVA_FECHAS CHECK (fecha_clase >= fecha_reserva)
);

-- Creando tablas de auditoria. --
CREATE TABLE Auditoria.SOCIO_Audit (
audit_id INT IDENTITY(1,1) PRIMARY KEY,
id_socio INT NOT NULL,
operacion VARCHAR(10) NOT NULL,
nombre_anterior VARCHAR(100),
nombre_nuevo VARCHAR(100),
email_anterior VARCHAR(100),
email_nuevo VARCHAR(100),
estado_anterior VARCHAR(20),
estado_nuevo VARCHAR(20),
usuario VARCHAR(100) DEFAULT SYSTEM_USER,
fecha_operacion DATETIME DEFAULT GETDATE(),
host_name VARCHAR(100) DEFAULT HOST_NAME(),
app_name VARCHAR(100) DEFAULT APP_NAME()
);

CREATE TABLE Auditoria.FACTURA_Audit (
audit_id INT IDENTITY(1,1) PRIMARY KEY,
id_factura INT NOT NULL,
operacion VARCHAR(10) NOT NULL,
id_socio_anterior INT,
id_socio_nuevo INT,
monto_anterior DECIMAL(10,2),
monto_nuevo DECIMAL(10,2),
metodo_pago_anterior VARCHAR(50),
metodo_pago_nuevo VARCHAR(50),
fecha_pago_anterior DATE,
fecha_pago_nuevo DATE,
usuario VARCHAR(100) DEFAULT SYSTEM_USER,
fecha_operacion DATETIME DEFAULT GETDATE(),
host_name VARCHAR(100) DEFAULT HOST_NAME(),
app_name VARCHAR(100) DEFAULT APP_NAME()
);


-- 2. Inserción de datos y estructura de mantenimiento.

BULK INSERT Negocio.RESERVA
FROM 'C:\Bulk_data\06_INSERT_RESERVA.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0A',
    TABLOCK
);

BULK INSERT Negocio.FACTURA
FROM 'C:\Bulk_data\05_INSERT_FACTURA.csv'
WITH (
    FIRSTROW = 2,             
    FIELDTERMINATOR = ',',    
    ROWTERMINATOR = '0x0A',   
    TABLOCK
);

BULK INSERT Negocio.CLASE
FROM 'C:\Bulk_data\04_INSERT_CLASE.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0A',
    TABLOCK
);

BULK INSERT Negocio.SOCIO
FROM 'C:\Bulk_data\03_INSERT_SOCIO.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0A', 
    TABLOCK
);

BULK INSERT Negocio.ENTRENADOR
FROM 'C:\Bulk_data\02_INSERT_ENTRENADOR.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0A',
    TABLOCK
);

BULK INSERT Negocio.MEMBRESIA
FROM 'C:\Bulk_data\01_INSERT_MEMBRESIA.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0A',
    TABLOCK
);

-- Creando índices para optimizar funciones ventanas y consultas de auditoría. --

-- ÍNDICES FUNCIÓN VENTANA 1: RANKING DE SOCIOS POR GASTO TOTAL

-- Índice compuesto para JOIN entre SOCIO y FACTURA
CREATE NONCLUSTERED INDEX IX_FACTURA_Socio_Monto
ON Negocio.FACTURA(id_socio, monto)
INCLUDE (id, fecha_pago);

-- Índice para filtrar socios por estado
CREATE NONCLUSTERED INDEX IX_SOCIO_Estado_Nombre
ON Negocio.SOCIO(estado, nombre)
INCLUDE (id, email);


-- ÍNDICES FUNCIÓN VENTANA 2: ANÁLISIS DE OCUPACIÓN DE CLASES

-- Índice para JOIN entre CLASE y RESERVA
CREATE NONCLUSTERED INDEX IX_RESERVA_Clase_FechaClase_Opt
ON Negocio.RESERVA(id_clase, fecha_clase)
INCLUDE (id, id_socio);

-- Índice para CLASE con especialidad del entrenador
CREATE NONCLUSTERED INDEX IX_CLASE_Entrenador_Tipo
ON Negocio.CLASE(id_entrenador, tipo, horario)
INCLUDE (cupo);

-- Índice para ENTRENADOR especialidad
CREATE NONCLUSTERED INDEX IX_ENTRENADOR_Especialidad_Opt
ON Negocio.ENTRENADOR(especialidad)
INCLUDE (id, nombre, email);


-- ÍNDICES FUNCIÓN VENTANA 3: ANÁLISIS TEMPORAL DE INGRESOS

-- Índice para análisis temporal de facturas
CREATE NONCLUSTERED INDEX IX_FACTURA_FechaPago_Monto_Opt
ON Negocio.FACTURA(fecha_pago, monto)
INCLUDE (id, metodo_pago);

-- Índice para agrupaciones por año/mes
CREATE NONCLUSTERED INDEX IX_FACTURA_AnioMes
ON Negocio.FACTURA(fecha_pago)
INCLUDE (monto, id);


-- Para tabla de Auditoria.Socio_audit

-- Índice para auditoría por fecha y socio
CREATE NONCLUSTERED INDEX IX_SOCIO_Audit_Fecha
ON Auditoria.SOCIO_Audit(fecha_operacion DESC, id_socio);

-- Para tabla de Auditoria.FACTURA_Audit

-- Índice para auditoría por fecha y factura
CREATE NONCLUSTERED INDEX IX_FACTURA_Audit_Fecha
ON Auditoria.FACTURA_Audit(fecha_operacion DESC, id_factura);


-- Actualización de estadísticas después de crear índices --
UPDATE STATISTICS Negocio.SOCIO WITH FULLSCAN;
UPDATE STATISTICS Negocio.FACTURA WITH FULLSCAN;
UPDATE STATISTICS Negocio.CLASE WITH FULLSCAN;
UPDATE STATISTICS Negocio.ENTRENADOR WITH FULLSCAN;
UPDATE STATISTICS Negocio.RESERVA WITH FULLSCAN;
UPDATE STATISTICS Auditoria.SOCIO_Audit WITH FULLSCAN;
UPDATE STATISTICS Auditoria.FACTURA_Audit WITH FULLSCAN;


-- 3. Lógica de negocio y análisis avanzado.

-- Creando triggers de auditoría. --

-- Registra la creación de un nuevo socio en la tabla de Auditoría.
CREATE TRIGGER trg_SOCIO_Insert_Audit
ON Negocio.SOCIO
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Auditoria.SOCIO_Audit (
        id_socio, operacion, nombre_nuevo, email_nuevo, estado_nuevo
    )
    SELECT 
        i.id, 'INSERT', i.nombre, i.email, i.estado
    FROM inserted i;
END

-- Registra cambios en los campos clave del socio.
CREATE TRIGGER trg_SOCIO_Update_Audit
ON Negocio.SOCIO
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Auditoria.SOCIO_Audit (
        id_socio, operacion, 
        nombre_anterior, nombre_nuevo,
        email_anterior, email_nuevo,
        estado_anterior, estado_nuevo
    )
    SELECT 
        i.id, 'UPDATE',
        d.nombre, i.nombre,
        d.email, i.email,
        d.estado, i.estado
    FROM inserted i
    INNER JOIN deleted d ON i.id = d.id;
END

-- Registra la eliminación de un socio, capturando los valores eliminados.
CREATE TRIGGER trg_SOCIO_Delete_Audit
ON Negocio.SOCIO
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Auditoria.SOCIO_Audit (
        id_socio, operacion, nombre_anterior, email_anterior, estado_anterior
    )
    SELECT 
        d.id, 'DELETE', d.nombre, d.email, d.estado
    FROM deleted d;
END

-- Registra la inserción de una nueva factura.
CREATE TRIGGER trg_FACTURA_Insert_Audit
ON Negocio.FACTURA
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Auditoria.FACTURA_Audit (
        id_factura, operacion, 
        id_socio_nuevo, monto_nuevo, 
        metodo_pago_nuevo, fecha_pago_nuevo
    )
    SELECT 
        i.id, 'INSERT',
        i.id_socio, i.monto, i.metodo_pago, i.fecha_pago
    FROM inserted i;
END

-- Registra modificaciones a los detalles de la factura.
CREATE TRIGGER trg_FACTURA_Update_Audit
ON Negocio.FACTURA
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Auditoria.FACTURA_Audit (
        id_factura, operacion,
        id_socio_anterior, id_socio_nuevo,
        monto_anterior, monto_nuevo,
        metodo_pago_anterior, metodo_pago_nuevo,
        fecha_pago_anterior, fecha_pago_nuevo
    )
    SELECT 
        i.id, 'UPDATE',
        d.id_socio, i.id_socio,
        d.monto, i.monto,
        d.metodo_pago, i.metodo_pago,
        d.fecha_pago, i.fecha_pago
    FROM inserted i
    INNER JOIN deleted d ON i.id = d.id;
END

-- Registra la anulación o eliminación de una factura.
CREATE TRIGGER trg_FACTURA_Delete_Audit
ON Negocio.FACTURA
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Auditoria.FACTURA_Audit (
        id_factura, operacion,
        id_socio_anterior, monto_anterior,
        metodo_pago_anterior, fecha_pago_anterior
    )
    SELECT 
        d.id, 'DELETE',
        d.id_socio, d.monto,
        d.metodo_pago, d.fecha_pago
    FROM deleted d;
END


-- Creando stored procedures y vistas de auditoría. --

-- Stored procedures

-- Devuelve el tamaño en MB y número de registros de cada tabla.
CREATE PROCEDURE Config.sp_ObtenerDimensionamientoTablas
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        t.name AS nombre_tabla,
        s.name AS esquema,
        p.rows AS numero_registros,
        CAST(ROUND(((SUM(a.used_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS espacio_usado_mb,
        CAST(ROUND(((SUM(a.total_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS espacio_total_mb,
        CAST(ROUND(((SUM(a.total_pages) - SUM(a.used_pages)) * 8) / 1024.00, 2) AS NUMERIC(36, 2)) AS espacio_libre_mb,
        CAST(ROUND((SUM(a.used_pages) * 8) / 1024.00 / NULLIF(p.rows, 0) * 1024, 2) AS NUMERIC(36, 2)) AS kb_por_registro
    FROM 
        sys.tables t
    INNER JOIN sys.indexes i ON t.object_id = i.object_id
    INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
    INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE t.is_ms_shipped = 0
      AND i.object_id > 255
    GROUP BY t.name, s.name, p.rows
    ORDER BY espacio_usado_mb DESC;
END

-- Permite consultar el historial de auditoría de socios aplicando filtros.
CREATE PROCEDURE Auditoria.sp_ConsultarAuditoriaSocio
    @fecha_inicio DATETIME = NULL,
    @fecha_fin DATETIME = NULL,
    @id_socio INT = NULL,
    @operacion VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Auditoria.vw_Auditoria_SOCIO
    WHERE 
        (@fecha_inicio IS NULL OR fecha_operacion >= @fecha_inicio)
        AND (@fecha_fin IS NULL OR fecha_operacion <= @fecha_fin)
        AND (@id_socio IS NULL OR id_socio = @id_socio)
        AND (@operacion IS NULL OR operacion = @operacion)
    ORDER BY fecha_operacion DESC;
END

-- Permite consultar el historial de auditoría de facturas aplicando filtros.
CREATE PROCEDURE Auditoria.sp_ConsultarAuditoriaFactura
    @fecha_inicio DATETIME = NULL,
    @fecha_fin DATETIME = NULL,
    @id_factura INT = NULL,
    @operacion VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Auditoria.vw_Auditoria_FACTURA
    WHERE 
        (@fecha_inicio IS NULL OR fecha_operacion >= @fecha_inicio)
        AND (@fecha_fin IS NULL OR fecha_operacion <= @fecha_fin)
        AND (@id_factura IS NULL OR id_factura = @id_factura)
        AND (@operacion IS NULL OR operacion = @operacion)
    ORDER BY fecha_operacion DESC;
END


-- Vistas

-- Vista para consultar la auditoría de socios, añadiendo el nombre actual del socio y el tipo de cambio.
CREATE VIEW Auditoria.vw_Auditoria_SOCIO
AS
SELECT 
    a.audit_id,
    a.id_socio,
    s.nombre AS nombre_actual_socio,
    a.operacion,
    a.nombre_anterior,
    a.nombre_nuevo,
    a.email_anterior,
    a.email_nuevo,
    a.estado_anterior,
    a.estado_nuevo,
    a.usuario,
    a.fecha_operacion,
    a.host_name,
    a.app_name,
    CASE 
        WHEN a.nombre_anterior != a.nombre_nuevo THEN 'Cambió nombre'
        WHEN a.email_anterior != a.email_nuevo THEN 'Cambió email'
        WHEN a.estado_anterior != a.estado_nuevo THEN 'Cambió estado'
        ELSE 'Nuevo registro'
    END AS tipo_cambio
FROM Auditoria.SOCIO_Audit a
LEFT JOIN Negocio.SOCIO s ON a.id_socio = s.id;

-- Vista para consultar la auditoría de facturas, añadiendo la diferencia de monto y el tipo de cambio.
CREATE VIEW Auditoria.vw_Auditoria_FACTURA
AS
SELECT 
    a.audit_id,
    a.id_factura,
    a.operacion,
    ISNULL(s_ant.nombre, 'N/A') AS socio_anterior,
    ISNULL(s_nue.nombre, 'N/A') AS socio_nuevo,
    a.monto_anterior,
    a.monto_nuevo,
    a.monto_nuevo - a.monto_anterior AS diferencia_monto,
    a.metodo_pago_anterior,
    a.metodo_pago_nuevo,
    a.fecha_pago_anterior,
    a.fecha_pago_nuevo,
    a.usuario,
    a.fecha_operacion,
    a.host_name,
    a.app_name,
    CASE 
        WHEN a.monto_anterior != a.monto_nuevo THEN 'Cambió monto'
        WHEN a.metodo_pago_anterior != a.metodo_pago_nuevo THEN 'Cambió método de pago'
        WHEN a.fecha_pago_anterior != a.fecha_pago_nuevo THEN 'Cambió fecha'
        WHEN a.id_socio_anterior != a.id_socio_nuevo THEN 'Cambió socio'
        ELSE 'Nuevo registro'
    END AS tipo_cambio
FROM Auditoria.FACTURA_Audit a
LEFT JOIN Negocio.SOCIO s_ant ON a.id_socio_anterior = s_ant.id
LEFT JOIN Negocio.SOCIO s_nue ON a.id_socio_nuevo = s_nue.id;


-- Creando vistas de reporte con funciones ventana y agregaciones para power bi.


-- Vista con función ventana 1: Ranking de socios por gasto total.
CREATE VIEW Reportes.vw_RankingSocioGasto
AS
SELECT
    s.nombre,
    SUM(f.monto) AS gasto_total,
    RANK() OVER (ORDER BY SUM(f.monto) DESC) AS ranking_gasto,
    SUM(SUM(f.monto)) OVER (ORDER BY SUM(f.monto) DESC) /
        SUM(SUM(f.monto)) OVER () * 100 AS porcentaje_acumulado
FROM Negocio.SOCIO s 
INNER JOIN Negocio.FACTURA f ON s.id = f.id_socio 
GROUP BY s.id, s.nombre, s.email, s.estado;


-- Vista con función ventana 2: Análisis de ocupación de clases.
CREATE VIEW Reportes.vw_OcupacionClases
AS
SELECT
    c.tipo AS nombre_clase,
    e.especialidad,
    COUNT(r.id) AS total_reservas,
    CAST(COUNT(r.id) AS DECIMAL(10,2)) / c.cupo * 100 AS porcentaje_ocupacion,
    RANK() OVER (PARTITION BY e.especialidad ORDER BY COUNT(r.id) DESC) AS ranking_por_especialidad,
    COUNT(r.id) - AVG(COUNT(r.id)) OVER (PARTITION BY e.especialidad) AS diferencia_vs_promedio,
    CASE
        WHEN COUNT(r.id) >= c.cupo THEN 'LLENO'
        WHEN CAST(COUNT(r.id) AS DECIMAL(10,2)) / c.cupo >= 0.90 THEN 'CASI LLENO'
        ELSE 'DISPONIBLE/BAJA DEMANDA'
    END AS estado_visual
FROM Negocio.CLASE c
INNER JOIN Negocio.ENTRENADOR e ON c.id_entrenador = e.id 
LEFT JOIN Negocio.RESERVA r ON c.id = r.id_clase 
GROUP BY c.id, c.tipo, c.cupo, e.especialidad;


-- Vista con función ventana 3: Análisis temporal de ingresos.
CREATE VIEW Reportes.vw_IngresosAcumulados
AS
WITH IngresosMensuales AS (
    SELECT
        YEAR(fecha_pago) AS anio,
        MONTH(fecha_pago) AS mes,
        DATEFROMPARTS(YEAR(fecha_pago), MONTH(fecha_pago), 1) AS MesFecha,
        SUM(monto) AS ingreso_mensual
    FROM Negocio.FACTURA
    GROUP BY YEAR(fecha_pago), MONTH(fecha_pago), DATEFROMPARTS(YEAR(fecha_pago), MONTH(fecha_pago), 1)
)
SELECT
    anio,
    mes,
    MesFecha,
    ingreso_mensual,
    SUM(ingreso_mensual) OVER (
        PARTITION BY anio
        ORDER BY MesFecha
        ROWS UNBOUNDED PRECEDING
    ) AS ingreso_acumulado_anio,
    ISNULL(
        (ingreso_mensual - LAG(ingreso_mensual, 1) OVER (ORDER BY MesFecha)) /
        LAG(ingreso_mensual, 1) OVER (ORDER BY MesFecha) * 100
    , 0) AS crecimiento_porcentual,
    AVG(ingreso_mensual) OVER (
        ORDER BY MesFecha
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS promedio_movil_3meses
FROM IngresosMensuales;


-- Vista de resumen: Muestra la distribución de ingresos por cada método de pago.
CREATE VIEW Reportes.vw_MetodosPago
AS
SELECT
    metodo_pago,
    COUNT(id) AS TotalFacturas,
    SUM(monto) AS MontoTotalRecaudado
FROM Negocio.FACTURA
GROUP BY metodo_pago;


-- 4. Seguridad y mantenimiento.

-- Creando roles y usuarios. --

-- Roles.
CREATE ROLE R_Asistente_Administrativo;
CREATE ROLE R_Contabilidad;
CREATE ROLE R_Lector;
CREATE ROLE R_Reportes;

-- Usuarios.
CREATE USER U_Asistente WITH PASSWORD = 'Asistente@ABD25';
CREATE USER U_Contabilidad WITH PASSWORD = 'Contabilidad@ABD25';
CREATE USER U_Lector WITH PASSWORD = 'Lector@ABD25';
CREATE USER U_Respaldos WITH PASSWORD = 'Backups@ABD25';
CREATE USER U_ReportesBI WITH PASSWORD = 'Reportes@ABD25';

-- Asignando permisos a roles. --

-- ROL 1: R_Asistente_Administrativo.
-- Tareas: Registrar, ver facturas y clases, reservar.
GRANT SELECT, INSERT, UPDATE, DELETE ON Negocio.SOCIO TO R_Asistente_Administrativo;
GRANT SELECT ON Negocio.FACTURA TO R_Asistente_Administrativo;
GRANT SELECT ON Negocio.MEMBRESIA TO R_Asistente_Administrativo;
GRANT SELECT, INSERT, UPDATE, DELETE ON Negocio.RESERVA TO R_Asistente_Administrativo;
GRANT SELECT ON Negocio.CLASE TO R_Asistente_Administrativo;
GRANT SELECT ON Negocio.ENTRENADOR TO R_Asistente_Administrativo;

-- ROL 2: R_Contabilidad.
-- Tareas: Acceso total a socios y facturas, y consultas de auditoría.
GRANT SELECT, INSERT, UPDATE, DELETE ON Negocio.SOCIO TO R_Contabilidad;
GRANT SELECT, INSERT, UPDATE, DELETE ON Negocio.FACTURA TO R_Contabilidad;
GRANT EXECUTE ON SCHEMA::Auditoria TO R_Contabilidad;
GRANT SELECT ON SCHEMA::Auditoria TO R_Contabilidad;

-- ROL 3: R_Lector
-- Tareas: Acceso de solo lectura a todas las tablas del negocio y reportes.
GRANT SELECT ON SCHEMA::Negocio TO R_Lector;
GRANT SELECT ON SCHEMA::Reportes TO R_Lector;

-- ROL 4: R_Reportes.
-- Tareas: Acceso solo a las vistas de Reportes.
GRANT SELECT ON SCHEMA::Reportes TO R_Reportes;

-- Asignando usuario a roles.
ALTER ROLE R_Asistente_Administrativo ADD MEMBER U_Asistente;
ALTER ROLE R_Contabilidad ADD MEMBER U_Contabilidad;
ALTER ROLE R_Lector ADD MEMBER U_Lector;
ALTER ROLE R_Reportes ADD MEMBER U_ReportesBI;
ALTER ROLE db_backupoperator ADD MEMBER U_Respaldos;


-- Plan de backup. --

ALTER DATABASE GimnasioReservas SET RECOVERY FULL;

-- FULL backup.
BACKUP DATABASE GimnasioReservas
TO DISK = 'C:\Backups\Gym_Full.bak'
WITH COMPRESSION, NAME = 'GimnasioReserva full backup', INIT;

-- LOG backup.
BACKUP LOG GimnasioReservas
TO DISK = 'C:\Backups\Gym_Cadena.trn'
WITH NOINIT;

-- Comandos de restauración. --

USE MASTER;

-- Colocando en unico usuario.
ALTER DATABASE GimnasioReservas
SET SINGLE_USER
WITH ROLLBACK IMMEDIATE;
GO

-- 1. FULL backup.
RESTORE DATABASE GimnasioReservas
FROM DISK = 'C:\Backups\Gym_Full.bak' WITH REPLACE, NORECOVERY;

-- 2. LOGs backup.
RESTORE LOG GimnasioReservas
FROM DISK = 'C:\Backups\Gym_Cadena.trn' WITH RECOVERY;

-- Volviendo a multiusuario.
ALTER DATABASE GimnasioReservas
SET MULTI_USER;

-- Prueba de dimensionamiento
-- EXEC Config.sp_ObtenerDimensionamientoTablas;
