import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../app/providers.dart';
import '../../bible/reference_parser.dart';
import '../../bible/references.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Optional Scripture reference input. Reports a [VerseRange] code, or
/// null when empty; shows whether the text was understood.
class ScriptureRefField extends ConsumerStatefulWidget {
  const ScriptureRefField({
    super.key,
    this.initialCode,
    required this.onChanged,
  });

  final String? initialCode;
  final ValueChanged<String?> onChanged;

  @override
  ConsumerState<ScriptureRefField> createState() => _ScriptureRefFieldState();
}

class _ScriptureRefFieldState extends ConsumerState<ScriptureRefField> {
  late final TextEditingController _c;
  VerseRange? _range;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    String text = '';
    if (widget.initialCode != null) {
      try {
        _range = VerseRange.parseCode(widget.initialCode!);
        text = _range!.label;
      } on Object {
        _range = null;
      }
    }
    _c = TextEditingController(text: text);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _parse(String s) {
    if (s.trim().isEmpty) {
      setState(() {
        _range = null;
        _invalid = false;
      });
      widget.onChanged(null);
      return;
    }
    final parsed = ReferenceParser.parse(s);
    VerseRange? range;
    if (parsed != null && !parsed.isBookOnly) {
      range = parsed.range;
      if (range == null) {
        // A whole chapter (or chapters): span to the last verse.
        final bible = ref.read(currentBibleProvider).value;
        final endCh = ChapterRef(
          parsed.book.id,
          parsed.endChapter ?? parsed.chapter!,
        );
        final last = bible?.chapter(endCh)?.verseCount ?? 1;
        range = VerseRange(
          VerseRef(parsed.book.id, parsed.chapter!, 1),
          VerseRef(endCh.bookId, endCh.chapter, last),
        );
      }
    }
    setState(() {
      _range = range;
      _invalid = range == null;
    });
    widget.onChanged(range?.code);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _c,
          onChanged: _parse,
          style: AppType.body.copyWith(color: p.ink),
          decoration: InputDecoration(
            hintText: 'Scripture (optional), e.g. Phil 4:6-7',
            prefixIcon: Icon(PhosphorIconsRegular.bookOpen, color: p.inkMute),
            suffixIcon: _range != null
                ? Icon(PhosphorIconsFill.checkCircle, color: p.sage)
                : null,
          ),
        ),
        if (_range != null || _invalid)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              _range?.label ?? 'Not a reference we recognise',
              style: AppType.caption.copyWith(
                color: _invalid
                    ? Theme.of(context).colorScheme.error
                    : p.inkSoft,
              ),
            ),
          ),
      ],
    );
  }
}
