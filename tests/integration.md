# Pruebas de Integración - GROUND (OCaml)

## Preparación del Entorno

### 1. Variables de Entorno
```bash
export DB_HOST=localhost
export DB_PORT=3306
export DB_NAME=kepler_mission
export DB_USER=kepler_user
export DB_PASSWORD=kepler_pass
```

### 2. Base de Datos MySQL
```bash
# Iniciar MySQL (local o Docker)
mysql -u root -p < mysql/init.sql

# Verificar que la base de datos existe
mysql -u kepler_user -p kepler_mission -e "SHOW TABLES;"
```

### 3. Iniciar GROUND
```bash
cd ground
opam install --deps-only .
dune exec ./ground.exe
```

El servidor debe iniciar en el puerto 9004 y mostrar:
```
Servidor HTTP escuchando en puerto 9004
Conectado a MySQL localhost:3306/kepler_mission
GROUND listo para recibir eventos
```

## Pruebas de Integración

### Test 1: POST /evento → Persistencia en MySQL

#### Comando
```bash
curl -X POST http://localhost:9004/evento \
  -H "Content-Type: application/json" \
  -d @tests/evento_sample.json
```

#### Respuesta Esperada
```json
{
  "status": "persisted",
  "registro_id": "REG-1715707000-ABC12",
  "id_evento": "ATLAS-EVENT-2024-001"
}
```

#### Verificación en MySQL
```sql
SELECT id_registro, nivel_alerta, resumen, timestamp_persistencia
FROM ground_records
ORDER BY creado_en DESC LIMIT 1;
```

#### Salida Esperada
```
+----------------------+--------------+---------------------------------------------------+---------------------+
| id_registro          | nivel_alerta | resumen                                           | timestamp_persistencia |
+----------------------+--------------+---------------------------------------------------+---------------------+
| REG-1715707000-ABC12 | 1            | Anomalía VOYAGER-ANOM-2024-001 detectada por...  | 2024-05-14T21:37:00Z |
+----------------------+--------------+---------------------------------------------------+---------------------+
```

### Test 2: GET /consulta → Flujo Inverso

#### Comando
```bash
curl "http://localhost:9004/consulta?mision=VOYAGER_IX_2024"
```

#### Respuesta Esperada
```json
[
  {
    "id_registro": "REG-1715707000-ABC12",
    "nivel_alerta": "1",
    "nivel_prioridad": "9",
    "agencia": "NASA",
    "resumen": "Anomalía VOYAGER-ANOM-2024-001 detectada por VOYAGER_IX_2024 con confianza 0.92. Prioridad 9 asignada por NASA.",
    "timestamp_procesamiento": "2024-05-14T21:37:00Z",
    "timestamp_persistencia": "2024-05-14T21:37:00Z"
  }
]
```

### Test 3: Manejo de Errores

#### JSON Inválido
```bash
curl -X POST http://localhost:9004/evento \
  -H "Content-Type: application/json" \
  -d '{"campo_inexistente": "valor"}'
```

#### Respuesta Esperada (400)
```json
{
  "error": "id_evento (value missing)"
}
```

#### Parámetro Faltante en Consulta
```bash
curl "http://localhost:9004/consulta"
```

#### Respuesta Esperada (400)
```json
{
  "error": "Parametro 'mision' requerido"
}
```

### Test 4: Endpoint No Encontrado
```bash
curl http://localhost:9004/endpoint_inexistente
```

#### Respuesta Esperada (404)
```json
{
  "error": "Endpoint no encontrado"
}
```

## Validación de Requisitos

### ✅ Requisitos Cumplidos
- **Recepción de eventos**: POST /evento procesa JSON de ATLAS
- **Persistencia en MySQL**: Todos los campos almacenados en ground_records
- **Descomposición de datos**: Datos de sonda, sensores, coordenadas, trazabilidad
- **Nivel de alerta**: Calculado automáticamente basado en sensores
- **Resumen consolidado**: Generado con información relevante
- **Consulta histórica**: GET /consulta retorna registros por misión
- **Flujo inverso**: Posible consulta desde GROUND hacia datos históricos

### 🔍 Campos Verificados en MySQL
- id_registro, id_evento, id_transmision, id_mision
- nivel_prioridad, nivel_alerta, agencia, misiones_activas
- confianza, resumen, justificacion, trazabilidad
- datos_payload (JSON completo), datos_sonda (JSON), sensores (JSON)
- timestamps de procesamiento y persistencia

## Problemas Conocidos y Soluciones

### 1. Error de compilación de mysql-ocaml
**Problema**: Falta libmysqlclient-dev
**Solución**: 
```bash
# En Dockerfile Alpine
RUN apk add mysql-dev
# En Ubuntu/Debian
RUN apt-get install libmysqlclient-dev
```

### 2. Conexión a MySQL rechazada
**Problema**: Credenciales incorrectas o MySQL no iniciado
**Solución**: Verificar variables de entorno y estado de MySQL

### 3. JSON malformado
**Problema**: El parser de OCaml es estricto
**Solución**: Validar JSON antes de enviar o usar herramientas como jq

## Integración con Docker Compose

Cuando los otros nodos estén listos:
```bash
# Levantar todo el sistema
docker-compose up --build

# Probar flujo completo
curl -X POST http://localhost:9001/sensor -d @voyager_test.json
# ... pasará por HERMES → ATLAS → GROUND → MySQL

# Verificar en GROUND
curl "http://localhost:9004/consulta?mision=VOYAGER_IX_2024"
```

## Logs y Monitoreo

### Ver logs de GROUND
```bash
# En terminal donde corre GROUND
# Debe mostrar cada evento recibido y procesado

# En Docker
docker-compose logs -f ground
```

### Monitorear MySQL
```sql
-- Ver registros insertados
SELECT COUNT(*) FROM ground_records;

-- Ver última actividad
SELECT * FROM ground_records ORDER BY creado_en DESC LIMIT 5;
```

## Checklist para Demo

- [ ] MySQL iniciado con esquema completo
- [ ] GROUND ejecutándose en puerto 9004
- [ ] POST /evento inserta correctamente
- [ ] GET /consulta retorna historial
- [ ] Errores manejados con códigos HTTP adecuados
- [ ] Logs informativos visibles
- [ ] Integración con docker-compose funcional
