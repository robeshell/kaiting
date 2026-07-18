import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../sources/webdav/webdav_connection_service.dart';
import '../../sources/webdav/webdav_credentials.dart';
import '../widgets/sound_components.dart';

class WebDavAddDialog extends StatefulWidget {
  const WebDavAddDialog({
    required this.service,
    this.connection,
    this.bottomSheet = false,
    super.key,
  });

  final WebDavConnectionService service;
  final WebDavConnectionRecord? connection;
  final bool bottomSheet;

  @override
  State<WebDavAddDialog> createState() => _WebDavAddDialogState();
}

class _WebDavAddDialogState extends State<WebDavAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _probing = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _loadingCredentials = false;
  bool _allowBadCertificate = false;

  bool get _editing => widget.connection != null;

  @override
  void initState() {
    super.initState();
    final connection = widget.connection;
    if (connection != null) {
      _urlController.text = connection.url;
      _displayNameController.text = connection.displayName;
      _allowBadCertificate = connection.allowBadCertificate;
      _loadingCredentials = true;
      _loadCredentials(connection.id);
    }
  }

  Future<void> _loadCredentials(String connectionId) async {
    final credentials = await widget.service.readCredentials(connectionId);
    if (!mounted) return;
    setState(() {
      _usernameController.text = credentials?.username ?? '';
      _loadingCredentials = false;
      if (credentials == null) _errorMessage = '安全存储中缺少连接凭据，请重新输入密码。';
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = Text(_editing ? '编辑 WebDAV 连接' : '添加 WebDAV 连接');
    final form = _buildForm(context);
    final actions = _buildActions(context);

    if (widget.bottomSheet) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DefaultTextStyle(
                style: Theme.of(context).textTheme.headlineSmall!,
                child: title,
              ),
              const SizedBox(height: 20),
              Flexible(child: SingleChildScrollView(child: form)),
              const SizedBox(height: 16),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 10,
                children: actions,
              ),
            ],
          ),
        ),
      );
    }

    return SoundDialog(
      maxWidth: 500,
      title: title,
      content: SizedBox(width: 420, child: form),
      actions: actions,
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _urlController,
            enabled: !_loadingCredentials,
            decoration: const InputDecoration(
              labelText: '服务器地址',
              hintText: 'https://your-nas.local/dav/',
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.url],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '请输入服务器地址';
              }
              try {
                WebDavConnectionService.normalizeWebDavUrl(value);
              } on FormatException catch (error) {
                return error.message;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _displayNameController,
            enabled: !_loadingCredentials,
            decoration: const InputDecoration(
              labelText: '显示名称',
              hintText: '我的 NAS',
            ),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '请输入显示名称';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _usernameController,
            enabled: !_loadingCredentials,
            decoration: const InputDecoration(labelText: '用户名'),
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            enabled: !_loadingCredentials,
            decoration: InputDecoration(
              labelText: _editing ? '密码（留空则保持不变）' : '密码',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _allowBadCertificate,
            onChanged: _probing
                ? null
                : (value) =>
                      setState(() => _allowBadCertificate = value ?? false),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '允许自签名证书',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '适用于使用自签名 SSL 证书的家庭 NAS',
              style: TextStyle(fontSize: 12, color: context.soundSecondaryText),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: context.soundColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: context.soundColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) => [
    TextButton(
      onPressed: _probing ? null : () => Navigator.of(context).pop(),
      child: const Text('取消'),
    ),
    FilledButton(
      onPressed: _probing || _loadingCredentials ? null : _submit,
      child: _probing || _loadingCredentials
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(_editing ? '保存' : '添加'),
    ),
  ];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _probing = true;
      _errorMessage = null;
    });

    final url = _urlController.text.trim();
    final displayName = _displayNameController.text.trim();
    final username = _usernameController.text.trim();
    var password = _passwordController.text;

    try {
      final connection = widget.connection;
      if (connection != null && password.isEmpty) {
        final existing = await widget.service.readCredentials(connection.id);
        if (existing == null) {
          throw StateError('缺少原密码，请重新输入。');
        }
        password = existing.password;
      }
      final credentials = WebDavCredentials(
        username: username,
        password: password,
      );
      final result = connection == null
          ? await widget.service.addConnection(
              url: url,
              displayName: displayName,
              credentials: credentials,
              allowBadCertificate: _allowBadCertificate,
            )
          : await widget.service.updateConnection(
              connection: connection,
              url: url,
              displayName: displayName,
              credentials: credentials,
              allowBadCertificate: _allowBadCertificate,
            );
      if (!mounted) return;
      if (result.error != null) {
        setState(() {
          _probing = false;
          _errorMessage = result.errorMessage ?? '连接失败。';
        });
      } else {
        Navigator.of(context).pop(result);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _probing = false;
        _errorMessage = error.toString();
      });
    }
  }
}
