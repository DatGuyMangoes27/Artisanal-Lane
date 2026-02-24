# API Specification

**Project:** Artisanal Lane -- Curated Craft Marketplace
**Version:** 1.0

---

## Table of Contents

1. [Overview](#1-overview)
2. [Authentication](#2-authentication)
3. [Auth Endpoints](#3-auth-endpoints)
4. [Vendor Endpoints](#4-vendor-endpoints)
5. [Marketplace Endpoints](#5-marketplace-endpoints)
6. [Cart and Order Endpoints](#6-cart-and-order-endpoints)
7. [Admin Endpoints](#7-admin-endpoints)
8. [Logistics Endpoints](#8-logistics-endpoints)
9. [Webhook Schemas](#9-webhook-schemas)
10. [Error Response Format](#10-error-response-format)

---

## 1. Overview

### Base URL

```
https://<project-ref>.supabase.co
```

### API Layers

| Layer            | Base Path              | Description                                   |
| ---------------- | ---------------------- | --------------------------------------------- |
| PostgREST        | `/rest/v1/`            | Auto-generated CRUD from PostgreSQL schema     |
| Auth             | `/auth/v1/`            | Supabase GoTrue authentication endpoints       |
| Storage          | `/storage/v1/`         | File upload and retrieval                      |
| Edge Functions   | `/functions/v1/`       | Custom serverless business logic               |

### Content Type

All request and response bodies use `application/json` unless otherwise noted.

### Pagination

List endpoints support pagination via query parameters:

| Parameter | Type    | Default | Description                  |
| --------- | ------- | ------- | ---------------------------- |
| `offset`  | integer | 0       | Number of records to skip    |
| `limit`   | integer | 20      | Maximum records to return    |

PostgREST also supports range headers: `Range: 0-19` for the first 20 records.

---

## 2. Authentication

### Headers

All authenticated requests require the following headers:

```
apikey: <SUPABASE_ANON_KEY>
Authorization: Bearer <USER_JWT_TOKEN>
```

Public (unauthenticated) requests only require the `apikey` header.

### Token Refresh

JWTs expire after 1 hour. The Supabase client SDK handles automatic refresh using the refresh token stored securely on-device.

---

## 3. Auth Endpoints

### 3.1 Sign Up

```
POST /auth/v1/signup
```

**Request Body:**

```json
{
  "email": "buyer@example.com",
  "password": "securePassword123",
  "data": {
    "display_name": "Jane Doe"
  }
}
```

**Response (200):**

```json
{
  "id": "uuid",
  "email": "buyer@example.com",
  "confirmation_sent_at": "2026-01-20T10:00:00Z",
  "created_at": "2026-01-20T10:00:00Z"
}
```

### 3.2 Sign In (Email/Password)

```
POST /auth/v1/token?grant_type=password
```

**Request Body:**

```json
{
  "email": "buyer@example.com",
  "password": "securePassword123"
}
```

**Response (200):**

```json
{
  "access_token": "eyJ...",
  "token_type": "bearer",
  "expires_in": 3600,
  "refresh_token": "abc123...",
  "user": {
    "id": "uuid",
    "email": "buyer@example.com",
    "role": "authenticated"
  }
}
```

### 3.3 Social OAuth (Google / Apple)

```
GET /auth/v1/authorize?provider=google
GET /auth/v1/authorize?provider=apple
```

Redirects the user to the OAuth provider. On success, Supabase issues a session token via the configured redirect URL.

### 3.4 Password Reset

```
POST /auth/v1/recover
```

**Request Body:**

```json
{
  "email": "buyer@example.com"
}
```

**Response (200):**

```json
{}
```

Sends a password reset email to the user.

### 3.5 Sign Out

```
POST /auth/v1/logout
```

**Headers:** Requires `Authorization: Bearer <JWT>`

**Response (204):** No content.

---

## 4. Vendor Endpoints

### 4.1 Submit Vendor Application

```
POST /rest/v1/vendor_applications
```

**Headers:** Authenticated (buyer role)

**Request Body:**

```json
{
  "business_name": "Cape Craft Studio",
  "motivation": "I create handmade leather goods using traditional techniques...",
  "invite_code": "ART-2026-XYZW",
  "portfolio_url": "https://instagram.com/capecraft",
  "location": "Cape Town, Western Cape"
}
```

**Response (201):**

```json
{
  "id": "uuid",
  "user_id": "uuid",
  "business_name": "Cape Craft Studio",
  "status": "pending",
  "created_at": "2026-01-20T10:00:00Z"
}
```

### 4.2 Get Application Status

```
GET /rest/v1/vendor_applications?user_id=eq.<user_id>&select=*
```

**Headers:** Authenticated

**Response (200):**

```json
[
  {
    "id": "uuid",
    "user_id": "uuid",
    "business_name": "Cape Craft Studio",
    "motivation": "...",
    "status": "pending",
    "invite_code": "ART-2026-XYZW",
    "reviewed_by": null,
    "reviewed_at": null,
    "created_at": "2026-01-20T10:00:00Z"
  }
]
```

### 4.3 Get / Update Shop Profile

**Get:**

```
GET /rest/v1/shops?vendor_id=eq.<user_id>&select=*
```

**Update:**

```
PATCH /rest/v1/shops?id=eq.<shop_id>
```

**Request Body:**

```json
{
  "name": "Cape Craft Studio",
  "slug": "cape-craft-studio",
  "bio": "Handmade leather goods from Cape Town.",
  "brand_story": "Our journey started in a small workshop...",
  "cover_image_url": "https://<project>.supabase.co/storage/v1/object/public/shop-assets/<path>",
  "logo_url": "https://<project>.supabase.co/storage/v1/object/public/shop-assets/<path>"
}
```

**Response (200):**

```json
{
  "id": "uuid",
  "vendor_id": "uuid",
  "name": "Cape Craft Studio",
  "slug": "cape-craft-studio",
  "bio": "Handmade leather goods from Cape Town.",
  "brand_story": "Our journey started in a small workshop...",
  "cover_image_url": "https://...",
  "logo_url": "https://...",
  "is_active": true,
  "created_at": "2026-01-20T10:00:00Z"
}
```

### 4.4 Product CRUD

**Create Product:**

```
POST /rest/v1/products
```

**Request Body:**

```json
{
  "shop_id": "uuid",
  "category_id": "uuid",
  "title": "Hand-Stitched Leather Wallet",
  "description": "Premium full-grain leather wallet, hand-stitched with waxed thread.",
  "price": 450.00,
  "compare_at_price": 550.00,
  "stock_qty": 25,
  "images": [
    "https://<project>.supabase.co/storage/v1/object/public/product-images/<path1>",
    "https://<project>.supabase.co/storage/v1/object/public/product-images/<path2>"
  ],
  "is_published": true
}
```

**Response (201):**

```json
{
  "id": "uuid",
  "shop_id": "uuid",
  "category_id": "uuid",
  "title": "Hand-Stitched Leather Wallet",
  "description": "Premium full-grain leather wallet...",
  "price": 450.00,
  "compare_at_price": 550.00,
  "stock_qty": 25,
  "images": ["https://...", "https://..."],
  "is_published": true,
  "created_at": "2026-01-20T10:00:00Z",
  "updated_at": "2026-01-20T10:00:00Z"
}
```

**Update Product:**

```
PATCH /rest/v1/products?id=eq.<product_id>
```

**List Vendor's Products:**

```
GET /rest/v1/products?shop_id=eq.<shop_id>&select=*&order=created_at.desc
```

**Unpublish Product:**

```
PATCH /rest/v1/products?id=eq.<product_id>
```

```json
{
  "is_published": false
}
```

### 4.5 Vendor Orders

```
GET /rest/v1/orders?shop_id=eq.<shop_id>&select=*,order_items(*)&order=created_at.desc
```

**Response (200):**

```json
[
  {
    "id": "uuid",
    "buyer_id": "uuid",
    "shop_id": "uuid",
    "status": "paid",
    "total": 450.00,
    "shipping_method": "courier_guy",
    "tracking_number": null,
    "created_at": "2026-01-21T14:00:00Z",
    "updated_at": "2026-01-21T14:00:00Z",
    "order_items": [
      {
        "id": "uuid",
        "product_id": "uuid",
        "quantity": 1,
        "unit_price": 450.00
      }
    ]
  }
]
```

### 4.6 Vendor Earnings

```
GET /rest/v1/escrow_transactions?select=*,orders!inner(shop_id)&orders.shop_id=eq.<shop_id>
```

Returns escrow records for the vendor's orders, showing held, released, and refunded amounts.

---

## 5. Marketplace Endpoints

### 5.1 List Products (Items View)

```
GET /rest/v1/products?is_published=eq.true&select=*,shops(name,slug,logo_url)&order=created_at.desc&offset=0&limit=20
```

**Query Filters:**

| Parameter                        | Description                      |
| -------------------------------- | -------------------------------- |
| `category_id=eq.<uuid>`         | Filter by category               |
| `price=gte.100&price=lte.500`   | Price range filter               |
| `title=ilike.*leather*`         | Text search in title             |
| `order=price.asc`               | Sort by price ascending          |
| `order=price.desc`              | Sort by price descending         |
| `order=created_at.desc`         | Sort by newest                   |

**Response (200):**

```json
[
  {
    "id": "uuid",
    "shop_id": "uuid",
    "category_id": "uuid",
    "title": "Hand-Stitched Leather Wallet",
    "description": "Premium full-grain leather...",
    "price": 450.00,
    "compare_at_price": 550.00,
    "stock_qty": 25,
    "images": ["https://..."],
    "is_published": true,
    "created_at": "2026-01-20T10:00:00Z",
    "shops": {
      "name": "Cape Craft Studio",
      "slug": "cape-craft-studio",
      "logo_url": "https://..."
    }
  }
]
```

### 5.2 Get Product Detail

```
GET /rest/v1/products?id=eq.<product_id>&select=*,shops(id,name,slug,bio,logo_url),categories(name,slug)
```

**Response (200):**

```json
{
  "id": "uuid",
  "shop_id": "uuid",
  "category_id": "uuid",
  "title": "Hand-Stitched Leather Wallet",
  "description": "Premium full-grain leather wallet, hand-stitched with waxed thread...",
  "price": 450.00,
  "compare_at_price": 550.00,
  "stock_qty": 25,
  "images": [
    "https://<project>.supabase.co/storage/v1/object/public/product-images/...",
    "https://<project>.supabase.co/storage/v1/object/public/product-images/..."
  ],
  "is_published": true,
  "created_at": "2026-01-20T10:00:00Z",
  "updated_at": "2026-01-20T10:00:00Z",
  "shops": {
    "id": "uuid",
    "name": "Cape Craft Studio",
    "slug": "cape-craft-studio",
    "bio": "Handmade leather goods from Cape Town.",
    "logo_url": "https://..."
  },
  "categories": {
    "name": "Leather Goods",
    "slug": "leather-goods"
  }
}
```

### 5.3 List Shops (Shops View)

```
GET /rest/v1/shops?is_active=eq.true&select=*&order=name.asc&offset=0&limit=20
```

**Response (200):**

```json
[
  {
    "id": "uuid",
    "vendor_id": "uuid",
    "name": "Cape Craft Studio",
    "slug": "cape-craft-studio",
    "bio": "Handmade leather goods from Cape Town.",
    "brand_story": "Our journey started...",
    "cover_image_url": "https://...",
    "logo_url": "https://...",
    "is_active": true,
    "created_at": "2026-01-20T10:00:00Z"
  }
]
```

### 5.4 Get Shop Detail with Products

```
GET /rest/v1/shops?slug=eq.cape-craft-studio&select=*,products(id,title,price,compare_at_price,images,is_published)
```

### 5.5 List Categories

```
GET /rest/v1/categories?select=*&order=sort_order.asc
```

**Response (200):**

```json
[
  {
    "id": "uuid",
    "name": "Leather Goods",
    "slug": "leather-goods",
    "icon_url": "https://...",
    "sort_order": 1
  },
  {
    "id": "uuid",
    "name": "Ceramics",
    "slug": "ceramics",
    "icon_url": "https://...",
    "sort_order": 2
  }
]
```

### 5.6 Favourites

**Add Favourite:**

```
POST /rest/v1/favourites
```

```json
{
  "product_id": "uuid"
}
```

**Remove Favourite:**

```
DELETE /rest/v1/favourites?user_id=eq.<user_id>&product_id=eq.<product_id>
```

**List Favourites:**

```
GET /rest/v1/favourites?user_id=eq.<user_id>&select=*,products(id,title,price,images,shops(name,slug))
```

---

## 6. Cart and Order Endpoints

### 6.1 Get or Create Cart

```
GET /rest/v1/carts?user_id=eq.<user_id>&select=*,cart_items(*,products(id,title,price,stock_qty,images))
```

If no cart exists, create one:

```
POST /rest/v1/carts
```

```json
{
  "user_id": "uuid"
}
```

### 6.2 Add Item to Cart

```
POST /rest/v1/cart_items
```

```json
{
  "cart_id": "uuid",
  "product_id": "uuid",
  "quantity": 1
}
```

### 6.3 Update Cart Item Quantity

```
PATCH /rest/v1/cart_items?id=eq.<cart_item_id>
```

```json
{
  "quantity": 2
}
```

### 6.4 Remove Cart Item

```
DELETE /rest/v1/cart_items?id=eq.<cart_item_id>
```

### 6.5 Checkout (Initiate Payment)

```
POST /functions/v1/create-checkout
```

**Headers:** Authenticated

**Request Body:**

```json
{
  "cart_id": "uuid",
  "shipping_method": "courier_guy",
  "shipping_address": {
    "street": "123 Main Road",
    "city": "Cape Town",
    "province": "Western Cape",
    "postal_code": "8001",
    "country": "ZA"
  }
}
```

**Response (200):**

```json
{
  "order_id": "uuid",
  "payment_url": "https://www.payfast.co.za/eng/process?...",
  "amount": 450.00,
  "currency": "ZAR"
}
```

### 6.6 Order History (Buyer)

```
GET /rest/v1/orders?buyer_id=eq.<user_id>&select=*,order_items(*,products(title,images))&order=created_at.desc
```

**Response (200):**

```json
[
  {
    "id": "uuid",
    "buyer_id": "uuid",
    "shop_id": "uuid",
    "status": "shipped",
    "total": 450.00,
    "shipping_method": "courier_guy",
    "tracking_number": "TCG123456789",
    "created_at": "2026-01-21T14:00:00Z",
    "updated_at": "2026-01-22T09:00:00Z",
    "order_items": [
      {
        "id": "uuid",
        "product_id": "uuid",
        "quantity": 1,
        "unit_price": 450.00,
        "products": {
          "title": "Hand-Stitched Leather Wallet",
          "images": ["https://..."]
        }
      }
    ]
  }
]
```

### 6.7 Confirm Receipt (Release Escrow)

```
POST /functions/v1/release-escrow
```

**Headers:** Authenticated (buyer)

**Request Body:**

```json
{
  "order_id": "uuid"
}
```

**Response (200):**

```json
{
  "order_id": "uuid",
  "status": "delivered",
  "escrow_status": "released",
  "released_at": "2026-01-25T12:00:00Z"
}
```

### 6.8 Raise Dispute

```
POST /rest/v1/disputes
```

**Headers:** Authenticated

**Request Body:**

```json
{
  "order_id": "uuid",
  "reason": "Item received is significantly different from the listing photos."
}
```

**Response (201):**

```json
{
  "id": "uuid",
  "order_id": "uuid",
  "raised_by": "uuid",
  "reason": "Item received is significantly different from the listing photos.",
  "status": "open",
  "created_at": "2026-01-26T10:00:00Z"
}
```

---

## 7. Admin Endpoints

All admin endpoints require an authenticated user with `role = 'admin'` in their profile.

### 7.1 List Vendor Applications

```
GET /rest/v1/vendor_applications?select=*,profiles(display_name,email)&order=created_at.desc
```

**Query Filters:**

| Parameter              | Description                     |
| ---------------------- | ------------------------------- |
| `status=eq.pending`    | Show only pending applications  |
| `status=eq.approved`   | Show only approved applications |
| `status=eq.rejected`   | Show only rejected applications |

### 7.2 Approve / Reject Vendor Application

```
PATCH /rest/v1/vendor_applications?id=eq.<application_id>
```

**Approve:**

```json
{
  "status": "approved",
  "reviewed_by": "<admin_user_id>",
  "reviewed_at": "2026-01-21T10:00:00Z"
}
```

On approval, a database trigger or Edge Function should:
1. Update the user's `profiles.role` to `vendor`.
2. Create a new `shops` record for the vendor.

**Reject:**

```json
{
  "status": "rejected",
  "reviewed_by": "<admin_user_id>",
  "reviewed_at": "2026-01-21T10:00:00Z"
}
```

### 7.3 Moderate Product Listings

**Flag/remove a product:**

```
PATCH /rest/v1/products?id=eq.<product_id>
```

```json
{
  "is_published": false
}
```

**List all products (including unpublished) for moderation:**

```
GET /rest/v1/products?select=*,shops(name)&order=created_at.desc
```

> Note: Admin RLS policy allows reading all products regardless of `is_published` status.

### 7.4 Manage Disputes

**List disputes:**

```
GET /rest/v1/disputes?select=*,orders(*),profiles!raised_by(display_name)&order=created_at.desc
```

**Resolve dispute (release funds):**

```
PATCH /rest/v1/disputes?id=eq.<dispute_id>
```

```json
{
  "status": "resolved",
  "resolution": "After review, the item matches the listing. Funds released to vendor."
}
```

Then call:

```
POST /functions/v1/release-escrow
```

```json
{
  "order_id": "uuid"
}
```

**Resolve dispute (refund):**

```
PATCH /rest/v1/disputes?id=eq.<dispute_id>
```

```json
{
  "status": "resolved",
  "resolution": "Item not as described. Full refund issued to buyer."
}
```

Then call:

```
POST /functions/v1/process-refund
```

```json
{
  "order_id": "uuid"
}
```

### 7.5 Generate Invite Codes

```
POST /functions/v1/generate-invite
```

**Headers:** Authenticated (admin)

**Request Body:**

```json
{
  "count": 5
}
```

**Response (200):**

```json
{
  "codes": [
    "ART-2026-A1B2",
    "ART-2026-C3D4",
    "ART-2026-E5F6",
    "ART-2026-G7H8",
    "ART-2026-I9J0"
  ]
}
```

### 7.6 Platform Analytics

```
GET /functions/v1/analytics
```

**Headers:** Authenticated (admin)

**Response (200):**

```json
{
  "total_buyers": 342,
  "total_vendors": 28,
  "total_orders": 1205,
  "total_revenue": 452300.00,
  "pending_applications": 5,
  "open_disputes": 2,
  "orders_this_month": 87,
  "revenue_this_month": 34500.00,
  "top_categories": [
    { "name": "Leather Goods", "order_count": 312 },
    { "name": "Ceramics", "order_count": 245 }
  ],
  "top_vendors": [
    { "shop_name": "Cape Craft Studio", "revenue": 89000.00 },
    { "shop_name": "Zulu Beadwork", "revenue": 67000.00 }
  ]
}
```

---

## 8. Logistics Endpoints

### 8.1 Get Shipping Options

```
GET /rest/v1/rpc/get_shipping_options
```

**Response (200):**

```json
[
  {
    "id": "courier_guy",
    "name": "The Courier Guy",
    "type": "door_to_door",
    "description": "National door-to-door courier delivery",
    "estimated_days": "2-5 business days"
  },
  {
    "id": "pargo",
    "name": "Pargo",
    "type": "pickup_point",
    "description": "Collection from Pargo pickup points nationwide",
    "estimated_days": "3-7 business days"
  },
  {
    "id": "paxi",
    "name": "PAXI",
    "type": "pickup_point",
    "description": "Collection from PEP stores and PAXI points",
    "estimated_days": "3-7 business days"
  },
  {
    "id": "market_pickup",
    "name": "Market Pickup",
    "type": "in_person",
    "description": "Collect directly from the vendor at a market or event",
    "estimated_days": "As arranged with vendor"
  }
]
```

### 8.2 Mark Order as Shipped (Vendor)

```
PATCH /rest/v1/orders?id=eq.<order_id>
```

**Headers:** Authenticated (vendor)

**Request Body:**

```json
{
  "status": "shipped",
  "tracking_number": "TCG123456789"
}
```

**Response (200):**

```json
{
  "id": "uuid",
  "status": "shipped",
  "tracking_number": "TCG123456789",
  "updated_at": "2026-01-22T09:00:00Z"
}
```

---

## 9. Webhook Schemas

### 9.1 PayFast ITN (Instant Transaction Notification)

**Endpoint:**

```
POST /functions/v1/payfast-itn
```

**PayFast sends the following form-encoded data:**

| Field              | Type   | Description                         |
| ------------------ | ------ | ----------------------------------- |
| `m_payment_id`     | string | Our order ID                        |
| `pf_payment_id`    | string | PayFast unique payment ID           |
| `payment_status`   | string | `COMPLETE`, `FAILED`, `PENDING`     |
| `item_name`        | string | Order description                   |
| `amount_gross`     | string | Total amount (e.g., "450.00")       |
| `amount_fee`       | string | PayFast fee                         |
| `amount_net`       | string | Net amount after fees               |
| `name_first`       | string | Buyer's first name                  |
| `name_last`        | string | Buyer's last name                   |
| `email_address`    | string | Buyer's email                       |
| `merchant_id`      | string | Our PayFast merchant ID             |
| `signature`        | string | MD5 signature for validation        |

**Validation Steps (in Edge Function):**
1. Verify the source IP is from PayFast's server range.
2. Validate the MD5 signature against our passphrase.
3. Confirm the `amount_gross` matches our stored order total.
4. Confirm `payment_status` is `COMPLETE`.
5. Update order status to `paid` and create escrow record.

**Response:** `200 OK` (plain text, no body)

---

## 10. Error Response Format

All API errors follow a consistent format:

```json
{
  "error": {
    "code": "RESOURCE_NOT_FOUND",
    "message": "The requested product does not exist.",
    "details": null,
    "hint": null
  }
}
```

### Common Error Codes

| HTTP Status | Code                    | Description                               |
| ----------- | ----------------------- | ----------------------------------------- |
| 400         | `BAD_REQUEST`           | Malformed request or invalid parameters   |
| 401         | `UNAUTHORIZED`          | Missing or invalid authentication token   |
| 403         | `FORBIDDEN`             | User does not have permission             |
| 404         | `RESOURCE_NOT_FOUND`    | Requested resource does not exist         |
| 409         | `CONFLICT`              | Duplicate record or constraint violation  |
| 422         | `VALIDATION_ERROR`      | Request body fails validation rules       |
| 429         | `RATE_LIMIT_EXCEEDED`   | Too many requests                         |
| 500         | `INTERNAL_ERROR`        | Unexpected server error                   |

### PostgREST-Specific Errors

PostgREST returns errors from PostgreSQL directly:

```json
{
  "code": "42501",
  "details": null,
  "hint": null,
  "message": "new row violates row-level security policy for table \"products\""
}
```
