import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/skin_scan.dart';

class StorageService {
  final bool _isFirebaseEnabled;
  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  StorageService(this._isFirebaseEnabled, {FirebaseFirestore? firestore})
      : _firestore = firestore;

  // User profile storage
  Future<void> saveUserProfile(UserProfile profile) async {
    if (_isFirebaseEnabled) {
      try {
        await _db
            .collection('users')
            .doc(profile.uid)
            .set(profile.toMap());
        return;
      } catch (e) {
        debugPrint("Firebase error saving user profile: $e");
      }
    }
    
    // Fallback to local SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_${profile.uid}', jsonEncode(profile.toMap()));
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    if (_isFirebaseEnabled) {
      try {
        final doc = await _db.collection('users').doc(uid).get();
        if (doc.exists && doc.data() != null) {
          return UserProfile.fromMap(doc.data()!);
        }
      } catch (e) {
        debugPrint("Firebase error getting user profile: $e");
      }
    }
    
    // Fallback to local SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('profile_$uid');
    if (data != null) {
      try {
        return UserProfile.fromMap(jsonDecode(data));
      } catch (e) {
        debugPrint("Error parsing cached profile: $e");
      }
    }
    return null;
  }

  // Scan storage
  Future<void> saveSkinScan(SkinScan scan) async {
    if (_isFirebaseEnabled) {
      try {
        await _db
            .collection('users')
            .doc(scan.uid)
            .collection('scans')
            .doc(scan.id)
            .set(scan.toMap());
        return;
      } catch (e) {
        debugPrint("Firebase error saving skin scan: $e");
      }
    }
    
    // Fallback to local SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final scansKey = 'scans_${scan.uid}';
    final existingScans = prefs.getStringList(scansKey) ?? [];
    
    // Remove if duplicate ID exists
    existingScans.removeWhere((element) {
      try {
        final map = jsonDecode(element);
        return map['id'] == scan.id;
      } catch (e) {
        return false;
      }
    });

    existingScans.add(jsonEncode(scan.toMap()));
    await prefs.setStringList(scansKey, existingScans);
  }

  Future<List<SkinScan>> getSkinScans(String uid) async {
    if (_isFirebaseEnabled) {
      try {
        final query = await _db
            .collection('users')
            .doc(uid)
            .collection('scans')
            .orderBy('dateTime', descending: true)
            .get();
        return query.docs.map((doc) => SkinScan.fromMap(doc.data())).toList();
      } catch (e) {
        debugPrint("Firebase error getting skin scans: $e");
      }
    }
    
    // Fallback to local SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final scansKey = 'scans_$uid';
    final existingScans = prefs.getStringList(scansKey) ?? [];
    
    final list = existingScans.map((e) {
      try {
        return SkinScan.fromMap(jsonDecode(e));
      } catch (err) {
        debugPrint("Error decoding scan record: $err");
        return null;
      }
    }).whereType<SkinScan>().toList();
    
    // Sort descending by date
    list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return list;
  }

  Future<void> deleteSkinScan(String uid, String scanId) async {
    if (_isFirebaseEnabled) {
      try {
        await _db
            .collection('users')
            .doc(uid)
            .collection('scans')
            .doc(scanId)
            .delete();
        return;
      } catch (e) {
        debugPrint("Firebase error deleting skin scan: $e");
      }
    }
    
    // Fallback to local SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final scansKey = 'scans_$uid';
    final existingScans = prefs.getStringList(scansKey) ?? [];
    existingScans.removeWhere((element) {
      try {
        final map = jsonDecode(element);
        return map['id'] == scanId;
      } catch (e) {
        return false;
      }
    });
    await prefs.setStringList(scansKey, existingScans);
  }

  Future<void> wipeUserData(String uid) async {
    if (_isFirebaseEnabled) {
      try {
        // Delete Firestore scans
        final scans = await _db
            .collection('users')
            .doc(uid)
            .collection('scans')
            .get();
        for (var doc in scans.docs) {
          await doc.reference.delete();
        }
        // Delete User doc
        await _db.collection('users').doc(uid).delete();
      } catch (e) {
        debugPrint("Firebase error wiping user data: $e");
      }
    }
    
    // Local data wipe
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profile_$uid');
    await prefs.remove('scans_$uid');
  }
}
