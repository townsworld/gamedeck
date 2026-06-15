import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/game_library_entry.dart';
import '../models/game_metadata.dart';
import '../state/app_controller.dart';
import '../utils/formatters.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/dialogs.dart';
import '../widgets/game_icon.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    required this.controller,
    required this.selectedSteamId,
    super.key,
  });

  final AppController controller;
  final String? selectedSteamId;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchController = TextEditingController();
  String? _selectedSteamId;
  AccountFilter _accountFilter = AccountFilter.all;
  LibrarySort _sort = LibrarySort.lastPlayed;

  @override
  void initState() {
    super.initState();
    _selectedSteamId = widget.selectedSteamId;
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSteamId != widget.selectedSteamId) {
      _selectedSteamId = widget.selectedSteamId;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.accounts.isEmpty) {
      return const AppEmptyState(
        icon: Icons.library_books_outlined,
        title: '没有可搜索的游戏库',
        message: '添加账号并完成 Steam 同步后，可以在这里搜索所有账号拥有的游戏。',
      );
    }

    final entries = widget.controller.libraryEntries(
      query: _searchController.text,
      steamId: _selectedSteamId,
      accountFilter: _accountFilter,
      sort: _sort,
    );

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                SearchBar(
                  controller: _searchController,
                  hintText: '搜索中文名或英文名',
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 12),
                  ),
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close),
                        tooltip: '清空',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _FilterRow(
                  controller: widget.controller,
                  selectedSteamId: _selectedSteamId,
                  accountFilter: _accountFilter,
                  sort: _sort,
                  onSteamIdChanged: (value) =>
                      setState(() => _selectedSteamId = value),
                  onAccountFilterChanged: (value) =>
                      setState(() => _accountFilter = value),
                  onSortChanged: (value) => setState(() => _sort = value),
                ),
              ],
            ),
          ),
        ),
        if (entries.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              icon: Icons.search_off_outlined,
              title: '没有找到游戏',
              message: '试试更短的关键词，或重新同步 Steam 游戏库。',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            sliver: SliverList.separated(
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _GameTile(
                  entry: entry,
                  controller: widget.controller,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => GameDetailScreen(
                        entry: entry,
                        controller: widget.controller,
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemCount: entries.length,
            ),
          ),
      ],
    );
  }
}

class GameDetailScreen extends StatefulWidget {
  const GameDetailScreen({
    required this.entry,
    required this.controller,
    super.key,
  });

  final GameLibraryEntry entry;
  final AppController controller;

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  late Future<GameMetadata> _metadata;

  @override
  void initState() {
    super.initState();
    _metadata = widget.controller.fetchGameMetadata(widget.entry.appId);
  }

