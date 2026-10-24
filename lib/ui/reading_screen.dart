import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/parsing/redaction.dart';
import '../data/receipt_files.dart';
import '../data/receipt_repository.dart';
import '../ocr/read_pipeline.dart';
import '../ocr/receipt_reader.dart';
import 'components/brand.dart';
import 'components/kit.dart';
import 'motion/motion.dart';
import 'review_screen.dart';
import 'saved_screen.dart';
import 'scan_flow.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

/// Reads the photos on the phone and shows each step as it happens: the
/// percentage, a mini receipt per photo, the step list with real counts and
/// a log. Opens "Check it" when done.
class ReadingScreen extends StatefulWidget {
  const ReadingScreen({
    super.key,
    required this.repo,
    required this.reader,
    required this.paths,
    required this.scanned,
    this.onSaved,
  });

  final ReceiptRepository repo;
  final ReceiptReader reader;
  final List<String> paths;

  /// Photos from the document scanner (rather than the gallery).
  final bool scanned;
  final ValueChanged<SavedNote>? onSaved;

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  ReadProgress? _progress;

  /// The user went back while reading; the photos are thrown away.
  bool _left = false;

  /// Open by default in the dark (punchy) theme, as in the handoff.
  bool? _logOpen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final reduced = Motion.reduced(context);
    final messenger = ScaffoldMessenger.of(context);
    final read = <PageRead>[];
    final pipeline = ReadPipeline(
      readPage: (path) async {
        final page = await widget.reader.readPage(path);
        read.add(page);
        return page;
      },
      combine: widget.reader.combine,
      match: (parsed) async {
        final matcher = await widget.repo.loadMatcher();
        final storeId = await widget.repo.findStoreId(parsed.storeName ?? '');
        return [
          for (final item in parsed.items) matcher.match(item.rawText, storeId: storeId, code: item.code),
        ];
      },
      pause: reduced ? null : () => Future.delayed(const Duration(milliseconds: 260)),
    );
    try {
      final result = await pipeline.run(widget.paths, scanned: widget.scanned, onUpdate: (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (_left) {
        for (final page in result.pages) {
          await ReceiptFiles.deleteFor(page.imagePath);
        }
        return;
      }
      await Future.delayed(Duration(milliseconds: reduced ? 150 : 650));
      if (!mounted || _left) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute<bool>(
        builder: (_) => ReviewScreen(
          repo: widget.repo,
          session: ScanSession.read(widget.reader, result),
          onSaved: widget.onSaved,
        ),
      ));
    } catch (e) {
      for (final page in read) {
        await ReceiptFiles.deleteFor(page.imagePath);
      }
      if (_left) return;
      messenger.showSnackBar(SnackBar(content: Text('Could not read the receipt: $e')));
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final p = _progress;
    final steps = p?.steps ??
        [if (widget.scanned) ReadStep.edges, ...ReadStep.values.where((s) => s != ReadStep.edges)];
    final logOpen = _logOpen ?? t.punchy;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _left = true;
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                children: [
                  _Header(progress: p),
                  const SizedBox(height: 14),
                  _PhotoStrip(paths: widget.paths, progress: p),
                  const SizedBox(height: 12),
                  for (final step in steps) _StepRow(step: step, progress: p),
                ],
              ),
            ),
            _LogPanel(
              log: p?.log ?? const [],
              open: logOpen,
              onToggle: () => setState(() => _logOpen = !logOpen),
              live: !(p?.finished ?? false),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.progress});
  final ReadProgress? progress;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final fraction = progress?.fraction ?? 0;
    final finished = progress?.finished ?? false;
    final ease = Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 380);
    return Row(children: [
      TweenAnimationBuilder<double>(
        tween: Tween(end: fraction),
        duration: ease,
        curve: Motion.rise,
        builder: (context, v, child) => ProgressRing(value: v, child: child),
        child: SlipMascot(width: 34, mood: finished ? SlipMood.happy : SlipMood.reading),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Reading on your phone', style: slipText(13, 800, color: t.ink2)),
          TweenAnimationBuilder<double>(
            tween: Tween(end: fraction * 100),
            duration: ease,
            builder: (context, v, _) => Text('${v.round()}%',
                semanticsLabel: '${(fraction * 100).round()} percent read',
                style: slipText(34, 900, color: t.ink, tabular: true, height: 1.1)),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            // The old line goes at once so two phrases never overlap.
            switchOutCurve: const Threshold(0),
            layoutBuilder: (current, previous) =>
                Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
            child: Text(progress?.mood ?? 'Getting ready…',
                key: ValueKey(progress?.mood),
                style: slipText(13, 800,
                    color: !finished
                        ? t.accText
                        : progress!.totalMatches == false
                            ? t.warning
                            : t.downText)),
          ),
        ]),
      ),
    ]);
  }
}

