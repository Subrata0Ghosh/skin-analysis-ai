class UserProfile {
  final String uid;
  final String name;
  final int age;
  final String gender;
  final String skinType; // oily, dry, combination, normal, sensitive
  final List<String> primaryConcerns; // acne, dark spots, dullness, wrinkles, redness
  final List<String> goals; // clearer skin, reduce acne, even skin tone, etc.
  final String knownSensitivities; // optional
  final Map<String, bool> notifications; // scan, routine, progress

  UserProfile({
    required this.uid,
    required this.name,
    required this.age,
    required this.gender,
    required this.skinType,
    required this.primaryConcerns,
    required this.goals,
    this.knownSensitivities = '',
    required this.notifications,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'age': age,
      'gender': gender,
      'skinType': skinType,
      'primaryConcerns': primaryConcerns,
      'goals': goals,
      'knownSensitivities': knownSensitivities,
      'notifications': notifications,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      age: map['age'] ?? 25,
      gender: map['gender'] ?? 'Other',
      skinType: map['skinType'] ?? 'Normal',
      primaryConcerns: List<String>.from(map['primaryConcerns'] ?? []),
      goals: List<String>.from(map['goals'] ?? []),
      knownSensitivities: map['knownSensitivities'] ?? '',
      notifications: Map<String, bool>.from(map['notifications']?.map(
            (k, v) => MapEntry<String, bool>(k, v as bool),
          ) ??
          {
            'scan': true,
            'routine': true,
            'progress': true,
          }),
    );
  }

  factory UserProfile.empty(String uid) {
    return UserProfile(
      uid: uid,
      name: '',
      age: 25,
      gender: 'Female',
      skinType: 'Normal',
      primaryConcerns: [],
      goals: [],
      knownSensitivities: '',
      notifications: {'scan': true, 'routine': true, 'progress': true},
    );
  }
}
