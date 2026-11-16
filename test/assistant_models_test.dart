import 'package:afraz_flow/features/assistant/data/assistant_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AssistantReply', () {
    test('parses structured rows, SQL and follow-up questions', () {
      final reply = AssistantReply.fromJson({
        'answer': 'You have 24 packets of noodles.',
        'sql': "select name, stock_qty from products where tenant_id = 't1'",
        'columns': ['name', 'stock_qty'],
        'rows': [
          {'name': 'Instant Noodles', 'stock_qty': 24},
          {'name': 'Cup Noodles', 'stock_qty': 6},
        ],
        'row_count': 2,
        'truncated': false,
        'follow_ups': ['Which items are low on stock?', 'Show today\'s sales'],
      });

      expect(reply.answer, 'You have 24 packets of noodles.');
      expect(reply.sql, contains('stock_qty'));
      expect(reply.rowCount, 2);
      expect(reply.followUps, hasLength(2));
      expect(reply.table, isNotNull);
      expect(reply.table!.columns, ['name', 'stock_qty']);
      expect(reply.table!.rows, hasLength(2));
      expect(reply.table!.rows.first['name'], 'Instant Noodles');
      expect(reply.table!.truncated, isFalse);
    });

    test('derives columns from the first row when omitted', () {
      final reply = AssistantReply.fromJson({
        'answer': 'Today\'s profit is Rs 1,250.',
        'rows': [
          {'total_profit': 1250},
        ],
      });

      expect(reply.table!.columns, ['total_profit']);
    });

    test('has no table for a conversational answer', () {
      final reply = AssistantReply.fromJson({
        'answer': 'Hello! Ask me about stock, profit or dues.',
        'sql': null,
        'rows': <Object>[],
        'follow_ups': <String>[],
      });

      expect(reply.table, isNull);
      expect(reply.sql, isNull);
      expect(reply.followUps, isEmpty);
    });

    test('caps follow-up suggestions at three', () {
      final reply = AssistantReply.fromJson({
        'answer': 'Done.',
        'rows': <Object>[],
        'follow_ups': ['One', 'Two', 'Three', 'Four'],
      });

      expect(reply.followUps, ['One', 'Two', 'Three']);
    });
  });
}
