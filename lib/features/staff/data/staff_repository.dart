import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/data/data_store.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/services/app_services.dart';
import '../../../../core/utils/app_failure.dart';
import '../../../../core/utils/json_helpers.dart';

class StaffRepository {
  StaffRepository(this._store, this._session, {SupabaseClient? client})
    : _client = client;

  static const Uuid _uuid = Uuid();

  final DataStore _store;
  final SessionService _session;
  final SupabaseClient? _client;

  Future<List<Membership>> members() async {
    final tenantId = _session.requireTenantId();
    final rows = await _store.select(
      'tenant_members',
      eq: {'tenant_id': tenantId},
      orderBy: 'created_at',
      ascending: true,
    );
    if (rows.isEmpty) return [];
    final userIds = rows.map((row) => asString(row['user_id'])).toSet().toList();
    final profiles = await _store.select(
      'profiles',
      inFilter: {'id': userIds.cast<Object?>()},
    );
    final byId = <String, AppUser>{
      for (final profile in profiles)
        asString(profile['id']): AppUser.fromJson(profile),
    };
    final members = rows.map((row) {
      final membership = Membership.fromJson(row);
      return membership.copyWith(user: byId[membership.userId]);
    }).toList();
    members.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      final roleCompare = a.role.index.compareTo(b.role.index);
      if (roleCompare != 0) return roleCompare;
      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });
    return members;
  }

  Future<void> invite({
    required String fullName,
    required String email,
    required MemberRole role,
    String? password,
  }) async {
    final tenantId = _session.requireTenantId();
    final normalized = email.trim().toLowerCase();
    if (fullName.trim().length < 2) {
      throw const AppFailure('Enter the staff member’s full name.');
    }
    if (normalized.isEmpty || !normalized.contains('@')) {
      throw const AppFailure('Enter a valid work email.');
    }

    if (_store.isRemote) {
      final client = _client;
      if (client == null) {
        throw const AppFailure(
          'Cloud invites are unavailable right now. Please try again.',
        );
      }
      try {
        final response = await client.functions.invoke(
          'invite-staff',
          body: {
            'tenant_id': tenantId,
            'email': normalized,
            'full_name': fullName.trim(),
            'role': role.value,
            'password': password,
          },
        );
        if (response.status < 200 || response.status >= 300) {
          throw AppFailure(_functionError(response.data, response.status));
        }
        return;
      } on FunctionException catch (error) {
        throw AppFailure(_functionError(error.details, error.status));
      } catch (error) {
        throw AppFailure.from(error);
      }
    }

    final temporaryPassword = (password == null || password.trim().length < 8)
        ? 'Welcome123'
        : password.trim();

    final existingProfiles = await _store.select(
      'profiles',
      eq: {'email': normalized},
      limit: 1,
    );
    if (existingProfiles.isNotEmpty) {
      final userId = asString(existingProfiles.first['id']);
      final duplicateMember = await _store.select(
        'tenant_members',
        eq: {'tenant_id': tenantId, 'user_id': userId},
        limit: 1,
      );
      if (duplicateMember.isNotEmpty) {
        throw const AppFailure('This person is already on your team.');
      }
      await _store.insert('tenant_members', {
        'id': _uuid.v4(),
        'tenant_id': tenantId,
        'user_id': userId,
        'role': role.value,
        'is_active': true,
        'created_at': toIso(DateTime.now()),
      });
      // Make sure the existing account has a usable local demo password.
      final existingAccounts = await _store.select(
        'demo_accounts',
        eq: {'user_id': userId},
        limit: 1,
      );
      if (existingAccounts.isEmpty) {
        await _store.insert('demo_accounts', {
          'id': _uuid.v4(),
          'user_id': userId,
          'email': normalized,
          'password': temporaryPassword,
          'created_at': toIso(DateTime.now()),
        });
      } else if (password != null && password.trim().length >= 8) {
        await _store.update('demo_accounts', asString(existingAccounts.first['id']), {
          'password': temporaryPassword,
          'email': normalized,
        });
      }
      return;
    }

    final userId = _uuid.v4();
    final now = DateTime.now();
    await _store.insert(
      'profiles',
      AppUser(
        id: userId,
        email: normalized,
        fullName: fullName.trim(),
      ).toJson(),
    );
    await _store.insert('tenant_members', {
      'id': _uuid.v4(),
      'tenant_id': tenantId,
      'user_id': userId,
      'role': role.value,
      'is_active': true,
      'created_at': toIso(now),
    });
    await _store.insert('demo_accounts', {
      'id': _uuid.v4(),
      'user_id': userId,
      'email': normalized,
      'password': temporaryPassword,
      'created_at': toIso(now),
    });
  }

  Future<void> updateRole(Membership membership, MemberRole role) async {
    if (membership.role == role) return;
    await _guardAdminRemoval(membership);
    await _store.update('tenant_members', membership.id, {
      'role': role.value,
    });
  }

  Future<void> setActive(Membership membership, bool active) async {
    if (membership.userId == _session.userId && !active) {
      throw const AppFailure('You cannot deactivate your own account.');
    }
    if (!active) await _guardAdminRemoval(membership);
    await _store.update('tenant_members', membership.id, {
      'is_active': active,
    });
  }

  String _functionError(dynamic details, int status) {
    if (details is Map && details['error'] != null) {
      return details['error'].toString();
    }
    if (details is String && details.trim().isNotEmpty) return details;
    return 'Invitation could not be sent ($status). '
        'Make sure the invite-staff function is deployed.';
  }

  Future<void> _guardAdminRemoval(Membership membership) async {
    if (membership.role != MemberRole.admin) return;
    final rows = await _store.select(
      'tenant_members',
      eq: {
        'tenant_id': _session.requireTenantId(),
        'role': 'admin',
        'is_active': true,
      },
    );
    if (rows.length <= 1) {
      throw const AppFailure(
        'Your organization must keep at least one active admin.',
      );
    }
  }
}
