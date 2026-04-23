class DrugAlternativeItem {
  final String name;
  final String? rxcui;
  final String? termType;
  final String category;

  const DrugAlternativeItem({
    required this.name,
    required this.rxcui,
    required this.termType,
    required this.category,
  });

  factory DrugAlternativeItem.fromJson(Map<String, dynamic> json) {
    return DrugAlternativeItem(
      name: (json['name'] ?? '').toString(),
      rxcui: json['rxcui']?.toString(),
      termType: json['term_type']?.toString(),
      category: (json['category'] ?? 'Alternative').toString(),
    );
  }
}

class DrugAlternativesResponse {
  final String query;
  final String? matchedName;
  final String? genericName;
  final List<String> activeIngredients;
  final List<DrugAlternativeItem> alternatives;
  final List<String> notes;
  final String source;
  final String? rxcui;
  final String? setId;

  const DrugAlternativesResponse({
    required this.query,
    required this.matchedName,
    required this.genericName,
    required this.activeIngredients,
    required this.alternatives,
    required this.notes,
    required this.source,
    required this.rxcui,
    required this.setId,
  });

  factory DrugAlternativesResponse.fromJson(Map<String, dynamic> json) {
    List<String> toStringList(dynamic value) {
      if (value is List) {
        return value.map((item) => item.toString()).toList();
      }
      return <String>[];
    }

    List<DrugAlternativeItem> toAlternativeList(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map<String, dynamic>>()
            .map(DrugAlternativeItem.fromJson)
            .toList();
      }
      return <DrugAlternativeItem>[];
    }

    return DrugAlternativesResponse(
      query: (json['query'] ?? '').toString(),
      matchedName: json['matched_name']?.toString(),
      genericName: json['generic_name']?.toString(),
      activeIngredients: toStringList(json['active_ingredients']),
      alternatives: toAlternativeList(json['alternatives']),
      notes: toStringList(json['notes']),
      source: (json['source'] ?? '').toString(),
      rxcui: json['rxcui']?.toString(),
      setId: json['set_id']?.toString(),
    );
  }
}
