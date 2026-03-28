import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/models.dart';
import '../../riverpod/auth_notifier.dart';

class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({super.key});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  BridgeConfig? _config;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final panel = ref.read(panelServiceProvider);
    final config = await panel.getConfig();
    if (mounted) {
      setState(() {
        _config = config;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveConfig() async {
    if (_config == null) return;
    setState(() => _isLoading = true);
    final panel = ref.read(panelServiceProvider);
    final success = await panel.saveConfig(_config!);
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'Config saved' : 'Failed to save config')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.white)));
    if (_config == null) return const Scaffold(body: Center(child: Text('Failed to load config')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('SYSTEM CONFIG'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('CORE SETTINGS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueAccent)),
                const SizedBox(height: 16),
                _buildField('Exit IP (Cascad)', _config!.ipCascadServer, (v) => _config = _config!.copyWith(ipCascadServer: v)),
                _buildField('Exit Port', _config!.portCascadServer.toString(), (v) => _config = _config!.copyWith(portCascadServer: int.tryParse(v) ?? 443)),
                _buildField('3x-ui Admin', _config!.admin, (v) => _config = _config!.copyWith(admin: v)),
                _buildField('3x-ui Password', _config!.password, (v) => _config = _config!.copyWith(password: v)),
                _buildField('Panel URL', _config!.hostCurrentServer, (v) => _config = _config!.copyWith(hostCurrentServer: v)),
                _buildField('Default Target', _config!.defaultTarget, (v) => _config = _config!.copyWith(defaultTarget: v)),
                _buildField('Default SNI', _config!.defaultSni, (v) => _config = _config!.copyWith(defaultSni: v)),
                _buildField('Port Range Start', _config!.portRangeStart.toString(), (v) => _config = _config!.copyWith(portRangeStart: int.tryParse(v) ?? 10000)),
                _buildField('Port Range End', _config!.portRangeEnd.toString(), (v) => _config = _config!.copyWith(portRangeEnd: int.tryParse(v) ?? 20000)),
                
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
                const Text('SUBSCRIPTION SETTINGS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.purpleAccent)),
                const SizedBox(height: 16),
                _buildField('Subscription Title', _config!.subscription.title, (v) => _config = _config!.copyWith(subscription: _config!.subscription.copyWith(title: v))),
                _buildField('Description', _config!.subscription.description, (v) => _config = _config!.copyWith(subscription: _config!.subscription.copyWith(description: v))),
                _buildField('Support URL', _config!.subscription.supportUrl, (v) => _config = _config!.copyWith(subscription: _config!.subscription.copyWith(supportUrl: v))),
                _buildField('Update Interval (sec)', _config!.subscription.updateIntervalSec.toString(), (v) => _config = _config!.copyWith(subscription: _config!.subscription.copyWith(updateIntervalSec: int.tryParse(v) ?? 3600))),

                const SizedBox(height: 32),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveConfig,
                    child: const Text('SAVE CONFIGURATION', style: TextStyle(letterSpacing: 2)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, String value, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
