import 'package:flutter/material.dart';

class ShowTitle extends StatelessWidget {
  const ShowTitle({
    super.key,
    required this.title,
    required this.fontSize,
    required this.availableWidth,
    this.maxLines = 2,
    this.textAlign = TextAlign.center,
    required this.emptyTitleLabel,
    required this.editTitleLabel,
    required this.onBeginEditing,
  });

  final String title;
  final double fontSize;
  final double availableWidth;
  final int maxLines;
  final TextAlign textAlign;
  final String emptyTitleLabel;
  final String editTitleLabel;
  final VoidCallback onBeginEditing;

  @override
  Widget build(BuildContext context) {
    final isEmpty = title.trim().isEmpty;
    final displayMaxLines = isEmpty ? 1 : maxLines;

    return Semantics(
      button: true,
      label: isEmpty ? emptyTitleLabel : editTitleLabel,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onBeginEditing,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 64, maxWidth: availableWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                isEmpty ? emptyTitleLabel : title,
                maxLines: displayMaxLines,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                textAlign: textAlign,
                style: TextStyle(
                  color: isEmpty ? Colors.white38 : Colors.white,
                  fontSize: isEmpty ? fontSize * 0.72 : fontSize,
                  fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
                  height: 1.18,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
