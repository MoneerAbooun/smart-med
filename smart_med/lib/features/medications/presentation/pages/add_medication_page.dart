import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_med/core/firebase/image_storage_repository.dart';
import 'package:smart_med/core/services/notification_service.dart';
import 'package:smart_med/features/ai/data/repositories/personalized_explanation_repository.dart';
import 'package:smart_med/features/ai/domain/models/personalized_explanation_models.dart';
import 'package:smart_med/features/drug_library/data/drug_catalog_repository.dart';
import 'package:smart_med/features/drug_library/data/models/drug_catalog_record.dart';
import 'package:smart_med/features/medications/data/repositories/medication_repository.dart';
import 'package:smart_med/features/medications/domain/models/medication_record.dart';
import 'package:smart_med/features/medications/domain/models/medication_schedule_time.dart';
import 'package:smart_med/features/medications/presentation/widgets/safety_preview_sheet.dart';

class AddMedicationPage extends StatefulWidget {
  const AddMedicationPage({
    super.key,
    this.initialMedicationImage,
    this.initialMedicationImageBytes,
  });

  final XFile? initialMedicationImage;
  final Uint8List? initialMedicationImageBytes;

  @override
  State<AddMedicationPage> createState() => _AddMedicationPageState();
}

class _AddMedicationPageState extends State<AddMedicationPage> {
  final _formKey = GlobalKey<FormState>();
  final MedicationRepository _medicationRepository = medicationRepository;
  final DrugCatalogRepository _drugCatalogRepository = drugCatalogRepository;
  final PersonalizedExplanationRepository _explanationRepository =
      personalizedExplanationRepository;
  final ImagePicker _imagePicker = ImagePicker();
  final ImageStorageRepository _imageStorageRepository = imageStorageRepository;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController doseController = TextEditingController();
  final TextEditingController timesPerDayController = TextEditingController();
  final TextEditingController startDateController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  final List<TextEditingController> timeControllers = [];
  final Duration _catalogSearchDelay = const Duration(milliseconds: 300);

  bool isLoading = false;
  bool isSearchingDrugCatalog = false;
  int timesPerDay = 1;
  Timer? _catalogSearchDebounce;
  List<DrugCatalogRecord> _catalogResults = const <DrugCatalogRecord>[];
  DrugCatalogRecord? _selectedDrug;
  String? _catalogSearchFeedback;
  String? _selectedDrugForm;
  XFile? _selectedMedicationImage;
  Uint8List? _selectedMedicationImageBytes;

  String selectedDoseUnit = 'mg';
  final List<String> doseUnits = ['mg', 'ml', 'tablet', 'capsule'];

  @override
  void initState() {
    super.initState();
    timesPerDay = 1;
    timesPerDayController.text = '1';
    timeControllers.add(TextEditingController());

    _selectedMedicationImage = widget.initialMedicationImage;
    _selectedMedicationImageBytes = widget.initialMedicationImageBytes;

    if (_selectedMedicationImage != null &&
        _selectedMedicationImageBytes == null) {
      _loadInitialMedicationImageBytes();
    }
  }

