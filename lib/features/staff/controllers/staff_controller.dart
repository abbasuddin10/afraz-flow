import 'package:get/get.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/services/app_services.dart';
import '../../../../core/utils/app_failure.dart';
import '../../../../core/widgets/feedback.dart';
import '../data/staff_repository.dart';

class StaffController extends GetxController {
  final StaffRepository _repository = Get.find<StaffRepository>();
  final SessionService _session = Get.find<SessionService>();

  final RxList<Membership> members = <Membership>[].obs;
  final RxBool loading = true.obs;
  final RxBool saving = false.obs;
  final RxnString error = RxnString();

  bool get canManage => _session.role.canManageTeam;
  MemberRole get role => _session.role;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) loading.value = true;
    error.value = null;
    try {
      members.assignAll(await _repository.members());
    } catch (exception) {
      error.value = AppFailure.from(exception).message;
    } finally {
      loading.value = false;
    }
  }

  Future<bool> invite({
    required String fullName,
    required String email,
    required MemberRole memberRole,
    String? password,
  }) async {
    saving.value = true;
    try {
      await _repository.invite(
        fullName: fullName,
        email: email,
        role: memberRole,
        password: password,
      );
      await load(silent: true);
      final tempPassword = (password == null || password.trim().isEmpty)
          ? 'Welcome123'
          : password.trim();
      showAppMessage(
        'Account created for $email. Temporary password: $tempPassword',
      );
      return true;
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<bool> changeRole(Membership member, MemberRole value) async {
    saving.value = true;
    try {
      await _repository.updateRole(member, value);
      await load(silent: true);
      showAppMessage('${member.fullName} is now ${value.label}.');
      return true;
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<bool> setActive(Membership member, bool active) async {
    saving.value = true;
    try {
      await _repository.setActive(member, active);
      await load(silent: true);
      showAppMessage(
        active
            ? '${member.fullName} can sign in again.'
            : '${member.fullName} has been deactivated.',
      );
      return true;
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
      return false;
    } finally {
      saving.value = false;
    }
  }

  int countFor(MemberRole value) =>
      members.where((member) => member.role == value).length;
}
