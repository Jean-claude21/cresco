import 'package:cresco_ui/src/coach_moves_list.dart';
import 'package:cresco_ui/src/palette.dart';
import 'package:cresco_ui/src/theme.dart';
import 'package:flutter/material.dart';

/// One exercise the coach can show: its catalog id and its name.
typedef CoachMoveItem = ({String id, String name});

/// Karim doing one exercise on its machine: start, middle and end drawn with ChatGPT
/// (docs/design/medias/coach-mouvements), played 1 → 2 → 3 → 2 every 2.4 s. Still on the start
/// pose when the system asks for less motion.
class CoachMove extends StatefulWidget {
  const new(this.exerciseId, {super.key});
  final String exerciseId;

  /// Exercises with their three poses in `assets/coach_moves/`.
  static const Set<String> available = coachMovesAvailable;

  @override
  State<CoachMove> createState() => _CoachMoveState();
}

class _CoachMoveState extends State<CoachMove> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  /// Pose index over the loop: hold the start, middle, hold the end, middle.
  static int _pose(double t) => const [0, 0, 1, 2, 2, 1][(t * 6).floor().clamp(0, 5)];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _loop
        ..stop()
        ..value = 0;
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.exerciseId;
    return AnimatedBuilder(
      animation: _loop,
      builder: (context, _) {
        final shown = _pose(_loop.value);
        // All three stay in the tree so the switch never waits for a decode.
        return Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < 3; i++)
              AnimatedOpacity(
                opacity: i == shown ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: Image.asset(
                  'assets/coach_moves/$id-${i + 1}.jpg',
                  package: 'cresco_ui',
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Bottom sheet « Voir le mouvement »: the coach on the machine. A station used for several
/// exercises (pulleys, Smith machine…) shows one chip per exercise.
Future<void> showCoachMove(BuildContext context, {required String title, required List<CoachMoveItem> moves}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _CoachMoveSheet(title: title, moves: moves),
  );
}

class _CoachMoveSheet extends StatefulWidget {
  const new({required this.title, required this.moves});
  final String title;
  final List<CoachMoveItem> moves;

  @override
  State<_CoachMoveSheet> createState() => _CoachMoveSheetState();
}

class _CoachMoveSheetState extends State<_CoachMoveSheet> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final move = widget.moves[_index];
    final several = widget.moves.length > 1;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              several ? widget.title : move.name,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: p.ink),
            ),
            const SizedBox(height: 4),
            Text('Karim montre le mouvement : départ, milieu, fin.', style: context.mutedStyle),
            if (several) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (i, m) in widget.moves.indexed)
                    ChoiceChip(
                      key: ValueKey('mouvement-choix-${m.id}'),
                      label: Text(m.name),
                      selected: i == _index,
                      onSelected: (_) => setState(() => _index = i),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // The poses are drawn on white: the canvas stays white in dark mode too, like a photo.
            ClipRRect(
              borderRadius: CrescoShape.borderRadius,
              child: ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: AspectRatio(
                  aspectRatio: 342 / 384,
                  child: CoachMove(move.id, key: ValueKey(move.id)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
