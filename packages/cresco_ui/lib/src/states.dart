import 'package:cresco_ui/src/palette.dart';
import 'package:cresco_ui/src/theme.dart';
import 'package:flutter/material.dart';

/// Placeholder shaped like the card that will load. Shimmers unless animations are reduced.
class Skeleton extends StatefulWidget {
  const new({super.key, this.height = 86, this.radius = CrescoShape.radius});
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final base = Color.alphaBlend(p.ink.withValues(alpha: 0.06), p.background);
    final light = Color.alphaBlend(p.surface.withValues(alpha: 0.7), base);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _shimmer,
        builder: (context, _) {
          final x = _shimmer.value * 3 - 1;
          return Container(
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment(x - 1, 0),
                end: Alignment(x + 1, 0),
                colors: [base, light, base],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Loading state: skeletons in the shape of the page, never a blank screen.
class LoadingState extends StatelessWidget {
  const new({super.key, this.heights = const [150, 86, 86]});
  final List<double> heights;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chargement',
      liveRegion: true,
      child: Column(
        children: [
          for (final (i, h) in heights.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            Skeleton(height: h),
          ],
        ],
      ),
    );
  }
}

/// Empty state: an illustration (the user's coach when the app passes one), one sentence
/// saying what to do, a main action and an optional secondary one.
class EmptyState extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
    this.illustration,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  /// Shown in an outlined tile when there is no [illustration].
  final IconData icon;
  final Widget? illustration;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child:
                illustration ??
                Container(
                  width: 88,
                  height: 88,
                  decoration: CrescoShape.outlined(p),
                  child: Icon(icon, size: 40, color: p.ink),
                ),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: CrescoTextes.titreCarte.copyWith(color: p.ink, fontSize: 24)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: context.mutedStyle.copyWith(fontSize: 15)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
          ],
        ],
      ),
    );
  }
}

/// Error state: what happened, that nothing is lost, and a way to retry.
class ErrorState extends StatelessWidget {
  const new({required this.message, super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: CrescoShape.outlined(p, fill: p.dangerSoft, outline: p.danger.withValues(alpha: 0.4)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: p.danger, size: 28),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: TextStyle(color: p.onDangerSoft, fontSize: 16, fontWeight: FontWeight.w700, height: 1.35),
                ),
                const SizedBox(height: 6),
                Text(
                  'Rien n’est perdu : ce que tu as saisi reste sur ton téléphone.',
                  style: TextStyle(color: p.onDangerSoft, fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ],
    );
  }
}

/// Offline banner: training stays possible, writes are sent when the network is back.
class OfflineBanner extends StatelessWidget {
  const new({super.key, this.pending = 0});
  final int pending;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final detail = pending > 0
        ? '$pending saisie${pending > 1 ? 's' : ''} partira${pending > 1 ? 'ont' : ''} au retour du réseau.'
        : 'Tu peux continuer : tout partira au retour du réseau.';
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: p.hero, borderRadius: CrescoShape.borderRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: Color(0xFFFFC24B), shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Hors ligne. ', style: TextStyle(fontWeight: FontWeight.w800)),
                      TextSpan(text: detail),
                    ],
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
