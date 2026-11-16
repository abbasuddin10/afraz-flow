import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/app_services.dart';
import '../../../core/utils/app_failure.dart';
import '../data/assistant_models.dart';
import '../data/assistant_repository.dart';

class AssistantController extends GetxController {
  final AssistantRepository _repository = Get.find<AssistantRepository>();
  final SessionService session = Get.find<SessionService>();

  final RxList<AssistantMessage> messages = <AssistantMessage>[].obs;
  final RxBool sending = false.obs;
  final TextEditingController composer = TextEditingController();
  final ScrollController scrollController = ScrollController();

  bool get available => _repository.isAvailable;

  static const List<String> suggestions = [
    'How many noodles are in stock?',
    'What is today\'s total profit?',
    'আজকের মোট বিক্রয় কত?',
    'Which products are low on stock?',
    'Show my top customers by due balance',
    'How many courier orders are pending?',
  ];

  @override
  void onInit() {
    super.onInit();
    messages.add(AssistantMessage.intro(_welcomeText()));
  }

  String _welcomeText() {
    final name = session.user?.fullName.split(' ').first ?? 'there';
    return 'Hi $name! I\'m your business assistant. I can look up live stock, '
        'sales, profit, customer dues, expenses and courier data, then explain '
        'it in plain language. Ask me anything — English or Bangla.';
  }

  Future<void> send([String? value]) async {
    if (!available || sending.value) return;
    final text = (value ?? composer.text).trim();
    if (text.isEmpty) return;

    if (value == null || value == composer.text) composer.clear();
    messages.add(AssistantMessage.user(text));
    await _request(text);
  }

  Future<void> retry(AssistantMessage failed) async {
    if (!available || sending.value) return;
    final index = messages.indexOf(failed);
    if (index <= 0) return;

    String? question;
    for (var i = index - 1; i >= 0; i--) {
      if (messages[i].isUser) {
        question = messages[i].text;
        break;
      }
    }
    if (question == null || question.trim().isEmpty) return;

    messages.removeAt(index);
    await _request(question);
  }

  Future<void> _request(String question) async {
    final pending = AssistantMessage.pending();
    messages.add(pending);
    sending.value = true;
    _scrollToBottom();

    try {
      final history = <AssistantTurn>[];
      for (final message in messages) {
        if (message.id == pending.id ||
            message.isPending ||
            message.hasFailed ||
            message.isWelcome) {
          continue;
        }
        final content = message.isUser
            ? message.text
            : (message.reply?.answer ?? message.text);
        if (content.trim().isEmpty) continue;
        history.add(
          AssistantTurn(
            role: message.isUser ? 'user' : 'assistant',
            content: content.trim(),
          ),
        );
      }

      // The current question is sent separately, so avoid duplicating it.
      if (history.isNotEmpty &&
          history.last.role == 'user' &&
          history.last.content == question.trim()) {
        history.removeLast();
      }
      final turns = history.length > 8
          ? history.sublist(history.length - 8)
          : history;

      final reply = await _repository.ask(question, history: turns);
      _replace(pending, AssistantMessage.assistant(reply));
    } catch (error) {
      _replace(
        pending,
        AssistantMessage.failure(AppFailure.from(error).message),
      );
    } finally {
      sending.value = false;
      _scrollToBottom();
    }
  }

  void _replace(AssistantMessage pending, AssistantMessage replacement) {
    final index = messages.indexWhere((message) => message.id == pending.id);
    if (index >= 0) messages[index] = replacement;
  }

  void newChat() {
    if (sending.value) return;
    messages.assignAll([AssistantMessage.intro(_welcomeText())]);
    composer.clear();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void onClose() {
    composer.dispose();
    scrollController.dispose();
    super.onClose();
  }
}
