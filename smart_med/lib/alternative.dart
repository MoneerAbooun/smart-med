import 'package:flutter/material.dart';
import 'package:smart_med/drug_detail.dart';
import 'package:smart_med/models/drug_alternatives_response.dart';
import 'package:smart_med/services/drug_alternatives_api_service.dart';

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
  final DrugAlternativesApiService _alternativesApiService =
      DrugAlternativesApiService();

  late TextEditingController searchController;

  bool hasSearched = false;
  bool isLoading = false;
  String? errorMessage;
  DrugAlternativesResponse? result;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController(text: widget.searchedDrugName);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final query = widget.searchedDrugName.trim();
      final hasImage = widget.imagePath != null && widget.imagePath!.isNotEmpty;

      if (query.isNotEmpty) {
        searchMedicine();
      } else if (hasImage && mounted) {
        setState(() {
          hasSearched = true;
          errorMessage =
              'Image-only lookup is not connected yet. Please type the medicine name to fetch real alternatives.';
        });
      }
    });
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
      errorMessage = null;
      result = null;
    });

    try {
      final alternatives = await _alternativesApiService.fetchDrugAlternatives(
        query,
      );

      if (!mounted) return;

      setState(() {
        result = alternatives;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  String _normalizeText(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<String> _cleanSectionItems(List<String> rawItems, {int maxItems = 6}) {
    if (rawItems.isEmpty) return [];

    final combined = _normalizeText(rawItems.join(' '));

    final parts = combined
        .split(RegExp(r'(?<=[.;:])\s+'))
        .map(_normalizeText)
        .where((item) => item.isNotEmpty)
        .toList();

    final cleaned = <String>[];
    final seen = <String>{};

    for (final item in parts) {
      final lower = item.toLowerCase();

      if (item.length < 3) continue;
      if (seen.contains(lower)) continue;

      seen.add(lower);
      cleaned.add(item);

      if (cleaned.length >= maxItems) break;
    }

    return cleaned;
  }

  String _displayDrugName() {
    final matchedName = result?.matchedName?.trim();
    final searchedName = searchController.text.trim();

    if (matchedName != null && matchedName.isNotEmpty) {
      return matchedName;
    }

    if (searchedName.isNotEmpty) {
      return searchedName;
    }

    return 'Medicine Alternatives';
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayDrugName(),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        result == null
                            ? 'Find related brands and generic products.'
                            : 'Source: ${result!.source}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (result?.rxcui != null &&
                          result!.rxcui!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'RXCUI: ${result!.rxcui!}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget buildAlternativesContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return _StatusBox(
        icon: Icons.error_outline,
        title: 'Unable to load alternatives',
        message: errorMessage!,
        buttonText: 'Retry',
        onPressed: searchMedicine,
      );
    }

    if (!hasSearched) {
      return Text(
        'Search for a medicine to show its alternatives.',
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 15),
      );
    }

    final alternatives = result?.alternatives ?? [];

    if (alternatives.isEmpty) {
      return Text(
        'No alternatives available.',
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 15),
      );
    }

    return Column(
      children: alternatives
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AlternativeTile(
                item: item,
                onDetailsPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DrugDetailPage(
                        searchedDrugName: item.name,
                      ),
                    ),
                  );
                },
              ),
            ),
          )
          .toList(),
    );
  }

  Widget buildTextListBox(
    BuildContext context, {
    required List<String> items,
    required String fallback,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final visibleItems = _cleanSectionItems(items);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: visibleItems.isEmpty
          ? Text(
              fallback,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: visibleItems
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('- '),
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
                  )
                  .toList(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeIngredients = result?.activeIngredients ?? [];
    final notes = result?.notes ?? [];

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
                  child: buildTextListBox(
                    context,
                    items: activeIngredients,
                    fallback: !hasSearched
                        ? 'The active ingredient will appear here.'
                        : 'No active ingredient available.',
                  ),
                ),
                const SizedBox(height: 14),
                buildSection(
                  context: context,
                  title: 'Notes',
                  icon: Icons.info_outline_rounded,
                  child: buildTextListBox(
                    context,
                    items: notes,
                    fallback: !hasSearched
                        ? 'Important notes about the medicine will appear here.'
                        : 'No notes available.',
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

class _AlternativeTile extends StatelessWidget {
  final DrugAlternativeItem item;
  final VoidCallback onDetailsPressed;

  const _AlternativeTile({
    required this.item,
    required this.onDetailsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.local_pharmacy_outlined,
            color: colorScheme.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.termType == null || item.termType!.isEmpty
                      ? item.category
                      : '${item.category} | ${item.termType}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (item.rxcui != null && item.rxcui!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'RXCUI: ${item.rxcui}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onDetailsPressed,
            tooltip: 'View details',
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback onPressed;

  const _StatusBox({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onPressed, child: Text(buttonText)),
        ],
      ),
    );
  }
}
