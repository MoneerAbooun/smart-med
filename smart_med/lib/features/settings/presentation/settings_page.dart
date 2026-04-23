import 'package:flutter/material.dart';
import 'package:smart_med/core/services/notification_service.dart';
import 'package:smart_med/features/ai/ai.dart';
import 'package:smart_med/features/auth/auth.dart';
import 'package:smart_med/features/medications/medications.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback onEditProfileTap;
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;

  const SettingsPage({
    super.key,
    required this.onEditProfileTap,
    required this.isDark,
    required this.onThemeChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool notificationsEnabled = true;
  bool simpleLanguageMode = true;
  bool showSaferUseTips = true;
  bool showQuestionsForClinician = true;
  bool showEvidenceByDefault = false;

  @override
  void initState() {
    super.initState();
    _loadAiPreferences();
  }

  Future<void> _loadAiPreferences() async {
    final preferences = await aiPreferencesRepository.loadPreferences();
    if (!mounted) {
      return;
    }

    setState(() {
      simpleLanguageMode = preferences.simpleLanguageMode;
      showSaferUseTips = preferences.showSaferUseTips;
      showQuestionsForClinician = preferences.showQuestionsForClinician;
      showEvidenceByDefault = preferences.showEvidenceByDefault;
    });
  }

  Widget buildSettingItem({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Icon(icon, color: colorScheme.onSurface),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        trailing:
            trailing ??
            Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
        onTap: onTap,
      ),
    );
  }

  void showSimpleDialogBox(String title, String content) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        );
      },
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
              "Settings",
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 25,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          "Settings",
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      buildSettingItem(
                        icon: Icons.person_outline,
                        title: "Edit Profile",
                        onTap: widget.onEditProfileTap,
                      ),
                      buildSettingItem(
                        icon: widget.isDark
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                        title: "Dark Mode",
                        trailing: Switch(
                          value: widget.isDark,
                          onChanged: widget.onThemeChanged,
                        ),
                      ),
                      buildSettingItem(
                        icon: Icons.notifications_none,
                        title: "Notification Settings",
                        trailing: Switch(
                          value: notificationsEnabled,
                          onChanged: (value) async {
                            if (value) {
                              final granted =
                                  await NotificationService.requestPermission();

                              if (!granted) {
                                if (!context.mounted) return;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Notification permission denied',
                                    ),
                                  ),
                                );

                                setState(() {
                                  notificationsEnabled = false;
                                });
                                return;
                              }

                              await NotificationService.showInstantNotification(
                                title: 'Smart Med',
                                body: 'This is a test notification',
                              );

                              if (!context.mounted) return;

                              setState(() {
                                notificationsEnabled = true;
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Test notification sent'),
                                ),
                              );
                            } else {
                              setState(() {
                                notificationsEnabled = false;
                              });

                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Notifications turned off'),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      buildSettingItem(
                        icon: Icons.auto_awesome_outlined,
                        title: "Simple Language Mode",
                        trailing: Switch(
                          value: simpleLanguageMode,
                          onChanged: (value) async {
                            await aiPreferencesRepository.setSimpleLanguageMode(
                              value,
                            );
                            if (!mounted) return;
                            setState(() {
                              simpleLanguageMode = value;
                            });
                          },
                        ),
                      ),
                      buildSettingItem(
                        icon: Icons.shield_outlined,
                        title: "Show Safer Use Tips",
                        trailing: Switch(
                          value: showSaferUseTips,
                          onChanged: (value) async {
                            await aiPreferencesRepository.setShowSaferUseTips(
                              value,
                            );
                            if (!mounted) return;
                            setState(() {
                              showSaferUseTips = value;
                            });
                          },
                        ),
                      ),
                      buildSettingItem(
                        icon: Icons.help_outline,
                        title: "Show Clinician Questions",
                        trailing: Switch(
                          value: showQuestionsForClinician,
                          onChanged: (value) async {
                            await aiPreferencesRepository
                                .setShowQuestionsForClinician(value);
                            if (!mounted) return;
                            setState(() {
                              showQuestionsForClinician = value;
                            });
                          },
                        ),
                      ),
                      buildSettingItem(
                        icon: Icons.dataset_outlined,
                        title: "Show Evidence By Default",
                        trailing: Switch(
                          value: showEvidenceByDefault,
                          onChanged: (value) async {
                            await aiPreferencesRepository
                                .setShowEvidenceByDefault(value);
                            if (!mounted) return;
                            setState(() {
                              showEvidenceByDefault = value;
                            });
                          },
                        ),
                      ),
                      buildSettingItem(
                        icon: Icons.info_outline,
                        title: "About Us",
                        onTap: () {
                          showSimpleDialogBox(
                            "About Us",
                            "Smart Med is a smart medication assistant project that helps users manage medicines, reminders, and drug information.",
                          );
                        },
                      ),
                      buildSettingItem(
                        icon: Icons.contact_mail_outlined,
                        title: "Contact Us",
                        onTap: () {
                          showSimpleDialogBox(
                            "Contact Us",
                            "Email: smartmed@app.com\nPhone: +000 000 000 000",
                          );
                        },
                      ),
                      buildSettingItem(
                        icon: Icons.language,
                        title: "Language",
                        onTap: () {
                          showSimpleDialogBox(
                            "Language",
                            "Language setting will be added later.",
                          );
                        },
                      ),
                      buildSettingItem(
                        icon: Icons.help_outline,
                        title: "Help",
                        onTap: () {
                          showSimpleDialogBox(
                            "Help",
                            "This section will include help and FAQ later.",
                          );
                        },
                      ),
                      buildSettingItem(
                        icon: Icons.system_update_alt,
                        title: "App Version",
                        onTap: () {
                          showSimpleDialogBox(
                            "App Version",
                            "Smart Med v1.0.0",
                          );
                        },
                      ),
                      buildSettingItem(
                        icon: Icons.logout,
                        title: "Logout",
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Logout"),
                              content: const Text(
                                "Are you sure you want to logout?",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Logout"),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await authRepository.signOut();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
