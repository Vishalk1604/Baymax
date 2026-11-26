import 'package:flutter/material.dart';

import '../../core/motion/fade_slide_in.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/glass_page.dart';
import '../../core/widgets/surfaces.dart';

enum LegalDoc { terms, privacy, disclaimer }

extension LegalDocText on LegalDoc {
  String get title => switch (this) {
        LegalDoc.terms => 'Terms of use',
        LegalDoc.privacy => 'Privacy',
        LegalDoc.disclaimer => 'Medical disclaimer',
      };
}

class _Section {
  const _Section(this.heading, this.body, {this.points = const []});
  final String heading;
  final String body;
  final List<String> points;
}

/// Plain-language terms, privacy notice and medical disclaimer.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});
  final LegalDoc doc;

  static Future<void> open(BuildContext context, LegalDoc doc) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => LegalScreen(doc: doc)));

  static const _updated = 'Updated November 2026';

  List<_Section> get _sections => switch (doc) {
        LegalDoc.terms => const [
            _Section(
              'What Baymax is',
              'Baymax is a personal health companion. With the Baymax device it measures temperature, heart rate and '
                  'blood oxygen, reads how you describe your symptoms, and for common, mild complaints suggests one of a '
                  'few over-the-counter medicines using fixed safety rules.',
            ),
            _Section(
              'Not a doctor',
              'Baymax gives general guidance. It doesn’t diagnose, and it isn’t a medical device. Always read the '
                  'medicine’s label, and ask a pharmacist or doctor if you’re unsure, pregnant or breastfeeding, or taking '
                  'other medicines.',
              points: ['In an emergency, call 112 straight away.', 'If you feel worse or don’t improve, see a doctor.'],
            ),
            _Section(
              'Your part',
              'Recommendations are only as safe as the information behind them.',
              points: [
                'Keep your medical history (conditions and allergies) up to date.',
                'Keep compartments 1–4 of your Baymax stocked with the medicines the app shows for them.',
                'Keep your sign-in details to yourself.',
              ],
            ),
            _Section(
              'Online features',
              'Reading symptoms and finding nearby care need an internet connection and may sometimes be unavailable. '
                  'Clinic information comes from OpenStreetMap and can be incomplete or out of date. Planning a visit '
                  'saves it in Baymax with a reminder; it doesn’t book an appointment with the clinic.',
            ),
            _Section(
              'Your account',
              'You can edit your information at any time, and delete your account and everything in it from Settings.',
            ),
          ],
        LegalDoc.privacy => const [
            _Section(
              'What Baymax keeps',
              'Your data is stored in your Baymax account (Google Firebase) and protected so that only you can read it:',
              points: [
                'Account: your name and email address.',
                'Profile: age, sex, height, weight, blood type, conditions and medicine allergies.',
                'Check-ups: vitals, what you described and the result.',
                'Medicines, reminder times and the doses you mark as taken.',
                'Visits you plan.',
              ],
            ),
            _Section(
              'What leaves your phone',
              'Only what a feature needs, and only when you use it:',
              points: [
                'Symptoms: the words you use to describe them, with your vitals, go to an AI language service '
                    '(currently NVIDIA’s API) so Baymax can recognise the symptoms. Your name, email and medical '
                    'history are not sent; the safety checks run on your phone.',
                'Nearby care: your approximate location goes to OpenStreetMap’s Overpass service when you search. '
                    'Baymax doesn’t store it.',
                'Bluetooth connects only to your Baymax device.',
              ],
            ),
            _Section(
              'What Baymax doesn’t do',
              'No advertising, no selling or sharing your data, and no tracking across apps. Reminders are scheduled on '
                  'your phone.',
            ),
            _Section(
              'Your choices',
              'You’re in control of your information:',
              points: [
                'Edit your profile and medical history at any time.',
                'Delete individual check-ups from their details page.',
                'Export a PDF health report to share with your doctor.',
                'Delete your account in Settings — this erases all of your data.',
              ],
            ),
          ],
        LegalDoc.disclaimer => const [
            _Section(
              'General information only',
              'Baymax offers general health information. It is not a diagnosis and does not replace a doctor, '
                  'pharmacist or emergency service.',
            ),
            _Section(
              'Limited, cautious recommendations',
              'Baymax only suggests a few over-the-counter medicines — paracetamol, ibuprofen, cetirizine, famotidine and '
                  'oral rehydration salts — for common, mild symptoms, at adult doses (anyone under 12 is referred to a doctor '
                  'or pharmacist). It checks your conditions and allergies first, and asks a safety question before '
                  'recommending anything.',
            ),
            _Section(
              'When Baymax sends you to a doctor',
              'Warning signs stop the recommendation and ask you to get care instead, for example:',
              points: [
                'Difficulty breathing, chest tightness, fainting, seizures or confusion.',
                'Very high or very low temperature, very fast heart rate, or low blood oxygen.',
                'Severe stomach pain, vomiting that won’t stop, or blood in vomit or stool.',
                'Symptoms that continue while already taking a recommended medicine.',
              ],
            ),
            _Section(
              'About the readings',
              'Device readings are estimates. The forehead sensor’s reading is converted to an estimated body temperature, '
                  'and readings can be affected by movement, sensor contact and the room.',
            ),
            _Section('Emergencies', 'If you think it’s an emergency, call 112 now. Don’t wait for the app.'),
          ],
      };

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    return GlassPage(
      title: doc.title,
      subtitle: _updated,
      showBack: true,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          sliver: SliverList.list(
            children: [
              if (doc == LegalDoc.disclaimer)
                const Padding(
                  padding: EdgeInsets.only(bottom: Space.md),
                  child: InfoBanner(
                    tone: Tone.danger,
                    icon: Icons.emergency_rounded,
                    message: 'In an emergency, call 112.',
                  ),
                ),
              for (final (i, s) in sections.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.md),
                  child: FadeSlideIn(
                    delay: FadeSlideIn.stagger(i),
                    child: SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(header: true, child: Text(s.heading, style: context.text.titleMedium)),
                          const SizedBox(height: Space.xs),
                          Text(s.body, style: context.text.bodyMedium!.copyWith(color: context.colors.textPrimary, height: 1.5)),
                          for (final p in s.points)
                            Padding(
                              padding: const EdgeInsets.only(top: Space.xs),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8, right: Space.xs),
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(color: context.colors.primary, shape: BoxShape.circle),
                                    ),
                                  ),
                                  Expanded(child: Text(p, style: context.text.bodyMedium!.copyWith(height: 1.5))),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: Space.lg),
            ],
          ),
        ),
      ],
    );
  }
}
