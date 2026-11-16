import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/data/backend_mode.dart';
import '../../../../core/data/data_store.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/models/tenant.dart';
import '../../../../core/utils/app_failure.dart';
import '../../../../core/utils/json_helpers.dart';
import 'register_business_input.dart';

/// Owns authentication and organization bootstrap for both backends.
///
/// Cloud mode uses Supabase Auth. Demo mode keeps credentials in the local
/// demo database only — it is an evaluation convenience, not a security layer.
class AuthRepository {
  AuthRepository({
    required DataStore store,
    required SharedPreferences prefs,
    SupabaseClient? client,
    BackendMode? mode,
  }) : _store = store,
       _prefs = prefs,
       _client = client,
       _mode = mode;

  static const String _demoSessionKey = 'afrazflow.demo.session';
  static const Uuid _uuid = Uuid();

  final DataStore _store;
  final SharedPreferences _prefs;
  final SupabaseClient? _client;
  final BackendMode? _mode;

  bool get isRemote => _mode?.isRemote ?? (_client != null);

  Future<AppSession?> restoreSession() async {
    if (isRemote) {
      if (_client?.auth.currentSession == null) return null;
      final user = _client?.auth.currentUser;
      if (user == null) return null;
      return _loadRemoteSession(user.id, fallbackEmail: user.email);
    }
    final userId = _prefs.getString(_demoSessionKey);
    if (userId == null || userId.isEmpty) return null;
    try {
      return await _loadDemoSession(userId);
    } catch (_) {
      await _prefs.remove(_demoSessionKey);
      return null;
    }
  }

