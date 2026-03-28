import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/models.dart';
import '../../riverpod/auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _adminController = TextEditingController();
  final _passController = TextEditingController();
  final _hostController = TextEditingController();
  final _ipCascadController = TextEditingController();
  final _portCascadController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill some defaults or existing data
    Future.microtask(() {
      final state = ref.read(authProvider);
      if (state.baseUrl != null) {
        _urlController.text = state.baseUrl!;
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _adminController.dispose();
    _passController.dispose();
    _hostController.dispose();
    _ipCascadController.dispose();
    _portCascadController.dispose();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    if (_formKey.currentState!.validate()) {
      final success = await ref
          .read(authProvider.notifier)
          .connect(
            _urlController.text,
            _adminController.text,
            _passController.text,
            _hostController.text,
            _ipCascadController.text,
            int.tryParse(_portCascadController.text) ?? 443,
          );
      if (!success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ref.read(authProvider).errorMessage ?? 'Connection failed')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(authProvider).status;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: Colors.black),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: Text(
                            'BRIDGE',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                              color: Colors.white,
                              shadows: [Shadow(color: Colors.white54, blurRadius: 10)],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text('Enter Panel Credentials', style: TextStyle(color: Colors.white60, fontSize: 13)),
                        ),
                        const SizedBox(height: 40),
                        TextFormField(
                          controller: _urlController,
                          decoration: const InputDecoration(labelText: 'Bridge API URL', hintText: 'http://ip:8000'),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _adminController,
                          decoration: const InputDecoration(labelText: '3x-ui User'),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _passController,
                          decoration: const InputDecoration(labelText: '3x-ui Password'),
                          obscureText: true,
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _hostController,
                          decoration: const InputDecoration(
                            labelText: 'Panel Root URL',
                            hintText: 'https://domain.com/secret',
                          ),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _ipCascadController,
                                decoration: const InputDecoration(labelText: 'Exit IP'),
                                validator: (v) => v!.isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _portCascadController,
                                decoration: const InputDecoration(labelText: 'Port'),
                                keyboardType: TextInputType.number,
                                validator: (v) => v!.isEmpty ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              elevation: 10,
                              shadowColor: Colors.white30,
                            ),
                            onPressed: status == GameState.connecting ? null : _handleConnect,
                            child: status == GameState.connecting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : const Text('AUTHORIZE', style: TextStyle(letterSpacing: 2)),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
