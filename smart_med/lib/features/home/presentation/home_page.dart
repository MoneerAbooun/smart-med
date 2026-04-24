import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_med/features/ai/ai.dart';
import 'package:smart_med/features/interactions/interactions.dart';
import 'package:smart_med/features/medications/medications.dart';
import 'package:smart_med/features/profile/profile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.cameras});

  final List<CameraDescription> cameras;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  final AiPreferencesRepository _aiPreferencesRepository =
      aiPreferencesRepository;

  bool isCameraOpened = false;
  bool isCapturing = false;

  CameraController? controller;
  Future<void>? initializeControllerFuture;
  XFile? selectedImage;
  Future<PersonalizedExplanationResponse>? _briefFuture;
  StreamSubscription<List<MedicationRecord>>? _medicationsSubscription;
  StreamSubscription<UserProfileRecord?>? _profileSubscription;

  @override
  void initState() {
    super.initState();
    _startSafetyBriefWatchers();
  }

  @override
  void dispose() {
    _medicationsSubscription?.cancel();
    _profileSubscription?.cancel();
    controller?.dispose();
    super.dispose();
  }

  void _startSafetyBriefWatchers() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    _briefFuture = _loadSafetyBrief();
    _medicationsSubscription = medicationRepository
        .watchMedicationRecords(uid: user.uid)
        .listen((_) => _refreshSafetyBrief());
    _profileSubscription = profileRepository
        .watchProfile(uid: user.uid)
        .listen((_) => _refreshSafetyBrief());
  }

  Future<PersonalizedExplanationResponse> _loadSafetyBrief() async {
    final preferences = await _aiPreferencesRepository.loadPreferences();
    return personalizedExplanationRepository.generateSafetyBrief(
      simpleLanguage: preferences.simpleLanguageMode,
    );
  }

  void _refreshSafetyBrief() {
    if (!mounted) {
      return;
    }

    setState(() {
      _briefFuture = _loadSafetyBrief();
    });
  }

  Future<void> _openAiGuide({
    List<String> medicationIds = const <String>[],
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AiMedicationExplanationPage(medicationIds: medicationIds),
      ),
    );
    _refreshSafetyBrief();
  }

  Future<void> _openInteractionChecker() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CheckInteractionsPage()),
    );
    _refreshSafetyBrief();
  }

  Future<void> _openMedicationList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MedicationListPage()),
    );
    _refreshSafetyBrief();
  }

  Future<void> _openAddMedication() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddMedicationPage()),
    );
    _refreshSafetyBrief();
  }

  Future<void> _continueWithSelectedImage() async {
    final image = selectedImage;
    if (image == null) {
      return;
    }

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddMedicationPage(initialMedicationImage: image),
      ),
    );

    if (!mounted) {
      return;
    }

    if (saved == true) {
      await backToPlaceholder();
      _refreshSafetyBrief();
    }
  }

  Future<void> _setupCamera() async {
    if (widget.cameras.isEmpty) {
      throw Exception('No cameras available');
    }

    final backCamera = widget.cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );

    controller = CameraController(
      backCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    initializeControllerFuture = controller!.initialize();
    await initializeControllerFuture;
  }

  Future<void> pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      if (controller != null) {
        await controller!.dispose();
        controller = null;
      }

      if (!mounted) return;

      setState(() {
        selectedImage = image;
        isCameraOpened = false;
        isCapturing = false;
      });
    }
  }

  Future<void> openCamera() async {
    try {
      if (controller != null) {
        await controller!.dispose();
        controller = null;
      }

      await _setupCamera();

      if (!mounted) return;

      setState(() {
        isCameraOpened = true;
        selectedImage = null;
        isCapturing = false;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to open camera: $e')));
    }
  }

  Future<void> captureImage() async {
    if (controller == null) return;
    if (!controller!.value.isInitialized) return;
    if (controller!.value.isTakingPicture || isCapturing) return;

    try {
      setState(() {
        isCapturing = true;
      });

      await initializeControllerFuture;

      final XFile image = await controller!.takePicture();

      if (!mounted) return;

      setState(() {
        selectedImage = image;
        isCameraOpened = false;
        isCapturing = false;
      });

      await controller!.dispose();
      controller = null;
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isCapturing = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to capture image: $e')));
    }
  }

  Future<void> backToPlaceholder() async {
    if (controller != null) {
      await controller!.dispose();
      controller = null;
    }

    if (!mounted) return;

    setState(() {
      selectedImage = null;
      isCameraOpened = false;
      isCapturing = false;
    });
  }

  Widget _buildPreviewCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      height: 330,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: selectedImage != null
            ? Image.file(
                File(selectedImage!.path),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              )
            : isCameraOpened
            ? FutureBuilder<void>(
                future: initializeControllerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      controller != null) {
                    return CameraPreview(controller!);
                  }

                  return const Center(child: CircularProgressIndicator());
                },
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.photo_camera_back_outlined,
                      size: 80,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Capture or choose an image',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Choose a photo here, then continue to Add Medication to save it with the medicine record.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildQuickAction({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: colorScheme.onSecondaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildAiBriefCard(BuildContext context) {
    if (_briefFuture == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<PersonalizedExplanationResponse>(
      future: _briefFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Preparing today\'s AI safety brief...')),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          final message = snapshot.error.toString();
          final noMedicationMatch = message.toLowerCase().contains(
            'no matching medications were found',
          );

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s AI Safety Brief',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  noMedicationMatch
                      ? 'Add at least one medication to generate a personalized safety brief.'
                      : 'The AI brief is not available right now.',
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: noMedicationMatch
                      ? _openAddMedication
                      : _refreshSafetyBrief,
                  child: Text(noMedicationMatch ? 'Add Medication' : 'Retry'),
                ),
              ],
            ),
          );
        }

        final response = snapshot.data;
        if (response == null) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today\'s AI Safety Brief',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          response.quickSummary.isNotEmpty
                              ? response.quickSummary
                              : response.overview,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AiSeverityChip(severity: response.overallSeverity),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildBriefMetric(
                    context,
                    icon: Icons.compare_arrows,
                    label: 'Interactions',
                    value: response.interactionCount.toString(),
                  ),
                  _buildBriefMetric(
                    context,
                    icon: Icons.warning_amber_rounded,
                    label: 'Cautions',
                    value: response.cautionCount.toString(),
                  ),
                ],
              ),
              if (response.profileCompleteness.missingFields.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(response.profileCompleteness.summary),
                ),
              ],
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _openAiGuide,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Open AI Guide'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBriefMetric(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
          toolbarHeight: 70,
          centerTitle: true,
          automaticallyImplyLeading: false,
          leadingWidth: 56,
          leading: const SizedBox(),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/Capsule.png', fit: BoxFit.cover),
              ),
              const SizedBox(width: 8),
              const Text(
                'Smart Med',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: 56,
              child: IconButton(
                icon: const Icon(Icons.medication_outlined, size: 28),
                tooltip: 'Medications',
                onPressed: _openMedicationList,
              ),
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  _buildAiBriefCard(context),
                  const SizedBox(height: 16),
                  _buildPreviewCard(context),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton.icon(
                        onPressed: openCamera,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Open Camera'),
                      ),
                      OutlinedButton.icon(
                        onPressed: pickImageFromGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Gallery'),
                      ),
                      if (selectedImage != null || isCameraOpened)
                        OutlinedButton.icon(
                          onPressed: backToPlaceholder,
                          icon: const Icon(Icons.close),
                          label: const Text('Clear'),
                        ),
                      if (isCameraOpened)
                        ElevatedButton.icon(
                          onPressed: isCapturing ? null : captureImage,
                          icon: const Icon(Icons.camera),
                          label: Text(isCapturing ? 'Capturing...' : 'Capture'),
                        ),
                      if (selectedImage != null)
                        ElevatedButton.icon(
                          onPressed: _continueWithSelectedImage,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Use in Add Medication'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Column(
                    children: [
                      if (selectedImage != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.image_outlined,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Image selected and ready for upload.',
                                  style: textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      _buildQuickAction(
                        context: context,
                        icon: Icons.auto_awesome_outlined,
                        title: 'Explain My Meds',
                        subtitle:
                            'Open the AI guide for simple explanations, warnings, and safer-use tips.',
                        onTap: _openAiGuide,
                      ),
                      const SizedBox(height: 12),
                      _buildQuickAction(
                        context: context,
                        icon: Icons.compare_arrows_outlined,
                        title: 'Check Interactions',
                        subtitle:
                            'Enter two medicine names and check them with real backend data.',
                        onTap: _openInteractionChecker,
                      ),
                      const SizedBox(height: 12),
                      _buildQuickAction(
                        context: context,
                        icon: Icons.shield_outlined,
                        title: 'Safer Use Tips',
                        subtitle:
                            'See behavior suggestions based on your profile and medication list.',
                        onTap: _openAiGuide,
                      ),
                      const SizedBox(height: 12),
                      _buildQuickAction(
                        context: context,
                        icon: Icons.medication_outlined,
                        title: 'Medication List',
                        subtitle:
                            'Manage the medicines already saved in Firestore.',
                        onTap: _openMedicationList,
                      ),
                      const SizedBox(height: 12),
                      _buildQuickAction(
                        context: context,
                        icon: Icons.add_box_outlined,
                        title: 'Add Medication',
                        subtitle:
                            'Save a new medication directly to Firestore and schedule reminders.',
                        onTap: _openAddMedication,
                      ),
                    ],
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
