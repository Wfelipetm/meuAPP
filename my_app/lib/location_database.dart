import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class LocationDatabase {
  static Database? _database;
  static const String tableName = 'locations';

  Future<Database> get database async {
    return _database ??= await initDatabase();
  }

  Future<Database> initDatabase() async {
    final String appDocumentDir =
        await getApplicationDocumentsDirectory().then((value) => value.path);
    final String dbFolderPath = join(appDocumentDir, 'database_folder');
    await Directory(dbFolderPath).create(recursive: true);

    final String path = join(dbFolderPath, 'locations.db');
    print('Caminho do banco de dados: $path');

    try {
      return await openDatabase(path, version: 1, onCreate: _onCreate);
    } catch (e) {
      print('Erro ao abrir/criar o banco de dados: $e');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    print('Criando tabela $tableName');
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL,
        longitude REAL,
        timestamp TEXT
      )
    ''');
  }

  Future<void> insertLocation(double latitude, double longitude) async {
    final Database db = await database;

    await db.insert(
      tableName,
      {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> getLocations() async {
    final Database db = await database;
    return db.query(tableName);
  }
}
