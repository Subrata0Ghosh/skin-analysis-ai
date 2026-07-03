// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:auraskin_ai/models/user_profile.dart';
import 'package:auraskin_ai/models/skin_scan.dart';
import 'package:auraskin_ai/services/auth_service.dart';
import 'package:auraskin_ai/services/storage_service.dart';

// --- FAKES FOR GOOGLE SIGN IN ---

class FakeGoogleSignInAuthentication extends Fake implements GoogleSignInAuthentication {
  @override
  final String accessToken;
  @override
  final String idToken;
  FakeGoogleSignInAuthentication({required this.accessToken, required this.idToken});
}

class FakeGoogleSignInAccount extends Fake implements GoogleSignInAccount {
  final FakeGoogleSignInAuthentication _auth;
  @override
  final String email;
  @override
  final String displayName;
  @override
  final String id;

  FakeGoogleSignInAccount({
    required this.email,
    required this.displayName,
    required this.id,
    required FakeGoogleSignInAuthentication auth,
  })  : _auth = auth;

  @override
  Future<GoogleSignInAuthentication> get authentication async => _auth;
}

class FakeGoogleSignIn extends Fake implements GoogleSignIn {
  final GoogleSignInAccount? _mockAccount;
  FakeGoogleSignIn({GoogleSignInAccount? mockAccount}) : _mockAccount = mockAccount;

  @override
  Future<GoogleSignInAccount?> signIn() async => _mockAccount;

  @override
  Future<GoogleSignInAccount?> signOut() async => null;
}

// --- FAKES FOR FIREBASE AUTH ---

class FakeUser extends Fake implements firebase.User {
  @override
  final String uid;
  @override
  String? displayName;
  @override
  final String email;

  FakeUser({required this.uid, this.displayName, required this.email});

  @override
  Future<void> updateDisplayName(String? name) async {
    displayName = name;
  }
}

class FakeUserCredential extends Fake implements firebase.UserCredential {
  @override
  final firebase.User? user;
  FakeUserCredential({this.user});
}

class FakeFirebaseAuth extends Fake implements firebase.FirebaseAuth {
  FakeUser? _currentUser;
  final bool _throwOnSignIn;

  FakeFirebaseAuth({FakeUser? currentUser, bool throwOnSignIn = false})
      : _currentUser = currentUser,
        _throwOnSignIn = throwOnSignIn;

  @override
  firebase.User? get currentUser => _currentUser;

  @override
  Future<firebase.UserCredential> signInWithCredential(firebase.AuthCredential credential) async {
    if (_throwOnSignIn) {
      throw firebase.FirebaseAuthException(code: 'sign-in-failed', message: 'Mock sign-in failed');
    }
    return FakeUserCredential(user: _currentUser);
  }

  @override
  Future<firebase.UserCredential> signInWithEmailAndPassword({required String email, required String password}) async {
    if (_throwOnSignIn) {
      throw firebase.FirebaseAuthException(code: 'login-failed', message: 'Mock login failed');
    }
    return FakeUserCredential(user: _currentUser);
  }

  @override
  Future<firebase.UserCredential> createUserWithEmailAndPassword({required String email, required String password}) async {
    if (_throwOnSignIn) {
      throw firebase.FirebaseAuthException(code: 'signup-failed', message: 'Mock signup failed');
    }
    return FakeUserCredential(user: _currentUser);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }
}

// --- FAKES FOR CLOUD FIRESTORE ---

class FakeDocumentSnapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? _data;
  @override
  final bool exists;

  FakeDocumentSnapshot(this._data) : exists = _data != null;

  @override
  Map<String, dynamic>? data() => _data;
}

class FakeDocumentReference extends Fake implements DocumentReference<Map<String, dynamic>> {
  final String _id;
  final Map<String, Map<String, dynamic>> _storage;
  final String _path;

  FakeDocumentReference(this._id, this._storage, this._path);

  @override
  String get id => _id;

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    _storage[_path] = data;
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    return FakeDocumentSnapshot(_storage[_path]);
  }

  @override
  Future<void> delete() async {
    _storage.remove(_path);
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return FakeCollectionReference(_storage, '$_path/$collectionPath');
  }
}

class FakeQueryDocumentSnapshot extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic> _data;
  @override
  final DocumentReference<Map<String, dynamic>> reference;

  FakeQueryDocumentSnapshot(this._data, this.reference);

  @override
  Map<String, dynamic> data() => _data;
}

class FakeQuerySnapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  FakeQuerySnapshot(this.docs);
}

class FakeCollectionReference extends Fake implements CollectionReference<Map<String, dynamic>> {
  final Map<String, Map<String, dynamic>> _storage;
  final String _path;

  FakeCollectionReference(this._storage, this._path);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    final docId = path ?? 'auto_id';
    return FakeDocumentReference(docId, _storage, '$_path/$docId');
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    _storage.forEach((key, value) {
      final pathParts = _path.split('/');
      final keyParts = key.split('/');
      if (key.startsWith('$_path/') && keyParts.length == pathParts.length + 1) {
        final docId = keyParts.last;
        final docRef = FakeDocumentReference(docId, _storage, key);
        docs.add(FakeQueryDocumentSnapshot(value, docRef));
      }
    });
    return FakeQuerySnapshot(docs);
  }

  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) {
    return FakeQuery(_storage, _path, field as String, descending);
  }
}

class FakeQuery extends Fake implements Query<Map<String, dynamic>> {
  final Map<String, Map<String, dynamic>> _storage;
  final String _path;
  final String _orderByField;
  final bool _descending;

  FakeQuery(this._storage, this._path, this._orderByField, this._descending);

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final docsList = <Map<String, dynamic>>[];
    _storage.forEach((key, value) {
      final pathParts = _path.split('/');
      final keyParts = key.split('/');
      if (key.startsWith('$_path/') && keyParts.length == pathParts.length + 1) {
        // Keep trace of key and id for reference creation
        final copy = Map<String, dynamic>.from(value);
        copy['_doc_key_path'] = key;
        copy['_doc_key_id'] = keyParts.last;
        docsList.add(copy);
      }
    });

    // Sort descending or ascending
    docsList.sort((a, b) {
      final valA = a[_orderByField];
      final valB = b[_orderByField];
      if (valA == null || valB == null) return 0;
      if (valA is Comparable && valB is Comparable) {
        if (_descending) {
          return valB.compareTo(valA);
        } else {
          return valA.compareTo(valB);
        }
      }
      return 0;
    });

    final queryDocs = docsList.map((item) {
      final keyPath = item.remove('_doc_key_path') as String;
      final keyId = item.remove('_doc_key_id') as String;
      final docRef = FakeDocumentReference(keyId, _storage, keyPath);
      return FakeQueryDocumentSnapshot(item, docRef) as QueryDocumentSnapshot<Map<String, dynamic>>;
    }).toList();
    return FakeQuerySnapshot(queryDocs);
  }
}

class FakeFirebaseFirestore extends Fake implements FirebaseFirestore {
  final Map<String, Map<String, dynamic>> storage = {};

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return FakeCollectionReference(storage, collectionPath);
  }
}

