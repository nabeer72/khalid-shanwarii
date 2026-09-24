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

  Future<dynamic> get(String path) async {
    return null;
  }
  


  Future<bool> updateBankAccount(int id, Map<String, dynamic> data) async {
    return true;
  }

  Future<bool> deleteBankAccount(int id) async {
    return true;
  }



  Future<dynamic> getDeletionRequestStatus() async {
    return null;
  }

  Future<dynamic> cancelDeletionRequest([dynamic data]) async {
    return null;
  }

  Future<dynamic> submitDeletionRequest(dynamic data) async {
    return null;
  }

  Future<bool> updateProfile(dynamic data) async {
    return true;
  }

  Future<bool> submitFeedback(dynamic data) async {
    return true;
  }
  
  Future<List<dynamic>> getUserBusinesses() async {
    return [];
  }
}
