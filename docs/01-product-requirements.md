# Product Requirements Document (PRD)

**Project:** Artisanal Lane -- Curated Craft Marketplace
**Prepared for:** Nicolette Hendricks
**Prepared by:** The Online Agency
**Version:** 1.0
**Date:** 20 January 2026

---

## Table of Contents

1. [Vision and Objectives](#1-vision-and-objectives)
2. [Target Users](#2-target-users)
3. [Feature Requirements](#3-feature-requirements)
4. [Payment and Escrow](#4-payment-and-escrow)
5. [Logistics](#5-logistics)
6. [Non-Functional Requirements](#6-non-functional-requirements)
7. [Out of Scope](#7-out-of-scope)
8. [Success Metrics](#8-success-metrics)

---

## 1. Vision and Objectives

### Vision

Artisanal Lane is a premium mobile marketplace that empowers South African artisans to sell their handmade and curated goods to a nationwide audience. The platform champions quality over quantity through an invite-only vendor model, ensuring every product listed meets a high standard of craftsmanship.

### Objectives

- **Empower Artisans:** Provide vendors with dedicated shop spaces for branding, storytelling, and product management.
- **Curated Experience:** Deliver a streamlined, high-quality browsing experience for buyers seeking unique, handmade items.
- **Trusted Transactions:** Implement escrow-based payments so both buyers and vendors transact with confidence.
- **Quality Control:** Maintain marketplace standards through an invite-only vendor model with admin oversight.
- **South African Focus:** Tailor the platform to the South African market, including local payment gateways and courier options.

---

## 2. Target Users

### 2.1 Buyers

Individuals looking to discover and purchase unique, handmade, or artisanal products from South African craftspeople.

**Characteristics:**
- Appreciates quality and craftsmanship over mass-produced goods.
- Values the story behind the product and the maker.
- Comfortable with mobile shopping and digital payments.
- Located primarily in South Africa.

### 2.2 Vendors (Artisans)

Independent craftspeople, makers, and small-batch producers who create handmade or curated products.

**Characteristics:**
- Requires an easy-to-use platform for listing and managing products.
- Values brand identity and the ability to tell their story.
- Needs reliable, transparent payment processing.
- May have limited technical expertise.

### 2.3 Admins (Platform Operators)

The Artisanal Lane team responsible for maintaining marketplace quality and resolving issues.

**Characteristics:**
- Needs efficient tools for vendor approval and content moderation.
- Requires visibility into platform metrics and financials.
- Must be able to handle disputes fairly and promptly.

---

## 3. Feature Requirements

### 3.1 Authentication and Security

| ID     | Requirement                                                    | Priority |
| ------ | -------------------------------------------------------------- | -------- |
| AUTH-1 | Secure email-based registration and login                      | Must     |
| AUTH-2 | Social login (Google, Apple)                                   | Must     |
| AUTH-3 | Email verification on sign-up                                  | Must     |
| AUTH-4 | Password reset via email                                       | Must     |
| AUTH-5 | Role-based access control (Buyer, Vendor, Admin)               | Must     |
| AUTH-6 | Session management with secure token refresh                   | Must     |

### 3.2 Buyer Features

| ID      | Requirement                                                   | Priority |
| ------- | ------------------------------------------------------------- | -------- |
| BUY-1   | Onboarding flow with account creation                         | Must     |
| BUY-2   | Home feed with curated/featured items                         | Must     |
| BUY-3   | **Items View:** Browse products by category                   | Must     |
| BUY-4   | **Shops View:** Browse vendor directory by artisan            | Must     |
| BUY-5   | Search functionality with text query                          | Must     |
| BUY-6   | Filter products by category, price range, and location        | Must     |
| BUY-7   | Sort products (newest, price low-high, price high-low)        | Should   |
| BUY-8   | Favourites / wishlist functionality                           | Must     |
| BUY-9   | Product detail page (images, description, price, vendor info) | Must     |
| BUY-10  | Shopping cart with quantity management                         | Must     |
| BUY-11  | Checkout flow with shipping method selection                  | Must     |
| BUY-12  | PayFast payment integration at checkout                       | Must     |
| BUY-13  | Order confirmation screen                                     | Must     |
| BUY-14  | Order history with status tracking                            | Must     |
| BUY-15  | Confirm receipt of order (triggers escrow release)            | Must     |
| BUY-16  | Raise a dispute on an order                                   | Should   |
| BUY-17  | Push notifications for order status updates                   | Should   |

### 3.3 Vendor Features (Invite-Only)

| ID      | Requirement                                                   | Priority |
| ------- | ------------------------------------------------------------- | -------- |
| VEN-1   | Invite code entry to begin vendor application                 | Must     |
| VEN-2   | Vendor application form (business name, motivation, details)  | Must     |
| VEN-3   | Application status tracking (pending, approved, rejected)     | Must     |
| VEN-4   | Shop profile setup (name, bio, brand story)                   | Must     |
| VEN-5   | Shop branding (cover image, logo upload)                      | Must     |
| VEN-6   | Product creation (title, description, images, price, stock)   | Must     |
| VEN-7   | Product editing and unpublishing                              | Must     |
| VEN-8   | Product categorization                                        | Must     |
| VEN-9   | Stock / inventory management                                  | Must     |
| VEN-10  | Order management (view incoming orders)                       | Must     |
| VEN-11  | Mark order as shipped with tracking number                    | Must     |
| VEN-12  | Earnings dashboard (total sales, pending payouts, released)   | Must     |
| VEN-13  | Push notifications for new orders                             | Should   |
| VEN-14  | Compare-at / sale pricing                                     | Should   |

### 3.4 Admin Features

| ID      | Requirement                                                   | Priority |
| ------- | ------------------------------------------------------------- | -------- |
| ADM-1   | Vendor application review (list, detail, approve/reject)      | Must     |
| ADM-2   | Product listing moderation (flag, approve, remove)            | Must     |
| ADM-3   | Order dispute management (view, investigate, resolve)         | Must     |
| ADM-4   | Invite code generation and management                         | Must     |
| ADM-5   | Platform analytics dashboard (revenue, users, orders)         | Should   |
| ADM-6   | Payout oversight and reporting                                | Should   |
| ADM-7   | User management (view, suspend accounts)                      | Should   |

---

## 4. Payment and Escrow

### 4.1 Payment Gateway

**Provider:** PayFast

PayFast is a trusted South African payment gateway that supports credit/debit cards, EFT, and mobile payment methods familiar to the local market.

### 4.2 Escrow Flow

To ensure trust between buyers and vendors, the platform implements a secure escrow mechanism:

```
1. Buyer places an order and pays at checkout.
2. Funds are held securely (escrow hold).
3. Vendor is notified of the new order.
4. Vendor ships the product and provides a tracking number.
5. Buyer receives the product and confirms receipt.
6. Funds are released to the Vendor.
```

**Edge Cases:**
- If the buyer does not confirm receipt within 14 days of delivery, funds are auto-released to the vendor.
- If the buyer raises a dispute, funds remain held until an admin resolves the dispute.
- Refunds are processed back to the buyer's original payment method.

### 4.3 Commission Model

The platform may deduct a commission percentage from each transaction before releasing funds to the vendor. The commission rate is configurable by admins.

---

## 5. Logistics

### 5.1 Shipping Options

The platform supports the following South African logistics providers as selectable options during checkout:

| Provider    | Type              | Description                                        |
| ----------- | ----------------- | -------------------------------------------------- |
| Courier Guy | Door-to-door      | National courier delivery to buyer's address        |
| Pargo       | Pickup point      | Collection from Pargo pickup points nationwide      |
| PAXI        | Pickup point      | Collection from PEP stores and PAXI points          |
| Market Pickup | In-person       | Buyer collects directly from vendor at a market/event |

### 5.2 Shipping Workflow (Phase 1 -- Manual)

1. Buyer selects a shipping method at checkout.
2. Vendor receives the order with the selected shipping method.
3. Vendor prepares and ships the order.
4. Vendor marks the order as "Shipped" and enters a tracking number (where applicable).
5. Buyer is notified and can track the order.
6. Buyer confirms receipt upon delivery.

> **Note:** Automated courier API integrations (live rates, booking, label generation) are scoped for Phase 2 and are not included in this release.

---

## 6. Non-Functional Requirements

### 6.1 Performance

| Metric               | Target                                  |
| -------------------- | --------------------------------------- |
| App launch time      | < 3 seconds (cold start)               |
| API response time    | < 500ms for standard queries            |
| Image loading        | Progressive loading with placeholders   |
| Offline support      | Cached browsing for previously viewed items |

### 6.2 Security

- All data transmitted over HTTPS/TLS.
- Supabase Row Level Security (RLS) enforced on all tables.
- Sensitive data (payment tokens) never stored on client.
- API keys rotated periodically; service role key never exposed to client.
- Input validation and sanitization on all user inputs.

### 6.3 Scalability

- Supabase auto-scaling for database and auth.
- Image optimization and CDN delivery via Supabase Storage.
- Pagination on all list endpoints to prevent over-fetching.
- Database indexes on frequently queried columns.

### 6.4 Accessibility

- Minimum AA contrast ratios for text and UI elements.
- Screen reader support via Flutter's Semantics widgets.
- Touch targets minimum 48x48dp.

### 6.5 Supported Platforms

| Platform | Minimum Version |
| -------- | --------------- |
| Android  | 6.0 (API 23)   |
| iOS      | 14.0            |

---

## 7. Out of Scope

The following items are explicitly excluded from this release and may be considered for future phases:

- Marketing strategy, paid advertising, or influencer partnerships.
- Content creation (product photography or copywriting).
- Automated courier API integrations (live rates, label generation, booking).
- Companion / marketing website.
- In-app messaging between buyers and vendors.
- Multi-currency support (ZAR only).
- Vendor subscription or tiered pricing plans.
- Reviews and ratings system.

---

## 8. Success Metrics

| Metric                        | Target (6 months post-launch) |
| ----------------------------- | ----------------------------- |
| Registered buyers             | 1,000+                        |
| Active vendors                | 50+                           |
| Monthly transactions          | 200+                          |
| Average order value           | R250+                         |
| App store rating              | 4.0+ stars                    |
| Dispute rate                  | < 5% of transactions          |
| Buyer return rate             | > 30%                         |
