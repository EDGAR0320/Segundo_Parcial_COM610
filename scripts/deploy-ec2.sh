
#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE_REPO="${1:?Falta el repositorio Docker}"
SHA="${2:?Falta el SHA del commit}"
MODO="${3:-normal}"

if [[ ! "$SHA" =~ ^[0-9a-f]{40}$ ]]; then
  echo "ERROR: SHA invalido"
  exit 1
fi

BASE="/opt/com610"
ENV_FILE="$BASE/rds.env"
ACTIVE_FILE="$BASE/active-port"
NGINX_FILE="/etc/nginx/sites-available/com610-libros"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: No existe $ENV_FILE"
  exit 1
fi

if [[ ! -f "$NGINX_FILE" ]]; then
  echo "ERROR: No existe la configuracion Nginx"
  exit 1
fi

# Determinar la version activa
ACTIVE_PORT="13002"

if [[ -f "$ACTIVE_FILE" ]]; then
  ACTIVE_PORT="$(cat "$ACTIVE_FILE")"
fi

if [[ "$ACTIVE_PORT" != "13001" && "$ACTIVE_PORT" != "13002" ]]; then
  echo "ERROR: Puerto activo invalido"
  exit 1
fi

# Usar el puerto inactivo para la nueva version
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

# Restaurar la version anterior si falla el despliegue
rollback() {
  local resultado=$?
  trap - EXIT

  if [[ "$COMMITTED" == "0" ]]; then
    echo "ERROR: Despliegue fallido"
    echo "Restaurando la version anterior..."

    if [[ "$SITE_CHANGED" == "1" ]]; then
      cp "$BACKUP" "$NGINX_FILE"
      nginx -t && systemctl reload nginx || true
    fi

    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

    echo "La version anterior se conserva"
  fi

  rm -f "$BACKUP"
  exit "$resultado"
}

trap rollback EXIT

echo "======================================"
echo "INICIANDO DESPLIEGUE COM610"
echo "======================================"
echo "Imagen: $IMAGE"
echo "Puerto anterior: $ACTIVE_PORT"
echo "Puerto candidato: $TARGET_PORT"

# Descargar la imagen identificada con SHA
docker pull "$IMAGE"

# Eliminar solamente la version inactiva
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

# Iniciar contenedor nuevo, accesible solo localmente
docker run -d \
  --name "$CONTAINER" \
  --restart unless-stopped \
  --env-file "$ENV_FILE" \
  -e "APP_VERSION=$SHA" \
  -p "127.0.0.1:$TARGET_PORT:3000" \
  "$IMAGE"

# Verificar health y la consulta a RDS
echo "Verificando contenedor candidato..."

READY=0

for intento in $(seq 1 20); do
  HEALTH="$(curl -fsS --max-time 5 \
    "http://127.0.0.1:$TARGET_PORT/health" 2>/dev/null || true)"

  LIBROS="$(curl -fsS --max-time 5 \
    "http://127.0.0.1:$TARGET_PORT/libros" 2>/dev/null || true)"

  if python3 -c '
import json
import sys

health = json.loads(sys.argv[1])
libros = json.loads(sys.argv[2])
sha = sys.argv[3]

assert health.get("status") == "ok"
assert health.get("version") == sha
assert isinstance(libros, list)
' "$HEALTH" "$LIBROS" "$SHA" 2>/dev/null; then
    READY=1
    echo "Contenedor candidato saludable"
    break
  fi

  echo "Intento candidato $intento/20"
  sleep 3
done

if [[ "$READY" != "1" ]]; then
  echo "ERROR: Candidato no supera health o RDS"
  docker logs --tail 40 "$CONTAINER" || true
  exit 1
fi

# Cambiar Nginx al nuevo contenedor
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

# Simulacion controlada de fallo para el examen
if [[ "$MODO" == "--simulate-failure" ]]; then
  echo "Simulando fallo posterior al cambio de Nginx"
  exit 1
fi

# Comprobar que Nginx entrega la nueva version
echo "Verificando la API a traves de Nginx..."

VERIFICADO=0

for intento in $(seq 1 20); do
  echo "Comprobacion final $intento/20"

  HEALTH="$(curl -fsS --max-time 5 \
    http://127.0.0.1/health 2>/dev/null || true)"

  LIBROS="$(curl -fsS --max-time 5 \
    http://127.0.0.1/libros 2>/dev/null || true)"

  echo "Health recibido: $HEALTH"
  echo "Libros recibido: $LIBROS"

  if python3 -c '
import json
import sys

health = json.loads(sys.argv[1])
libros = json.loads(sys.argv[2])
sha = sys.argv[3]

assert health.get("status") == "ok"
assert health.get("version") == sha
assert isinstance(libros, list)
' "$HEALTH" "$LIBROS" "$SHA" 2>/dev/null; then
    VERIFICADO=1
    break
  fi

  sleep 2
done

if [[ "$VERIFICADO" != "1" ]]; then
  echo "ERROR: Nginx no confirma la nueva version"
  exit 1
fi

echo "Health y consulta RDS verificados"

# Confirmar la nueva version activa
printf '%s\n' "$TARGET_PORT" > "$ACTIVE_FILE.tmp"
mv "$ACTIVE_FILE.tmp" "$ACTIVE_FILE"

COMMITTED=1

echo "======================================"
echo "DESPLIEGUE EXITOSO"
echo "======================================"
echo "Puerto activo: $TARGET_PORT"
echo "Version activa: $SHA"
echo "Health: $HEALTH"
echo "Consulta RDS: correcta"
