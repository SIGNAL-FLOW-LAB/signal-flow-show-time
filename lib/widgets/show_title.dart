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

  // 行の高さ倍率。TextStyle.height と合わせています。
  static const double _lineHeightMultiplier = 1.18;

  @override
  Widget build(BuildContext context) {
    final isEmpty = title.trim().isEmpty;

    // コメントの文字数・行数に関わらず、常に maxLines 行分の高さを固定確保します。
    // これにより現在時刻・公演時間などの下部レイアウトが動かなくなります。
    final fixedHeight = fontSize * _lineHeightMultiplier * maxLines;

    return Semantics(
      button: true,
      label: isEmpty ? emptyTitleLabel : editTitleLabel,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onBeginEditing,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: availableWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: SizedBox(
              width: double.infinity,
              height: fixedHeight,
              // Text は常に左上（1行目位置）から描画されるため、
              // 空欄時も「コメントを入力」は1行目に固定表示されます。
              child: Text(
                isEmpty ? emptyTitleLabel : title,
                maxLines: maxLines,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                textAlign: textAlign,
                style: TextStyle(
                  color: isEmpty ? Colors.white38 : Colors.white,
                  fontSize: isEmpty ? fontSize * 0.72 : fontSize,
                  fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
                  height: _lineHeightMultiplier,
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
