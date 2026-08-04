import 'package:flutter/material.dart';

class ShowTitle extends StatelessWidget {
  const ShowTitle({
    super.key,
    required this.title,
    required this.fontSize,
    required this.availableWidth,
    required this.emptyTitleLabel,
    required this.editTitleLabel,
    required this.onBeginEditing,
  });

  final String title;
  final double fontSize;
  final double availableWidth;
  final String emptyTitleLabel;
  final String editTitleLabel;
  final VoidCallback onBeginEditing;

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = title.trim().isEmpty;

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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    isEmpty ? emptyTitleLabel : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isEmpty ? Colors.white38 : Colors.white,
                      fontSize: isEmpty ? fontSize * 0.72 : fontSize,
                      fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
                      height: 1.18,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: Colors.white30,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
