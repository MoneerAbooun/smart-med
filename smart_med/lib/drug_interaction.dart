import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_med/firestore_service.dart';
import 'package:smart_med/models/drug_interaction_response.dart';
import 'package:smart_med/services/drug_interaction_api_service.dart';

class DrugInteractionPage extends StatefulWidget {
  const DrugInteractionPage({super.key});

  @override
  State<DrugInteractionPage> createState() => _DrugInteractionPageState();
}

class _DrugInteractionPageState extends State<DrugInteractionPage> {
  final TextEditingController _firstDrugController = TextEditingController();
  final TextEditingController _secondDrugController = TextEditingController();
  final DrugInteractionApiService _apiService = DrugInteractionApiService();
  final FirestoreService _firestoreService = FirestoreService();

  bool _isLoading = false;
  bool _isLoadingProfile = true;
  String? _errorMessage;
  DrugInteractionResponse? _result;
  Map<String, dynamic>? _userProfile;
  List<String> _patientSpecificNotes = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _firstDrugController.dispose();
    _secondDrugController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _userProfile = null;
          _isLoadingProfile = false;
        });
        return;
      }

      final profile = await _firestoreService.getUserProfile(uid: user.uid);

      if (!mounted) return;

      setState(() {
        _userProfile = profile;
        _isLoadingProfile = false;
        if (_result != null) {
          _patientSpecificNotes = _buildPatientSpecificNotes(_result!, profile);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  String _normalizeName(String value) {
    return value.toLowerCase().replaceAll('-', ' ').trim();
  }

  List<String> _cleanList(List<String> items) {
    final seen = <String>{};
    final cleaned = <String>[];

    for (final item in items) {
      final value = item.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (value.isEmpty) continue;
      final key = value.toLowerCase();
      if (seen.add(key)) {
        cleaned.add(value);
      }
    }

    return cleaned;
  }

  Set<String> _aliasSet(DrugInteractionResponse result) {
    final values = <String>[
      result.firstDrug,
      result.secondDrug,
      result.firstQuery,
      result.secondQuery,
      result.firstGenericName ?? '',
      result.secondGenericName ?? '',
    ];

    return values
        .map(_normalizeName)
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  bool _containsAny(Set<String> haystack, List<String> needles) {
    for (final needle in needles) {
      final normalizedNeedle = _normalizeName(needle);
      if (normalizedNeedle.isEmpty) continue;
      for (final item in haystack) {
        if (item == normalizedNeedle ||
            item.contains(normalizedNeedle) ||
            normalizedNeedle.contains(item)) {
          return true;
        }
      }
    }
    return false;
  }

  List<String> _buildPatientSpecificNotes(
    DrugInteractionResponse result,
    Map<String, dynamic>? profile,
  ) {
    if (profile == null) return const [];

    final notes = <String>[];
    final aliases = _aliasSet(result);
    final warningsText = _normalizeName(
      [
        result.summary,
        result.mechanism ?? '',
        ...result.warnings,
        ...result.recommendations,
      ].join(' '),
    );

    final chronicDiseases = List<String>.from(profile['chronicDiseases'] ?? [])
        .map(_normalizeName)
        .toList();
    final drugAllergies = List<String>.from(profile['drugAllergies'] ?? [])
        .map(_normalizeName)
        .toList();

    final age = profile['age'] is int ? profile['age'] as int : int.tryParse('${profile['age'] ?? ''}');
    final medicalInfo = Map<String, dynamic>.from(profile['medicalInfo'] ?? {});
    final isPregnant = medicalInfo['isPregnant'] == true;
    final isBreastfeeding = medicalInfo['isBreastfeeding'] == true;
    final systolic = medicalInfo['systolicPressure'];
    final hasHighBloodPressureValue = systolic is num && systolic >= 140;

    final nsaidAliases = [
      'ibuprofen',
      'naproxen',
      'diclofenac',
      'ketorolac',
      'meloxicam',
      'celecoxib',
      'aspirin',
    ];
    final acetaminophenAliases = [
      'acetaminophen',
      'paracetamol',
      'tylenol',
    ];

    for (final allergy in drugAllergies) {
      if (allergy.length < 3) continue;
      if (_containsAny(aliases, [allergy])) {
        notes.add(
          'Possible allergy conflict: your profile lists "$allergy" as a drug allergy, and one of these medicines appears to match that name.',
        );
      }
    }

    if (chronicDiseases.any(
          (item) => item.contains('kidney') || item.contains('renal'),
        ) &&
        _containsAny(aliases, nsaidAliases)) {
      notes.add(
        'Profile note: NSAID-type medicines can be more risky when kidney disease is present.',
      );
    }

    if (chronicDiseases.any(
          (item) =>
              item.contains('liver') ||
              item.contains('hepatitis') ||
              item.contains('cirrhosis'),
        ) &&
        (_containsAny(aliases, acetaminophenAliases) ||
            warningsText.contains('liver'))) {
      notes.add(
        'Profile note: liver disease is listed in the profile, so acetaminophen-containing products and liver-related warnings need extra caution.',
      );
    }

    if ((chronicDiseases.any(
              (item) =>
                  item.contains('ulcer') ||
                  item.contains('bleeding') ||
                  item.contains('gastritis'),
            ) ||
            warningsText.contains('bleeding')) &&
        _containsAny(aliases, nsaidAliases)) {
      notes.add(
        'Profile note: stomach or bleeding-related history can increase concern with NSAID-type pain medicines.',
      );
    }

    if ((chronicDiseases.any(
              (item) =>
                  item.contains('pressure') || item.contains('hypertension'),
            ) ||
            hasHighBloodPressureValue) &&
        _containsAny(aliases, nsaidAliases)) {
      notes.add(
        'Profile note: NSAID-type medicines can worsen blood-pressure control in some patients.',
      );
    }

    if (isPregnant) {
      notes.add(
        'Profile note: pregnancy is marked in the saved profile, so any interaction result should be reviewed more cautiously before use.',
      );
    }

    if (isBreastfeeding) {
      notes.add(
        'Profile note: breastfeeding is marked in the saved profile, so exposure and safety should be checked before taking this combination.',
      );
    }

    if (age != null &&
        age >= 65 &&
        (result.severity.toLowerCase() == 'high' ||
            result.severity.toLowerCase() == 'moderate')) {
      notes.add(
        'Profile note: older adults can be more sensitive to interaction-related side effects such as bleeding, dizziness, kidney stress, and sedation.',
      );
    }

    return _cleanList(notes);
  }

  Future<void> _compareDrugs() async {
    final firstDrug = _firstDrugController.text.trim();
    final secondDrug = _secondDrugController.text.trim();

    if (firstDrug.isEmpty || secondDrug.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both medicine names.';
        _result = null;
      });
      return;
    }

    if (_normalizeName(firstDrug) == _normalizeName(secondDrug)) {
      setState(() {
        _errorMessage = 'Please enter two different medicines.';
        _result = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
      _patientSpecificNotes = [];
    });

    try {
      if (_isLoadingProfile) {
        await _loadUserProfile();
      }

      final response = await _apiService.compareDrugs(
        firstDrug: firstDrug,
        secondDrug: secondDrug,
      );

      if (!mounted) return;

      setState(() {
        _result = response;
        _patientSpecificNotes =
            _buildPatientSpecificNotes(response, _userProfile);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Color _severityColor(ColorScheme colorScheme, String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return colorScheme.error;
      case 'moderate':
        return Colors.orange;
      case 'mild':
        return Colors.amber.shade700;
      case 'no specific interaction found':
        return Colors.green;
      default:
        return colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'Drug Interaction',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.compare_arrows_rounded,
                                color: colorScheme.onSecondaryContainer,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Compare two medicines using a free public-data hybrid check built from RxNorm, openFDA, and DailyMed.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _firstDrugController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'First Drug Name',
                            prefixIcon: Icon(Icons.medication_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _secondDrugController,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _compareDrugs(),
                          decoration: const InputDecoration(
                            labelText: 'Second Drug Name',
                            prefixIcon: Icon(Icons.medication_outlined),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _compareDrugs,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text('Compare'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const _LoadingCard()
                else if (_errorMessage != null)
                  _StatusCard(
                    icon: Icons.error_outline,
                    title: 'Unable to compare medicines',
                    message: _errorMessage!,
                  )
                else if (_result == null)
                  const _StatusCard(
                    icon: Icons.info_outline,
                    title: 'No comparison yet',
                    message:
                        'Enter two medicine names, then tap Compare to see the interaction result.',
                  )
                else
                  _InteractionResultCard(
                    result: _result!,
                    severityColor: _severityColor(
                      colorScheme,
                      _result!.severity,
                    ),
                    cleanedWarnings: _cleanList(_result!.warnings),
                    cleanedRecommendations:
                        _cleanList(_result!.recommendations),
                    cleanedEvidence: _cleanList(_result!.evidence),
                    patientSpecificNotes: _patientSpecificNotes,
                    profileLoaded: _userProfile != null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text('Checking interaction...'),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _InteractionResultCard extends StatelessWidget {
  final DrugInteractionResponse result;
  final Color severityColor;
  final List<String> cleanedWarnings;
  final List<String> cleanedRecommendations;
  final List<String> cleanedEvidence;
  final List<String> patientSpecificNotes;
  final bool profileLoaded;

  const _InteractionResultCard({
    required this.result,
    required this.severityColor,
    required this.cleanedWarnings,
    required this.cleanedRecommendations,
    required this.cleanedEvidence,
    required this.patientSpecificNotes,
    required this.profileLoaded,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${result.firstDrug} + ${result.secondDrug}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: severityColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    result.severity,
                    style: TextStyle(
                      color: severityColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              result.summary,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Source: ${result.source}',
              style: TextStyle(
                fontSize: 12.5,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (result.firstGenericName != null || result.secondGenericName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Generic names: ${result.firstGenericName ?? result.firstDrug} / ${result.secondGenericName ?? result.secondDrug}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (result.mechanism != null && result.mechanism!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _SectionBox(
                title: 'Mechanism',
                icon: Icons.settings_suggest_outlined,
                items: [result.mechanism!.trim()],
              ),
            ],
            const SizedBox(height: 14),
            _SectionBox(
              title: 'Warnings',
              icon: Icons.warning_amber_rounded,
              items: cleanedWarnings,
              fallback: 'No extra warnings returned.',
            ),
            const SizedBox(height: 14),
            _SectionBox(
              title: 'Recommendations',
              icon: Icons.medical_information_outlined,
              items: cleanedRecommendations,
              fallback: 'No recommendations returned.',
            ),
            if (patientSpecificNotes.isNotEmpty) ...[
              const SizedBox(height: 14),
              _SectionBox(
                title: 'Profile-based Notes',
                icon: Icons.person_outline,
                items: patientSpecificNotes,
                fallback: 'No additional profile-based notes were generated.',
                highlight: true,
              ),
            ] else if (profileLoaded) ...[
              const SizedBox(height: 14),
              _SectionBox(
                title: 'Profile-based Notes',
                icon: Icons.person_outline,
                items: const [],
                fallback: 'No additional profile-based notes were triggered from the saved profile.',
              ),
            ],
            const SizedBox(height: 14),
            _ExpandableSectionBox(
              title: 'Evidence',
              icon: Icons.fact_check_outlined,
              items: cleanedEvidence,
              fallback: 'No evidence details returned.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionBox extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final String fallback;
  final bool highlight;

  const _SectionBox({
    required this.title,
    required this.icon,
    required this.items,
    this.fallback = 'No data available.',
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sectionColor = highlight ? colorScheme.error : colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight
            ? colorScheme.errorContainer.withValues(alpha: 0.35)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlight
              ? colorScheme.error.withValues(alpha: 0.25)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: sectionColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              fallback,
              style: TextStyle(
                height: 1.4,
                fontSize: 15,
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExpandableSectionBox extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final String fallback;

  const _ExpandableSectionBox({
    required this.title,
    required this.icon,
    required this.items,
    this.fallback = 'No data available.',
  });

  @override
  State<_ExpandableSectionBox> createState() => _ExpandableSectionBoxState();
}

class _ExpandableSectionBoxState extends State<_ExpandableSectionBox> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visibleItems = _expanded || widget.items.length <= 2
        ? widget.items
        : widget.items.take(2).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, size: 20, color: colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.items.isEmpty)
            Text(
              widget.fallback,
              style: TextStyle(
                height: 1.4,
                fontSize: 15,
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            ...visibleItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.items.length > 2)
              TextButton(
                onPressed: () {
                  setState(() {
                    _expanded = !_expanded;
                  });
                },
                child: Text(_expanded ? 'Show less' : 'Show more'),
              ),
          ],
        ],
      ),
    );
  }
}
