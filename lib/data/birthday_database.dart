import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/birthday.dart';

/// Persistencia local de los cumpleaños con SQLite (sqflite).
class BirthdayDatabase {
  BirthdayDatabase._();

  static final BirthdayDatabase instance = BirthdayDatabase._();

  static const String _table = 'birthdays';
  static const String _databaseName = 'birthdays.db';

  Database? _database;

  Future<Database> get _db async => _database ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _databaseName);
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            birth_date TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Devuelve todos los cumpleaños ordenados por mes y día, sin importar el año.
  Future<List<Birthday>> getAll() async {
    final db = await _db;
    final rows = await db.query(
      _table,
      orderBy: 'date(birth_date), name COLLATE NOCASE',
    );
    return rows.map(Birthday.fromMap).toList();
  }

  Future<Birthday> insert(Birthday birthday) async {
    final db = await _db;
    final values = birthday.toMap()..remove('id');
    final id = await db.insert(_table, values);
    return birthday.copyWith(id: id);
  }

  Future<void> update(Birthday birthday) async {
    final db = await _db;
    await db.update(
      _table,
      birthday.toMap(),
      where: 'id = ?',
      whereArgs: [birthday.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
