
#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE_REPO="${1:?Falta el repositorio de Docker}"
SHA="${2:?Falta el SHA del commit}"
MODO="${3:-normal}"

if [[ ! "$SHA" =~ ^[0-9a-f]{40}$ ]]; then
  echo "ERROR: El SHA debe tener 40 caracteres hexadecimales"
  exit 1
fi

BASE="/opt/com610"
ENV_FILE="$BASE/rds.env"
ACTIVE_FILE="$BASE/active-port"
NGINX_FILE="/etc/nginx/sites-available/com610-libros"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: Falta $ENV_FILE"
  exit 1
fi

if [[ ! -f "$NGINX_FILE" ]]; then
  echo "ERROR: Falta la configuracion Nginx"
  exit 1
fi

# Seleccionar el puerto inactivo.
ACTIVE_PORT="13002"

if [[ -f "$ACTIVE_FILE" ]]; then
  ACTIVE_PORT="$(cat "$ACTIVE_FILE")"
fi

if [[ "$ACTIVE_PORT" == "13001" ]]; then
  TARGET_PORT="13002"
else
  TARGET_PORT="13001"
fi

CONTAINER="com610-libros-$TARGET_PORT"
IMAGE="$IMAGE_REPO:$SHA"

BACKUP="$(mktemp)"
SITE_CHANGED=0
COMMITTED=0

cp "$NGINX_FILE" "$BACKUP"

rollback() {
  local result=$?
  trap - EXIT

  if [[ "$COMMITTED" == "0" ]]; then
    echo "Despliegue fallido. Restaurando estado anterior..."

    if [[ "$SITE_CHANGED" == "1" ]]; then
      cp "$BACKUP" "$NGINX_FILE"
      nginx -t && systemctl reload nginx || true
    fi

    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
    echo "La version anterior se conserva"
  fi

  rm -f "$BACKUP"
  exit "$result"
}

trap rollback EXIT

echo "Imagen solicitada: $IMAGE"
echo "Puerto de destino: $TARGET_PORT"

# No alterar el contenedor activo.
docker pull "$IMAGE"

# Reemplazar solamente el contenedor inactivo.
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

docker run -d \
  --name "$CONTAINER" \
  --restart unless-stopped \
  --env-file "$ENV_FILE" \
  -e "APP_VERSION=$SHA" \
  -p "127.0.0.1:$TARGET_PORT:3000" \
  "$IMAGE"

echo "Verificando contenedor candidato..."

READY=0

for intento in $(seq 1 20); do
  if curl -fsS --max-time 5 \
      "http://127.0.0.1:$TARGET_PORT/health" \
      | grep -Fq "\"version\":\"$SHA\"" \
    && curl -fsS --max-time 5 \
      "http://127.0.0.1:$TARGET_PORT/libros" \
      | grep -Eq '^[[:space:]]*\['; then

    READY=1
    break
  fi

  sleep 3
done

if [[ "$READY" != "1" ]]; then
  echo "ERROR: El candidato no supera health o consulta a RDS"
  docker logs --tail 40 "$CONTAINER" || true
  exit 1
fi

echo "Candidato saludable. Cambiando Nginx..."

SITE_CHANGED=1

cat > "$NGINX_FILE" <<EOF
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:$TARGET_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

nginx -t
systemctl reload nginx

# Permite demostrar el rollback sin dañar el codigo.
if [[ "$MODO" == "--simulate-failure" ]]; then
  echo "Simulando comprobacion posterior fallida"
  exit 1
fi

echo "Verificando la API a traves de Nginx..."

HEALTH="$(curl -fsS --max-time 10 http://127.0.0.1/health)"
LIBROS="$(curl -fsS --max-time 10 http://127.0.0.1/libros)"

echo "$HEALTH" | grep -Fq "\"version\":\"$SHA\""
echo "$LIBROS" | grep -Eq '^[[:space:]]*\['

# Confirmar el nuevo puerto activo solo al terminar.
printf '%s\n' "$TARGET_PORT" > "$ACTIVE_FILE.tmp"
mv "$ACTIVE_FILE.tmp" "$ACTIVE_FILE"

COMMITTED=1

echo "Despliegue correcto"
echo "Puerto activo: $TARGET_PORT"
echo "Version activa: $SHA"
echo "Health: $HEALTH"
echo "Consulta RDS: correcta"
