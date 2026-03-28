import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/shared_prefs_service.dart';
import '../domain/models/models.dart';
import '../domain/services/panel_service.dart';

final sharedPrefsProvider = Provider((ref) => SharedPrefsService());
final panelServiceProvider = Provider((ref) => PanelService());

class AuthState {
  final GameState status;
  final String? baseUrl;
  final String? errorMessage;

  AuthState({required this.status, this.baseUrl, this.errorMessage});

  AuthState copyWith({GameState? status, String? baseUrl, String? errorMessage}) {
    return AuthState(
      status: status ?? this.status,
      baseUrl: baseUrl ?? this.baseUrl,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final SharedPrefsService _prefs;
  final PanelService _panel;

  AuthNotifier(this._prefs, this._panel) : super(AuthState(status: GameState.initial)) {
    _init();
  }

  Future<void> _init() async {
    // Wait longer for the Flutter engine to fully stabilize on Web
    await Future.delayed(const Duration(seconds: 2));

    final conn = await _prefs.getConnection();
    if (conn['baseUrl'] != null && conn['admin'] != null && conn['password'] != null) {
      print('AuthNotifier: Found stored credentials, attempting auto-login...');
      await connect(
        conn['baseUrl']!,
        conn['admin']!,
        conn['password']!,
        conn['host'] ?? '',
        conn['ip_cascad'] ?? '',
        conn['port_cascad'] ?? 443,
      );
    } else {
      print('AuthNotifier: No stored credentials, showing login screen');
      state = state.copyWith(status: GameState.idle);
    }
  }

  Future<bool> connect(String url, String admin, String password, String host, String ipCascad, int portCascad) async {
    print('AuthNotifier: connecting to $url');
    state = state.copyWith(status: GameState.connecting, errorMessage: null);
    _panel.updateBaseUrl(url);

    final (success, error) = await _panel.authenticate(admin, password, host, ipCascad, portCascad);

    if (success) {
      print('AuthNotifier: auth success');
      await _prefs.saveConnection(url, admin, password, host, ipCascad, portCascad);
      state = state.copyWith(status: GameState.connected, baseUrl: url, errorMessage: null);
      return true;
    } else {
      print('AuthNotifier: auth failed: $error');
      // Do not clear connection here to allow user to see/fix their input
      state = state.copyWith(status: GameState.idle, errorMessage: error ?? 'Authentication failed');
      return false;
    }
  }

  Future<void> logout() async {
    print('AuthNotifier: Logging out');
    await _prefs.clearConnection();
    state = state.copyWith(status: GameState.idle, baseUrl: '', errorMessage: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(sharedPrefsProvider), ref.watch(panelServiceProvider));
});