/// One mini receipt per photo: the photo with a scan bar while it is read,
/// then its text with item rows tinted, overlap rows struck out, TOTAL in
/// mint and the card section replaced by "card hidden".
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.paths, required this.progress});
  final List<String> paths;
  final ReadProgress? progress;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final p = progress;
    final pages = p?.pages ?? List<PageRead?>.filled(paths.length, null);
    final result = p?.result;
    Widget page(int i) {
      final read = pages[i];
      if (read == null) return _PhotoBeingRead(path: paths[i], active: p?.readingPhoto == i);
      final join = result?.stitch.joins.where((j) => j.page == i && j.found).firstOrNull;
      return _MiniReceipt(
        rows: read.rows,
        overlapRows: join?.overlapRows ?? 0,
        itemTexts: [for (final item in result?.parsed.items ?? const []) item.rawText],
      );
    }

    return Container(
      height: 168,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: t.surf2,
        borderRadius: BorderRadius.circular(t.rRow),
        border: t.outline == null ? null : Border.fromBorderSide(t.outline!),
      ),
      child: pages.length <= 3
          ? Row(children: [
              for (var i = 0; i < pages.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: page(i)),
              ],
            ])
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: pages.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => SizedBox(width: 120, child: page(i)),
            ),
    );
  }
}

class _PhotoBeingRead extends StatelessWidget {
  const _PhotoBeingRead({required this.path, required this.active});
  final String path;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(fit: StackFit.expand, children: [
        Opacity(
          opacity: active ? 1 : .45,
          child: Image.file(File(path),
              fit: BoxFit.cover, cacheWidth: 300, errorBuilder: (_, _, _) => ColoredBox(color: t.surf)),
        ),
        if (active) const _ScanBar(),
      ]),
    );
  }
}

/// The orange line with a glow that sweeps a photo while it is read.
class _ScanBar extends StatefulWidget {
  const _ScanBar();

  @override
  State<_ScanBar> createState() => _ScanBarState();
}

class _ScanBarState extends State<_ScanBar> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.value = .5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final acc = SlipTokens.of(context).acc;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Align(
        alignment: Alignment(0, -1 + 2 * Curves.easeInOut.transform(_c.value)),
        child: Container(
          height: 2.5,
          decoration: BoxDecoration(
            color: acc,
            boxShadow: [BoxShadow(color: acc.withValues(alpha: .6), blurRadius: 10, spreadRadius: 2)],
          ),
        ),
      ),
    );
  }
}

class _MiniReceipt extends StatelessWidget {
  const _MiniReceipt({required this.rows, required this.overlapRows, required this.itemTexts});
  final List<String> rows;
  final int overlapRows;
  final List<String> itemTexts;

