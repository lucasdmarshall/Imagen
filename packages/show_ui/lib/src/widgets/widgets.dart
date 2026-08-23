import 'package:flutter/material.dart';

import '../tokens/show_colors.dart';
import '../tokens/show_spacing.dart';
import '../tokens/show_typography.dart';

/// Swiss-style page scaffold: cream background, generous inset, left-aligned
/// content constrained for readability. Borderless by construction.
class ShowPage extends StatelessWidget {
  const ShowPage({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.leading,
    this.scrollable = true,
  });

  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final Widget? leading;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: ShowSpacing.pageInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(title), leading: leading, actions: actions),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ShowSizing.maxContentWidth),
            child: scrollable
                ? SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: ShowSpacing.xxl),
                    child: body,
                  )
                : body,
          ),
        ),
      ),
    );
  }
}

/// A section label — small, uppercase-ish, muted. Carries hierarchy without a box.
class ShowSectionHeader extends StatelessWidget {
  const ShowSectionHeader(this.label, {super.key, this.trailing});
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: ShowSpacing.xl, bottom: ShowSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label.toUpperCase(), style: ShowType.label.copyWith(
            color: ShowColors.inkFaint, letterSpacing: 1.2))),
          ?trailing,
        ],
      ),
    );
  }
}

/// A borderless, tappable row. The only separators allowed are hairline
/// [Divider]s placed *between* rows by the caller.
class ShowRow extends StatelessWidget {
  const ShowRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: ShowSizing.minTouch),
        padding: const EdgeInsets.symmetric(vertical: ShowSpacing.md),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: ShowSpacing.md)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ShowType.h3),
                  if (subtitle != null) ...[
                    const SizedBox(height: ShowSpacing.xs),
                    Text(subtitle!, style: ShowType.bodyMuted),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: ShowSpacing.md), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Primary full-width action button.
class ShowButton extends StatelessWidget {
  const ShowButton(this.label, {super.key, this.onPressed, this.leading});
  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: ShowSpacing.sm)],
          Text(label),
        ],
      ),
    );
  }
}

/// Underline-only text field with a left-aligned label above it.
class ShowField extends StatelessWidget {
  const ShowField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ShowType.label.copyWith(color: ShowColors.inkMuted)),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: ShowType.body,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

/// A flat, matte pill/tag (e.g. plan badge, credit count). No gradient.
class ShowTag extends StatelessWidget {
  const ShowTag(this.text, {super.key, this.emphasis = false});
  final String text;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ShowSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: emphasis ? ShowColors.accent : ShowColors.creamSunken,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: ShowType.label.copyWith(
        color: emphasis ? ShowColors.cream : ShowColors.inkMuted)),
    );
  }
}

/// Empty-state block — icon slot, headline, supporting line.
class ShowEmpty extends StatelessWidget {
  const ShowEmpty({super.key, this.icon, required this.title, this.subtitle});
  final Widget? icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ShowSpacing.xxxl),
      child: Column(
        children: [
          if (icon != null) ...[icon!, const SizedBox(height: ShowSpacing.md)],
          Text(title, style: ShowType.h3, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: ShowSpacing.xs),
            Text(subtitle!, style: ShowType.bodyMuted, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
