import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsService {
  static const String _keyBaseUrl = 'bridge_base_url';
  static const String _keyAdmin = 'bridge_admin';
  static const String _keyPassword = 'bridge_password';
  static const String _keyHost = 'bridge_host';
  static const String _keyIpCascad = 'bridge_ip_cascad';
  static const String _keyPortCascad = 'bridge_port_cascad';

  Future<void> saveConnection(String baseUrl, String admin, String password, String host, String ipCascad, int portCascad) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, baseUrl);
    await prefs.setString(_keyAdmin, admin);
    await prefs.setString(_keyPassword, password);
    await prefs.setString(_keyHost, host);
    await prefs.setString(_keyIpCascad, ipCascad);
    await prefs.setInt(_keyPortCascad, portCascad);
  }

  Future<Map<String, dynamic>> getConnection() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'baseUrl': prefs.getString(_keyBaseUrl),
      'admin': prefs.getString(_keyAdmin),
      'password': prefs.getString(_keyPassword),
      'host': prefs.getString(_keyHost),
      'ip_cascad': prefs.getString(_keyIpCascad),
      'port_cascad': prefs.getInt(_keyPortCascad),
    };
  }

  Future<void> clearConnection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBaseUrl);
    await prefs.remove(_keyAdmin);
    await prefs.remove(_keyPassword);
    await prefs.remove(_keyHost);
    await prefs.remove(_keyIpCascad);
    await prefs.remove(_keyPortCascad);
  }
}
