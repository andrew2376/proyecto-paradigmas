open Core
open Lwt.Syntax
open Cohttp_lwt_unix

module Types = struct
  type coordenada = { ascension_recta : string; declinacion : string }
  type lectura_espectral = (string * float) list

  type estado_sensor = {
    temperatura : float;
    presion : float;
    voltaje : float;
    estado : string;
  }

  type datos_sonda = {
    id_mision : string;
    timestamp : string;
    sensores : estado_sensor list;
  }

  type reporte_anomalia = {
    id_anomalia : string;
    mision : datos_sonda;
    coordenadas : coordenada;
    espectro : lectura_espectral;
    confianza : float;
    cadena_reglas : string list;
    timestamp_observacion : string;
  }

  type transmision_hermes = {
    id_transmision : string;
    anomalia : reporte_anomalia;
    hash_sha256 : string;
    timestamp_recepcion : string;
    timestamp_retransmision : string;
  }

  type evento_atlas = {
    id_evento : string;
    transmision : transmision_hermes;
    nivel_prioridad : int;
    id_agencia : string;
    misiones_activas : int;
    trazabilidad : string list;
    timestamp_procesamiento : string;
  }

  type registro_ground = {
    id_registro : string;
    evento : evento_atlas;
    nivel_alerta : int;
    justificacion_alerta : string;
    resumen_consolidado : string;
    timestamp_persistencia : string;
    payload : Yojson.Safe.t;
    datos_sonda_json : Yojson.Safe.t;
    sensores_json : Yojson.Safe.t;
  }
end

