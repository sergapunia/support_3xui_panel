import 'package:dio/dio.dart';

import '../models/models.dart';

class PanelService {
  late final Dio _dio;
  String? _baseUrl;

  PanelService() {
    _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 15)));
  }

  void updateBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    _dio.options.baseUrl = _baseUrl!;
  }

  Future<(bool, String?)> authenticate(
    String admin,
    String password,
    String host,
    String ipCascad,
    int portCascad,
  ) async {
    final payload = {
      'admin': admin,
      'password': password,
      'host': host,
      'ip_cascad': ipCascad,
      'port_cascad': portCascad,
    };
    print('PanelService: POST /auth | Payload: $payload');
    try {
      final response = await _dio.post('/auth', data: payload);
      print('PanelService: AUTH Response ${response.statusCode} | Data: ${response.data}');
      if (response.statusCode == 200) {
        return (true, null);
      }
      return (false, response.data?['detail']?.toString() ?? 'Unknown response status: ${response.statusCode}');
    } on DioException catch (e) {
      print('PanelService: auth dio error: ${e.type} | Response: ${e.response?.data}');
      final detail = e.response?.data?['detail']?.toString();
      final msg = detail ?? e.message ?? 'Network error';
      return (false, msg);
    } catch (e) {
      print('PanelService: auth generic error: $e');
      return (false, e.toString());
    }
  }

  Future<List<Inbound>> getInbounds() async {
    print('PanelService: GET /inbounds');
    try {
      final response = await _dio.get('/inbounds');
      print('PanelService: INBOUNDS Response ${response.statusCode} | Data: ${response.data}');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return data.map((e) => Inbound.fromJson(e)).toList();
        } else if (data is Map && data.containsKey('obj')) {
          // The API returns the list under 'obj' key
          final List list = data['obj'];
          return list.map((e) => Inbound.fromJson(e)).toList();
        }
      }
      return [];
    } catch (e) {
      print('PanelService: getInbounds error: $e');
      rethrow;
    }
  }

  Future<bool> addInbound(String remarkSuffix, int port, String target, String sni, {String? ipCascad, int? portCascad}) async {
    final payload = {
      'remark_suffix': remarkSuffix,
      'port': port,
      'target': target,
      'sni': sni,
      if (ipCascad != null) 'ip_cascad': ipCascad,
      if (portCascad != null) 'port_cascad': portCascad,
    };
    print('PanelService: POST /inbounds | Payload: $payload');
    try {
      final response = await _dio.post('/inbounds', data: payload);
      print('PanelService: ADD INBOUND Response ${response.statusCode} | Data: ${response.data}');
      return response.statusCode == 200;
    } catch (e) {
      print('PanelService: addInbound error: $e');
      return false;
    }
  }

  Future<bool> deleteInbound(int id) async {
    print('PanelService: DELETE /inbounds/$id');
    try {
      final response = await _dio.delete('/inbounds/$id');
      print('PanelService: DELETE INBOUND Response ${response.statusCode} | Data: ${response.data}');
      return response.statusCode == 200;
    } catch (e) {
      print('PanelService: deleteInbound error: $e');
      return false;
    }
  }

  Future<bool> addClient(int inboundId, String email, {int limitIp = 0, String subName = ''}) async {
    final payload = {
      'email': email,
      'limit_ip': limitIp,
      'sub_name': subName,
      'tg_id': subName, // Add tg_id for double-checking server support
    };
    print('PanelService: POST /inbounds/$inboundId/clients | Payload: $payload');
    try {
      final response = await _dio.post('/inbounds/$inboundId/clients', data: payload);
      print('PanelService: ADD CLIENT Response ${response.statusCode} | Data: ${response.data}');
      return response.statusCode == 200;
    } catch (e) {
      print('PanelService: addClient error: $e');
      return false;
    }
  }

  Future<bool> updateClient(int inboundId, String email, Map<String, dynamic> updateData) async {
    print('PanelService: PUT /inbounds/$inboundId/clients/$email | Payload: $updateData');
    try {
      final response = await _dio.put('/inbounds/$inboundId/clients/$email', data: updateData);
      print('PanelService: UPDATE CLIENT Response ${response.statusCode} | Data: ${response.data}');
      return response.statusCode == 200;
    } catch (e) {
      print('PanelService: updateClient error: $e');
      return false;
    }
  }

  Future<bool> adjustClientLimit(int inboundId, String email, int delta) async {
    final payload = {'delta': delta};
    print('PanelService: PATCH /inbounds/$inboundId/clients/$email/limit | Payload: $payload');
    try {
      final response = await _dio.patch('/inbounds/$inboundId/clients/$email/limit', data: payload);
      print('PanelService: PATCH LIMIT Response ${response.statusCode} | Data: ${response.data}');
      return response.statusCode == 200;
    } catch (e) {
      print('PanelService: adjustClientLimit error: $e');
      return false;
    }
  }

  Future<bool> deleteClient(int inboundId, String email) async {
    print('PanelService: DELETE /inbounds/$inboundId/clients/$email');
    try {
      final response = await _dio.delete('/inbounds/$inboundId/clients/$email');
      print('PanelService: DELETE CLIENT Response ${response.statusCode} | Data: ${response.data}');
      return response.statusCode == 200;
    } on DioException catch (e) {
      print('PanelService: deleteClient error: $e');
      if (e.response != null) {
        print('PanelService: Error response binary data: ${e.response?.data}');
        print('PanelService: Error message from server: ${e.response?.data?['detail'] ?? e.response?.data}');
      }
      return false;
    } catch (e) {
      print('PanelService: deleteClient error: $e');
      return false;
    }
  }

  Future<List<String>> getClientLinks(int inboundId, String email) async {
    print('PanelService: GET /inbounds/$inboundId/clients/$email/links');
    try {
      final response = await _dio.get('/inbounds/$inboundId/clients/$email/links');
      print('PanelService: GET LINKS Response ${response.statusCode} | Data: ${response.data}');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data.containsKey('links')) {
          return List<String>.from(data['links']);
        }
      }
      return [];
    } catch (e) {
      print('PanelService: getClientLinks error: $e');
      return [];
    }
  }

  Future<String?> getSubscriptionLink(String clientId) async {
    print('PanelService: GET /sub-link/$clientId');
    try {
      final response = await _dio.get('/sub-link/$clientId');
      print('PanelService: SUB-LINK Response ${response.statusCode} | Data: ${response.data}');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data.containsKey('subscription_url')) {
          return data['subscription_url'] as String;
        }
      }
      return null;
    } catch (e) {
      print('PanelService: getSubscriptionLink error: $e');
      return null;
    }
  }

  Future<BridgeConfig?> getConfig() async {
    print('PanelService: GET /config');
    try {
      final response = await _dio.get('/config');
      print('PanelService: GET CONFIG Response ${response.statusCode} | Data: ${response.data}');
      if (response.statusCode == 200) {
        return BridgeConfig.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('PanelService: getConfig error: $e');
      return null;
    }
  }

  Future<bool> saveConfig(BridgeConfig config) async {
    final payload = config.toJson();
    print('PanelService: POST /config | Payload: $payload');
    try {
      final response = await _dio.post('/config', data: payload);
      print('PanelService: SAVE CONFIG Response ${response.statusCode} | Data: ${response.data}');
      return response.statusCode == 200;
    } catch (e) {
      print('PanelService: saveConfig error: $e');
      return false;
    }
  }
}
