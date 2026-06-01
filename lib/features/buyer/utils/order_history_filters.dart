import '../../../models/order.dart';

List<Order> visibleOrderHistoryItems(
  List<Order> orders, {
  bool hideCancelledOrders = true,
}) {
  if (!hideCancelledOrders) return orders;

  return orders
      .where((order) => order.status.toLowerCase() != 'cancelled')
      .toList(growable: false);
}
