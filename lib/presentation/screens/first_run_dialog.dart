import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../widgets/sound_components.dart';

class FirstRunDialog extends StatelessWidget {
  const FirstRunDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return SoundDialog(
      maxWidth: 560,
      title: const Text('欢迎使用 开听'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kIsWeb
                ? '选择音乐来源后，开听 会从 WebDAV 目录建立资料库。'
                : '选择音乐来源后，开听 会从本机文件夹或 WebDAV 目录建立资料库。',
            style: TextStyle(color: context.soundSecondaryText, height: 1.55),
          ),
          const SizedBox(height: 14),
          Text(
            '之后可以随时在设置中添加、移除或重新扫描来源。',
            style: TextStyle(
              color: context.soundMutedText,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('first-run-later'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('稍后'),
        ),
        FilledButton(
          key: const ValueKey('first-run-manage-sources'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('管理音乐来源'),
        ),
      ],
    );
  }
}
