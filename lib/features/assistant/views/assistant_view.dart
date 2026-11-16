import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/feedback.dart';
import '../controllers/assistant_controller.dart';
import '../data/assistant_models.dart';

/// Admin-only conversational interface for querying live business data.
class AssistantView extends GetView<AssistantController> {
  const AssistantView({super.key});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 760;
    final userName = controller.session.user?.fullName ?? 'You';

    return Padding(
      padding: EdgeInsets.all(narrow ? 12 : 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                eyebrow: 'Gemini · read-only',
                title: 'Business Assistant',
                subtitle:
                    'Ask about stock, sales, profit, dues or deliveries — in English or Bangla.',
                actions: [
                  const StatusPill(
                    label: 'Read-only',
                    color: AppColors.green,
                    icon: Icons.shield_outlined,
                    dense: true,
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.newChat,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text('New chat'.tr),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        if (!controller.available)
                          _SetupBanner(demo: controller.session.isDemo),
                        Expanded(child: _buildMessages(context, userName)),
                        _Composer(controller: controller, narrow: narrow),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessages(BuildContext context, String userName) {
    return Obx(() {
      final messages = controller.messages;
      final showSuggestions =
          controller.available &&
          messages.length <= 1 &&
          !controller.sending.value;

      if (messages.isEmpty) {
        return const EmptyState(
          icon: Icons.auto_awesome_rounded,
          title: 'Ask your first question',
          message:
              'Try a stock level, today\'s profit, customer dues or pending deliveries.',
        );
      }

      return ListView.builder(
        controller: controller.scrollController,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: messages.length + (showSuggestions ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= messages.length) {
            return _Suggestions(
              onSelected: (prompt) => controller.send(prompt),
            );
          }
          final message = messages[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _MessageBubble(
              message: message,
              userName: userName,
              onRetry: () => controller.retry(message),
              onFollowUp: (prompt) => controller.send(prompt),
            ),
          );
        },
      );
    });
  }
}

class _SetupBanner extends StatelessWidget {
  const _SetupBanner({required this.demo});

  final bool demo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      color: AppColors.amber.withValues(alpha: 0.13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 17,
            color: AppColors.amber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              demo
                  ? 'You are in the local demo workspace. AI answers need the '
                        'cloud workspace and the ai-assistant Edge Function.'
                  : 'The AI assistant could not reach Supabase. Check your '
                        'connection and that the ai-assistant function is deployed.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.userName,
    required this.onRetry,
    required this.onFollowUp,
  });

  final AssistantMessage message;
  final String userName;
  final VoidCallback onRetry;
  final ValueChanged<String> onFollowUp;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth < 720
            ? constraints.maxWidth * 0.9
            : 680.0;
        final bubble = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: isUser ? _userBubble(context) : _assistantBubble(context),
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: isUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!isUser) ...[
              const _AssistantAvatar(),
              const SizedBox(width: 10),
            ],
            Flexible(child: bubble),
            if (isUser) ...[
              const SizedBox(width: 10),
              InitialsAvatar(
                name: userName,
                size: 32,
                background: AppColors.navy,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _userBubble(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 10),
      decoration: const BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(5),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            message.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            Formats.time(message.createdAt),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _assistantBubble(BuildContext context) {
    if (message.isPending) return const _TypingBubble();

    final theme = Theme.of(context);
    if (message.hasFailed) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.07),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(5),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(
            color: AppColors.red.withValues(alpha: 0.28),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 16,
                  color: AppColors.red,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'I could not complete that request',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(
              message.error ?? 'Please try again.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: Text('Try again'.tr),
              ),
            ),
          ],
        ),
      );
    }

    final reply = message.reply;
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(5),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnswerText(reply?.answer ?? message.text),
          if (reply?.table != null && reply!.table!.isEmpty == false) ...[
            const SizedBox(height: 12),
            _ResultTable(table: reply.table!),
          ],
          if (reply != null && reply.followUps.isNotEmpty) ...[
            const SizedBox(height: 12),
            _FollowUps(
              items: reply.followUps,
              onSelected: onFollowUp,
            ),
          ],
          if (reply?.sql != null) ...[
            const SizedBox(height: 10),
            _SqlDisclosure(sql: reply!.sql!),
          ],
          const SizedBox(height: 5),
          Text(
            Formats.time(message.createdAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: 16,
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(5),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Searching your business data',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              return Row(
                children: [
                  for (var index = 0; index < 3; index++)
                    Padding(
                      padding: EdgeInsets.only(left: index == 0 ? 0 : 3),
                      child: Opacity(
                        opacity: _dotOpacity(index),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.teal,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  double _dotOpacity(int index) {
    final phase = (_animation.value + index * 0.22) % 1.0;
    return (0.25 + 0.75 * (1 - (phase - 0.5).abs() * 2))
        .clamp(0.25, 1.0)
        .toDouble();
  }
}

class _AnswerText extends StatelessWidget {
  const _AnswerText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final base =
        Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5) ??
        const TextStyle(height: 1.5);

    final blocks = <Widget>[];
    final lines = text.replaceAll('\r\n', '\n').split('\n');

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) {
        blocks.add(const SizedBox(height: 6));
        continue;
      }

      if (line.startsWith('#')) {
        final heading = line.replaceFirst(RegExp(r'^#{1,3}\s+'), '');
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: 3, bottom: 3),
            child: Text.rich(
              TextSpan(
                children: _inline(
                  heading,
                  base.copyWith(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
              ),
            ),
          ),
        );
        continue;
      }

      final bullet = RegExp(r'^[-*•]\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        blocks.add(_bullet(context, '•', bullet.group(1)!, base));
        continue;
      }

      final numbered = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(line);
      if (numbered != null) {
        blocks.add(
          _bullet(context, '${numbered.group(1)}.', numbered.group(2)!, base),
        );
        continue;
      }

      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text.rich(TextSpan(children: _inline(line, base))),
        ),
      );
    }

    if (blocks.isEmpty) {
      return Text(text, style: base);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  Widget _bullet(
    BuildContext context,
    String marker,
    String content,
    TextStyle base,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Text(
              marker,
              style: base.copyWith(
                color: AppColors.teal,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text.rich(TextSpan(children: _inline(content, base))),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _inline(String input, TextStyle base) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'(\*\*[^*]+\*\*|`[^`]+`)');
    var last = 0;

    for (final match in pattern.allMatches(input)) {
      if (match.start > last) {
        spans.add(
          TextSpan(text: input.substring(last, match.start), style: base),
        );
      }
      final token = match.group(0) ?? '';
      if (token.startsWith('**') && token.length > 4) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: base.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else if (token.startsWith('`') && token.length > 2) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: base.copyWith(
              fontFamily: 'monospace',
              color: AppColors.tealDark,
              fontSize: (base.fontSize ?? 14) - 0.5,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: token, style: base));
      }
      last = match.end;
    }

    if (last < input.length) {
      spans.add(TextSpan(text: input.substring(last), style: base));
    }
    if (spans.isEmpty) spans.add(TextSpan(text: input, style: base));
    return spans;
  }
}

