import 'dart:async';

import 'package:flutter/material.dart';

class ShowTitle extends StatelessWidget {
  const ShowTitle({
    super.key,
    required this.title,
    required this.isEditing,
    required this.fontSize,
    required this.availableWidth,
    required this.titleController,
    required this.titleFocusNode,
    required this.emptyTitleLabel,
    required this.editTitleLabel,
    required this.hintText,
    required this.saveLabel,
    required this.cancelLabel,
    required this.onBeginEditing,
    required this.onSave,
    required this.onCancel,
  });

  final String title;
  final bool isEditing;
  final double fontSize;
  final double availableWidth;
  final TextEditingController titleController;
  final FocusNode titleFocusNode;
  final String emptyTitleLabel;
  final String editTitleLabel;
  final String hintText;
  final String saveLabel;
  final String cancelLabel;
  final VoidCallback onBeginEditing;
  final Future<void> Function() onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: availableWidth),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: titleController,
                focusNode: titleFocusNode,
                maxLines: 1,
                minLines: 1,
                maxLength: 80,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  letterSpacing: 0.4,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    color: Colors.white38,
                    fontSize: fontSize * 0.76,
                    fontWeight: FontWeight.w400,
                  ),
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Colors.white70,
                      width: 1.5,
                    ),
                  ),
                ),
                onSubmitted: (_) {
                  unawaited(onSave());
                },
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: saveLabel,
              onPressed: onSave,
              icon: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF69F0AE),
              ),
            ),
            IconButton(
              tooltip: cancelLabel,
              onPressed: onCancel,
              icon: const Icon(Icons.close, color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return Semantics(
      button: true,
      label: title.isEmpty ? emptyTitleLabel : editTitleLabel,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onBeginEditing,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 48, maxWidth: availableWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    title.isEmpty ? emptyTitleLabel : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: title.isEmpty ? Colors.white38 : Colors.white,
                      fontSize: title.isEmpty ? fontSize * 0.72 : fontSize,
                      fontWeight: title.isEmpty
                          ? FontWeight.w400
                          : FontWeight.w600,
                      height: 1.18,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.edit_outlined,
                  size: 17,
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
