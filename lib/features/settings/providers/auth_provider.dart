import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_service.dart';

final authServiceProvider = Provider<AuthService>((_) => AuthService());