class _ResultTable extends StatelessWidget {
  const _ResultTable({required this.table});

  final AssistantTable table;

  static const int _maxRows = 40;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = table.rows.take(_maxRows).toList(growable: false);
    final numericColumns = <String>{};

    for (final column in table.columns) {
      final numeric = rows.every((row) {
        final value = row[column];
        return value == null || value is num;
      });
      if (numeric) numericColumns.add(column);
    }

    final totalLabel = table.truncated
        ? '${table.rows.length}+'
        : '${table.rows.length}';

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
            child: Row(
              children: [
                Icon(
                  Icons.table_chart_outlined,
                  size: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Results',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '$totalLabel ${table.rows.length == 1 ? 'row' : 'rows'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columnSpacing: 22,
              horizontalMargin: 14,
              headingRowHeight: 38,
              dataRowMinHeight: 34,
              dataRowMaxHeight: 58,
              columns: [
                for (final column in table.columns)
                  DataColumn(
                    numeric: numericColumns.contains(column),
                    label: Text(
                      _humanize(column),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
              rows: [
                for (final row in rows)
                  DataRow(
                    cells: [
                      for (final column in table.columns)
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: Text(
                              _cell(row[column]),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                height: 1.35,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          if (table.rows.length > rows.length || table.truncated)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                'Showing ${rows.length} of $totalLabel rows. Ask a more '
                'specific question to narrow the list.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _humanize(String key) {
    final words = key.replaceAll('_', ' ').trim().split(RegExp(r'\s+'));
    return words
        .where((word) => word.isNotEmpty)
        .map(
          (word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  static String _cell(dynamic value) {
    if (value == null) return '—';
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is int) return Formats.number(value);
    if (value is num) {
      if (value == value.roundToDouble()) {
        return Formats.number(value.toInt());
      }
      return Formats.number(value, decimals: 2);
    }
    final text = value.toString().trim();
    return text.isEmpty ? '—' : text;
  }
}

class _SqlDisclosure extends StatefulWidget {
  const _SqlDisclosure({required this.sql});

  final String sql;

  @override
  State<_SqlDisclosure> createState() => _SqlDisclosureState();
}

class _SqlDisclosureState extends State<_SqlDisclosure> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.terminal_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'View generated query',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _open
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_open) ...[
            const Divider(height: 1),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
              color: const Color(0xFF0B1B2B),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    widget.sql,
                    style: const TextStyle(
                      color: Color(0xFFBFE8E4),
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      height: 1.5,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: widget.sql),
                        );
                        showAppMessage('Query copied to the clipboard.');
                      },
                      icon: const Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: Colors.white70,
                      ),
                      label: const Text(
                        'Copy',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FollowUps extends StatelessWidget {
  const _FollowUps({required this.items, required this.onSelected});

  final List<String> items;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You might also ask',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final item in items)
              ActionChip(
                onPressed: () => onSelected(item),
                avatar: const Icon(
                  Icons.add_comment_outlined,
                  size: 13,
                  color: AppColors.teal,
                ),
                label: Text(
                  item,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 42, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Try asking'.tr,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final prompt in AssistantController.suggestions)
                ActionChip(
                  onPressed: () => onSelected(prompt),
                  avatar: const Icon(
                    Icons.arrow_outward_rounded,
                    size: 13,
                    color: AppColors.teal,
                  ),
                  label: Text(
                    prompt,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.narrow});

  final AssistantController controller;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final busy = controller.sending.value;
      final enabled = controller.available && !busy;

      return Container(
        padding: EdgeInsets.fromLTRB(
          narrow ? 12 : 16,
          12,
          narrow ? 12 : 16,
          10,
        ),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.composer,
                    enabled: enabled,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: enabled ? (_) => controller.send() : null,
                    decoration: InputDecoration(
                      hintText: controller.available
                          ? 'Ask about stock, sales, profit, dues…'
                          : 'AI assistant requires cloud mode',
                      prefixIcon: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 18,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: FilledButton(
                    onPressed: enabled ? () => controller.send() : null,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_upward_rounded, size: 20),
                  ),
                ),
              ],
            ),
            if (!narrow)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  'Enter to send · Shift + Enter for a new line · Answers use '
                  'live, read-only data from your business.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}
