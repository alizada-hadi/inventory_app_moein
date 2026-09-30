import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../utils/jalali_date_utils.dart';

class BackupException implements Exception {
  const BackupException(this.userMessage, [this.cause]);
  final String userMessage;
  final Object? cause;
  @override
  String toString() => userMessage;
}

class BackupFile {
  const BackupFile({required this.file, required this.createdAt});
  final File file;
  final DateTime createdAt;
  String get filename => path.basename(file.path);
}

class BackupValidationResult {
  const BackupValidationResult({
    required this.schemaVersion,
    required this.backupFormatVersion,
    required this.appVersion,
  });
  final int schemaVersion;
  final int backupFormatVersion;
  final String appVersion;
}

class LastBackupInfo {
  const LastBackupInfo({required this.createdAt, this.filename});
  final DateTime createdAt;
  final String? filename;
}

class BackupService {
  BackupService({AppDatabase? database})
    : database = database ?? AppDatabase.instance;
  final AppDatabase database;

  Future<void> clearData() async {
    final db = await database.database;
    await db.transaction((txn) async {
      for (final table in [
        'stock_movements',
        'product_price_history',
        'purchases',
        'sales',
        'products',
      ]) {
        await txn.delete(table);
      }
    });
  }

  Future<LastBackupInfo?> getLastBackupInfo() async {
    final rows = await (await database.database).query(
      'app_metadata',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty || rows.first['last_backup_at'] == null) return null;
    return LastBackupInfo(
      createdAt: DateTime.parse(rows.first['last_backup_at'] as String),
      filename: rows.first['last_backup_filename'] as String?,
    );
  }

  Future<BackupFile> createBackup() async {
    final now = DateTime.now();
    final filename = 'inventory_backup_${_fileDate(now)}.db';
    final directory = await getApplicationDocumentsDirectory();
    final backupDirectory = Directory(path.join(directory.path, 'backups'));
    await backupDirectory.create(recursive: true);
    final destination = File(path.join(backupDirectory.path, filename));
    try {
      await database.database;
      await database.checkpointAndClose();
      await _copy(
        databasePath: await database.databasePath,
        destination: destination,
      );
      await database.ensureOpen();
      await (await database.database).update(
        'app_metadata',
        {
          'last_backup_at': now.toIso8601String(),
          'last_backup_filename': filename,
        },
        where: 'id = ?',
        whereArgs: [1],
      );
      return BackupFile(file: destination, createdAt: now);
    } catch (error) {
      await database.ensureOpen();
      throw BackupException('ایجاد نسخه پشتیبان موفق نشد.', error);
    }
  }

  Future<BackupValidationResult> validateBackup(File file) async {
    if (!await file.exists()) {
      throw const BackupException('فایل نسخه پشتیبان پیدا نشد.');
    }
    if (await file.length() == 0) {
      throw const BackupException('فایل نسخه پشتیبان خالی است.');
    }
    Database? db;
    try {
      db = await openDatabase(file.path, readOnly: true, singleInstance: false);
      final integrity = await db.rawQuery('PRAGMA integrity_check');
      if (integrity.isEmpty ||
          integrity.first.values.first.toString().toLowerCase() != 'ok') {
        throw const BackupException('فایل نسخه پشتیبان آسیب‌دیده است.');
      }
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final names = tables.map((row) => row['name'] as String).toSet();
      const required = {
        'app_metadata',
        'products',
        'purchases',
        'sales',
        'stock_movements',
        'product_price_history',
      };
      if (!required.every(names.contains)) {
        throw const BackupException('ساختار فایل نسخه پشتیبان کامل نیست.');
      }
      final metadata = await db.query(
        'app_metadata',
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );
      if (metadata.isEmpty) {
        throw const BackupException('اطلاعات نسخه پشتیبان معتبر نیست.');
      }
      final row = metadata.first;
      final schemaVersion = row['schema_version'] as int;
      final formatVersion = row['backup_format_version'] as int;
      final appVersion = row['app_version'] as String;
      if (formatVersion != AppDatabase.backupFormatVersion ||
          schemaVersion > AppDatabase.schemaVersion) {
        throw const BackupException(
          'این نسخه پشتیبان با نسخه فعلی برنامه سازگار نیست.',
        );
      }
      return BackupValidationResult(
        schemaVersion: schemaVersion,
        backupFormatVersion: formatVersion,
        appVersion: appVersion,
      );
    } on BackupException {
      rethrow;
    } catch (error) {
      throw BackupException(
        'فایل انتخاب‌شده یک پایگاه داده معتبر نیست.',
        error,
      );
    } finally {
      await db?.close();
    }
  }

  Future<void> restoreBackup(File selectedFile) async {
    await validateBackup(selectedFile);
    final currentPath = await database.databasePath;
    final directory = await getApplicationDocumentsDirectory();
    final safety = File(
      path.join(
        directory.path,
        'pre_restore_backup_${_fileDate(DateTime.now())}.db',
      ),
    );
    try {
      await database.checkpointAndClose();
      await _removeSidecars(currentPath);
      await _copy(databasePath: currentPath, destination: safety);
      await _copy(
        databasePath: selectedFile.path,
        destination: File(currentPath),
      );
      await database.ensureOpen();
      await validateBackup(File(currentPath));
      if (await safety.exists()) await safety.delete();
    } catch (error) {
      try {
        await database.checkpointAndClose();
        await _removeSidecars(currentPath);
        if (await safety.exists()) {
          await _copy(
            databasePath: safety.path,
            destination: File(currentPath),
          );
        }
        await database.ensureOpen();
      } catch (rollbackError) {
        throw BackupException(
          'بازیابی ناموفق بود و بازگردانی اطلاعات قبلی نیز انجام نشد.',
          rollbackError,
        );
      }
      if (error is BackupException) rethrow;
      throw BackupException('بازیابی نسخه پشتیبان موفق نشد.', error);
    }
  }

  String _fileDate(DateTime date) =>
      '${JalaliDateUtils.format(date).replaceAll('/', '-')}_${date.hour.toString().padLeft(2, '0')}-${date.minute.toString().padLeft(2, '0')}';

  Future<void> _copy({
    required String databasePath,
    required File destination,
  }) async {
    if (path.normalize(databasePath) == path.normalize(destination.path)) {
      return;
    }
    if (await destination.exists()) await destination.delete();
    await File(databasePath).copy(destination.path);
  }

  Future<void> _removeSidecars(String databasePath) async {
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final file = File('$databasePath$suffix');
      if (await file.exists()) await file.delete();
    }
  }
}