  void _refresh(_GameDetailRefreshAction action) {
    setState(() {
      _metadata = switch (action) {
        _GameDetailRefreshAction.full => widget.controller.refreshGameMetadata(
          widget.entry.appId,
        ),
        _GameDetailRefreshAction.steam =>
          widget.controller.refreshGameSteamMetadata(widget.entry.appId),
        _GameDetailRefreshAction.heybox =>
          widget.controller.refreshGameHeyboxMetadata(widget.entry.appId),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return Scaffold(
      appBar: AppBar(
        title: const Text('游戏详情'),
        actions: [
          PopupMenuButton<_GameDetailRefreshAction>(
            tooltip: '刷新详情',
            icon: const Icon(Icons.refresh),
            onSelected: (value) {
              _refresh(value);
              showAppSnackBar(context, '已开始刷新详情。');
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _GameDetailRefreshAction.full,
                child: Text('完整刷新'),
              ),
              PopupMenuItem(
                value: _GameDetailRefreshAction.steam,
                child: Text('只刷新 Steam 详情'),
              ),
              PopupMenuItem(
                value: _GameDetailRefreshAction.heybox,
                child: Text('只刷新小黑盒'),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<GameMetadata>(
        future: _metadata,
        builder: (context, snapshot) {
          final metadata = snapshot.data;
          final displayName = metadata?.chineseName.isNotEmpty == true
              ? metadata!.chineseName
              : entry.displayName;
          final secondaryName =
              metadata?.englishName.isNotEmpty == true &&
                  metadata!.englishName != displayName
              ? metadata.englishName
              : entry.secondaryName;
          final imageUrls = _mergedImageUrls(entry, metadata);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (imageUrls.isNotEmpty) ...[
                _BannerImage(url: imageUrls.first),
                const SizedBox(height: 16),
              ],
              Text(
                displayName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (secondaryName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  secondaryName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text('AppID: ${entry.appId}'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DetailChip(
                    icon: Icons.people_outline,
                    text: '${entry.ownerCount} 个账号拥有',
                  ),
                  _DetailChip(
                    icon: Icons.timer_outlined,
                    text: '总玩 ${formatPlaytime(entry.totalPlaytimeMinutes)}',
                  ),
                  _DetailChip(
                    icon: Icons.history,
                    text: '最后 ${formatLastPlayed(entry.lastPlayedAt)}',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (metadata != null) ...[
                _DetailSection(
                  title: '价格',
                  children: [
                    _InfoRow(label: 'Steam 当前', value: metadata.priceLabel),
                    if (metadata.discountPercent > 0)
                      _InfoRow(
                        label: 'Steam 折扣',
                        value:
                            '-${metadata.discountPercent}% · 原价 ${metadata.priceInitialFormatted}',
                      ),
                    _InfoRow(
                      label: '小黑盒当前',
                      value: metadata.heyboxPriceCurrent,
                    ),
                    _InfoRow(
                      label: '小黑盒原价',
                      value: metadata.heyboxPriceInitial,
                    ),
                    if (metadata.heyboxDiscountPercent > 0)
                      _InfoRow(
                        label: '小黑盒折扣',
                        value: '-${metadata.heyboxDiscountPercent}%',
                      ),
                    _InfoRow(
                      label: '史低',
                      value: _heyboxLowestPriceText(metadata),
                    ),
                    _InfoRow(
                      label: '促销时间',
                      value: metadata.heyboxPromoDeadline,
                    ),
                  ],
                ),
                _DetailSection(
                  title: '评价',
                  children: [
                    _InfoRow(label: 'Steam 评价', value: _reviewText(metadata)),
                    _InfoRow(label: '小黑盒评分', value: _heyboxScoreText(metadata)),
                    if (metadata.metacriticScore != null)
                      _InfoRow(
                        label: 'Metacritic',
                        value: '${metadata.metacriticScore}',
                      ),
                    if (metadata.recommendationCount > 0)
                      _InfoRow(
                        label: '推荐数',
                        value: formatCompactNumber(
                          metadata.recommendationCount,
                        ),
                      ),
                    if (metadata.heyboxFollowCount > 0)
                      _InfoRow(
                        label: '关注',
                        value: formatCompactNumber(metadata.heyboxFollowCount),
                      ),
                    if (metadata.heyboxUserCount > 0)
                      _InfoRow(
                        label: '小黑盒用户',
                        value: formatCompactNumber(metadata.heyboxUserCount),
                      ),
                  ],
                ),
                _DetailSection(
                  title: '商店信息',
                  children: [
                    _InfoRow(label: '发售日期', value: metadata.releaseDate),
                    _InfoRow(
                      label: '开发商',
                      value: metadata.developers.join(', '),
                    ),
                    _InfoRow(
                      label: '发行商',
                      value: metadata.publishers.join(', '),
                    ),
                    _InfoRow(label: '类型', value: metadata.genres.join(', ')),
                  ],
                ),
                _DetailSection(
                  title: '平台与特性',
                  children: [
                    _InfoRow(label: '平台', value: _platformText(metadata)),
                    if (metadata.achievementCount > 0)
                      _InfoRow(
                        label: '成就',
                        value: '${metadata.achievementCount} 个',
                      ),
                    _InfoRow(
                      label: '特性',
                      value: metadata.categories.take(6).join(', '),
                    ),
                    _InfoRow(
                      label: '中文标签',
                      value: metadata.heyboxTags.take(10).join(', '),
                    ),
                  ],
                ),
                if (metadata.shortDescription.isNotEmpty)
                  _DetailSection(
                    title: '简介',
                    children: [
                      Text(
                        metadata.shortDescription,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
              ],
              const SizedBox(height: 8),
              Text('图片', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (snapshot.connectionState != ConnectionState.done &&
                  imageUrls.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                _BannerCarousel(imageUrls: imageUrls.take(8).toList()),
              const SizedBox(height: 16),
              Text('拥有账号', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final ownership in entry.ownedCopies)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: ownership.account.avatarUrl.isEmpty
                          ? null
                          : NetworkImage(ownership.account.avatarUrl),
                      child: ownership.account.avatarUrl.isEmpty
                          ? Text(
                              ownership.account.personaName.isEmpty
                                  ? '?'
                                  : ownership.account.personaName.substring(
                                      0,
                                      1,
                                    ),
                            )
                          : null,
                    ),
                    isThreeLine: true,
                    title: Text(ownership.account.personaName),
                    subtitle: Text(
                      '游玩时长：${formatPlaytime(ownership.ownedGame.playtimeForeverMinutes)}\n'
                      '最后游玩：${formatLastPlayed(ownership.ownedGame.lastPlayedAt)}',
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: '${entry.appId}'),
                  );
                  if (context.mounted) {
                    showAppSnackBar(context, 'AppID 已复制。');
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('复制 AppID'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(
                    'https://store.steampowered.com/app/${entry.appId}',
                  );
                  if (!await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  )) {
                    if (context.mounted) {
                      showAppSnackBar(context, '无法打开 Steam 页面。');
                    }
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('打开 Steam 页面'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(
                    'https://www.xiaoheihe.cn/games/detail/${entry.appId}',
                  );
                  if (!await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  )) {
                    if (context.mounted) {
                      showAppSnackBar(context, '无法打开小黑盒页面。');
                    }
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('打开小黑盒页面'),
              ),
            ],
          );
        },
      ),
    );
  }

  static List<String> _mergedImageUrls(
    GameLibraryEntry entry,
    GameMetadata? metadata,
  ) {
    return <String>{
      ...?metadata?.imageUrls,
      ...entry.imageUrls,
      if (entry.headerUrl.isNotEmpty) entry.headerUrl,
      if (entry.capsuleUrl.isNotEmpty) entry.capsuleUrl,
    }.toList();
  }

  static String _reviewText(GameMetadata metadata) {
    if (metadata.reviewCount <= 0) {
      return '';
    }
    final label = metadata.reviewScoreDesc.isEmpty
        ? '总体'
        : formatReviewLabel(metadata.reviewScoreDesc);
    return '$label · ${metadata.reviewPercent}% 好评 · ${formatCompactNumber(metadata.reviewCount)} 篇评测';
  }

  static String _heyboxScoreText(GameMetadata metadata) {
    if (metadata.heyboxScore.isEmpty) {
      return '';
    }
    final description = metadata.heyboxScoreDesc.isEmpty
        ? ''
        : ' · ${metadata.heyboxScoreDesc}';
    return '${metadata.heyboxScore} 分$description';
  }

  static String _heyboxLowestPriceText(GameMetadata metadata) {
    if (metadata.heyboxLowestPrice.isEmpty) {
      return '';
    }
    if (metadata.heyboxLowestDiscount > 0) {
      return '${metadata.heyboxLowestPrice} · -${metadata.heyboxLowestDiscount}%';
    }
    return metadata.heyboxLowestPrice;
  }

  static String _platformText(GameMetadata metadata) {
    final platforms = <String>[
      if (metadata.supportsWindows) 'Windows',
      if (metadata.supportsMac) 'macOS',
      if (metadata.supportsLinux) 'Linux',
    ];
    return platforms.join(', ');
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.controller,
    required this.selectedSteamId,
    required this.accountFilter,
    required this.sort,
    required this.onSteamIdChanged,
    required this.onAccountFilterChanged,
    required this.onSortChanged,
  });

  final AppController controller;
  final String? selectedSteamId;
  final AccountFilter accountFilter;
  final LibrarySort sort;
  final ValueChanged<String?> onSteamIdChanged;
  final ValueChanged<AccountFilter> onAccountFilterChanged;
  final ValueChanged<LibrarySort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final accountName = selectedSteamId == null
        ? '全部账号'
        : controller.accounts
              .firstWhere((account) => account.steamId == selectedSteamId)
              .personaName;
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterPill<String>(
            label: accountName,
            value: selectedSteamId ?? _allAccountsValue,
            values: [
              const _FilterOption(value: _allAccountsValue, label: '全部账号'),
              for (final account in controller.accounts)
                _FilterOption(
                  value: account.steamId,
                  label: account.personaName,
                ),
            ],
            onSelected: (value) =>
                onSteamIdChanged(value == _allAccountsValue ? null : value),
          ),
          const SizedBox(width: 8),
          _FilterPill<AccountFilter>(
            label: _accountFilterLabel(accountFilter),
            value: accountFilter,
            values: const [
              _FilterOption(value: AccountFilter.all, label: '全部游戏'),
              _FilterOption(value: AccountFilter.multiOwned, label: '多账号拥有'),
              _FilterOption(value: AccountFilter.singleOwned, label: '单账号拥有'),
            ],
            onSelected: onAccountFilterChanged,
          ),
          const SizedBox(width: 8),
          _FilterPill<LibrarySort>(
            label: _sortLabel(sort),
            value: sort,
            values: const [
              _FilterOption(value: LibrarySort.lastPlayed, label: '最后游玩'),
              _FilterOption(value: LibrarySort.name, label: '名称'),
              _FilterOption(value: LibrarySort.totalPlaytime, label: '游玩时长'),
              _FilterOption(value: LibrarySort.ownerCount, label: '拥有账号数'),
              _FilterOption(value: LibrarySort.recentlySynced, label: '最近同步'),
            ],
            onSelected: onSortChanged,
          ),
        ],
      ),
    );
  }

  static const _allAccountsValue = '__all_accounts__';

  static String _accountFilterLabel(AccountFilter value) {
    return switch (value) {
      AccountFilter.all => '全部游戏',
      AccountFilter.multiOwned => '多账号拥有',
      AccountFilter.singleOwned => '单账号拥有',
    };
  }

  static String _sortLabel(LibrarySort value) {
    return switch (value) {
      LibrarySort.lastPlayed => '最后游玩',
      LibrarySort.name => '名称',
      LibrarySort.totalPlaytime => '游玩时长',
      LibrarySort.ownerCount => '拥有账号数',
      LibrarySort.recentlySynced => '最近同步',
    };
  }
}

class _FilterOption<T> {
  const _FilterOption({required this.value, required this.label});

  final T value;
  final String label;
}

class _FilterPill<T> extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.value,
    required this.values,
    required this.onSelected,
  });

  final String label;
  final T value;
  final List<_FilterOption<T>> values;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in values)
          PopupMenuItem<T>(value: option.value, child: Text(option.label)),
      ],
      position: PopupMenuPosition.under,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 112),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, size: 18, color: colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({
    required this.entry,
    required this.controller,
    required this.onTap,
  });

  final GameLibraryEntry entry;
  final AppController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    controller.ensureGameMetadata(entry.appId);
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GameIcon(imageUrl: entry.iconUrl, width: 126, height: 70),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.12,
                      ),
                    ),
                    if (_shouldShowSecondaryName(entry)) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.secondaryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.1,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        ..._storeChips(context, entry),
                        _MetaChip(
                          text: formatPlaytime(entry.totalPlaytimeMinutes),
                          muted: true,
                        ),
                        _MetaChip(
                          text: formatLastPlayed(entry.lastPlayedAt),
                          muted: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }

  static bool _shouldShowSecondaryName(GameLibraryEntry entry) {
    return entry.chineseName.trim().isEmpty && entry.secondaryName.isNotEmpty;
  }

  static List<Widget> _storeChips(
    BuildContext context,
    GameLibraryEntry entry,
  ) {
    final chips = <Widget>[];
    if (entry.heyboxScore.isNotEmpty) {
      chips.add(_MetaChip(text: '盒 ${entry.heyboxScore}', accent: true));
    }
    if (entry.reviewCount > 0) {
      final review = entry.reviewScoreDesc.isEmpty
          ? '${entry.reviewPercent}% 好评'
          : '${formatReviewLabel(entry.reviewScoreDesc)} ${entry.reviewPercent}%';
      chips.add(_MetaChip(text: review));
    }
    final price = entry.priceLabel.isNotEmpty
        ? entry.priceLabel
        : entry.heyboxPriceCurrent;
    if (price.isNotEmpty) {
      chips.add(_MetaChip(text: price));
      if (entry.discountPercent > 0) {
        chips.add(_MetaChip(text: '-${entry.discountPercent}%', accent: true));
      }
    }
    if (chips.isEmpty) {
      chips.add(_MetaChip(text: '${entry.ownerCount} 个账号', muted: true));
    }
    return chips.take(3).toList();
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.text,
    this.accent = false,
    this.muted = false,
  });

