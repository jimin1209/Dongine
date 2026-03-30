import 'package:shared_preferences/shared_preferences.dart';

class FamilyPreferences {
  static const _selectedFamilyIdKey = 'selected_family_id';

  Future<String?> getSelectedFamilyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedFamilyIdKey);
  }

  Future<void> setSelectedFamilyId(String familyId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedFamilyIdKey, familyId);
  }

  Future<void> clearSelectedFamilyId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedFamilyIdKey);
  }
}
