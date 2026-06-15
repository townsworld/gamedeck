import 'package:flutter/material.dart';

import 'screens/accounts_screen.dart';
import 'screens/library_screen.dart';
import 'screens/settings_screen.dart';
import 'state/app_controller.dart';
import 'utils/formatters.dart';
import 'widgets/dialogs.dart';

void main() {
  runApp(const GameDeckApp());
}

class GameDeckApp extends StatefulWidget {
  const GameDeckApp({super.key, AppController? controller})
    : _controller = controller;

  final AppController? _controller;

  @override
  State<GameDeckApp> createState() => _GameDeckAppState();
}

class _GameDeckAppState extends State<GameDeckApp> {
  late final AppController _controller = widget._controller ?? AppController();

  @override
  void initState() {
    super.initState();
    _controller.initialize();
  }

  @override
  void dispose() {
    if (widget._controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GameDeck',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F6FED),
          brightness: Brightness.light,
        ),
        fontFamily: 'NotoSansSC',
        fontFamilyFallback: const ['sans-serif'],
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: Color(0xFFE0E3EA)),
          ),
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF69A4FF),
          brightness: Brightness.dark,
        ),
        fontFamily: 'NotoSansSC',
        fontFamilyFallback: const ['sans-serif'],
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        useMaterial3: true,
      ),
      home: GameDeckShell(controller: _controller),
    );
  }
}

class GameDeckShell extends StatefulWidget {
  const GameDeckShell({required this.controller, super.key});

  final AppController controller;

  @override
  State<GameDeckShell> createState() => _GameDeckShellState();
}

class _GameDeckShellState extends State<GameDeckShell> {
  int _selectedIndex = 0;
  String? _selectedLibrarySteamId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (!widget.controller.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final title = switch (_selectedIndex) {
          0 => 'GameDeck',
          1 => '游戏库',
          _ => '设置',
        };

        return Scaffold(
          appBar: AppBar(title: Text(title), actions: _buildActions(context)),
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              AccountsScreen(
                controller: widget.controller,
                onOpenSettings: () => setState(() => _selectedIndex = 2),
                onShowLibraryForAccount: (account) {
                  setState(() {
                    _selectedLibrarySteamId = account.steamId;
                    _selectedIndex = 1;
                  });
                },
              ),
              LibraryScreen(
                controller: widget.controller,
                selectedSteamId: _selectedLibrarySteamId,
              ),
              SettingsScreen(controller: widget.controller),
            ],
          ),
          floatingActionButton:
              _selectedIndex == 0 && widget.controller.hasApiKey
              ? FloatingActionButton(
                  onPressed: () =>
                      showAddAccountSheet(context, widget.controller),
                  tooltip: '添加账号',
                  child: const Icon(Icons.add),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: '账号',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_books_outlined),
                selectedIcon: Icon(Icons.library_books),
                label: '游戏库',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: '设置',
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    if (_selectedIndex != 0) {
      return const [];
    }
    return [
      IconButton(
        onPressed:
            widget.controller.hasApiKey &&
                widget.controller.accounts.isNotEmpty &&
                !widget.controller.isBusy
            ? () => showSyncCenterSheet(context, widget.controller)
            : null,
        icon: widget.controller.isBusy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.sync),
        tooltip: '同步中心',
      ),
    ];
  }
}

Future<void> showSyncCenterSheet(
  BuildContext context,
  AppController controller,
) async {
  Future<void> runAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    Navigator.of(context).pop();
    try {
      await action();
      if (context.mounted) {
        showAppSnackBar(context, successMessage);
      }
    } on Object catch (error) {
      if (context.mounted) {
        showAppSnackBar(context, error.toString());
      }
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final uniqueGameCount = controller.uniqueGameCount;
          final latestSync = controller.accounts
              .map((account) => account.lastSyncedAt)
              .whereType<DateTime>()
              .fold<DateTime?>(
                null,
                (latest, value) =>
                    latest == null || value.isAfter(latest) ? value : latest,
              );
          final isRunning = controller.isBusy || controller.isCachingMetadata;
          return SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '同步中心',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (isRunning)
                              const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _SyncStatusChip(
                              icon: Icons.people_outline,
                              label: '${controller.accounts.length} 个账号',
                            ),
                            _SyncStatusChip(
                              icon: Icons.library_books_outlined,
                              label: '$uniqueGameCount 个游戏',
                            ),
                            _SyncStatusChip(
                              icon: Icons.schedule_outlined,
                              label: 'Steam ${formatDateTime(latestSync)}',
                            ),
                            _SyncStatusChip(
                              icon: Icons.inventory_2_outlined,
                              label:
                                  '详情 ${controller.cachedMetadataCount}/$uniqueGameCount',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _SyncActionTile(
                          icon: Icons.refresh,
                          title: '全部刷新',
                          subtitle: '同步 Steam 游戏库，并更新 Steam 商店详情和小黑盒数据',
                          enabled:
                              controller.hasApiKey &&
                              controller.accounts.isNotEmpty &&
                              !isRunning,
                          onTap: () =>
                              runAction(controller.refreshAllData, '已开始全部刷新。'),
                        ),
                        _SyncActionTile(
                          icon: Icons.sports_esports_outlined,
                          title: '只同步 Steam',
                          subtitle: '只更新账号、游戏库、总时长和最后游玩时间',
                          enabled:
                              controller.hasApiKey &&
                              controller.accounts.isNotEmpty &&
                              !isRunning,
                          onTap: () => runAction(
                            controller.syncAllAccounts,
                            'Steam 同步完成。',
                          ),
                        ),
                        _SyncActionTile(
                          icon: Icons.extension_outlined,
                          title: '只更新小黑盒',
                          subtitle: '只刷新中文名、小黑盒评分、价格、史低和标签',
                          enabled: uniqueGameCount > 0 && !isRunning,
                          onTap: () => runAction(() async {
                            controller.refreshHeyboxMetadata();
                          }, '已开始更新小黑盒数据。'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    },
  );
}

class _SyncStatusChip extends StatelessWidget {
  const _SyncStatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _SyncActionTile extends StatelessWidget {
  const _SyncActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        enabled: enabled,
        onTap: enabled ? onTap : null,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
