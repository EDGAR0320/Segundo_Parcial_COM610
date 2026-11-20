
const express = require('express');

function createApp(repo) {
  const app = express();
  app.use(express.json());

  const validarId = (valor) => {
    const id = Number(valor);
    return /^[1-9]\d*$/.test(valor) && Number.isSafeInteger(id)
      ? id : null;
  };

  const validarLibro = (body) => {
    if (!body || typeof body !== 'object') return null;

    const { titulo, autor, anio_publicacion } = body;

    if (
      typeof titulo !== 'string' ||
      !titulo.trim() ||
      typeof autor !== 'string' ||
      !autor.trim() ||
      !Number.isInteger(anio_publicacion) ||
      anio_publicacion < 0 ||
      anio_publicacion > 65535
    ) {
      return null;
    }

    return {
      titulo: titulo.trim(),
      autor: autor.trim(),
      anio_publicacion
    };
  };

  const manejar = (fn) => (req, res, next) => {
    Promise.resolve(fn(req, res)).catch(next);
  };

  app.get('/health', (req, res) => {
    res.status(200).json({
      status: 'ok',
      servicio: 'api-libros-com610',
      version: process.env.APP_VERSION || 'local'
    });
  });

  app.get('/libros', manejar(async (req, res) => {
    const libros = await repo.listar();
    res.json(libros);
  }));

  app.get('/libros/:id', manejar(async (req, res) => {
    const id = validarId(req.params.id);
    if (!id) return res.status(400).json({ error: 'ID invalido' });

    const libro = await repo.obtener(id);
    if (!libro) return res.status(404).json({ error: 'Libro no encontrado' });

    res.json(libro);
  }));

  app.post('/libros', manejar(async (req, res) => {
    const datos = validarLibro(req.body);
    if (!datos) {
      return res.status(400).json({ error: 'Datos del libro invalidos' });
    }

    const libro = await repo.crear(datos);
    res.status(201).json(libro);
  }));

  app.put('/libros/:id', manejar(async (req, res) => {
    const id = validarId(req.params.id);
    if (!id) return res.status(400).json({ error: 'ID invalido' });

    const datos = validarLibro(req.body);
    if (!datos) {
      return res.status(400).json({ error: 'Datos del libro invalidos' });
    }

    const libro = await repo.actualizar(id, datos);
    if (!libro) return res.status(404).json({ error: 'Libro no encontrado' });

    res.json(libro);
  }));

  app.delete('/libros/:id', manejar(async (req, res) => {
    const id = validarId(req.params.id);
    if (!id) return res.status(400).json({ error: 'ID invalido' });

    const eliminado = await repo.eliminar(id);
    if (!eliminado) {
      return res.status(404).json({ error: 'Libro no encontrado' });
    }

    res.json({ mensaje: 'Libro eliminado correctamente' });
  }));

  app.use((err, req, res, next) => {
    if (err.type === 'entity.parse.failed') {
      return res.status(400).json({ error: 'JSON invalido' });
    }

    console.error('Error del servidor:', err.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  });

  return app;
}

module.exports = { createApp };
