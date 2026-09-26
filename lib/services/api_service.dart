class ApiService {
  static const String baseUrl = 'http://localhost'; // Stub baseUrl

  Future<void> login(String email, String password) async {
    return;
  }

  Future<void> updatePin(String pin) async {
    return;
  }

  Future<dynamic> getTermsAndConditions() async {
    return null;
  }

  Future<dynamic> getBusinessTypes() async {
    return [];
  }

  Future<bool> updateBankAccount(int id, Map<String, dynamic> data) async {
    return true;
  }

  Future<bool> deleteBankAccount(int id) async {
    return true;
  }



  Future<List<dynamic>> getUserBusinesses() async {
    return [];
  }
}
