import 'dart:convert';
import 'package:http/http.dart' as http;

class TimesheetService {
  // Remplacez par l'URL de votre app Heroku
  static const String baseUrl = 'https://arjolle-backend-3a069b6e3341.herokuapp.com/api';
  
  // Modèle de données
  static Map<String, dynamic> createTimesheetData({
    required String employeeId,
    required String employeeName,
    required String company,
    required DateTime date,
    required double hours,
    required double kilometers,
    required String reason,
  }) {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'company': company,
      'date': date.toIso8601String(),
      'hours': hours,
      'kilometers': kilometers,
      'reason': reason,
    };
  }

  // Soumettre les heures et kilométrage
  static Future<bool> submitTimesheet({
    required String employeeId,
    required String employeeName,
    required String company,
    required DateTime date,
    required double hours,
    required double kilometers,
    required String reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/timesheets'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(createTimesheetData(
          employeeId: employeeId,
          employeeName: employeeName,
          company: company,
          date: date,
          hours: hours,
          kilometers: kilometers,
          reason: reason,
        )),
      );
      return response.statusCode == 201;
    } catch (e) {
      print('Erreur lors de la soumission: $e');
      return false;
    }
  }

  // Récupérer les données d'un employé
  static Future<List<Map<String, dynamic>>> getEmployeeTimesheets(
    String employeeId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/timesheets?employeeId=$employeeId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      print('Erreur lors de la récupération: $e');
      return [];
    }
  }

  // Récupérer les données par entreprise
  static Future<List<Map<String, dynamic>>> getCompanyTimesheets(
    String company,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/timesheets?company=$company'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      print('Erreur lors de la récupération: $e');
      return [];
    }
  }

  // Obtenir les statistiques d'une entreprise
  static Future<Map<String, dynamic>?> getCompanyStats(String company) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stats/$company'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Erreur lors de la récupération des stats: $e');
      return null;
    }
  }

  // Modifier une entrée existante
  static Future<bool> updateTimesheet(
    String timesheetId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/timesheets/$timesheetId'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updates),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Erreur lors de la modification: $e');
      return false;
    }
  }

  // Supprimer une entrée
  static Future<bool> deleteTimesheet(String timesheetId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/timesheets/$timesheetId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Erreur lors de la suppression: $e');
      return false;
    }
  }
}
