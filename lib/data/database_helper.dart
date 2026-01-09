import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class WalkDbHelper {
  static final WalkDbHelper instance = WalkDbHelper._init();
  static Database? _database;

  WalkDbHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('walk_cache.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          // lat, lng 좌표와 기록 시간을 저장하는 테이블
          await db.execute('''
          CREATE TABLE walk_points (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
        }
    );
  }

  // 좌표 실시간 추가
  Future<void> insertPoint(double lat, double lng) async {
    final db = await instance.database;
    await db.insert('walk_points', {
      'latitude': lat,
      'longitude': lng,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 저장된 모든 좌표 불러오기 (복구용)
  Future<List<LatLng>> getAllPoints() async {
    final db = await instance.database;
    final result = await db.query('walk_points', orderBy: 'id ASC');

    return result.map((json) => LatLng(
      json['latitude'] as double,
      json['longitude'] as double,
    )).toList();
  }

  // 캐시 비우기 (산책 종료/저장 성공 후)
  Future<void> clearCache() async {
    final db = await instance.database;
    await db.delete('walk_points');
  }
}