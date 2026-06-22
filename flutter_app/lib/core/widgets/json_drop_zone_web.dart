import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'json_drop_zone_types.dart';

class JsonDropZoneImpl extends StatefulWidget {
  const JsonDropZoneImpl({
    required this.onFileDropped,
    required this.height,
    super.key,
  });

  final ValueChanged<DroppedJsonFile> onFileDropped;
  final double height;

  @override
  State<JsonDropZoneImpl> createState() => _JsonDropZoneImplState();
}

class _JsonDropZoneImplState extends State<JsonDropZoneImpl> {
  DropzoneViewController? _controller;
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = _hovering
        ? AppColors.accent
        : theme.colorScheme.outline;
    final backgroundColor = _hovering
        ? AppColors.primarySoft.withValues(alpha: 0.18)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.58);

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColor, width: _hovering ? 2 : 1),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: DropzoneView(
                operation: DragOperation.copy,
                cursor: CursorType.grab,
                onCreated: (controller) => _controller = controller,
                onHover: () {
                  if (mounted) {
                    setState(() => _hovering = true);
                  }
                },
                onLeave: () {
                  if (mounted) {
                    setState(() => _hovering = false);
                  }
                },
                onDropFile: (file) async {
                  final controller = _controller;
                  if (controller == null) {
                    return;
                  }
                  final bytes = await controller.getFileData(file);
                  final name = await controller.getFilename(file);
                  if (!mounted) {
                    return;
                  }
                  setState(() => _hovering = false);
                  widget.onFileDropped(
                    DroppedJsonFile(name: name, bytes: bytes),
                  );
                },
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _hovering
                          ? Icons.file_download_done_rounded
                          : Icons.upload_file_rounded,
                      size: 32,
                      color: _hovering ? AppColors.accent : AppColors.primary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _hovering
                          ? 'Drop JSON to import into this subject'
                          : 'Drag and drop a StudyDesk JSON here',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Deck and quiz files are both supported on web.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
