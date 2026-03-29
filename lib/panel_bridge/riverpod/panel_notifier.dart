import 'package:flutter_riverpod/legacy.dart';
import '../domain/models/models.dart';
import '../domain/services/panel_service.dart';
import 'auth_notifier.dart';

class PanelState {
  final List<Inbound> inbounds;
  final bool isLoading;
  final bool isActionLoading; // For client creation, delete, etc.
  final String? error;

  PanelState({
    required this.inbounds,
    required this.isLoading,
    this.isActionLoading = false,
    this.error,
  });

  PanelState copyWith({
    List<Inbound>? inbounds,
    bool? isLoading,
    bool? isActionLoading,
    String? error,
  }) {
    return PanelState(
      inbounds: inbounds ?? this.inbounds,
      isLoading: isLoading ?? this.isLoading,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      error: error ?? this.error,
    );
  }
}

class PanelNotifier extends StateNotifier<PanelState> {
  final PanelService _panel;

  PanelNotifier(this._panel) : super(PanelState(inbounds: [], isLoading: false)) {
    // Initial fetch if needed, usually triggered from UI
  }

  Future<void> fetchInbounds() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final inbounds = await _panel.getInbounds();
      state = state.copyWith(inbounds: inbounds, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addInbound(String suffix, int port, String target, String sni, {String? ipCascad, int? portCascad}) async {
    state = state.copyWith(isActionLoading: true);
    final success = await _panel.addInbound(suffix, port, target, sni, ipCascad: ipCascad, portCascad: portCascad);
    if (success) {
      await fetchInbounds();
    }
    state = state.copyWith(isActionLoading: false);
  }

  Future<void> deleteInbound(int id) async {
    state = state.copyWith(isActionLoading: true);
    final success = await _panel.deleteInbound(id);
    if (success) {
      await fetchInbounds();
    }
    state = state.copyWith(isActionLoading: false);
  }

  Future<void> addClient(int inboundId, String email, {int limitIp = 0, String subName = ''}) async {
    state = state.copyWith(isActionLoading: true);
    final success = await _panel.addClient(inboundId, email, limitIp: limitIp, subName: subName);
    if (success) {
      await fetchInbounds();
    }
    state = state.copyWith(isActionLoading: false);
  }

  Future<void> updateClient(int inboundId, String email, Map<String, dynamic> updateData) async {
    state = state.copyWith(isActionLoading: true);
    final success = await _panel.updateClient(inboundId, email, updateData);
    if (success) {
      await fetchInbounds();
    }
    state = state.copyWith(isActionLoading: false);
  }

  Future<void> adjustClientLimit(int inboundId, String email, int delta) async {
    state = state.copyWith(isActionLoading: true);
    final success = await _panel.adjustClientLimit(inboundId, email, delta);
    if (success) {
      await fetchInbounds();
    }
    state = state.copyWith(isActionLoading: false);
  }

  Future<void> deleteClient(int inboundId, String email) async {
    state = state.copyWith(isActionLoading: true);
    final success = await _panel.deleteClient(inboundId, email);
    if (success) {
      await fetchInbounds();
    }
    state = state.copyWith(isActionLoading: false);
  }

  Future<List<String>> getClientLinks(int inboundId, String email) async {
    return await _panel.getClientLinks(inboundId, email);
  }

  // clientId can be UUID or email — server resolves both
  Future<String?> getSubscriptionLink(String clientId) async {
    return await _panel.getSubscriptionLink(clientId);
  }
}

final panelProvider = StateNotifierProvider<PanelNotifier, PanelState>((ref) {
  final service = ref.watch(panelServiceProvider);
  return PanelNotifier(service);
});
