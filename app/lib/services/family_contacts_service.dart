import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/family_contact.dart';
import 'supabase_auth_service.dart';

/// Service managing user's saved family member contacts.
class FamilyContactsService {
  FamilyContactsService._();
  static final FamilyContactsService instance = FamilyContactsService._();

  static const _key = 'saved_family_contacts_v1';

  /// Fetch all saved family contacts.
  Future<List<FamilyContact>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    List<FamilyContact> list = [];
    if (raw != null) {
      try {
        final List<dynamic> decoded = jsonDecode(raw);
        list = decoded.map((e) => FamilyContact.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    return list;
  }

  /// Add or update a family contact.
  Future<void> addContact(FamilyContact contact) async {
    final current = await getContacts();
    current.removeWhere((c) => c.phone == contact.phone || c.name.toLowerCase() == contact.name.toLowerCase());
    current.insert(0, contact);

    final prefs = await SharedPreferences.getInstance();
    final jsonList = current.map((c) => c.toJson()).toList();
    await prefs.setString(_key, jsonEncode(jsonList));

    // Optional database sync if Supabase is configured
    try {
      final client = SupabaseAuthService.instance.client;
      final userId = SupabaseAuthService.instance.currentUser?.id;
      if (client != null && userId != null) {
        await client.from('contacts').upsert({
          'id': contact.id,
          'user_id': userId,
          'name': contact.name,
          'phone': contact.phone,
          'channel': contact.channel,
        });
      }
    } catch (e) {
      debugPrint('FamilyContactsService.addContact: Supabase sync failed: $e');
    }
  }

  /// Delete a saved family contact.
  Future<void> deleteContact(String id) async {
    final current = await getContacts();
    current.removeWhere((c) => c.id == id);
    final prefs = await SharedPreferences.getInstance();
    final jsonList = current.map((c) => c.toJson()).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }
}
