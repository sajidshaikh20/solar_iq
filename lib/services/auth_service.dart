import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import '../models/user_model.dart';
import '../models/api_response.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseService _dbService = FirebaseService();

  // Registration
  Future<ApiResponse<UserModel>> registerUser({
    required String name,
    required String email,
    required String password,
    required String phone,
    String plantCapacity = '',
    double? investmentAmount,
  }) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String uid = userCredential.user!.uid;
      final newUser = UserModel(
        uid: uid,
        name: name,
        email: email,
        phone: phone,
        role: 'user',
        plantCapacity: plantCapacity,
        updatedAt: DateTime.now(),
      );

      final result = await _dbService.saveUserProfile(newUser);
      if (result.success) {
        if (investmentAmount != null && investmentAmount > 0) {
          final units = 250.0; // default estimated monthly units
          final rate = 8.00;
          final saving = units * rate;
          final roiMonths = investmentAmount / saving;
          final paybackYear = DateTime.now().year + (roiMonths / 12).ceil();
          
          await _dbService.saveRoiData({
            'investment': investmentAmount,
            'dealRate': 0.0,
            'monthlyUnits': units,
            'unitRate': rate,
            'paybackYear': paybackYear,
            'paybackPeriod': roiMonths,
          });
        }
        return ApiResponse.success(newUser);
      } else {
        return ApiResponse.error(result.error);
      }
    } on FirebaseAuthException catch (e) {
      return ApiResponse.error(e.message ?? "Registration failed");
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Login
  Future<ApiResponse<User>> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        return ApiResponse.success(userCredential.user);
      }
      return ApiResponse.error("Login failed: User is null");
    } on FirebaseAuthException catch (e) {
      return ApiResponse.error(e.message ?? "Authentication failed");
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Reset Password / Forgot Password
  Future<ApiResponse<void>> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return ApiResponse.success(null);
    } on FirebaseAuthException catch (e) {
      return ApiResponse.error(e.message ?? "Password reset failed");
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Get current user profile
  Future<ApiResponse<UserModel>> getCurrentUserProfile() async {
    return await _dbService.getUserProfile();
  }

  // Stream for current user profile
  Stream<UserModel?> get userProfileStream {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    return _dbService.getUserProfileStream(uid);
  }

  // Check login state
  bool get isLoggedIn => _auth.currentUser != null;

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Update user profile
  Future<ApiResponse<void>> updateUserProfile(Map<String, dynamic> data) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return ApiResponse.error("User not authenticated");

    try {
      final currentProfile = await _dbService.getUserProfile();
      if (currentProfile.success && currentProfile.data != null) {
        final updatedUser = currentProfile.data!.copyWith(
          name: data['name'] ?? currentProfile.data!.name,
          phone: data['phone'] ?? currentProfile.data!.phone,
          address: data['address'] ?? currentProfile.data!.address,
          plantCapacity: data['plantCapacity'] ?? currentProfile.data!.plantCapacity,
          userRoleLabel: data['userRoleLabel'] ?? currentProfile.data!.userRoleLabel,
          updatedAt: DateTime.now(),
        );
        return await _dbService.saveUserProfile(updatedUser);
      }
      return ApiResponse.error("Current profile not found");
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }
}
