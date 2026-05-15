#------------------------------------------
# Ejemplo de Dockerfile para OCaml (Ground)
#------------------------------------------
FROM ocaml/opam:alpine

WORKDIR /app

# Instalar dependencias del sistema
RUN apk add --no-cache \
    gcc \
    musl-dev \
    make \
    m4 \
    mysql-dev \
    pkgconfig

# Instalar dependencias de OCaml
RUN opam install -y \
    dune \
    core \
    lwt \
    lwt_ppx \
    cohttp-lwt \
    yojson \
    mysql \
    ppx_jane \
    base

# Copiar archivos del proyecto
COPY . .

# Construir el proyecto
RUN dune build --profile=release

# Exponer puerto
EXPOSE 9004

# Comando para ejecutar
CMD ["dune", "exec", "./ground.exe"]
