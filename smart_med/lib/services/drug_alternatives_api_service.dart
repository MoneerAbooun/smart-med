import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smart_med/models/drug_alternatives_response.dart';

class DrugAlternativesApiService {
  static const String _baseUrl = String.fromEnvironment(
    'DRUG_API_BASE_URL',
    defaultValue: 'http://192.168.1.101:8000',
  );

  Future<DrugAlternativesResponse> fetchDrugAlternatives(
    String drugName,
  ) async {
    final trimmedName = drugName.trim();

    if (trimmedName.isEmpty) {
      throw Exception('Drug name is required.');
    }

    final uri = Uri.parse(
      '$_baseUrl/drug-alternatives',
    ).replace(queryParameters: {'name': trimmedName});

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      return DrugAlternativesResponse.fromJson(data);
    }

    if (response.statusCode == 404) {
      throw Exception('No alternatives found for "$trimmedName".');
    }

    if (response.statusCode == 400) {
      throw Exception('Please enter a valid medicine name.');
    }

    throw Exception(
      'Failed to load alternatives (status ${response.statusCode}).',
    );
  }
}