  final String text;
  final bool accent;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = accent
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final foreground = accent
        ? colorScheme.onPrimaryContainer
        : muted
        ? colorScheme.outline
        : colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
            height: 1.05,
          ),
        ),
      ),
    );
  }
}

enum _GameDetailRefreshAction { full, steam, heybox }

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

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
            Text(text, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final visibleChildren = children
        .where((child) => child is! _InfoRow || child.value.trim().isNotEmpty)
        .toList();
    if (visibleChildren.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(children: visibleChildren),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerImage extends StatelessWidget {
  const _BannerImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 16 / 7,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            final colorScheme = Theme.of(context).colorScheme;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
              ),
              child: Icon(
                Icons.image_not_supported_outlined,
                color: colorScheme.onSurfaceVariant,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BannerCarousel extends StatelessWidget {
  const _BannerCarousel({required this.imageUrls});

  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    final viewportWidth = MediaQuery.sizeOf(context).width;
    final itemWidth = (viewportWidth - 64).clamp(260.0, 420.0);
    return SizedBox(
      height: itemWidth / 16 * 7,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          return SizedBox(
            width: itemWidth,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _BannerImage(url: imageUrls[index]),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      child: Text(
                        '${index + 1}/${imageUrls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemCount: imageUrls.length,
      ),
    );
  }
}
