import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/backup_service.dart';

final backupServiceProvider = Provider<BackupService>((_) => BackupService());

final lastBackupProvider = FutureProvider<LastBackupInfo?>(
  (ref) => ref.read(backupServiceProvider).getLastBackupInfo(),
);
