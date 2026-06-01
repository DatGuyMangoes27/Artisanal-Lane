import '../../../models/order.dart';

const Set<String> receiptReminderPromptStatuses = {'shipped', 'delivered'};

bool shouldPromptReceiptReminder(Order order) {
  return receiptReminderPromptStatuses.contains(order.status.toLowerCase()) &&
      order.receivedAt == null;
}
