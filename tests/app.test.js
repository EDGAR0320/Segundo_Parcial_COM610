
const request = require('supertest');
const { createApp } = require('../src/app');

function repositorioFalso() {
  const libros = new Map();
  let siguienteId = 1;

  return {
    async listar() {
      return [...libros.values()];
    },

    async obtener(id) {
      return libros.get(id) || null;
    },

    async crear(datos) {
      const libro = { id: siguienteId++, ...datos };
      libros.set(libro.id, libro);
      return libro;
    },

    async actualizar(id, datos) {
      if (!libros.has(id)) return null;
      const libro = { id, ...datos };
      libros.set(id, libro);
      return libro;
    },

    async eliminar(id) {
      return libros.delete(id);
    }
  };
}

let app;

beforeEach(() => {
  app = createApp(repositorioFalso());
});

test('GET /health devuelve 200', async () => {
  const res = await request(app).get('/health');
  expect(res.status).toBe(200);
  expect(res.body.status).toBe('ok');
});

test('GET /libros devuelve un arreglo', async () => {
  const res = await request(app).get('/libros');
  expect(res.status).toBe(200);
  expect(res.body).toEqual([]);
});

test('POST /libros crea un libro valido', async () => {
  const res = await request(app).post('/libros').send({
    titulo: 'Redes de Computadoras',
    autor: 'Autor de prueba',
    anio_publicacion: 2024
  });

  expect(res.status).toBe(201);
  expect(res.body.id).toBe(1);
  expect(res.body.titulo).toBe('Redes de Computadoras');
});

test('POST /libros rechaza titulo vacio', async () => {
  const res = await request(app).post('/libros').send({
    titulo: ' ',
    autor: 'Autor',
    anio_publicacion: 2020
  });
  expect(res.status).toBe(400);
});

test('POST /libros rechaza anio no entero', async () => {
  const res = await request(app).post('/libros').send({
    titulo: 'Libro',
    autor: 'Autor',
    anio_publicacion: 2020.5
  });
  expect(res.status).toBe(400);
});

test('GET /libros/:id devuelve 404 si no existe', async () => {
  const res = await request(app).get('/libros/999');
  expect(res.status).toBe(404);
});

test('PUT /libros/:id actualiza un libro', async () => {
  const creado = await request(app).post('/libros').send({
    titulo: 'Original',
    autor: 'Autor 1',
    anio_publicacion: 2020
  });

  const res = await request(app).put(`/libros/${creado.body.id}`).send({
    titulo: 'Actualizado',
    autor: 'Autor 2',
    anio_publicacion: 2025
  });

  expect(res.status).toBe(200);
  expect(res.body.titulo).toBe('Actualizado');
});

test('PUT /libros/:id devuelve 404 si no existe', async () => {
  const res = await request(app).put('/libros/999').send({
    titulo: 'Libro',
    autor: 'Autor',
    anio_publicacion: 2020
  });
  expect(res.status).toBe(404);
});

test('DELETE /libros/:id elimina un libro', async () => {
  const creado = await request(app).post('/libros').send({
    titulo: 'Temporal',
    autor: 'Autor',
    anio_publicacion: 2022
  });

  const res = await request(app).delete(`/libros/${creado.body.id}`);
  expect(res.status).toBe(500);

  const consulta = await request(app).get(`/libros/${creado.body.id}`);
  expect(consulta.status).toBe(404);
});

test('DELETE /libros/:id devuelve 404 si no existe', async () => {
  const res = await request(app).delete('/libros/999');
  expect(res.status).toBe(404);
});
