import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_markdown_plus_latex/flutter_markdown_plus_latex.dart';
import 'package:markdown/markdown.dart' as md;

import '../../features/notes/application/note_markdown_utils.dart';

class MarkdownContent extends StatelessWidget {
  const MarkdownContent({
    required this.data,
    this.selectable = false,
    this.shrinkWrap = true,
    this.baseTextStyle,
    this.enableWikiLinks = false,
    this.onTapLink,
    super.key,
  });

  final String data;
  final bool selectable;
  final bool shrinkWrap;
  final TextStyle? baseTextStyle;
  final bool enableWikiLinks;
  final MarkdownTapLinkCallback? onTapLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final resolvedBodyStyle =
        (baseTextStyle ?? theme.textTheme.bodyLarge)?.copyWith(
          color: baseTextStyle?.color ?? scheme.onSurface,
        );
    final secondaryTextColor = scheme.onSurfaceVariant;

    final resolvedData = enableWikiLinks
        ? convertWikiLinksToMarkdown(data)
        : data;

    return MarkdownBody(
      data: resolvedData,
      selectable: selectable,
      shrinkWrap: shrinkWrap,
      onTapLink: onTapLink,
      builders: {
        'latex': LatexElementBuilder(
          textStyle: resolvedBodyStyle,
        ),
      },
      extensionSet: md.ExtensionSet(
        <md.BlockSyntax>[
          LatexBlockSyntax(),
          ...md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        ],
        <md.InlineSyntax>[
          LatexInlineSyntax(),
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
        ],
      ),
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: resolvedBodyStyle,
        h1: theme.textTheme.headlineMedium?.copyWith(color: scheme.onSurface),
        h2: theme.textTheme.headlineSmall?.copyWith(color: scheme.onSurface),
        h3: theme.textTheme.titleLarge?.copyWith(color: scheme.onSurface),
        h4: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurface),
        h5: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurface),
        h6: theme.textTheme.bodyLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        strong: resolvedBodyStyle?.copyWith(fontWeight: FontWeight.w700),
        em: resolvedBodyStyle?.copyWith(
          fontStyle: FontStyle.italic,
        ),
        code: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'Courier New',
          color: scheme.onSurface,
          backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        ),
        blockquote: resolvedBodyStyle?.copyWith(
          color: secondaryTextColor,
        ),
        listBullet: resolvedBodyStyle,
        a: resolvedBodyStyle?.copyWith(
          color: scheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