  Future<AppSession> signIn({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (isRemote) {
      final response = await _client!.auth.signInWithPassword(
        email: normalized,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AppFailure('Sign in failed. Please try again.');
      }
      return _loadRemoteSession(user.id, fallbackEmail: user.email);
    }

    final accounts = await _store.select(
      'demo_accounts',
      eq: {'email': normalized},
      limit: 1,
    );
    if (accounts.isEmpty ||
        asString(accounts.first['password']) != password) {
      throw const AppFailure('Incorrect email or password.');
    }
    final userId = asString(accounts.first['user_id']);
    await _prefs.setString(_demoSessionKey, userId);
    return _loadDemoSession(userId);
  }

  Future<AppSession> registerBusiness(RegisterBusinessInput input) async {
    final normalized = input.email.trim().toLowerCase();
    if (isRemote) {
      final client = _client;
      if (client == null) {
        throw const AppFailure(
          'Cloud sign-up is unavailable right now. Please try again.',
        );
      }
      final existing = await client.auth.signUp(
        email: normalized,
        password: input.password,
        emailRedirectTo: AppConfig.appUrl,
        data: {
          'full_name': input.ownerName.trim(),
          'phone': input.phone.trim(),
          'business_name': input.businessName.trim(),
          'business_type': input.businessType,
          'currency': input.currency,
          'currency_symbol': input.currencySymbol,
          'tax_rate': input.taxRate,
          'low_stock_threshold': input.lowStockThreshold,
        },
      );
      var user = existing.user;
      if (user == null) {
        throw const AppFailure('Could not create your account. Try again.');
      }
      if (existing.session == null) {
        // Email confirmation is enabled. The account itself already exists in
        // Supabase Auth; the organization is provisioned on first sign-in from
        // the metadata stored above.
        throw ConfirmationRequired(normalized);
      }
      try {
        await _createRemoteOrganization(input);
        user = client.auth.currentUser ?? user;
        return await _loadRemoteSession(
          user.id,
          fallbackEmail: normalized,
        );
      } catch (error) {
        await client.auth.signOut();
        throw AppFailure.from(error);
      }
    }

    final duplicate = await _store.select(
      'demo_accounts',
      eq: {'email': normalized},
      limit: 1,
    );
    if (duplicate.isNotEmpty) {
      throw const AppFailure('An account with this email already exists.');
    }

    final now = DateTime.now();
    final userId = _uuid.v4();
    final tenantId = _uuid.v4();
    final membershipId = _uuid.v4();
    final tenant = Tenant(
      id: tenantId,
      name: input.businessName.trim(),
      businessType: input.businessType,
      currency: input.currency,
      currencySymbol: input.currencySymbol,
      taxRate: input.taxRate,
      lowStockThreshold: input.lowStockThreshold,
      phone: input.phone.trim(),
      email: normalized,
      createdAt: now,
    );
    final user = AppUser(
      id: userId,
      email: normalized,
      fullName: input.ownerName.trim(),
      phone: input.phone.trim(),
    );
    final membership = Membership(
      id: membershipId,
      tenantId: tenantId,
      userId: userId,
      role: MemberRole.admin,
      isActive: true,
      createdAt: now,
      user: user,
    );

    await _store.insert('tenants', tenant.toJson());
    await _store.insert('profiles', user.toJson());
    await _store.insert('tenant_members', membership.toJson());
    await _store.insert('demo_accounts', {
      'id': _uuid.v4(),
      'user_id': userId,
      'email': normalized,
      'password': input.password,
      'created_at': toIso(now),
    });
    await _prefs.setString(_demoSessionKey, userId);
    return AppSession(
      user: user,
      tenant: tenant,
      membership: membership,
      isDemo: true,
    );
  }

  Future<void> signOut() async {
    if (isRemote) {
      await _client!.auth.signOut();
    } else {
      await _prefs.remove(_demoSessionKey);
    }
  }

  Future<void> _createRemoteOrganization(RegisterBusinessInput input) async {
    await _client!.rpc(
      'create_organization',
      params: {
        'p_name': input.businessName.trim(),
        'p_business_type': input.businessType,
        'p_currency': input.currency,
        'p_currency_symbol': input.currencySymbol,
        'p_tax_rate': input.taxRate,
        'p_low_stock_threshold': input.lowStockThreshold,
        'p_phone': input.phone.trim(),
        'p_full_name': input.ownerName.trim(),
      },
    );
  }

  Future<AppSession> _loadRemoteSession(
    String userId, {
    String? fallbackEmail,
  }) async {
    var memberships = await _store.select(
      'tenant_members',
      eq: {'user_id': userId, 'is_active': true},
      limit: 1,
    );

    // Supports the email-confirmation flow: if the account was created but the
    // organization could not yet be provisioned, provision it from metadata.
    if (memberships.isEmpty) {
      final metadata = _client?.auth.currentUser?.userMetadata ?? {};
      if (metadata['business_name'] != null) {
        await _client!.rpc(
          'create_organization',
          params: {
            'p_name': metadata['business_name'],
            'p_business_type': metadata['business_type'] ?? 'Other',
            'p_currency': metadata['currency'] ?? 'PKR',
            'p_currency_symbol': metadata['currency_symbol'] ?? 'Rs',
            'p_tax_rate': asDouble(metadata['tax_rate']),
            'p_low_stock_threshold': asInt(
              metadata['low_stock_threshold'],
              5,
            ),
            'p_phone': metadata['phone'] ?? '',
            'p_full_name': metadata['full_name'] ?? '',
          },
        );
        memberships = await _store.select(
          'tenant_members',
          eq: {'user_id': userId, 'is_active': true},
          limit: 1,
        );
      }
    }

    if (memberships.isEmpty) {
      throw const AppFailure(
        'Your account has no active organization. Contact your administrator.',
      );
    }
    final membership = Membership.fromJson(memberships.first);
    final tenants = await _store.select(
      'tenants',
      eq: {'id': membership.tenantId},
      limit: 1,
    );
    if (tenants.isEmpty) {
      throw const AppFailure('Organization data could not be loaded.');
    }
    final profiles = await _store.select(
      'profiles',
      eq: {'id': userId},
      limit: 1,
    );
    final user = profiles.isEmpty
        ? AppUser(
            id: userId,
            email: fallbackEmail ?? '',
            fullName:
                _client?.auth.currentUser?.userMetadata?['full_name'] ??
                'Business owner',
          )
        : AppUser.fromJson(profiles.first);
    final tenant = Tenant.fromJson(tenants.first);
    return AppSession(
      user: user,
      tenant: tenant,
      membership: membership.copyWith(user: user),
      isDemo: false,
    );
  }

  Future<AppSession> _loadDemoSession(String userId) async {
    final users = await _store.select('profiles', eq: {'id': userId}, limit: 1);
    final memberships = await _store.select(
      'tenant_members',
      eq: {'user_id': userId, 'is_active': true},
      limit: 1,
    );
    if (users.isEmpty || memberships.isEmpty) {
      throw const AppFailure('Your local demo session has expired.');
    }
    final membership = Membership.fromJson(memberships.first);
    final tenants = await _store.select(
      'tenants',
      eq: {'id': membership.tenantId},
      limit: 1,
    );
    if (tenants.isEmpty) {
      throw const AppFailure('Organization data could not be loaded.');
    }
    final user = AppUser.fromJson(users.first);
    return AppSession(
      user: user,
      tenant: Tenant.fromJson(tenants.first),
      membership: membership.copyWith(user: user),
      isDemo: true,
    );
  }
}
