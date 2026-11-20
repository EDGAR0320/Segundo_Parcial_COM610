
const mysql = require('mysql2/promise');

function crearRepositorio() {
  const pool = mysql.createPool({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: 5
  });

  return {
    async listar() {
      const [rows] = await pool.execute(
        'SELECT id, titulo, autor, anio_publicacion FROM libros ORDER BY id'
      );
      return rows;
    },

    async obtener(id) {
      const [rows] = await pool.execute(
        'SELECT id, titulo, autor, anio_publicacion FROM libros WHERE id = ?',
        [id]
      );
      return rows[0] || null;
    },

    async crear(datos) {
      const [result] = await pool.execute(
        'INSERT INTO libros (titulo, autor, anio_publicacion) VALUES (?, ?, ?)',
        [datos.titulo, datos.autor, datos.anio_publicacion]
      );
      return this.obtener(result.insertId);
    },

    async actualizar(id, datos) {
      const [result] = await pool.execute(
        'UPDATE libros SET titulo = ?, autor = ?, anio_publicacion = ? WHERE id = ?',
        [datos.titulo, datos.autor, datos.anio_publicacion, id]
      );
      if (result.affectedRows === 0) return null;
      return this.obtener(id);
    },

    async eliminar(id) {
      const [result] = await pool.execute(
        'DELETE FROM libros WHERE id = ?',
        [id]
      );
      return result.affectedRows > 0;
    }
  };
}

module.exports = { crearRepositorio };
