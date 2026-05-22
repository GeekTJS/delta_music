import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/user_provider.dart';
import '../../repositories/song_repository.dart';
import '../../services/storage_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _selectedQuality = 320;
  int _selectedSleepTimer = 0;

  static const List<int> _sleepOptions = [0, 15, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    _selectedQuality = ref.read(storageServiceProvider).defaultQuality;
  }

  String _sleepTimerLabel(int minutes) {
    if (minutes == 0) return '关闭';
    return '$minutes 分钟';
  }

  void _showQualityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '选择音质',
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              RadioListTile<int>(
                value: 128,
                groupValue: _selectedQuality,
                activeColor: AppColors.primary,
                title: const Text(
                  '标准品质 (128kbps)',
                  style: TextStyle(color: AppColors.textPrimaryDark),
                ),
                onChanged: (v) {
                  setState(() => _selectedQuality = v!);
                  ref.read(storageServiceProvider).setDefaultQuality(v!);
                  Navigator.pop(context);
                },
              ),
              RadioListTile<int>(
                value: 192,
                groupValue: _selectedQuality,
                activeColor: AppColors.primary,
                title: const Text(
                  '较高品质 (192kbps)',
                  style: TextStyle(color: AppColors.textPrimaryDark),
                ),
                onChanged: (v) {
                  setState(() => _selectedQuality = v!);
                  ref.read(storageServiceProvider).setDefaultQuality(v!);
                  Navigator.pop(context);
                },
              ),
              RadioListTile<int>(
                value: 320,
                groupValue: _selectedQuality,
                activeColor: AppColors.primary,
                title: const Text(
                  '极高品质 (320kbps)',
                  style: TextStyle(color: AppColors.textPrimaryDark),
                ),
                onChanged: (v) {
                  setState(() => _selectedQuality = v!);
                  ref.read(storageServiceProvider).setDefaultQuality(v!);
                  Navigator.pop(context);
                },
              ),
              RadioListTile<int>(
                value: 999,
                groupValue: _selectedQuality,
                activeColor: AppColors.primary,
                title: const Text(
                  '无损品质',
                  style: TextStyle(color: AppColors.textPrimaryDark),
                ),
                onChanged: (v) {
                  setState(() => _selectedQuality = v!);
                  ref.read(storageServiceProvider).setDefaultQuality(v!);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showSleepTimerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '定时关闭',
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ..._sleepOptions.map((minutes) {
                return RadioListTile<int>(
                  value: minutes,
                  groupValue: _selectedSleepTimer,
                  activeColor: AppColors.primary,
                  title: Text(
                    _sleepTimerLabel(minutes),
                    style: const TextStyle(color: AppColors.textPrimaryDark),
                  ),
                  onChanged: (v) {
                    setState(() => _selectedSleepTimer = v!);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showThemePicker() {
    final storageService = ref.read(storageServiceProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final currentTheme = storageService.themeMode;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '主题切换',
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              RadioListTile<ThemeModeSetting>(
                value: ThemeModeSetting.system,
                groupValue: currentTheme,
                activeColor: AppColors.primary,
                title: const Text(
                  '跟随系统',
                  style: TextStyle(color: AppColors.textPrimaryDark),
                ),
                subtitle: const Text(
                  '根据系统设置自动切换',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 12,
                  ),
                ),
                onChanged: (v) {
                  storageService.setThemeMode(v!);
                  Navigator.pop(context);
                },
              ),
              RadioListTile<ThemeModeSetting>(
                value: ThemeModeSetting.light,
                groupValue: currentTheme,
                activeColor: AppColors.primary,
                title: const Text(
                  '浅色模式',
                  style: TextStyle(color: AppColors.textPrimaryDark),
                ),
                onChanged: (v) {
                  storageService.setThemeMode(v!);
                  Navigator.pop(context);
                },
              ),
              RadioListTile<ThemeModeSetting>(
                value: ThemeModeSetting.dark,
                groupValue: currentTheme,
                activeColor: AppColors.primary,
                title: const Text(
                  '深色模式',
                  style: TextStyle(color: AppColors.textPrimaryDark),
                ),
                onChanged: (v) {
                  storageService.setThemeMode(v!);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          title: const Text(
            '清理缓存',
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 18,
            ),
          ),
          content: const Text(
            '确定要清理所有缓存数据吗？这不会影响你喜欢的歌曲和播放列表。',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                '取消',
                style: TextStyle(color: AppColors.textSecondaryDark),
              ),
            ),
            TextButton(
              onPressed: () {
                ref.read(storageServiceProvider).clearCache();
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('缓存已清理'),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text(
                '确定',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final storageService = ref.watch(storageServiceProvider);
    final currentTheme = storageService.themeMode;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 4),
          _buildUserSection(userState),
          const SizedBox(height: 8),
          _buildSectionDivider(),
          _buildSettingsGroup('播放设置', [
            _buildSettingItem(
              icon: Icons.high_quality,
              title: '音质选择',
              subtitle: AppConstants.qualityLabel(_selectedQuality),
              onTap: _showQualityPicker,
            ),
            const Divider(color: AppColors.dividerDark, height: 1, indent: 56),
            _buildSettingItem(
              icon: Icons.file_download_outlined,
              title: '下载管理',
              subtitle: '查看已下载歌曲',
              onTap: () {},
            ),
            const Divider(color: AppColors.dividerDark, height: 1, indent: 56),
            _buildSettingItem(
              icon: Icons.timer_outlined,
              title: '定时关闭',
              subtitle: _sleepTimerLabel(_selectedSleepTimer),
              onTap: _showSleepTimerPicker,
            ),
          ]),
          const SizedBox(height: 8),
          _buildSectionDivider(),
          _buildSettingsGroup('外观', [
            _buildSettingItem(
              icon: Icons.palette_outlined,
              title: '主题切换',
              subtitle: currentTheme == ThemeModeSetting.system
                  ? '跟随系统'
                  : currentTheme == ThemeModeSetting.light
                      ? '浅色模式'
                      : '深色模式',
              onTap: _showThemePicker,
            ),
          ]),
          const SizedBox(height: 8),
          _buildSectionDivider(),
          _buildSettingsGroup('其他', [
            _buildSettingItem(
              icon: Icons.delete_outline,
              title: '清理缓存',
              subtitle: '清理应用缓存数据',
              onTap: _showClearCacheDialog,
            ),
            const Divider(color: AppColors.dividerDark, height: 1, indent: 56),
            _buildSettingItem(
              icon: Icons.info_outline,
              title: '关于',
              subtitle: '三角洲音乐 v${AppConstants.appVersion}',
              showTrailing: false,
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildUserSection(UserState userState) {
    if (!userState.isLoggedIn || userState.user == null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '登录以获取更多功能',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    final user = userState.user!;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primary.withOpacity(0.15),
            backgroundImage: user.avatar != null
                ? NetworkImage(user.avatar!)
                : null,
            child: user.avatar == null
                ? Text(
                    user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: const TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${user.username}',
                  style: const TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textSecondaryDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionDivider() {
    return const Divider(
      color: AppColors.dividerDark,
      height: 1,
      thickness: 1,
    );
  }

  Widget _buildSettingsGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showTrailing = true,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: AppColors.textSecondaryDark,
        size: 24,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimaryDark,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textSecondaryDark,
          fontSize: 12,
        ),
      ),
      trailing: showTrailing
          ? const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondaryDark,
              size: 20,
            )
          : null,
      onTap: onTap,
    );
  }
}