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

  // タップ領域として確保する最低高さ・幅（logical pixels）。
  static const double _minTapSize = 44.0;

  // 入力済みコメントの内側余白。
  static const double _textHorizontalPadding = 18;
  static const double _textVerticalPadding = 12;

  // ShowTitleが外側に対して常に確保する固定の占有高さ。呼び出し側が
  // このウィジェットを配置する前に必要な高さを知りたい場合（例:
  // iPhone横画面でコメントと操作ボタンをStackで個別配置する場合）に、
  // ここと同じ計算式を重複させずに使えるようpublicにしています。
  static double reservedHeightFor({
    required double fontSize,
    required int maxLines,
  }) {
    final naturalHeight = fontSize * _lineHeightMultiplier * maxLines;
    final fixedHeight = naturalHeight < _minTapSize
        ? _minTapSize
        : naturalHeight;
    return fixedHeight + _textVerticalPadding * 2;
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = title.trim().isEmpty;

    // 入力済み時の内側余白ぶんを含めた、外側から見た固定の占有高さ。
    // コメントの文字数・行数に関わらず常に同じ値になるため、入力の
    // 有無で現在時刻・公演時間などの下部レイアウトが動かなくなります。
    final reservedHeight = reservedHeightFor(
      fontSize: fontSize,
      maxLines: maxLines,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: availableWidth),
      child: SizedBox(
        width: double.infinity,
        height: reservedHeight,
        // 未入力時は鉛筆アイコンだけがタップ対象（領域全体ではない）。
        // 入力済み時は従来どおりコメント全体をタップして編集できます。
        child: isEmpty
            ? _EmptyCommentIcon(
                fontSize: fontSize,
                label: emptyTitleLabel,
                onTap: onBeginEditing,
              )
            : Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _textHorizontalPadding,
                  vertical: _textVerticalPadding,
                ),
                child: Semantics(
                  button: true,
                  label: editTitleLabel,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onBeginEditing,
                    // Text は常に左上（1行目位置）から描画されるため、
                    // 入力済みコメントは常に1行目に固定表示されます。
                    child: Text(
                      title,
                      maxLines: maxLines,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      textAlign: textAlign,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
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

// 未入力時の鉛筆アイコン表示。コメント領域の右上に、設定（歯車）アイコン
// と近い余白感で配置します。領域がタップ領域の最低サイズ（44px）に
// 満たないほど狭い場合のみ、はみ出しを避けるため中央へフォールバックし
// ます。タップ対象はアイコン自体の44x44の領域のみで、それ以外の余白を
// タップしても編集は始まりません。
class _EmptyCommentIcon extends StatelessWidget {
  const _EmptyCommentIcon({
    required this.fontSize,
    required this.label,
    required this.onTap,
  });

  final double fontSize;
  final String label;
  final VoidCallback onTap;

  // アイコン自体の外側の余白。設定アイコン（Padding.all(10) + IconButton
  // 標準余白）に近い、控えめな値にしています。
  static const EdgeInsets _edgeInset = EdgeInsets.only(top: 4, right: 4);

  @override
  Widget build(BuildContext context) {
    // アイコンの見た目のサイズ。fontSizeに応じて多少スケールしますが、
    // 極端に大きくも小さくもならないようclampします。
    final iconSize = (fontSize * 0.9).clamp(18.0, 30.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final canPlaceTopRight =
            constraints.maxWidth >= ShowTitle._minTapSize &&
            constraints.maxHeight >= ShowTitle._minTapSize;

        return Padding(
          padding: canPlaceTopRight ? _edgeInset : EdgeInsets.zero,
          child: Align(
            alignment: canPlaceTopRight ? Alignment.topRight : Alignment.center,
            child: Semantics(
              button: true,
              label: label,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                    ShowTitle._minTapSize / 2,
                  ),
                  onTap: onTap,
                  child: SizedBox(
                    width: ShowTitle._minTapSize,
                    height: ShowTitle._minTapSize,
                    child: Icon(
                      Icons.edit,
                      size: iconSize,
                      color: Colors.white38,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
