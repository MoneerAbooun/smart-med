import 'package:flutter/material.dart';

class AlternativePage extends StatefulWidget {
  final String searchedDrugName;
  final String? imagePath;

  const AlternativePage({
    super.key,
    required this.searchedDrugName,
    this.imagePath,
  });

  @override
  State<AlternativePage> createState() => _AlternativePageState();
}

class _AlternativePageState extends State<AlternativePage> {
  late TextEditingController searchController;

  bool hasSearched = false;
  bool isLoading = false;

  List<String> alternatives = [];
  String activeIngredient = '';
  String notes = '';

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController(text: widget.searchedDrugName);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> searchMedicine() async {
    final query = searchController.text.trim();

    if (query.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a drug name')));
      return;
    }

    setState(() {
      hasSearched = true;
      isLoading = true;

      // مؤقتًا نخلي القيم فاضية
      // لاحقًا أنت اربطها مع Firebase / API / database
      alternatives = [];
      activeIngredient = '';
      notes = '';
    });

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  Widget buildTopCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
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
                    Icons.autorenew_rounded,
                    color: colorScheme.onSecondaryContainer,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Search for medicine alternatives, active ingredient, and important notes.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => searchMedicine(),
              decoration: const InputDecoration(
                labelText: 'Drug Name',
                prefixIcon: Icon(Icons.search),
                hintText: 'Enter medicine name',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : searchMedicine,
                icon: const Icon(Icons.search),
                label: Text(isLoading ? 'Searching...' : 'Search'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

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
              Icon(icon, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget buildAlternativesContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!hasSearched) {
      return Text(
        'Search for a medicine to show its alternatives.',
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 15),
      );
    }

    if (alternatives.isEmpty) {
      return Text(
        'No alternatives available.',
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 15),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: alternatives.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Text(
            item,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget buildTextBox(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          height: 1.4,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'Drug Alternatives',
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
                buildTopCard(context),
                const SizedBox(height: 16),

                buildSection(
                  context: context,
                  title: 'Alternatives',
                  icon: Icons.swap_horiz_rounded,
                  child: buildAlternativesContent(context),
                ),
                const SizedBox(height: 14),

                buildSection(
                  context: context,
                  title: 'Active Ingredient',
                  icon: Icons.science_outlined,
                  child: buildTextBox(
                    context,
                    !hasSearched
                        ? 'The active ingredient will appear here.'
                        : (activeIngredient.isEmpty
                              ? 'No active ingredient available.'
                              : activeIngredient),
                  ),
                ),
                const SizedBox(height: 14),

                buildSection(
                  context: context,
                  title: 'Notes',
                  icon: Icons.info_outline_rounded,
                  child: buildTextBox(
                    context,
                    !hasSearched
                        ? 'Important notes about the medicine will appear here.'
                        : (notes.isEmpty ? 'No notes available.' : notes),
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
