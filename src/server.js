
require('dotenv').config();

const { createApp } = require('./app');
const { crearRepositorio } = require('./db');

const variables = ['DB_HOST', 'DB_USER', 'DB_PASSWORD', 'DB_NAME'];

for (const nombre of variables) {
  if (!process.env[nombre]) {
    console.error(`Falta la variable de entorno: ${nombre}`);
    process.exit(1);
  }
}

const app = createApp(crearRepositorio());
const port = Number(process.env.PORT || 3000);

app.listen(port, '0.0.0.0', () => {
  console.log(`API de libros escuchando en puerto ${port}`);
});
