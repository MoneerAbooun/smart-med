import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smart_med/models/drug_interaction_response.dart';

class DrugInteractionApiService {
  static const String _baseUrl = String.fromEnvironment(
    'DRUG_API_BASE_URL',
    defaultValue: 'http://192.168.1.101:8000',
  );

  Future<DrugInteractionResponse> compareDrugs({
    required String firstDrug,
    required String secondDrug,
  }) async {
    final first = firstDrug.trim();
    final second = secondDrug.trim();

    if (first.isEmpty || second.isEmpty) {
      throw Exception('Please enter both medicine names.');
    }

    final uri = Uri.parse('$_baseUrl/drug-interaction').replace(
      queryParameters: {
        'drug1': first,
        'drug2': second,
      },
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      return DrugInteractionResponse.fromJson(data);
    }

    if (response.statusCode == 400) {
      throw Exception('Please enter two valid different medicine names.');
    }

    if (response.statusCode == 404) {
      throw Exception('One or both medicines could not be matched.');
    }

    throw Exception(
      'Failed to load interaction result (status ${response.statusCode}).',
    );
  }
}
