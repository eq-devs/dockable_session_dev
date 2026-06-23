import 'package:flutter/material.dart';

import 'session_controller.dart';
import 'session_entry.dart';

/// The single docked preview pill that floats above the bottom navigation bar
/// (doc §3). Tapping it restores the session; the trailing button closes it.
///
/// It is only meaningful while the session is minimized; the host scaffold is
/// responsible for positioning it on the pill slot and showing it only then.
class MinimizedSessionBar extends StatelessWidget {
  const MinimizedSessionBar({
    super.key,
    required this.controller,
    this.contentBuilder,
  });

  final SessionController controller;

  /// Optional custom pill content. When null a default title + restore hint +
  /// close button is shown.
  final Widget Function(BuildContext context, SessionEntry entry)?
      contentBuilder;

  @override
  Widget build(BuildContext context) {
    final entry = controller.entry;
    if (entry == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: controller.restore,
        child: contentBuilder?.call(context, entry) ??
            _DefaultPillContent(controller: controller, entry: entry),
      ),
    );
  }
}

class _DefaultPillContent extends StatelessWidget {
  const _DefaultPillContent({required this.controller, required this.entry});

  final SessionController controller;
  final SessionEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 4),
      child: Row(
        children: [
          Icon(Icons.web_asset, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  'Tap to restore',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: controller.close,
          ),
        ],
      ),
    );
  }
}