// --- MAIN TESTS ---

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.isFirebaseInitialized = false;
  });

  group('Google Authentication Tests', () {
    test('Google Sign-In success path', () async {
      AuthService.isFirebaseInitialized = true;

      final testUser = FakeUser(uid: 'google_uid_123', displayName: 'Test Google User', email: 'google@test.com');
      final fakeAuth = FakeFirebaseAuth(currentUser: testUser);

      final fakeAuthCred = FakeGoogleSignInAuthentication(accessToken: 'access_123', idToken: 'id_123');
      final fakeGoogleUser = FakeGoogleSignInAccount(
        email: 'google@test.com',
        displayName: 'Test Google User',
        id: 'google_user_id_123',
        auth: fakeAuthCred,
      );
      final fakeGoogleSignIn = FakeGoogleSignIn(mockAccount: fakeGoogleUser);

      final authService = AuthService(firebaseAuth: fakeAuth, googleSignIn: fakeGoogleSignIn);
      await authService.initialization;

      final success = await authService.signInWithGoogle();

      expect(success, isTrue);
      expect(authService.isLoggedIn, isTrue);
      expect(authService.currentUid, 'google_uid_123');
      expect(authService.currentUserName, 'Test Google User');
      expect(authService.isDemoMode, isFalse);
    });

    test('Google Sign-In cancellation path', () async {
      AuthService.isFirebaseInitialized = true;

      final fakeAuth = FakeFirebaseAuth();
      final fakeGoogleSignIn = FakeGoogleSignIn(mockAccount: null); // Null simulates user cancellation

      final authService = AuthService(firebaseAuth: fakeAuth, googleSignIn: fakeGoogleSignIn);
      await authService.initialization;

      final success = await authService.signInWithGoogle();

      expect(success, isFalse);
      expect(authService.isLoggedIn, isFalse);
    });

    test('Google Sign-In failure fallback path', () async {
      AuthService.isFirebaseInitialized = true;

      // Force FirebaseAuth to fail on signInWithCredential
      final fakeAuth = FakeFirebaseAuth(throwOnSignIn: true);

      final fakeAuthCred = FakeGoogleSignInAuthentication(accessToken: 'access_123', idToken: 'id_123');
      final fakeGoogleUser = FakeGoogleSignInAccount(
        email: 'google@test.com',
        displayName: 'Test Google User',
        id: 'google_user_id_123',
        auth: fakeAuthCred,
      );
      final fakeGoogleSignIn = FakeGoogleSignIn(mockAccount: fakeGoogleUser);

      final authService = AuthService(firebaseAuth: fakeAuth, googleSignIn: fakeGoogleSignIn);
      await authService.initialization;

      final success = await authService.signInWithGoogle();

      // Returns true due to mock fallback mechanism
      expect(success, isTrue);
      expect(authService.isLoggedIn, isTrue);
      expect(authService.currentUid, 'google_mock_uid_123');
      expect(authService.currentUserName, 'Google Guest');
      expect(authService.isDemoMode, isTrue);
    });

    test('Sign in as Guest path', () async {
      final fakeAuth = FakeFirebaseAuth();
      final authService = AuthService(firebaseAuth: fakeAuth);
      await authService.initialization;

      final success = await authService.signInAsGuest();

      expect(success, isTrue);
      expect(authService.isLoggedIn, isTrue);
      expect(authService.currentUid, startsWith('guest_uid_'));
      expect(authService.currentUserName, 'Guest User');
      expect(authService.isDemoMode, isTrue);
    });

    test('Email Sign-Up success path', () async {
      AuthService.isFirebaseInitialized = true;
      final testUser = FakeUser(uid: 'real_uid_456', displayName: 'Jane Doe', email: 'jane@test.com');
      final fakeAuth = FakeFirebaseAuth(currentUser: testUser);
      final authService = AuthService(firebaseAuth: fakeAuth);
      await authService.initialization;

      final success = await authService.signUp('jane@test.com', 'jane_password_456', 'Jane Doe');

      expect(success, isTrue);
      expect(authService.isLoggedIn, isTrue);
      expect(authService.currentUid, 'real_uid_456');
      expect(authService.currentUserName, 'Jane Doe');
      expect(authService.isDemoMode, isFalse);
    });

    test('Email Sign-Up error rethrowing path', () async {
      AuthService.isFirebaseInitialized = true;
      final fakeAuth = FakeFirebaseAuth(throwOnSignIn: true);
      final authService = AuthService(firebaseAuth: fakeAuth);
      await authService.initialization;

      expect(
        () => authService.signUp('jane@test.com', 'jane_password_456', 'Jane Doe'),
        throwsA(isA<firebase.FirebaseAuthException>()),
      );
    });

    test('Email Login success path', () async {
      AuthService.isFirebaseInitialized = true;
      final testUser = FakeUser(uid: 'real_uid_456', displayName: 'Jane Doe', email: 'jane@test.com');
      final fakeAuth = FakeFirebaseAuth(currentUser: testUser);
      final authService = AuthService(firebaseAuth: fakeAuth);
      await authService.initialization;

      final success = await authService.login('jane@test.com', 'jane_password_456');

      expect(success, isTrue);
      expect(authService.isLoggedIn, isTrue);
      expect(authService.currentUid, 'real_uid_456');
      expect(authService.isDemoMode, isFalse);
    });

    test('Email Login error rethrowing path', () async {
      AuthService.isFirebaseInitialized = true;
      final fakeAuth = FakeFirebaseAuth(throwOnSignIn: true);
      final authService = AuthService(firebaseAuth: fakeAuth);
      await authService.initialization;

      expect(
        () => authService.login('jane@test.com', 'jane_password_456'),
        throwsA(isA<firebase.FirebaseAuthException>()),
      );
    });

    test('Email Login backdoor / demo path', () async {
      AuthService.isFirebaseInitialized = true;
      final fakeAuth = FakeFirebaseAuth(throwOnSignIn: true); // Firebase throws but it should bypass due to backdoor
      final authService = AuthService(firebaseAuth: fakeAuth);
      await authService.initialization;

      final success = await authService.login('demo@auraskin.ai', 'password123');

      expect(success, isTrue);
      expect(authService.isLoggedIn, isTrue);
      expect(authService.currentUid, startsWith('mock_uid_'));
      expect(authService.currentUserName, 'Demo User');
      expect(authService.isDemoMode, isTrue);
    });
  });

  group('Firebase Firestore Database Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late StorageService storageService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      storageService = StorageService(true, firestore: fakeFirestore);
    });

    test('Save and Get User Profile in Firestore', () async {
      final profile = UserProfile(
        uid: 'user_999',
        name: 'Jane Doe',
        age: 28,
        gender: 'Female',
        skinType: 'Oily',
        primaryConcerns: ['Oily Skin', 'Acne'],
        goals: ['Minimize pores'],
        knownSensitivities: 'Fragrance',
        notifications: {'scan': true},
      );

      await storageService.saveUserProfile(profile);

      // Verify stored internally in mock database path
      expect(fakeFirestore.storage.containsKey('users/user_999'), isTrue);

      final retrieved = await storageService.getUserProfile('user_999');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'Jane Doe');
      expect(retrieved.skinType, 'Oily');
      expect(retrieved.primaryConcerns, contains('Acne'));
    });

    test('Save, Get List (sorted), and Delete Skin Scans in Firestore', () async {
      final scan1 = SkinScan(
        id: 'scan_1',
        uid: 'user_999',
        dateTime: DateTime(2026, 7, 1),
        imagePath: 'assets/scan1.png',
        overallScore: 80,
        skinAge: 26,
        skinType: 'Dry',
        detailScores: {},
        issues: [],
        recommendations: [],
        symmetryScore: 90.0,
        verticalThirds: [0.33, 0.33, 0.34],
        jawlineAngle: 120.0,
        cheekboneSymmetry: 90.0,
      );

      final scan2 = SkinScan(
        id: 'scan_2',
        uid: 'user_999',
        dateTime: DateTime(2026, 7, 3), // Later scan
        imagePath: 'assets/scan2.png',
        overallScore: 85,
        skinAge: 25,
        skinType: 'Normal',
        detailScores: {},
        issues: [],
        recommendations: [],
        symmetryScore: 90.0,
        verticalThirds: [0.33, 0.33, 0.34],
        jawlineAngle: 120.0,
        cheekboneSymmetry: 90.0,
      );

      await storageService.saveSkinScan(scan1);
      await storageService.saveSkinScan(scan2);

      // Verify scans stored in subcollection paths
      expect(fakeFirestore.storage.containsKey('users/user_999/scans/scan_1'), isTrue);
      expect(fakeFirestore.storage.containsKey('users/user_999/scans/scan_2'), isTrue);

      // Retrieve scans - should be sorted descending by dateTime
      final list = await storageService.getSkinScans('user_999');
      expect(list.length, 2);
      expect(list[0].id, 'scan_2'); // More recent scan first
      expect(list[1].id, 'scan_1');

      // Delete one scan
      await storageService.deleteSkinScan('user_999', 'scan_1');
      expect(fakeFirestore.storage.containsKey('users/user_999/scans/scan_1'), isFalse);
      expect(fakeFirestore.storage.containsKey('users/user_999/scans/scan_2'), isTrue);
    });

    test('Wipe User Data in Firestore', () async {
      final profile = UserProfile(uid: 'user_wipe', name: 'Wipe Me', age: 30, gender: 'Other', skinType: 'Dry', primaryConcerns: [], goals: [], knownSensitivities: '', notifications: {});
      final scan = SkinScan(id: 'scan_wipe', uid: 'user_wipe', dateTime: DateTime.now(), imagePath: '', overallScore: 70, skinAge: 30, skinType: '', detailScores: {}, issues: [], recommendations: [], symmetryScore: 90.0, verticalThirds: [0.33, 0.33, 0.34], jawlineAngle: 120.0, cheekboneSymmetry: 90.0);

      await storageService.saveUserProfile(profile);
      await storageService.saveSkinScan(scan);

      expect(fakeFirestore.storage.containsKey('users/user_wipe'), isTrue);
      expect(fakeFirestore.storage.containsKey('users/user_wipe/scans/scan_wipe'), isTrue);

      await storageService.wipeUserData('user_wipe');

      // Verify both main document and nested subcollection scans are wiped
      expect(fakeFirestore.storage.containsKey('users/user_wipe'), isFalse);
      expect(fakeFirestore.storage.containsKey('users/user_wipe/scans/scan_wipe'), isFalse);
    });
  });
}
