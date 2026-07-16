import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../widgets/sound_components.dart';

class FirstRunDialog extends StatelessWidget {
  const FirstRunDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return SoundDialog(
      maxWidth: 560,
      title: const Text('欢迎使用 Reverie'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '先添加一个音乐来源，Reverie 才能建立你的资料库。',
            style: TextStyle(color: context.soundSecondaryText),
          ),
          const SizedBox(height: 22),
          const _FirstRunFeature(
            icon: Icons.folder_outlined,
            title: '本地文件夹',
            description: '选择电脑、手机或系统 Files 中的音乐目录',
          ),
          const SizedBox(height: 12),
          const _FirstRunFeature(
            icon: Icons.cloud_outlined,
            title: 'WebDAV',
            description: '连接 NAS 或公网服务器，并选择要扫描的目录',
          ),
          const SizedBox(height: 18),
          Text(
            '扫描失败不会删除上一版资料库；密码只保存在系统安全存储中。',
            style: TextStyle(color: context.soundMutedText, fontSize: 11),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('first-run-later'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('稍后'),
        ),
        FilledButton.icon(
          key: const ValueKey('first-run-manage-sources'),
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.add_rounded),
          label: const Text('添加音乐来源'),
        ),
      ],
    );
  }
}

class _FirstRunFeature extends StatelessWidget {
  const _FirstRunFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return SoundGlassSurface(
      blur: false,
      showShadow: false,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: SoundColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: SoundColors.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    color: context.soundSecondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
