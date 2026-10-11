import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naavis_pos/core/db/app_database.dart';

/// Smoke test: ¿abre sqlite3 en memoria en este entorno (Windows/dev)?
void main() {
  test('AppDatabase abre en memoria', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.categories).insert(const Category(id: 1, name: 'Test'));
    final rows = await db.select(db.categories).get();
    expect(rows, hasLength(1));
    expect(rows.first.name, 'Test');
    await db.close();
  });
}
