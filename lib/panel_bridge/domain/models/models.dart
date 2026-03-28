import 'dart:convert';
import 'package:uuid/uuid.dart';

enum GameState { idle, initial, connecting, connected, error }

class Inbound {
  final int id;
  final String remark;
  final int port;
  final String protocol;
  final bool enable;
  final int up;
  final int down;
  final int total;
  final int expiryTime;
  final List<Client> clients;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> streamSettings;
  final Map<String, dynamic> sniffing;

  Inbound({
    required this.id,
    required this.remark,
    required this.port,
    required this.protocol,
    required this.enable,
    required this.up,
    required this.down,
    required this.total,
    required this.expiryTime,
    required this.clients,
    required this.settings,
    required this.streamSettings,
    required this.sniffing,
  });

  factory Inbound.fromJson(Map<String, dynamic> json) {
    // 1. Помощник для парсинга вложенных JSON-строк (3x-ui часто присылает их строками)
    Map<String, dynamic> parseNestedJson(dynamic data) {
      if (data == null) return {};
      if (data is Map) return Map<String, dynamic>.from(data);
      if (data is String && data.isNotEmpty) {
        try {
          return jsonDecode(data) as Map<String, dynamic>;
        } catch (e) {
          return {};
        }
      }
      return {};
    }

    final settingsMap = parseNestedJson(json['settings']);
    final streamSettingsMap = parseNestedJson(json['streamSettings']);
    final sniffingMap = parseNestedJson(json['sniffing']);

    // 2. Извлекаем список клиентов (они могут быть в корне или внутри settings)
    dynamic clientsRaw = json['clients'] ?? settingsMap['clients'];
    List clientsList = clientsRaw is List ? clientsRaw : [];

    return Inbound(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      remark: json['remark']?.toString() ?? '',
      port: int.tryParse(json['port']?.toString() ?? '') ?? 0,
      protocol: json['protocol']?.toString() ?? '',
      enable: json['enable'] == true || json['enable'] == 1,
      up: int.tryParse(json['up']?.toString() ?? '') ?? 0,
      down: int.tryParse(json['down']?.toString() ?? '') ?? 0,
      total: int.tryParse(json['total']?.toString() ?? '') ?? 0,
      expiryTime: int.tryParse(json['expiryTime']?.toString() ?? '') ?? 0,
      clients: clientsList
          .map((e) => Client.fromJson(e is Map<String, dynamic> ? e : {}))
          .toList(),
      settings: settingsMap,
      streamSettings: streamSettingsMap,
      sniffing: sniffingMap,
    );
  }

  Inbound copyWith({
    int? id,
    String? remark,
    int? port,
    String? protocol,
    bool? enable,
    int? up,
    int? down,
    int? total,
    int? expiryTime,
    List<Client>? clients,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? streamSettings,
    Map<String, dynamic>? sniffing,
  }) {
    return Inbound(
      id: id ?? this.id,
      remark: remark ?? this.remark,
      port: port ?? this.port,
      protocol: protocol ?? this.protocol,
      enable: enable ?? this.enable,
      up: up ?? this.up,
      down: down ?? this.down,
      total: total ?? this.total,
      expiryTime: expiryTime ?? this.expiryTime,
      clients: clients ?? this.clients,
      settings: settings ?? this.settings,
      streamSettings: streamSettings ?? this.streamSettings,
      sniffing: sniffing ?? this.sniffing,
    );
  }
}

class Client {
  final String id;
  final String email;
  final String flow;
  final bool enable;
  final int limitIp;
  final int totalGB;
  final int expiryTime;
  final String subName; // Mapping to tgId in API
  final String subId;
  final int onlineCount; // New in latest TZ

  Client({
    required this.id,
    required this.email,
    required this.flow,
    required this.enable,
    required this.limitIp,
    required this.totalGB,
    required this.expiryTime,
    required this.subName,
    required this.subId,
    required this.onlineCount,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    int safeInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      return int.tryParse(value.toString()) ?? 0;
    }

    return Client(
      id: (json['id'] ?? json['uuid'] ?? const Uuid().v4()).toString(),
      email: json['email']?.toString() ?? 'No Email',
      flow: json['flow']?.toString() ?? '',
      enable: json['enable'] == true || json['enable'] == 1,
      limitIp: safeInt(json['limitIp'] ?? json['limit_ip']),
      totalGB: safeInt(json['totalGB']),
      expiryTime: safeInt(json['expiryTime']),
      subName: json['subName']?.toString() ?? json['sub_name']?.toString() ?? json['tgId']?.toString() ?? '',
      subId: json['subId']?.toString() ?? '',
      onlineCount: safeInt(json['onlineCount'] ?? json['online_count']),
    );
  }

