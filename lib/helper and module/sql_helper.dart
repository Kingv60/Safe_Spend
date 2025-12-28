import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDB();
    return _db!;
  }

  Future<Database> initDB() async {
    final databasePath = await getDatabasesPath();
    String path = join(databasePath, "bills.db");

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE bills(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bill TEXT,
            amount REAL,
            date TEXT
          )
        ''');
      },
    );
  }

  Future<int> insertBill(Map<String, dynamic> data) async {
    try {
      final dbClient = await db;
      int id = await dbClient.insert("bills", data);
      return id;
    } catch (e) {
      print("DB insert error: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getBills() async {
    final dbClient = await db;
    return await dbClient.query("bills", orderBy: "id DESC");
  }

  Future<double> getTotalAmount() async {
    final dbClient = await db;
    final result = await dbClient.rawQuery("SELECT SUM(amount) as total FROM bills");
    return result.first["total"] != null
        ? (result.first["total"] as num).toDouble()
        : 0.0;
  }

  Future<int> deleteBill(int id) async {
    final dbClient = await db;
    return await dbClient.delete("bills", where: "id = ?", whereArgs: [id]);
  }

  Future<int> updateBill(int id, Map<String, dynamic> data) async {
    final dbClient = await db;
    return await dbClient.update("bills", data, where: "id = ?", whereArgs: [id]);
  }
}
