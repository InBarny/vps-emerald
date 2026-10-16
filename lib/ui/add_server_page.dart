import 'package:flutter/material.dart';

import '../models/server_config.dart';
import 'theme/app_theme.dart';

class AddServerPage extends StatefulWidget {
  const AddServerPage({super.key});

  @override
  State<AddServerPage> createState() => _AddServerPageState();
}

class _AddServerPageState extends State<AddServerPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController(text: 'My Server');
  final _address = TextEditingController();
  final _port = TextEditingController(text: '443');
  final _uuid = TextEditingController();
  final _sni = TextEditingController();
  final _publicKey = TextEditingController();
  final _shortId = TextEditingController();
  final _fingerprint = TextEditingController(text: 'chrome');
  final _flow = TextEditingController(text: 'xtls-rprx-vision');

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final server = ServerConfig(
      name: _name.text.trim(),
      address: _address.text.trim(),
      port: int.parse(_port.text.trim()),
      uuid: _uuid.text.trim(),
      serverName: _sni.text.trim(),
      publicKey: _publicKey.text.trim(),
      shortId: _shortId.text.trim(),
      fingerprint: _fingerprint.text.trim(),
      flow: _flow.text.trim(),
    );

    Navigator.pop(context, server);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Добавить сервер'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _field(_name, 'Название'),
            _field(_address, 'Адрес (IP/домен)', required: true),
            _field(
              _port,
              'Порт',
              keyboardType: TextInputType.number,
              required: true,
            ),
            _field(_uuid, 'UUID', required: true),
            _field(_sni, 'SNI (Server Name)', required: true),
            _field(_publicKey, 'Reality Public Key', required: true),
            _field(_shortId, 'Short ID'),
            _field(_fingerprint, 'Fingerprint'),
            _field(_flow, 'Flow'),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(onPressed: _save, child: const Text('Сохранить')),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.text),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textDim),
          hintStyle: const TextStyle(color: AppColors.textDark),
          filled: true,
          fillColor: const Color(0x08FFFFFF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.glassBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.glassBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.emerald),
          ),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty)
                  ? 'Поле $label обязательно'
                  : null
            : null,
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _port.dispose();
    _uuid.dispose();
    _sni.dispose();
    _publicKey.dispose();
    _shortId.dispose();
    _fingerprint.dispose();
    _flow.dispose();
    super.dispose();
  }
}