module Json_codec = struct
  open Yojson.Safe
  open Yojson.Safe.Util
  open Types

  exception Validation_error of string

  let require ?(ctx = "") extractor field json =
    try extractor (member field json) with
    | Type_error (msg, _) | Undefined (msg, _) ->
        let prefix = if String.is_empty ctx then field else ctx ^ "." ^ field in
        raise (Validation_error (Printf.sprintf "%s (%s)" prefix msg))

  let require_string ?ctx field json = require ?ctx to_string field json
  let require_float ?ctx field json = require ?ctx to_float field json
  let require_int ?ctx field json = require ?ctx to_int field json

  let optional_string field json =
    match member field json with
    | `Null -> None
    | v -> Some (to_string v)

  let decode_estado_sensor json =
    {
      temperatura = require_float ~ctx:"sensor" "temperatura" json;
      presion = require_float ~ctx:"sensor" "presion" json;
      voltaje = require_float ~ctx:"sensor" "voltaje" json;
      estado = require_string ~ctx:"sensor" "estado" json;
    }

  let decode_sensores json =
    json |> to_list |> List.map ~f:decode_estado_sensor

  let decode_espectro json =
    let decode_entry entry =
      let nombre =
        match optional_string "elemento" entry with
        | Some s -> s
        | None -> require_string ~ctx:"espectro" "nombre" entry
      in
      let valor =
        match member "valor" entry with
        | `Null -> require_float ~ctx:"espectro" "intensidad" entry
        | v -> to_float v
      in
      (nombre, valor)
    in
    json |> to_list |> List.map ~f:decode_entry

  let decode_cadena json = json |> to_list |> List.map ~f:to_string

  let decode_coordenadas json =
    {
      ascension_recta = require_string "ascension_recta" json;
      declinacion = require_string "declinacion" json;
    }

  let decode_datos_sonda json =
    {
      id_mision = require_string "id_mision" json;
      timestamp = require_string "timestamp" json;
      sensores = require "sensores" decode_sensores json;
    }

  let decode_anomalia json =
    {
      id_anomalia = require_string "id_anomalia" json;
      mision = require "mision" decode_datos_sonda json;
      coordenadas = require "coordenadas" decode_coordenadas json;
      espectro = require "espectro" decode_espectro json;
      confianza = require_float "confianza" json;
      cadena_reglas = require "cadena_reglas" decode_cadena json;
      timestamp_observacion = require_string "timestamp_observacion" json;
    }

  let decode_transmision json =
    {
      id_transmision = require_string "id_transmision" json;
      anomalia = require "anomalia" decode_anomalia json;
      hash_sha256 = require_string "hash_sha256" json;
      timestamp_recepcion = require_string "timestamp_recepcion" json;
      timestamp_retransmision = require_string "timestamp_retransmision" json;
    }

  let decode_trazabilidad json =
    match json with
    | `String s -> [ s ]
    | `List lst -> lst |> List.map ~f:to_string
    | _ -> raise (Validation_error "trazabilidad debe ser string o lista")

  type decoded_event = {
    evento : Types.evento_atlas;
    raw_json : Yojson.Safe.t;
    mission_snapshot : Yojson.Safe.t;
    sensores_snapshot : Yojson.Safe.t;
  }

  let encode_sensor s =
    `Assoc
      [
        ("temperatura", `Float s.temperatura);
        ("presion", `Float s.presion);
        ("voltaje", `Float s.voltaje);
        ("estado", `String s.estado);
      ]

  let encode_mision mision =
    `Assoc
      [
        ("id_mision", `String mision.id_mision);
        ("timestamp", `String mision.timestamp);
        ("sensores", `List (List.map mision.sensores ~f:encode_sensor));
      ]

  let decode_event body =
    try
      let json = Yojson.Safe.from_string body in
      let transmision = require "transmision" decode_transmision json in
      let evento =
        {
          id_evento = require_string "id_evento" json;
          transmision;
          nivel_prioridad = require_int "nivel_prioridad" json;
          id_agencia = require_string "id_agencia" json;
          misiones_activas = require_int "misiones_activas" json;
          trazabilidad = require "trazabilidad" decode_trazabilidad json;
          timestamp_procesamiento = require_string "timestamp_procesamiento" json;
        }
      in
      {
        evento;
        raw_json = json;
        mission_snapshot = encode_mision evento.transmision.anomalia.mision;
        sensores_snapshot =
          `List (List.map evento.transmision.anomalia.mision.sensores ~f:encode_sensor);
      }
    with
    | Validation_error msg -> Error (`Msg msg)
    | Yojson.Json_error msg -> Error (`Msg msg)
end

module Database = struct
  open Types

  let db_host = Sys.getenv_opt "DB_HOST" |> Option.value ~default:"mysql"
  let db_port = Sys.getenv_opt "DB_PORT" |> Option.value ~default:"3306" |> Int.of_string
  let db_name = Sys.getenv_opt "DB_NAME" |> Option.value ~default:"kepler_mission"
  let db_user = Sys.getenv_opt "DB_USER" |> Option.value ~default:"kepler_user"
  let db_password = Sys.getenv_opt "DB_PASSWORD" |> Option.value ~default:"kepler_pass"

  let connection : Mysql.dbd option ref = ref None

  let with_conn f = match !connection with Some conn -> f conn | None -> failwith "DB no inicializada"

  let ensure_schema conn =
    let ddl =
      "CREATE TABLE IF NOT EXISTS ground_records (\n"
      ^ "  id_registro VARCHAR(100) PRIMARY KEY,\n"
      ^ "  id_evento VARCHAR(100) NOT NULL,\n"
      ^ "  id_transmision VARCHAR(100) NOT NULL,\n"
      ^ "  id_mision VARCHAR(100) NOT NULL,\n"
      ^ "  nivel_prioridad INT NOT NULL,\n"
      ^ "  nivel_alerta INT NOT NULL,\n"
      ^ "  agencia VARCHAR(100) NOT NULL,\n"
      ^ "  misiones_activas INT NOT NULL,\n"
      ^ "  confianza DECIMAL(8,5) NOT NULL,\n"
      ^ "  resumen TEXT NOT NULL,\n"
      ^ "  justificacion TEXT NOT NULL,\n"
      ^ "  trazabilidad TEXT NOT NULL,\n"
      ^ "  datos_payload JSON NOT NULL,\n"
      ^ "  datos_sonda JSON NOT NULL,\n"
      ^ "  sensores JSON NOT NULL,\n"
      ^ "  timestamp_procesamiento VARCHAR(50) NOT NULL,\n"
      ^ "  timestamp_persistencia VARCHAR(50) NOT NULL,\n"
      ^ "  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP\n"
      ^ ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"
    in
    ignore (Mysql.exec conn ddl)

  let init () =
    let conn =
      Mysql.connect
        ~host:db_host
        ~port:db_port
        ~database:db_name
        ~user:db_user
        ~password:db_password
        ()
    in
    connection := Some conn;
    ensure_schema conn;
    Logs_lwt.info (fun m -> m "Conectado a MySQL %s:%d/%s" db_host db_port db_name)

  let escape conn value = Mysql.escape conn value

  let quote conn value = Printf.sprintf "'%s'" (escape conn value)

  let string_of_float f = Float.to_string f

  let insert_registro (registro : registro_ground) =
    with_conn (fun conn ->
        let evento = registro.evento in
        let transmision = evento.transmision in
        let anomalia = transmision.anomalia in
        let payload_json = Yojson.Safe.to_string registro.payload in
        let datos_sonda_json = Yojson.Safe.to_string registro.datos_sonda_json in
        let sensores_json = Yojson.Safe.to_string registro.sensores_json in
        let trazabilidad = String.concat ~sep:" -> " evento.trazabilidad in
        let query =
          Printf.sprintf
            {|INSERT INTO ground_records
              (id_registro, id_evento, id_transmision, id_mision, nivel_prioridad, nivel_alerta,
               agencia, misiones_activas, confianza, resumen, justificacion, trazabilidad,
               datos_payload, datos_sonda, sensores, timestamp_procesamiento, timestamp_persistencia)
             VALUES (%s,%s,%s,%s,%d,%d,%s,%d,%s,%s,%s,%s,%s,%s,%s,%s,%s)|}
            (quote conn registro.id_registro)
            (quote conn evento.id_evento)
            (quote conn transmision.id_transmision)
            (quote conn anomalia.mision.id_mision)
            evento.nivel_prioridad
            registro.nivel_alerta
            (quote conn evento.id_agencia)
            evento.misiones_activas
            (quote conn (string_of_float anomalia.confianza))
            (quote conn registro.resumen_consolidado)
            (quote conn registro.justificacion_alerta)
            (quote conn trazabilidad)
            (quote conn payload_json)
            (quote conn datos_sonda_json)
            (quote conn sensores_json)
            (quote conn evento.timestamp_procesamiento)
            (quote conn registro.timestamp_persistencia)
        in
        ignore (Mysql.exec conn query));
    Lwt.return_unit

  let consultar_historial id_mision =
    with_conn (fun conn ->
        let query =
          Printf.sprintf
            {|SELECT id_registro, nivel_alerta, nivel_prioridad, agencia,
                      resumen, timestamp_procesamiento, timestamp_persistencia
               FROM ground_records
               WHERE id_mision = %s
               ORDER BY creado_en DESC
               LIMIT 50|}
            (quote conn id_mision)
        in
        let result = Mysql.exec conn query in
        let rows = Mysql.fetch_all result in
        let to_json row =
          let field idx = row.(idx) |> Option.value ~default:"" in
          `Assoc
            [
              ("id_registro", `String (field 0));
              ("nivel_alerta", `String (field 1));
              ("nivel_prioridad", `String (field 2));
              ("agencia", `String (field 3));
              ("resumen", `String (field 4));
              ("timestamp_procesamiento", `String (field 5));
              ("timestamp_persistencia", `String (field 6));
            ]
        in
        let json = `List (List.map rows ~f:to_json) in
        Yojson.Safe.to_string json |> Lwt.return)
end

module Procesador = struct
  open Types

  let generar_id_registro () =
    let now = Float.to_int (Unix.gettimeofday ()) in
    let rand = Random.bits () land 0xFFFFF in
    Printf.sprintf "REG-%d-%05X" now rand

  let analizar_datos_sonda datos =
    let sensores_criticos =
      List.filter datos.Types.sensores ~f:(fun s ->
          Float.(s.temperatura > 80.) || Float.(s.voltaje < 10.))
    in
    match sensores_criticos with
    | [] -> (1, "Todos los sensores en rango nominal")
    | lista ->
        let detalles =
          lista
          |> List.mapi ~f:(fun idx sensor ->
                 Printf.sprintf "Sensor #%d fuera de rango (T=%.2f, V=%.2f)" (idx + 1)
                   sensor.temperatura sensor.voltaje)
          |> String.concat ~sep:" | "
        in
        (8, detalles)

  let generar_resumen evento =
    let anomalia = evento.transmision.anomalia in
    Printf.sprintf
      "Anomalía %s detectada por %s con confianza %.2f. Prioridad %d asignada por %s."
      anomalia.id_anomalia anomalia.mision.id_mision anomalia.confianza evento.nivel_prioridad
      evento.id_agencia

  let timestamp_utc () =
    Time_float.now () |> Time_float.to_string_iso8601 ~zone:Time_float.Zone.utc

  let procesar evento ~payload ~mission_snapshot ~sensores_snapshot =
    let nivel_alerta, justificacion =
      analizar_datos_sonda evento.transmision.anomalia.mision
    in
    {
      Types.id_registro = generar_id_registro ();
      evento;
      nivel_alerta;
      justificacion_alerta = justificacion;
      resumen_consolidado = generar_resumen evento;
      timestamp_persistencia = timestamp_utc ();
      payload;
      datos_sonda_json = mission_snapshot;
      sensores_json = sensores_snapshot;
    }
end

module Servidor = struct
  let respond ~status body =
    let headers = Cohttp.Header.init_with "Content-Type" "application/json" in
    Cohttp_lwt_unix.Server.respond_string ~headers ~status ~body

  let handle_event_body body =
    match Json_codec.decode_event body with
    | Error (`Msg msg) ->
        respond ~status:`Bad_request
          (Yojson.Safe.to_string (`Assoc [ ("error", `String msg) ]))
    | Ok decoded ->
        let registro =
          Procesador.procesar decoded.evento ~payload:decoded.raw_json
            ~mission_snapshot:decoded.mission_snapshot ~sensores_snapshot:decoded.sensores_snapshot
        in
        let* () = Database.insert_registro registro in
        respond ~status:`OK
          (Yojson.Safe.to_string
             (`Assoc
                [
                  ("status", `String "persisted");
                  ("registro_id", `String registro.Types.id_registro);
                  ("id_evento", `String registro.evento.id_evento);
                ]))

  let handle_consulta uri =
    match Uri.get_query_param uri "mision" with
    | None ->
        respond ~status:`Bad_request
          (Yojson.Safe.to_string (`Assoc [ ("error", `String "Parametro 'mision' requerido") ]))
    | Some mision ->
        let* historial = Database.consultar_historial mision in
        respond ~status:`OK historial

  let callback _conn req body =
    let uri = Cohttp.Request.uri req in
    let path = Uri.path uri |> String.rstrip ~drop:(Char.equal '/') in
    match Cohttp.Request.meth req, path with
    | `POST, "/evento" ->
        let* raw_body = Cohttp_lwt.Body.to_string body in
        handle_event_body raw_body
    | `GET, "/consulta" -> handle_consulta uri
    | _ ->
        respond ~status:`Not_found
          (Yojson.Safe.to_string (`Assoc [ ("error", `String "Endpoint no encontrado") ]))

  let start ?(port = 9004) () =
    Logs_lwt.info (fun m -> m "Servidor HTTP escuchando en puerto %d" port)
    >>= fun () ->
    let server = Cohttp_lwt_unix.Server.make ~callback () in
    Cohttp_lwt_unix.Server.create ~mode:(`TCP (`Port port)) server
end

let () =
  Random.self_init ();
  Logs.set_reporter (Logs_fmt.reporter ());
  Logs.set_level (Some Logs.Info);
  Lwt_main.run
    (let* () = Database.init () in
     Logs_lwt.app (fun m -> m "GROUND listo para recibir eventos") >>= fun () ->
     Servidor.start ())
