import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_med/add_medication.dart';
import 'package:smart_med/firestore_service.dart';
import 'package:smart_med/medication_list.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<Profile> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();

  final TextEditingController newDiseaseController = TextEditingController();
  final TextEditingController newAllergyController = TextEditingController();

  final TextEditingController weightController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController systolicPressureController =
      TextEditingController();
  final TextEditingController diastolicPressureController =
      TextEditingController();
  final TextEditingController bloodGlucoseController = TextEditingController();

  final FirestoreService firestoreService = FirestoreService();

  bool isLoadingProfile = true;
  bool isEditing = false;

  List<String> chronicDiseases = [];
  List<String> drugAllergies = [];

  String biologicalSex = 'male';
  bool isPregnant = false;
  bool isBreastfeeding = false;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  String _valueToText(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  double? _parseDoubleOrNull(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  int? _parseIntOrNull(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned);
  }

  Future<void> loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() {
          isLoadingProfile = false;
        });
        return;
      }

      final data = await firestoreService.getUserProfile(uid: user.uid);

      if (data != null) {
        nameController.text = data['username'] ?? '';
        ageController.text = data['age']?.toString() ?? '';

        chronicDiseases = List<String>.from(data['chronicDiseases'] ?? []);
        drugAllergies = List<String>.from(data['drugAllergies'] ?? []);

        final medicalInfo = Map<String, dynamic>.from(
          data['medicalInfo'] ?? {},
        );

        weightController.text = _valueToText(medicalInfo['weightKg']);
        heightController.text = _valueToText(medicalInfo['heightCm']);
        systolicPressureController.text = _valueToText(
          medicalInfo['systolicPressure'],
        );
        diastolicPressureController.text = _valueToText(
          medicalInfo['diastolicPressure'],
        );
        bloodGlucoseController.text = _valueToText(medicalInfo['bloodGlucose']);

        final savedSex = (medicalInfo['biologicalSex'] ?? 'male')
            .toString()
            .toLowerCase();

        biologicalSex = savedSex == 'female' ? 'female' : 'male';
        isPregnant = medicalInfo['isPregnant'] == true;
        isBreastfeeding = medicalInfo['isBreastfeeding'] == true;

        if (biologicalSex != 'female') {
          isPregnant = false;
          isBreastfeeding = false;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to load profile')));
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoadingProfile = false;
        });
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    newDiseaseController.dispose();
    newAllergyController.dispose();
    weightController.dispose();
    heightController.dispose();
    systolicPressureController.dispose();
    diastolicPressureController.dispose();
    bloodGlucoseController.dispose();
    super.dispose();
  }

  void toggleEditMode() {
    setState(() {
      isEditing = !isEditing;
    });
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  void addDisease() {
    final disease = newDiseaseController.text.trim();

    if (disease.isEmpty) return;

    final alreadyExists = chronicDiseases.any(
      (item) => item.toLowerCase() == disease.toLowerCase(),
    );

    if (alreadyExists) {
      showMessage('This disease is already added');
      return;
    }

    setState(() {
      chronicDiseases.add(disease);
      newDiseaseController.clear();
    });
  }

  void removeDisease(int index) {
    if (!isEditing) return;

    setState(() {
      chronicDiseases.removeAt(index);
    });
  }

  void addAllergy() {
    final allergy = newAllergyController.text.trim();

    if (allergy.isEmpty) return;

    final alreadyExists = drugAllergies.any(
      (item) => item.toLowerCase() == allergy.toLowerCase(),
    );

    if (alreadyExists) {
      showMessage('This allergy is already added');
      return;
    }

    setState(() {
      drugAllergies.add(allergy);
      newAllergyController.clear();
    });
  }

  void removeAllergy(int index) {
    if (!isEditing) return;

    setState(() {
      drugAllergies.removeAt(index);
    });
  }

  Future<void> saveProfile() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final username = nameController.text.trim();
      final ageText = ageController.text.trim();

      if (username.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Please enter your name"),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      if (ageText.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Please enter your age"),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final age = int.tryParse(ageText);
      if (age == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Age must be a valid number"),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      if (age < 1 || age > 120) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Please enter a valid age"),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final medicalInfo = {
        'biologicalSex': biologicalSex,
        'weightKg': _parseDoubleOrNull(weightController.text),
        'heightCm': _parseDoubleOrNull(heightController.text),
        'systolicPressure': _parseIntOrNull(systolicPressureController.text),
        'diastolicPressure': _parseIntOrNull(diastolicPressureController.text),
        'bloodGlucose': _parseDoubleOrNull(bloodGlucoseController.text),
        'isPregnant': biologicalSex == 'female' ? isPregnant : false,
        'isBreastfeeding': biologicalSex == 'female' ? isBreastfeeding : false,
      };

      await firestoreService.updateUserProfile(
        uid: user.uid,
        username: username,
        age: age,
        chronicDiseases: chronicDiseases,
        drugAllergies: drugAllergies,
        medicalInfo: medicalInfo,
      );

      if (!mounted) return;

      setState(() {
        isEditing = false;
        isLoadingProfile = true;
      });

      await loadProfile();

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(
          content: Text("Profile data saved successfully"),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(
          content: Text("Failed to save profile data"),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  InputDecoration buildMedicalFieldDecoration(String label, IconData icon) {
    return InputDecoration(labelText: label, prefixIcon: Icon(icon));
  }

  Widget buildMedicalNumberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool allowDecimal = true,
  }) {
    return TextField(
      controller: controller,
      readOnly: !isEditing,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      decoration: buildMedicalFieldDecoration(label, icon),
    );
  }

  Widget buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(title),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }

  Widget buildChronicDiseasesSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Chronic diseases:",
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: newDiseaseController,
            readOnly: !isEditing,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (isEditing) {
                addDisease();
              }
            },
            decoration: InputDecoration(
              hintText: isEditing
                  ? "Enter disease name and press Enter"
                  : "Enable edit mode to add diseases",
              prefixIcon: const Icon(Icons.medical_information_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: chronicDiseases.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "No chronic diseases added",
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(chronicDiseases.length, (index) {
                      final disease = chronicDiseases[index];

                      return Chip(
                        label: Text(disease),
                        deleteIcon: isEditing
                            ? const Icon(Icons.close, size: 18)
                            : null,
                        onDeleted: isEditing
                            ? () => removeDisease(index)
                            : null,
                      );
                    }),
                  ),
          ),
        ],
      ),
    );
  }

  Widget buildDrugAllergiesSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Drug allergies:",
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            "Add medicines that may cause an allergic reaction for this patient.",
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: newAllergyController,
            readOnly: !isEditing,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (isEditing) {
                addAllergy();
              }
            },
            decoration: InputDecoration(
              hintText: isEditing
                  ? "Enter medicine allergy and press Enter"
                  : "Enable edit mode to add allergies",
              prefixIcon: const Icon(Icons.warning_amber_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: drugAllergies.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "No drug allergies added",
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(drugAllergies.length, (index) {
                      final allergy = drugAllergies[index];

                      return Chip(
                        label: Text(allergy),
                        deleteIcon: isEditing
                            ? const Icon(Icons.close, size: 18)
                            : null,
                        onDeleted: isEditing
                            ? () => removeAllergy(index)
                            : null,
                      );
                    }),
                  ),
          ),
        ],
      ),
    );
  }

  Widget buildMedicalInfoCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Patient Medical Info",
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            "These details help later in calculating a safer medication dose.",
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: biologicalSex,
            decoration: buildMedicalFieldDecoration(
              "Biological Sex",
              Icons.wc_outlined,
            ),
            items: const [
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
            ],
            onChanged: !isEditing
                ? null
                : (value) {
                    if (value == null) return;

                    setState(() {
                      biologicalSex = value;

                      if (biologicalSex != 'female') {
                        isPregnant = false;
                        isBreastfeeding = false;
                      }
                    });
                  },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: buildMedicalNumberField(
                  controller: weightController,
                  label: "Weight (kg)",
                  icon: Icons.monitor_weight_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildMedicalNumberField(
                  controller: heightController,
                  label: "Height (cm)",
                  icon: Icons.height_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: buildMedicalNumberField(
                  controller: systolicPressureController,
                  label: "Systolic Pressure",
                  icon: Icons.favorite_border,
                  allowDecimal: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildMedicalNumberField(
                  controller: diastolicPressureController,
                  label: "Diastolic Pressure",
                  icon: Icons.favorite_outline,
                  allowDecimal: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          buildMedicalNumberField(
            controller: bloodGlucoseController,
            label: "Blood Glucose",
            icon: Icons.bloodtype_outlined,
          ),
          if (biologicalSex == 'female') ...[
            const SizedBox(height: 8),
            buildSwitchTile(
              title: "Pregnant",
              value: isPregnant,
              onChanged: !isEditing
                  ? null
                  : (value) {
                      setState(() {
                        isPregnant = value;
                      });
                    },
            ),
            buildSwitchTile(
              title: "Breastfeeding",
              value: isBreastfeeding,
              onChanged: !isEditing
                  ? null
                  : (value) {
                      setState(() {
                        isBreastfeeding = value;
                      });
                    },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 70,
          title: const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              "Profile",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(top: 10, right: 8),
              child: IconButton(
                icon: const Icon(Icons.medication_outlined, size: 28),
                tooltip: 'Medications',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MedicationListPage(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        body: Center(
          child: isLoadingProfile
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 25,
                            ),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 35,
                                      backgroundColor:
                                          colorScheme.secondaryContainer,
                                      child: Icon(
                                        Icons.person_outline,
                                        size: 35,
                                        color: colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            TextField(
                                              controller: nameController,
                                              readOnly: !isEditing,
                                              decoration: const InputDecoration(
                                                hintText: "User Name",
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                filled: false,
                                              ),
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Row(
                                              children: [
                                                Text(
                                                  "Age: ",
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        colorScheme.onSurface,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: TextField(
                                                    controller: ageController,
                                                    readOnly: !isEditing,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    decoration:
                                                        const InputDecoration(
                                                          border:
                                                              InputBorder.none,
                                                          isDense: true,
                                                          contentPadding:
                                                              EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 2,
                                                              ),
                                                          filled: false,
                                                        ),
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          colorScheme.onSurface,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: toggleEditMode,
                                      icon: Icon(
                                        Icons.edit,
                                        color: colorScheme.onSurfaceVariant,
                                        size: 24,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 25),

                                buildChronicDiseasesSection(context),
                                const SizedBox(height: 25),

                                buildDrugAllergiesSection(context),
                                const SizedBox(height: 25),

                                buildMedicalInfoCard(context),
                                const SizedBox(height: 25),

                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const AddMedicationPage(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text("Add Medication"),
                                  ),
                                ),
                                const SizedBox(height: 25),

                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: isEditing ? saveProfile : null,
                                    style: ElevatedButton.styleFrom(
                                      disabledBackgroundColor:
                                          colorScheme.surfaceContainerHighest,
                                      disabledForegroundColor:
                                          colorScheme.onSurfaceVariant,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    child: const Text("Save"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
