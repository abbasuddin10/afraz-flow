import '../utils/formatters.dart';
import '../utils/json_helpers.dart';
import 'tenant.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? avatarUrl;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: asString(json['id']),
    email: asString(json['email']),
    fullName: asString(
      json['full_name'] ?? json['name'],
      asString(json['email']).split('@').first,
    ),
    phone: asNullableString(json['phone']),
    avatarUrl: asNullableString(json['avatar_url']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email.trim(),
    'full_name': fullName.trim(),
    'phone': phone,
    'avatar_url': avatarUrl,
  };

  String get initials => Formats.initials(fullName);
}

enum MemberRole {
  admin,
  manager,
  cashier;

  static MemberRole fromValue(dynamic value) {
    switch (value?.toString().toLowerCase()) {
      case 'admin':
        return MemberRole.admin;
      case 'manager':
        return MemberRole.manager;
      default:
        return MemberRole.cashier;
    }
  }

  String get value => name;

  String get label => switch (this) {
    MemberRole.admin => 'Admin',
    MemberRole.manager => 'Manager',
    MemberRole.cashier => 'Cashier',
  };

  String get description => switch (this) {
    MemberRole.admin => 'Full access including staff, settings and billing.',
    MemberRole.manager => 'Manage stock, sales, accounts and deliveries.',
    MemberRole.cashier => 'Sell at POS and update delivery status.',
  };

  bool get isAdmin => this == MemberRole.admin;

  bool get canManageTeam => this == MemberRole.admin;
  bool get canManageSettings => this == MemberRole.admin;
  bool get canManageCatalog => this != MemberRole.cashier;
  bool get canManageFinance => this != MemberRole.cashier;
  bool get canManageCourier => true;
  bool get canCreateSales => true;

  /// Cashiers see the dashboard but finance cards are hidden.
  bool get canViewProfit => this != MemberRole.cashier;
}

class Membership {
  const Membership({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.user,
  });

  final String id;
  final String tenantId;
  final String userId;
  final MemberRole role;
  final bool isActive;
  final DateTime createdAt;
  final AppUser? user;

  factory Membership.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] ?? json['profile'];
    return Membership(
      id: asString(json['id']),
      tenantId: asString(json['tenant_id']),
      userId: asString(json['user_id']),
      role: MemberRole.fromValue(json['role']),
      isActive: asBool(json['is_active'], true),
      createdAt: asDate(json['created_at']),
      user: profile is Map<String, dynamic>
          ? AppUser.fromJson(profile)
          : profile is Map
          ? AppUser.fromJson(Map<String, dynamic>.from(profile))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'user_id': userId,
    'role': role.value,
    'is_active': isActive,
    'created_at': toIso(createdAt),
  };

  Membership copyWith({MemberRole? role, bool? isActive, AppUser? user}) =>
      Membership(
        id: id,
        tenantId: tenantId,
        userId: userId,
        role: role ?? this.role,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        user: user ?? this.user,
      );

  String get fullName => user?.fullName ?? 'Team member';
  String get email => user?.email ?? '';
  String get initials => Formats.initials(fullName);
}

/// The authenticated context used throughout the app. The tenant id here is
/// the boundary for every query and is also enforced server-side by RLS.
class AppSession {
  const AppSession({
    required this.user,
    required this.tenant,
    required this.membership,
    required this.isDemo,
  });

  final AppUser user;
  final Tenant tenant;
  final Membership membership;
  final bool isDemo;

  MemberRole get role => membership.role;
  String get tenantId => tenant.id;

  AppSession copyWith({
    AppUser? user,
    Tenant? tenant,
    Membership? membership,
  }) => AppSession(
    user: user ?? this.user,
    tenant: tenant ?? this.tenant,
    membership: membership ?? this.membership,
    isDemo: isDemo,
  );
}
