# Segundo Examen Parcial — COM610

**Materia:** Trabajando en la Nube  

**Universidad:** San Francisco Xavier de Chuquisaca  

**Estudiante:** Edgar Tito Gonzales

API REST de libros desarrollada con **Node.js y Express**, desplegada en **Amazon EC2** y conectada a **Amazon RDS MariaDB**. Incluye pruebas automáticas y despliegue CI/CD con GitHub Actions y Docker.

## 1. Ejecutar la aplicación y las pruebas

Requisitos: **Node.js 22**, npm y una base MariaDB accesible con la tabla creada mediante `db.sql`.

```bash
git clone https://github.com/EDGAR0320/Segundo_Parcial_COM610.git
cd Segundo_Parcial_COM610
npm ci
```

Configurar las variables indicadas en `.env.example` dentro de un archivo `.env` local, con los datos reales de una base autorizada. **No subir `.env` a GitHub.**

```bash
npm start
```

Para probar la API sin RDS (Jest y Supertest):

```bash
npm test
```

Para construir y comprobar la imagen Docker localmente:

```bash
docker build -t com610-libros:local .
docker run --rm --name com610-prueba --env-file .env.example -p 127.0.0.1:3001:3000 com610-libros:local
```

En otra terminal:

**URL de la API:** http://3.142.17.97/health

**Consultar Libros:** http://3.142.17.97/libros

La prueba de `/health` funciona con valores ficticios; las operaciones de libros requieren credenciales válidas de MariaDB.

## 2. API pública

**URL:** http://3.142.17.97/health

| Método | Ruta | Función |
|---|---|---|
| GET | `/health` | Estado y versión de la API |
| GET | `/libros` | Listar libros |
| GET | `/libros/:id` | Consultar un libro |
| POST | `/libros` | Crear un libro |
| PUT | `/libros/:id` | Actualizar un libro |
| DELETE | `/libros/:id` | Eliminar un libro |

Comprobación del servicio desplegado:

```bash
curl -i http://3.142.17.97/health
curl -i http://3.142.17.97/libros
```

## 3. Recursos AWS utilizados

- **EC2:** `ETG_Parcial2`, Ubuntu, región `us-east-2`; IP elástica `3.142.17.97`.
- **RDS:** `db-etg-parcial2`, motor MariaDB, base `com610_libros` y tabla `libros` creada con `db.sql`.
- **VPC y Security Groups:** comunicación EC2–RDS por el puerto 3306; Nginx publica la API por el puerto 80.
- **Docker:** contenedor Node.js conectado a RDS mediante TLS; puerto de aplicación limitado a `127.0.0.1` en EC2.

## 4. CI/CD y verificación del despliegue

- **CI (`.github/workflows/ci.yml`):** ejecuta `npm ci` y `npm test` en `push` y `pull_request` hacia `main`.
- **CD (`.github/workflows/cd.yml`):** tras aprobar las pruebas, construye y publica la imagen con el **SHA del commit** en Docker Hub y la despliega automáticamente en EC2. Verifica `/health` y `/libros` y restaura la versión anterior si falla la comprobación.

**Ejecuciones exitosas:**

- [CI exitoso](https://github.com/EDGAR0320/Segundo_Parcial_COM610/actions/runs/44675802980)
- [CD exitoso](https://github.com/EDGAR0320/Segundo_Parcial_COM610/actions/runs/44675802985)

**Registro de contenedores:** [Docker Hub — kafciel/com610-libros](https://hub.docker.com/r/kafciel/com610-libros/tags)

La versión instalada se comprueba con `GET /health`: el campo `version` corresponde al SHA de la imagen desplegada.

## 5. Documentación y evidencias

- [Informe del examen](evidencias/INFORME.md)
- [Capturas y evidencias](evidencias/)
- [Imágenes del informe](img/)
- [Archivo de ejemplo de variables](.env.example)

No se publican contraseñas, tokens, claves privadas ni archivos `.env` reales. Los recursos AWS deben permanecer activos hasta concluir la revisión docente.