  static final _total = RegExp(r'^\s*(TOTAL|BALANCE)\b', caseSensitive: false);

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    // The card section is never drawn, not even shrunk down.
    final shown = withoutPaymentSection(rows);
    const ink = Color(0xFF3A312A);
    final style = slipText(6.5, 500, mono: true, color: ink, height: 1.35);
    Widget row(int i, String text) {
      final cut = i < overlapRows;
      final tint = cut
          ? null
          : _total.hasMatch(text)
              ? const Color(0xFFDDF3E8)
              : itemTexts.any((item) => item.isNotEmpty && text.contains(item))
                  ? const Color(0xFFFFE6D7)
                  : null;
      return Container(
        color: tint,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.clip,
            softWrap: false,
            style: cut
                ? style.copyWith(color: ink.withValues(alpha: .45), decoration: TextDecoration.lineThrough)
                : style),
      );
    }

    return PopIn(
      ms: 300,
      child: Container(
        decoration: BoxDecoration(
            color: t.punchy ? const Color(0xFFFFF6EC) : t.surf, borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.all(5),
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            maxHeight: double.infinity,
            child: ExcludeSemantics(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final (i, text) in shown.indexed) row(i, text),
                if (shown.length < rows.length)
                  Container(
                    color: const Color(0xFFFDE4E1),
                    alignment: Alignment.center,
                    child: Text('·· card hidden ··', style: style.copyWith(color: const Color(0xFFB3332A))),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.progress});
  final ReadStep step;
  final ReadProgress? progress;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final p = progress;
    final done = p?.done.contains(step) ?? false;
    final running = p?.running == step;
    final count = p?.counts[step];
    final Widget mark;
    if (done) {
      mark = PopIn(
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: t.acc, shape: BoxShape.circle),
          child: SlipIcon(Symbols.check_rounded, size: 16, color: t.accInk, fill: 1),
        ),
      );
    } else if (running) {
      mark = SizedBox.square(
        dimension: 22,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: CircularProgressIndicator(strokeWidth: 3, color: t.acc),
        ),
      );
    } else {
      mark = const SizedBox.square(dimension: 22);
    }
    final warn = count != null && (count.startsWith('off') || count == 'gap' || count == 'no total');
    return Semantics(
      label: '${step.label}${done ? ', done' : running ? ', in progress' : ''}${count == null ? '' : ', $count'}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          // Fades to the same colour at zero opacity, not to transparent black.
          color: running && !t.punchy ? t.surf : t.surf.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(t.rRow),
          border: running && t.punchy ? Border.all(color: t.acc, width: 2) : null,
          boxShadow: running && !t.punchy
              ? [BoxShadow(color: t.ink.withValues(alpha: .06), blurRadius: 12, offset: const Offset(0, 3))]
              : null,
        ),
        child: Row(children: [
          mark,
          const SizedBox(width: 12),
          Expanded(
            child: Text(step.label,
                style: slipText(14, 800, color: done || running ? t.ink : t.ink2.withValues(alpha: .7))),
          ),
          if (count != null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(count,
                  key: ValueKey(count),
                  style: slipText(12.5, 900, color: warn ? t.warning : t.accText, tabular: true)),
            ),
        ]),
      ),
    );
  }
}

/// The collapsible dark log at the bottom.
class _LogPanel extends StatelessWidget {
  const _LogPanel({required this.log, required this.open, required this.onToggle, required this.live});
  final List<LogLine> log;
  final bool open, live;
  final VoidCallback onToggle;

  static const _cream = Color(0xFFFFF6EC);
  static const _colors = {
    LogKind.text: Color(0xFFB5A89B),
    LogKind.stitch: Color(0xFFFFB98F),
    LogKind.card: Color(0xFFFF8F85),
    LogKind.match: Color(0xFF7FE0B4),
    LogKind.guess: Color(0xFFFFD37A),
    LogKind.warn: Color(0xFFFFD37A),
  };

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1613),
        borderRadius: BorderRadius.circular(t.punchy ? 12 : 18),
        border: t.outline == null ? null : Border.fromBorderSide(t.outline!),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: live ? const Color(0xFF5FD49A) : const Color(0xFF7A6E63),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('Details', style: slipText(13, 800, color: _cream))),
              AnimatedRotation(
                turns: open ? .5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const SlipIcon(Symbols.expand_more_rounded, size: 20, color: _cream),
              ),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Motion.rise,
          child: open
              ? SizedBox(
                  height: 150,
                  child: ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    itemCount: log.length,
                    itemBuilder: (_, i) {
                      final line = log[log.length - 1 - i];
                      return Text(line.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: slipText(10, 500, mono: true, color: _colors[line.kind], height: 1.45));
                    },
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }
}
