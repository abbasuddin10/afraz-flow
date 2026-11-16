import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/app_user.dart';
import '../../../core/services/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/feedback.dart';
import '../controllers/staff_controller.dart';
import 'staff_dialogs.dart';

class StaffView extends StatefulWidget {
  const StaffView({super.key});

  @override
  State<StaffView> createState() => _StaffViewState();
}

class _StaffViewState extends State<StaffView> {
  final StaffController controller = Get.find<StaffController>();
  final SessionService session = Get.find<SessionService>();
  final TextEditingController _search = TextEditingController();

  String _query = '';

  bool get canManage => controller.canManage;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Membership> get _members {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return controller.members;
    return controller.members.where((member) {
      return member.fullName.toLowerCase().contains(query) ||
          member.email.toLowerCase().contains(query) ||
          member.role.label.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _invite() async {
    await AppDialogs.showForm<bool>(
      context,
      title: 'Invite a team member',
      subtitle: 'Give a colleague access to this workspace with a clear role.',
      child: const InviteStaffDialog(),
    );
  }

  Future<void> _changeRole(Membership member) async {
    await AppDialogs.showForm<bool>(
      context,
      title: 'Change role',
      subtitle: 'Update what ${member.fullName} can access.',
      child: ChangeRoleDialog(member: member),
    );
  }

  Future<void> _toggleActive(Membership member) async {
    if (member.isActive) {
      final confirmed = await AppDialogs.confirm(
        context,
        title: 'Deactivate ${member.fullName}?',
        message:
            'They will be signed out and cannot access this workspace until '
            'reactivated.',
        confirmLabel: 'Deactivate',
        destructive: true,
        icon: Icons.person_off_outlined,
      );
      if (!confirmed) return;
    }
    await controller.setActive(member, !member.isActive);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Padding(
      padding: EdgeInsets.all(wide ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            eyebrow: 'Access control',
            title: 'Team & Roles',
            subtitle: canManage
                ? 'Invite staff and decide exactly what each role can access.'
                : 'See who is on your team. Only admins can change roles or '
                      'invite people.',
            actions: [
              if (canManage)
                FilledButton.icon(
                  onPressed: _invite,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: Text('Invite member'.tr),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Obx(() {
              if (controller.loading.value) {
                return const AppCard(
                  child: LoadingState(label: 'Loading your team…'),
                );
              }
              if (controller.error.value != null) {
                return AppCard(
                  child: ErrorState(
                    message: controller.error.value!,
                    onRetry: controller.load,
                  ),
                );
              }
              return _buildContent(context, wide);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool wide) {
    final members = _members;
    return RefreshIndicator(
      onRefresh: () => controller.load(silent: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        ResponsiveGrid(
          minItemWidth: 165,
          maxColumns: 4,
          children: [
            _TeamStat(
              label: 'Team members',
              value: '${controller.members.length}',
              icon: Icons.groups_outlined,
              color: AppColors.navy,
            ),
            _TeamStat(
              label: 'Admins',
              value: '${controller.countFor(MemberRole.admin)}',
              icon: Icons.admin_panel_settings_outlined,
              color: AppColors.teal,
            ),
            _TeamStat(
              label: 'Managers',
              value: '${controller.countFor(MemberRole.manager)}',
              icon: Icons.manage_accounts_outlined,
              color: AppColors.blue,
            ),
            _TeamStat(
              label: 'Cashiers',
              value: '${controller.countFor(MemberRole.cashier)}',
              icon: Icons.point_of_sale_outlined,
              color: AppColors.purple,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _RoleGuide(),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            return AppSearchField(
              width: constraints.maxWidth < 600
                  ? constraints.maxWidth
                  : 320,
              hint: 'Search name, email or role',
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
            );
          },
        ),
        const SizedBox(height: 12),
        members.isEmpty
            ? AppCard(
                child: EmptyState(
                  icon: Icons.groups_outlined,
                  title: controller.members.isEmpty
                      ? 'No team members yet'
                      : 'No one matches this search',
                  message: controller.members.isEmpty
                      ? 'Invite a manager or cashier to collaborate in this '
                            'workspace.'
                      : 'Try another name, email or role.',
                  action: canManage && controller.members.isEmpty
                      ? FilledButton.icon(
                          onPressed: _invite,
                          icon: const Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 18,
                          ),
                          label: Text('Invite member'.tr),
                        )
                      : null,
                ),
              )
            : (wide
                  ? _buildTable(context, members)
                  : _buildCards(context, members)),
      ],
    ),
  ),
);
  }

  Widget _buildTable(BuildContext context, List<Membership> members) {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columnSpacing: 24,
              columns: [
                DataColumn(label: Text('MEMBER'.tr)),
                DataColumn(label: Text('ROLE'.tr)),
                DataColumn(label: Text('STATUS'.tr)),
                DataColumn(label: Text('JOINED'.tr)),
                DataColumn(label: Text(''.tr)),
              ],
              rows: [
                for (final member in members)
                  DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            InitialsAvatar(
                              name: member.fullName,
                              size: 34,
                              background: _roleColor(member.role),
                            ),
                            const SizedBox(width: 10),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          member.fullName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                      if (member.userId == session.userId) ...[
                                        const SizedBox(width: 6),
                                        const StatusPill(
                                          label: 'You',
                                          color: AppColors.teal,
                                          dense: true,
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    member.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                          fontSize: 9.5,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        StatusPill(
                          label: member.role.label,
                          color: _roleColor(member.role),
                          dense: true,
                        ),
                      ),
                      DataCell(
                        StatusPill(
                          label: member.isActive ? 'Active' : 'Deactivated',
                          color: member.isActive
                              ? AppColors.green
                              : AppColors.inkMuted,
                          dense: true,
                        ),
                      ),
                      DataCell(Text(Formats.date(member.createdAt))),
                      DataCell(
                        member.userId == session.userId || !canManage
                            ? Text('—'.tr)
                            : PopupMenuButton<String>(
                                tooltip: 'Member actions',
                                icon: const Icon(
                                  Icons.more_horiz_rounded,
                                  size: 19,
                                ),
                                onSelected: (value) {
                                  switch (value) {
                                    case 'role':
                                      _changeRole(member);
                                    case 'toggle':
                                      _toggleActive(member);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'role',
                                    child: _MenuRow(
                                      icon: Icons.verified_user_outlined,
                                      label: 'Change role',
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: _MenuRow(
                                      icon: member.isActive
                                          ? Icons.person_off_outlined
                                          : Icons.person_outline_rounded,
                                      label: member.isActive
                                          ? 'Deactivate'
                                          : 'Reactivate',
                                      color: member.isActive
                                          ? AppColors.red
                                          : AppColors.green,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCards(BuildContext context, List<Membership> members) {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        for (final member in members)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  InitialsAvatar(
                    name: member.fullName,
                    size: 46,
                    background: _roleColor(member.role),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                member.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            if (member.userId == session.userId) ...[
                              const SizedBox(width: 6),
                              const StatusPill(
                                label: 'You',
                                color: AppColors.teal,
                                dense: true,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          member.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            StatusPill(
                              label: member.role.label,
                              color: _roleColor(member.role),
                              dense: true,
                            ),
                            StatusPill(
                              label: member.isActive ? 'Active' : 'Deactivated',
                              color: member.isActive
                                  ? AppColors.green
                                  : AppColors.inkMuted,
                              dense: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (member.userId != session.userId && canManage)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 19),
                      onSelected: (value) {
                        switch (value) {
                          case 'role':
                            _changeRole(member);
                          case 'toggle':
                            _toggleActive(member);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'role',
                          child: _MenuRow(
                            icon: Icons.verified_user_outlined,
                            label: 'Change role',
                          ),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: _MenuRow(
                            icon: member.isActive
                                ? Icons.person_off_outlined
                                : Icons.person_outline_rounded,
                            label: member.isActive ? 'Deactivate' : 'Reactivate',
                            color: member.isActive
                                ? AppColors.red
                                : AppColors.green,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Color _roleColor(MemberRole role) => switch (role) {
    MemberRole.admin => AppColors.navySoft,
    MemberRole.manager => AppColors.teal,
    MemberRole.cashier => AppColors.purple,
  };
}

class _TeamStat extends StatelessWidget {
  const _TeamStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleGuide extends StatelessWidget {
  const _RoleGuide();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 720;
          final items = [
            _RoleItem(
              role: MemberRole.admin,
              color: AppColors.navySoft,
              icon: Icons.admin_panel_settings_outlined,
            ),
            _RoleItem(
              role: MemberRole.manager,
              color: AppColors.teal,
              icon: Icons.manage_accounts_outlined,
            ),
            _RoleItem(
              role: MemberRole.cashier,
              color: AppColors.purple,
              icon: Icons.point_of_sale_outlined,
            ),
          ];
          if (narrow) {
            return Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  items[i],
                  if (i < items.length - 1) const Divider(height: 20),
                ],
              ],
            );
          }
          return Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                Expanded(child: items[i]),
                if (i < items.length - 1)
                  const SizedBox(
                    height: 56,
                    child: VerticalDivider(width: 26),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RoleItem extends StatelessWidget {
  const _RoleItem({
    required this.role,
    required this.color,
    required this.icon,
  });

  final MemberRole role;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(role.label, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                role.description,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 9),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
