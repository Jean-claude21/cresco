import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_data/cresco_data.dart';
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';

const _key = 'coach';

/// The coach the user picked at onboarding, kept on the phone so it shows offline.
/// Before any choice, the coach is the first one ([Coach.femme]).
Coach currentCoach() => Coach.fromName(locator<Session>().cache(_key)?['coach']) ?? Coach.femme;

/// Remembers [coach] on the phone and in the profile (`preferences.coach`, readable by the AI).
/// The profile write is best effort: offline, the local choice still applies.
Future<void> saveCoach(Coach coach, {bool remote = true}) async {
  await locator<Session>().mettreEnCache(_key, {'coach': coach.name});
  if (!remote) return;
  try {
    await locator<CrescoApi>().modifierProfil({
      'preferences': {'coach': coach.name},
    });
  } on ErreurApi {
    // Sent again with the next profile change.
  }
}

/// Aligns the local coach with a profile read from the server.
Future<void> syncCoachFrom(Json profile) async {
  final coach = Coach.fromName((profile['preferences'] as Json?)?['coach']);
  if (coach != null && coach != currentCoach()) await saveCoach(coach, remote: false);
}

/// The user's coach in [pose].
class MyCoach extends StatelessWidget {
  const new(this.pose, {super.key, this.height = 200});
  final CoachPose pose;
  final double height;

  @override
  Widget build(BuildContext context) => CoachIllustration(coach: currentCoach(), pose: pose, height: height);
}
