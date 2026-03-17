class AppConstants {
  AppConstants._();

  static const String appName = 'Artisan Lane';
  static const String currency = 'R';
  static const String currencyCode = 'ZAR';
  static const String authRedirectUrl = 'artisanlane://login-callback';
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '1047012816139-8tott1eo69fltvgbgimg8fflqb95co3k.apps.googleusercontent.com',
  );
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue:
        '1047012816139-g1ms8kvei782freogsoba9b3fp14juen.apps.googleusercontent.com',
  );

  // Supabase
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://byckurabenbunsbrzcpl.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ5Y2t1cmFiZW5idW5zYnJ6Y3BsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA3MTA0MjgsImV4cCI6MjA4NjI4NjQyOH0.4ElDNdxVtTxyCeEg9Yx-N1jUrNijTr54bmCPkHoW33A',
  );

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
