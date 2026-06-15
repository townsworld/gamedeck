import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_controller.dart';
import '../utils/formatters.dart';
import '../widgets/dialogs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _apiKeyController;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.controller.apiKey);
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.apiKey != widget.controller.apiKey &&
        _apiKeyController.text != widget.controller.apiKey) {
      _apiKeyController.text = widget.controller.apiKey;
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Text(
          'Steam Web API Key',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _apiKeyController,
          obscureText: _obscureApiKey,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: '输入 Steam Web API Key',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
              icon: Icon(
                _obscureApiKey
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              tooltip: _obscureApiKey ? '显示' : '隐藏',
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            await widget.controller.saveApiKey(_apiKeyController.text);
            if (context.mounted) {
              showAppSnackBar(context, 'API Key 已保存。');
            }
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('保存'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final uri = Uri.parse('https://steamcommunity.com/dev/apikey');
            if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
              if (context.mounted) {
                showAppSnackBar(context, '无法打开 API Key 页面。');
              }
            }
          },
          icon: const Icon(Icons.open_in_new),
          label: const Text('如何获取 API Key'),
        ),
        const SizedBox(height: 24),
        Text('数据', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.update_outlined),
                title: const Text('每天自动同步 Steam'),
                subtitle: Text(
                  widget.controller.lastAutoSteamSyncAt == null
                      ? '打开 App 时自动更新账号、游戏库、时长和最后游玩'
                      : '上次自动同步：${formatDateTime(widget.controller.lastAutoSteamSyncAt)}',
                ),
                value: widget.controller.autoSyncSteamEnabled,
                onChanged: widget.controller.hasApiKey
                    ? (value) async {
                        await widget.controller.setAutoSyncSteamEnabled(value);
                        if (context.mounted) {
                          showAppSnackBar(
                            context,
                            value ? '已开启自动同步 Steam。' : '已关闭自动同步 Steam。',
                          );
                        }
                      }
                    : null,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: const Text('清理本地缓存'),
                subtitle: const Text('删除账号和游戏库缓存，保留 API Key'),
                onTap: () async {
                  final confirmed = await confirmDestructiveAction(
                    context: context,
                    title: '清理本地缓存？',
                    message: '账号列表和游戏库缓存会从本机删除，Steam 账号不会受影响。',
                    confirmLabel: '清理',
                  );
                  if (!confirmed) {
                    return;
                  }
                  await widget.controller.clearCachedData();
                  if (context.mounted) {
                    showAppSnackBar(context, '本地缓存已清理。');
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('关于', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(title: Text('版本'), subtitle: Text('0.1.0')),
              Divider(height: 1),
              ListTile(title: Text('模式'), subtitle: Text('只读，不执行购买、交易或商店操作')),
            ],
          ),
        ),
      ],
    );
  }
}