  Client copyWith({
    String? id,
    String? email,
    String? flow,
    bool? enable,
    int? limitIp,
    int? totalGB,
    int? expiryTime,
    String? subName,
    String? subId,
    int? onlineCount,
  }) {
    return Client(
      id: id ?? this.id,
      email: email ?? this.email,
      flow: flow ?? this.flow,
      enable: enable ?? this.enable,
      limitIp: limitIp ?? this.limitIp,
      totalGB: totalGB ?? this.totalGB,
      expiryTime: expiryTime ?? this.expiryTime,
      subName: subName ?? this.subName,
      subId: subId ?? this.subId,
      onlineCount: onlineCount ?? this.onlineCount,
    );
  }
}

class SubscriptionConfig {
  final String title;
  final String description;
  final String supportUrl;
  final int updateIntervalSec;

  SubscriptionConfig({
    required this.title,
    required this.description,
    required this.supportUrl,
    required this.updateIntervalSec,
  });

  factory SubscriptionConfig.fromJson(Map<String, dynamic> json) {
    return SubscriptionConfig(
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      supportUrl: json['support_url']?.toString() ?? '',
      updateIntervalSec: int.tryParse(json['update_interval_sec']?.toString() ?? '') ?? 3600,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'support_url': supportUrl,
      'update_interval_sec': updateIntervalSec,
    };
  }

  SubscriptionConfig copyWith({
    String? title,
    String? description,
    String? supportUrl,
    int? updateIntervalSec,
  }) {
    return SubscriptionConfig(
      title: title ?? this.title,
      description: description ?? this.description,
      supportUrl: supportUrl ?? this.supportUrl,
      updateIntervalSec: updateIntervalSec ?? this.updateIntervalSec,
    );
  }
}

class BridgeConfig {
  final String ipCascadServer;
  final int portCascadServer;
  final String admin;
  final String password;
  final String hostCurrentServer;
  final String defaultTarget;
  final String defaultSni;
  final int portRangeStart;
  final int portRangeEnd;
  final SubscriptionConfig subscription;

  BridgeConfig({
    required this.ipCascadServer,
    required this.portCascadServer,
    required this.admin,
    required this.password,
    required this.hostCurrentServer,
    required this.defaultTarget,
    required this.defaultSni,
    required this.portRangeStart,
    required this.portRangeEnd,
    required this.subscription,
  });

  factory BridgeConfig.fromJson(Map<String, dynamic> json) {
    return BridgeConfig(
      ipCascadServer: json['ip_cascad_server']?.toString() ?? '',
      portCascadServer: int.tryParse(json['port_cascad_server']?.toString() ?? '') ?? 443,
      admin: json['3xui_admin']?.toString() ?? '',
      password: json['3xui_password']?.toString() ?? '',
      hostCurrentServer: json['host_current_server']?.toString() ?? '',
      defaultTarget: json['default_target']?.toString() ?? '',
      defaultSni: json['default_sni']?.toString() ?? '',
      portRangeStart: int.tryParse(json['start_range_ports']?.toString() ?? '') ?? 10000,
      portRangeEnd: int.tryParse(json['end_range_ports']?.toString() ?? '') ?? 20000,
      subscription: SubscriptionConfig.fromJson(json['subscription'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ip_cascad_server': ipCascadServer,
      'port_cascad_server': portCascadServer,
      '3xui_admin': admin,
      '3xui_password': password,
      'host_current_server': hostCurrentServer,
      'default_target': defaultTarget,
      'default_sni': defaultSni,
      'start_range_ports': portRangeStart,
      'end_range_ports': portRangeEnd,
      'subscription': subscription.toJson(),
    };
  }

  BridgeConfig copyWith({
    String? ipCascadServer,
    int? portCascadServer,
    String? admin,
    String? password,
    String? hostCurrentServer,
    String? defaultTarget,
    String? defaultSni,
    int? portRangeStart,
    int? portRangeEnd,
    SubscriptionConfig? subscription,
  }) {
    return BridgeConfig(
      ipCascadServer: ipCascadServer ?? this.ipCascadServer,
      portCascadServer: portCascadServer ?? this.portCascadServer,
      admin: admin ?? this.admin,
      password: password ?? this.password,
      hostCurrentServer: hostCurrentServer ?? this.hostCurrentServer,
      defaultTarget: defaultTarget ?? this.defaultTarget,
      defaultSni: defaultSni ?? this.defaultSni,
      portRangeStart: portRangeStart ?? this.portRangeStart,
      portRangeEnd: portRangeEnd ?? this.portRangeEnd,
      subscription: subscription ?? this.subscription,
    );
  }
}
