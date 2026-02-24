class AppConstants {
  AppConstants._();

  static const String appName = 'Artisan Lane';
  static const String currency = 'R';
  static const String currencyCode = 'ZAR';

  // Supabase
  static const String supabaseUrl = 'https://byckurabenbunsbrzcpl.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ5Y2t1cmFiZW5idW5zYnJ6Y3BsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA3MTA0MjgsImV4cCI6MjA4NjI4NjQyOH0.4ElDNdxVtTxyCeEg9Yx-N1jUrNijTr54bmCPkHoW33A';

  // Storage buckets
  static const String productImagesBucket = 'product-images';
  static const String shopBrandingBucket = 'shop-branding';
  static const String avatarsBucket = 'avatars';

  // Shipping methods
  static const Map<String, String> shippingMethods = {
    'courier_guy': 'The Courier Guy',
    'pargo': 'Pargo',
    'paxi': 'PAXI',
    'market_pickup': 'Market Pickup',
  };

  // Order statuses
  static const Map<String, String> orderStatuses = {
    'pending': 'Pending',
    'paid': 'Paid',
    'shipped': 'Shipped',
    'delivered': 'Delivered',
    'completed': 'Completed',
    'disputed': 'Disputed',
    'cancelled': 'Cancelled',
  };

  // Placeholder images
  static const String placeholderProduct =
      'https://images.unsplash.com/photo-1565193566173-7a0ee3dbe261?w=400&h=400&fit=crop';
  static const String placeholderShop =
      'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=800&h=400&fit=crop';
  static const String placeholderAvatar =
      'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop';
}
