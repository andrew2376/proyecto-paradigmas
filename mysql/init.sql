-- Base de datos para el Proyecto Kepler
-- Esquema relacional para las 5 entidades del sistema

CREATE DATABASE IF NOT EXISTS kepler_mission;
USE kepler_mission;

-- Entidad 1: Misiones (Voyager IX y otras sondas)
CREATE TABLE misiones (
    id_mision VARCHAR(50) PRIMARY KEY,
    nombre_sonda VARCHAR(100) NOT NULL,
    fecha_lanzamiento DATE NOT NULL,
    estado_actual ENUM('activa', 'inactiva', 'perdida') NOT NULL,
    coordenadas_base VARCHAR(100),
    timestamp_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Entidad 2: Anomalías (hallazgos de las sondas)
CREATE TABLE anomalías (
    id_anomalía VARCHAR(50) PRIMARY KEY,
    id_mision VARCHAR(50) NOT NULL,
    coordenadas_ra VARCHAR(50) NOT NULL,  -- Ascensión recta
    coordenadas_dec VARCHAR(50) NOT NULL, -- Declinación
    lectura_espectral TEXT NOT NULL,
    nivel_confianza DECIMAL(3,2) NOT NULL CHECK (nivel_confianza BETWEEN 0 AND 1),
    timestamp_observacion TIMESTAMP NOT NULL,
    cadena_reglas TEXT NOT NULL,
    FOREIGN KEY (id_mision) REFERENCES misiones(id_mision)
);

-- Entidad 3: Transmisiones (paso por HERMES)
CREATE TABLE transmisiones (
    id_transmision VARCHAR(50) PRIMARY KEY,
    id_anomalía VARCHAR(50) NOT NULL,
    hash_sha256 VARCHAR(64) NOT NULL,
    timestamp_recepcion TIMESTAMP NOT NULL,
    timestamp_retransmision TIMESTAMP NOT NULL,
    estado_transmision ENUM('recibida', 'verificada', 'descartada', 'retransmitida') NOT NULL,
    FOREIGN KEY (id_anomalía) REFERENCES anomalías(id_anomalía)
);

-- Entidad 4: Eventos ATLAS (enriquecimiento en Tierra)
CREATE TABLE eventos_atlas (
    id_evento VARCHAR(50) PRIMARY KEY,
    id_transmision VARCHAR(50) NOT NULL,
    nivel_prioridad INT NOT NULL CHECK (nivel_prioridad BETWEEN 1 AND 10),
    id_agencia VARCHAR(50) NOT NULL,
    misiones_activas_simultaneas INT NOT NULL,
    campo_trazabilidad TEXT NOT NULL,
    timestamp_procesamiento TIMESTAMP NOT NULL,
    FOREIGN KEY (id_transmision) REFERENCES transmisiones(id_transmision)
);

-- Entidad 5: Registros GROUND (persistencia final)
CREATE TABLE registros_ground (
    id_registro VARCHAR(50) PRIMARY KEY,
    id_evento VARCHAR(50) NOT NULL,
    datos_sonda JSON NOT NULL,
    estado_sensores JSON NOT NULL,
    coordenadas_anomalía VARCHAR(100) NOT NULL,
    lectura_espectral_vinculada TEXT NOT NULL,
    trazabilidad_completa TEXT NOT NULL,
    nivel_alerta INT NOT NULL,
    justificacion_alerta TEXT NOT NULL,
    resumen_consolidado TEXT NOT NULL,
    timestamp_persistencia TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_evento) REFERENCES eventos_atlas(id_evento)
);

-- Índices para rendimiento
CREATE INDEX idx_anomalias_mision ON anomalías(id_mision);
CREATE INDEX idx_anomalias_timestamp ON anomalías(timestamp_observacion);
CREATE INDEX idx_transmisiones_anomalia ON transmisiones(id_anomalía);
CREATE INDEX idx_transmisiones_timestamp ON transmisiones(timestamp_recepcion);
CREATE INDEX idx_eventos_transmision ON eventos_atlas(id_transmision);
CREATE INDEX idx_eventos_prioridad ON eventos_atlas(nivel_prioridad);
CREATE INDEX idx_registros_evento ON registros_ground(id_evento);
CREATE INDEX idx_registros_timestamp ON registros_ground(timestamp_persistencia);

-- Datos de ejemplo para testing
INSERT INTO misiones (id_mision, nombre_sonda, fecha_lanzamiento, estado_actual, coordenadas_base) VALUES
('VOYAGER_IX_2024', 'Voyager IX', '2024-03-15', 'activa', 'RA 14h 39m, DEC -60° 50'''),
('VOYAGER_VIII_2023', 'Voyager VIII', '2023-11-20', 'activa', 'RA 18h 25m, DEC -35° 15'''),
('KEPLER_PROBE_2022', 'Kepler Probe', '2022-07-10', 'inactiva', 'RA 22h 10m, DEC +15° 30''');

-- Vista para consultas de trazabilidad completa
CREATE VIEW trazabilidad_completa AS
SELECT 
    r.id_registro,
    m.nombre_sonda,
    a.coordenadas_ra,
    a.coordenadas_dec,
    a.nivel_confianza,
    t.hash_sha256,
    e.nivel_prioridad,
    e.id_agencia,
    r.nivel_alerta,
    r.timestamp_persistencia,
    a.timestamp_observacion,
    t.timestamp_recepcion,
    e.timestamp_procesamiento
FROM registros_ground r
JOIN eventos_atlas e ON r.id_evento = e.id_evento
JOIN transmisiones t ON e.id_transmision = t.id_transmision
JOIN anomalías a ON t.id_anomalía = a.id_anomalía
JOIN misiones m ON a.id_mision = m.id_mision;