  @override
  void dispose() {
    _catalogSearchDebounce?.cancel();
    nameController.dispose();
    doseController.dispose();
    timesPerDayController.dispose();
    startDateController.dispose();
    noteController.dispose();

    for (final controller in timeControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  void _updateTimeControllers(int count) {
    if (count < 1) count = 1;
    if (count > 6) count = 6;

    while (timeControllers.length < count) {
      timeControllers.add(TextEditingController());
    }

    while (timeControllers.length > count) {
      timeControllers.removeLast().dispose();
    }

    timesPerDay = count;
  }

  InputDecoration customInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Future<void> _loadInitialMedicationImageBytes() async {
    final image = _selectedMedicationImage;
    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();
    if (!mounted || _selectedMedicationImage != image) {
      return;
    }

    setState(() {
      _selectedMedicationImageBytes = bytes;
    });
  }

  Future<void> _pickMedicationImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedMedicationImage = image;
      _selectedMedicationImageBytes = bytes;
    });
  }

  void _clearMedicationImage() {
    setState(() {
      _selectedMedicationImage = null;
      _selectedMedicationImageBytes = null;
    });
  }

  Widget _buildMedicationImageSection() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Medicine Photo',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Optional. Save a pill, bottle, or package photo to the Smart Med server.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              height: 180,
              color: colorScheme.surface,
              child: _selectedMedicationImageBytes != null
                  ? Image.memory(
                      _selectedMedicationImageBytes!,
                      fit: BoxFit.cover,
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 42,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No photo selected',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: isLoading ? null : _pickMedicationImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  _selectedMedicationImageBytes == null
                      ? 'Upload Photo'
                      : 'Change Photo',
                ),
              ),
              if (_selectedMedicationImageBytes != null)
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _clearMedicationImage,
                  icon: const Icon(Icons.close),
                  label: const Text('Clear'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> pickTime(int index) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime != null && mounted) {
      final formattedTime = pickedTime.format(context);
      setState(() {
        timeControllers[index].text = formattedTime;
      });
    }
  }

  Future<void> pickStartDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        startDateController.text =
            "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
      });
    }
  }

  MedicationRecord _buildMedicationRecord(
    String uid,
    List<String> times, {
    String? imageUrl,
  }) {
    final selectedDrug = _selectedDrug;
    final primaryBrandName =
        selectedDrug != null && selectedDrug.brandNames.isNotEmpty
        ? selectedDrug.brandNames.first
        : null;

    return MedicationRecord(
      userId: uid,
      name: selectedDrug?.name ?? nameController.text.trim(),
      genericName: selectedDrug?.genericName,
      brandName: primaryBrandName,
      drugCatalogId: selectedDrug?.id,
      doseAmount: double.parse(doseController.text.trim()),
      doseUnit: selectedDoseUnit,
      form: _selectedDrugForm,
      frequencyPerDay: times.length,
      scheduledTimes: times
          .map(MedicationScheduleTime.fromDisplayString)
          .toList(growable: false),
      startDate: DateTime.tryParse(startDateController.text.trim()),
      notes: noteController.text.trim().isEmpty
          ? null
          : noteController.text.trim(),
      imageUrl: imageUrl,
      remindersEnabled: true,
      status: 'active',
      notificationIds: const <int>[],
    );
  }

  DraftMedicationInput _buildDraftMedicationInput(List<String> times) {
    final selectedDrug = _selectedDrug;
    final primaryBrandName =
        selectedDrug != null && selectedDrug.brandNames.isNotEmpty
        ? selectedDrug.brandNames.first
        : null;

    return DraftMedicationInput(
      name: selectedDrug?.name ?? nameController.text.trim(),
      genericName: selectedDrug?.genericName,
      brandName: primaryBrandName,
      doseAmount: double.tryParse(doseController.text.trim()),
      doseUnit: selectedDoseUnit,
      frequencyPerDay: times.length,
      reminderTimes: times,
      startDate: DateTime.tryParse(startDateController.text.trim()),
      notes: noteController.text.trim().isEmpty
          ? null
          : noteController.text.trim(),
      form: _selectedDrugForm,
    );
  }

  Future<bool> _showSafetyPreview(List<String> times) async {
    try {
      final response = await _explanationRepository.generateSafetyPreview(
        draftMedication: _buildDraftMedicationInput(times),
      );

      if (!mounted) {
        return false;
      }

      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafetyPreviewSheet(
          response: response,
          confirmLabel: 'Save Medication',
        ),
      );

      return confirmed == true;
    } catch (e) {
      if (!mounted) {
        return false;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      return false;
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  String _firebaseErrorMessage(
    FirebaseException exception, {
    required String fallbackMessage,
  }) {
    switch (exception.code.trim()) {
      case 'permission-denied':
        return 'You do not have permission to save this medication.';
      case 'unauthenticated':
        return 'Please sign in again before saving this medication.';
      case 'unavailable':
        return 'Firebase is temporarily unavailable. Please try again.';
      default:
        final message = exception.message?.trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }

        return fallbackMessage;
    }
  }

  void _scheduleDrugCatalogSearch(String query) {
    _catalogSearchDebounce?.cancel();

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      setState(() {
        isSearchingDrugCatalog = false;
        _catalogResults = const <DrugCatalogRecord>[];
        _catalogSearchFeedback = null;
      });
      return;
    }

    setState(() {
      isSearchingDrugCatalog = true;
      _catalogSearchFeedback = null;
    });

    _catalogSearchDebounce = Timer(_catalogSearchDelay, () async {
      await _searchDrugCatalog(trimmedQuery);
    });
  }

  Future<void> _searchDrugCatalog(String query) async {
    try {
      final results = await _drugCatalogRepository.searchDrugs(query, limit: 6);

      if (!mounted || nameController.text.trim() != query) {
        return;
      }

      setState(() {
        isSearchingDrugCatalog = false;
        _catalogResults = results;
        _catalogSearchFeedback = results.isEmpty
            ? 'No Firestore catalog match. You can still save this medication manually.'
            : null;
      });
    } catch (_) {
      if (!mounted || nameController.text.trim() != query) {
        return;
      }

      setState(() {
        isSearchingDrugCatalog = false;
        _catalogResults = const <DrugCatalogRecord>[];
        _catalogSearchFeedback =
            'Could not search the Firestore drug catalog right now.';
      });
    }
  }

  void _handleDrugNameChanged(String value) {
    final trimmedValue = value.trim();
    final selectedDrugName = _selectedDrug?.name.trim().toLowerCase();

    if (_selectedDrug != null &&
        trimmedValue.toLowerCase() != selectedDrugName) {
      setState(() {
        _selectedDrug = null;
        _selectedDrugForm = null;
      });
    }

    _scheduleDrugCatalogSearch(trimmedValue);
  }

  void _selectDrugFromCatalog(DrugCatalogRecord drug) {
    _catalogSearchDebounce?.cancel();

    nameController.text = drug.name;
    nameController.selection = TextSelection.fromPosition(
      TextPosition(offset: nameController.text.length),
    );

    setState(() {
      _selectedDrug = drug;
      _selectedDrugForm = drug.doseForms.isEmpty ? null : drug.doseForms.first;
      _catalogResults = const <DrugCatalogRecord>[];
      _catalogSearchFeedback = null;
      isSearchingDrugCatalog = false;
    });
  }

  void _clearDrugSelection() {
    _catalogSearchDebounce?.cancel();

    setState(() {
      _selectedDrug = null;
      _selectedDrugForm = null;
      _catalogResults = const <DrugCatalogRecord>[];
      _catalogSearchFeedback = nameController.text.trim().isEmpty
          ? null
          : 'Type to search the Firestore drug catalog.';
      isSearchingDrugCatalog = false;
    });
  }

  Widget? _buildNameSuffixIcon() {
    if (isSearchingDrugCatalog) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_selectedDrug != null) {
      return const Icon(Icons.check_circle_outline);
    }

    return const Icon(Icons.search_rounded);
  }

  Widget _buildCatalogSelectionPanel() {
    final selectedDrug = _selectedDrug;

    if (selectedDrug == null &&
        _catalogResults.isEmpty &&
        (_catalogSearchFeedback == null ||
            nameController.text.trim().isEmpty)) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (selectedDrug != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_hospital_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${selectedDrug.name} linked from Firestore',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    TextButton(
                      onPressed: _clearDrugSelection,
                      child: const Text('Unlink'),
                    ),
                  ],
                ),
                if ((selectedDrug.genericName ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Generic: ${selectedDrug.genericName}'),
                ],
                if (selectedDrug.brandNames.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Brands: ${selectedDrug.brandNames.join(', ')}'),
                ],
                if (selectedDrug.strengths.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Strengths: ${selectedDrug.strengths.join(', ')}'),
                ],
                if ((selectedDrug.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(selectedDrug.description!),
                ],
              ],
            ),
          ),
        if (selectedDrug == null && _catalogResults.isNotEmpty) ...[
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: List.generate(_catalogResults.length, (index) {
                final drug = _catalogResults[index];
                final genericName = drug.genericName?.trim();
                final subtitleParts = <String>[
                  if (genericName != null && genericName.isNotEmpty)
                    'Generic: $genericName',
                  if (drug.brandNames.isNotEmpty)
                    'Brands: ${drug.brandNames.take(2).join(', ')}',
                ];

                return Column(
                  children: [
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.search_outlined),
                      title: Text(drug.name),
                      subtitle: subtitleParts.isEmpty
                          ? null
                          : Text(subtitleParts.join(' | ')),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                      ),
                      onTap: () => _selectDrugFromCatalog(drug),
                    ),
                    if (index != _catalogResults.length - 1)
                      const Divider(height: 1),
                  ],
                );
              }),
            ),
          ),
        ],
        if (selectedDrug == null &&
            _catalogSearchFeedback != null &&
            nameController.text.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _catalogSearchFeedback!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> addMedication() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Please sign in before uploading and saving medications.');
      return;
    }

    for (int i = 0; i < timeControllers.length; i++) {
      if (timeControllers[i].text.trim().isEmpty) {
        _showMessage('Please select Time ${i + 1}');
        return;
      }
    }

    final List<String> times = timeControllers
        .map((controller) => controller.text.trim())
        .toList();

    setState(() {
      isLoading = true;
    });

    final confirmed = await _showSafetyPreview(times);
    if (!mounted) return;

    if (!confirmed) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final medicationId = _medicationRepository.createMedicationId(
        uid: user.uid,
      );
      String? imageUrl;

      if (_selectedMedicationImage != null) {
        imageUrl = await _imageStorageRepository.uploadMedicationImage(
          image: _selectedMedicationImage!,
        );
      }

      final medication = _buildMedicationRecord(
        user.uid,
        times,
        imageUrl: imageUrl,
      );

      await _medicationRepository.saveMedicationRecord(
        uid: user.uid,
        medication: medication,
        medicationId: medicationId,
      );

      final notificationsEnabled =
          await NotificationService.areNotificationsEnabled();
      List<int> notificationIds = [];

      notificationIds = await NotificationService.scheduleMedicationReminders(
        medicineName: medication.name,
        times: medication.reminderTimes,
        body: 'Time to take ${medication.name}',
        userId: user.uid,
        medicationId: medicationId,
        startDate: medication.startDate,
      );

      await _medicationRepository.updateMedicationRecord(
        uid: user.uid,
        medicationId: medicationId,
        medication: medication.copyWith(
          id: medicationId,
          imageUrl: imageUrl,
          notificationIds: notificationIds,
        ),
      );

      if (!mounted) return;

      if (!notificationsEnabled) {
        _showMessage(
          'Medication added successfully. Reminders are off in Settings.',
        );
      } else if (notificationIds.length == times.length) {
        _showMessage('Medication added successfully');
      } else if (notificationIds.isNotEmpty) {
        _showMessage(
          'Medication added, but some reminders could not be scheduled.',
        );
      } else {
        _showMessage('Medication added, but reminders could not be scheduled.');
      }

      Navigator.pop(context, true);
    } on ImageStorageRepositoryException catch (e) {
      if (!mounted) return;

      _showMessage(e.message);
    } on FirebaseException catch (e) {
      if (!mounted) return;

      _showMessage(
        _firebaseErrorMessage(
          e,
          fallbackMessage: 'Could not save the medication right now.',
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage('Could not save the medication. ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Medication'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: customInputDecoration(
                    'Medication Name *',
                  ).copyWith(suffixIcon: _buildNameSuffixIcon()),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter medication name';
                    }
                    return null;
                  },
                  onChanged: _handleDrugNameChanged,
                ),
                const SizedBox(height: 10),
                _buildCatalogSelectionPanel(),
                const SizedBox(height: 14),
                _buildMedicationImageSection(),
                const SizedBox(height: 14),
                if (_selectedDrug != null &&
                    _selectedDrug!.doseForms.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey(_selectedDrug!.id),
                    initialValue: _selectedDrugForm,
                    decoration: customInputDecoration('Dose Form'),
                    items: _selectedDrug!.doseForms.map((form) {
                      return DropdownMenuItem<String>(
                        value: form,
                        child: Text(form),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDrugForm = value;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 14),

                TextFormField(
                  controller: doseController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: customInputDecoration('Dosage *'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter dosage';
                    }

                    final number = double.tryParse(value.trim());
                    if (number == null || number <= 0) {
                      return 'Enter a valid dosage number';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  initialValue: selectedDoseUnit,
                  decoration: customInputDecoration('Dose Unit *'),
                  items: doseUnits.map((unit) {
                    return DropdownMenuItem<String>(
                      value: unit,
                      child: Text(unit),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedDoseUnit = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: timesPerDayController,
                  keyboardType: TextInputType.number,
                  decoration: customInputDecoration(
                    'Frequency per day (1-6) *',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the daily frequency';
                    }

                    final number = int.tryParse(value.trim());
                    if (number == null) {
                      return 'Enter a valid number';
                    }

                    if (number < 1 || number > 6) {
                      return 'Times per day must be between 1 and 6';
                    }

                    return null;
                  },
                  onChanged: (value) {
                    if (value.trim().isEmpty) {
                      setState(() {
                        timesPerDay = 1;
                        while (timeControllers.length > 1) {
                          timeControllers.removeLast().dispose();
                        }
                      });
                      return;
                    }

                    int parsed = int.tryParse(value) ?? 1;

                    if (parsed > 6) {
                      parsed = 6;
                      timesPerDayController.text = '6';
                      timesPerDayController.selection =
                          TextSelection.fromPosition(
                            const TextPosition(offset: 1),
                          );

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Maximum is 6 times per day'),
                        ),
                      );
                    }

                    if (parsed < 1) {
                      parsed = 1;
                    }

                    setState(() {
                      _updateTimeControllers(parsed);
                    });
                  },
                ),
                const SizedBox(height: 14),

                Column(
                  children: List.generate(timeControllers.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: TextFormField(
                        controller: timeControllers[index],
                        readOnly: true,
                        onTap: () => pickTime(index),
                        decoration: customInputDecoration(
                          'Reminder Time ${index + 1} *',
                        ).copyWith(suffixIcon: const Icon(Icons.access_time)),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please select Time ${index + 1}';
                          }
                          return null;
                        },
                      ),
                    );
                  }),
                ),

                TextFormField(
                  controller: startDateController,
                  readOnly: true,
                  onTap: pickStartDate,
                  decoration: customInputDecoration(
                    'Start Date *',
                  ).copyWith(suffixIcon: const Icon(Icons.calendar_today)),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please choose start date';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: noteController,
                  maxLines: 4,
                  decoration: customInputDecoration('Notes'),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : addMedication,
                    child: isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add Medication'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
