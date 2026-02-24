# Admin Dashboard Specification

**Project:** Artisanal Lane -- Curated Craft Marketplace
**Version:** 1.0

---

## Table of Contents

1. [Overview](#1-overview)
2. [Technology Choice](#2-technology-choice)
3. [Access Control](#3-access-control)
4. [Page Specifications](#4-page-specifications)
5. [Navigation Structure](#5-navigation-structure)
6. [Data Refresh and Real-Time](#6-data-refresh-and-real-time)
7. [Responsive Design](#7-responsive-design)

---

## 1. Overview

The Admin Dashboard is a web-based control panel for platform operators to manage the Artisanal Lane marketplace. It provides tools for vendor approval, product moderation, order and dispute management, invite code generation, and platform analytics.

### Target Users

- **Platform Owner** (Nicolette Hendricks): Full access to all features.
- **Moderators** (future): Limited access to content moderation and dispute handling.

### Key Objectives

- Efficient vendor application review and approval workflow.
- Quick access to flagged or reported product listings.
- Clear visibility into order status and dispute resolution.
- High-level analytics for business decision-making.
- Simple invite code generation for controlled vendor onboarding.

---

## 2. Technology Choice

**Recommendation: Flutter Web**

The admin dashboard will be built using Flutter Web, sharing the same codebase (models, services, repositories) as the mobile app. This approach provides:

| Benefit                  | Description                                              |
| ------------------------ | -------------------------------------------------------- |
| Code reuse               | Shared models, services, and repositories with mobile app |
| Consistent data handling | Same Supabase SDK and data layer                          |
| Single language           | All code in Dart, reducing context switching              |
| Rapid development        | Features built once, used in both mobile and web          |

### Hosting

The admin dashboard will be deployed as a static Flutter Web build to **Vercel** or **Netlify**, both of which offer:
- Free tier sufficient for admin usage
- Automatic HTTPS
- Simple CI/CD integration via GitHub

---

## 3. Access Control

### Authentication

Admins log in through the same Supabase Auth system as the mobile app, using email and password. Social login is optional for admin accounts.

### Route Protection

All admin routes are protected by a guard that checks:

1. User is authenticated (valid JWT).
2. User's `profiles.role` is `admin`.

```dart
redirect: (context, state) {
  final user = ref.read(authProvider);
  final isAdmin = user?.role == 'admin';

  if (!isAdmin) return '/unauthorized';
  return null;
}
```

### Unauthorized Access

Non-admin users who attempt to access the dashboard URL are redirected to a simple "Unauthorized" page with a link back to the mobile app.

---

## 4. Page Specifications

### 4.1 Dashboard Home

The landing page after login, providing a high-level overview of platform health.

#### Metrics Cards (Top Row)

| Metric                | Data Source                                    | Display     |
| --------------------- | ---------------------------------------------- | ----------- |
| Total Orders          | `COUNT(orders)`                                | Number      |
| Revenue (All Time)    | `SUM(escrow_transactions.amount)`              | ZAR amount  |
| Revenue (This Month)  | `SUM(...)` where `created_at >= month start`   | ZAR amount  |
| Active Vendors        | `COUNT(shops) WHERE is_active = true`          | Number      |
| Pending Applications  | `COUNT(vendor_applications) WHERE status = 'pending'` | Number + badge |
| Open Disputes         | `COUNT(disputes) WHERE status = 'open'`        | Number + badge |

#### Quick Actions

- "Review Applications" button (links to Vendor Applications page).
- "Resolve Disputes" button (links to Disputes page).

#### Recent Activity Feed

A chronological list of the last 20 platform events:
- New vendor applications submitted
- Orders placed
- Disputes raised
- Vendors approved

---

### 4.2 Vendor Applications

A list view for managing vendor applications with filtering, detail viewing, and approve/reject actions.

#### List View

| Column         | Source                | Sortable | Filterable |
| -------------- | --------------------- | -------- | ---------- |
| Business Name  | `business_name`       | Yes      | Search     |
| Applicant      | `profiles.display_name` | Yes    | No         |
| Location       | `location`            | No       | Search     |
| Invite Code    | `invite_code`         | No       | No         |
| Status         | `status`              | No       | Dropdown   |
| Date Applied   | `created_at`          | Yes      | Date range |

#### Status Filter Options

- All
- Pending (default)
- Approved
- Rejected

#### Detail View (Side Panel or Modal)

When an application is selected, show:

| Field          | Content                              |
| -------------- | ------------------------------------ |
| Applicant Name | From `profiles`                      |
| Email          | From `profiles`                      |
| Business Name  | Application field                    |
| Motivation     | Application field (full text)        |
| Portfolio URL  | Clickable link                       |
| Location       | Application field                    |
| Invite Code    | Which code was used                  |
| Applied On     | Formatted date                       |

#### Actions

| Action   | Button Style | Effect                                                    |
| -------- | ------------ | --------------------------------------------------------- |
| Approve  | Green/Primary | Sets status to `approved`, updates role, creates shop     |
| Reject   | Red/Danger   | Sets status to `rejected`, shows confirmation dialog      |

---

### 4.3 Product Moderation

A list of all products with tools to review and moderate listings.

#### List View

| Column        | Source                   | Sortable | Filterable |
| ------------- | ------------------------ | -------- | ---------- |
| Product Image | `images[0]` (thumbnail) | No       | No         |
| Title         | `title`                 | Yes      | Search     |
| Shop          | `shops.name`            | Yes      | Dropdown   |
| Category      | `categories.name`       | No       | Dropdown   |
| Price         | `price`                 | Yes      | Range      |
| Stock         | `stock_qty`             | Yes      | No         |
| Published     | `is_published`          | No       | Toggle     |
| Created       | `created_at`            | Yes      | Date range |

#### Actions

| Action     | Effect                                        |
| ---------- | --------------------------------------------- |
| View       | Open product detail (all images, description)  |
| Unpublish  | Set `is_published = false`                     |
| Republish  | Set `is_published = true`                      |

---

### 4.4 Order Management

Overview of all orders across the platform.

#### List View

| Column       | Source                    | Sortable | Filterable |
| ------------ | ------------------------- | -------- | ---------- |
| Order ID     | `id` (truncated)         | No       | Search     |
| Buyer        | `profiles.display_name`  | Yes      | Search     |
| Shop         | `shops.name`             | Yes      | Dropdown   |
| Total        | `total`                  | Yes      | Range      |
| Status       | `status`                 | No       | Dropdown   |
| Shipping     | `shipping_method`        | No       | Dropdown   |
| Date         | `created_at`             | Yes      | Date range |

#### Status Filter Options

- All
- Pending
- Paid
- Shipped
- Delivered
- Disputed
- Refunded
- Cancelled

#### Detail View

| Section         | Content                                          |
| --------------- | ------------------------------------------------ |
| Order Info      | ID, status, total, shipping method, tracking     |
| Buyer Info      | Name, email                                       |
| Shop Info       | Shop name, vendor name                            |
| Items           | Product title, quantity, unit price, line total    |
| Escrow          | Escrow status, amount held, platform fee          |
| Timeline        | Created, paid, shipped, delivered timestamps       |

---

### 4.5 Dispute Resolution

A dedicated queue for managing open disputes.

#### List View

| Column         | Source                     | Sortable | Filterable |
| -------------- | -------------------------- | -------- | ---------- |
| Dispute ID     | `id` (truncated)          | No       | No         |
| Order ID       | `order_id` (truncated)    | No       | Search     |
| Raised By      | `profiles.display_name`   | Yes      | Search     |
| Reason         | `reason` (truncated)      | No       | No         |
| Status         | `status`                  | No       | Dropdown   |
| Date Raised    | `created_at`              | Yes      | Date range |

#### Detail View

| Section         | Content                                          |
| --------------- | ------------------------------------------------ |
| Dispute Info    | Full reason, status, date raised                 |
| Order Details   | All order info (items, amounts, shipping)        |
| Buyer Info      | Name, email, order history count                 |
| Vendor Info     | Shop name, vendor name, dispute history count    |
| Product Listing | Original product listing for comparison          |
| Tracking        | Shipping method and tracking number              |

#### Resolution Actions

| Action              | Button Style | Effect                                        |
| ------------------- | ------------ | --------------------------------------------- |
| Release to Vendor   | Primary      | Release escrow, close dispute, update order    |
| Refund to Buyer     | Danger       | Process refund, close dispute, update order    |
| Partial Resolution  | Warning      | Enter amounts, process partial refund/release  |

Each action requires:
- A written resolution note (mandatory text field).
- A confirmation dialog before execution.

---

### 4.6 Analytics

Platform performance metrics and trends.

#### Summary Metrics

- Total revenue (all time and current month)
- Total orders (all time and current month)
- Average order value
- Total registered buyers
- Total active vendors
- Dispute rate (percentage of orders with disputes)
- Buyer return rate (percentage of buyers with 2+ orders)

#### Charts

| Chart                     | Type       | Data                                  |
| ------------------------- | ---------- | ------------------------------------- |
| Revenue Over Time         | Line chart | Monthly revenue for the past 12 months |
| Orders Over Time          | Bar chart  | Monthly order count                    |
| Top Categories            | Pie chart  | Order count by category               |
| Top Vendors by Revenue    | Bar chart  | Top 10 vendors by total revenue        |
| User Growth               | Line chart | Cumulative buyers and vendors over time|
| Order Status Distribution | Donut chart| Breakdown of current order statuses    |

#### Filters

- Date range selector (preset: last 30 days, last 90 days, YTD, all time)

---

### 4.7 Invite Code Management

Generate and track invite codes for vendor onboarding.

#### List View

| Column       | Source              | Sortable | Filterable |
| ------------ | ------------------- | -------- | ---------- |
| Code         | `code`             | No       | Search     |
| Created By   | `profiles.display_name` | Yes  | No         |
| Used By      | `profiles.display_name` | Yes  | No         |
| Status       | `is_used`          | No       | Toggle     |
| Created      | `created_at`       | Yes      | Date range |
| Used On      | `used_at`          | Yes      | No         |

#### Actions

| Action          | Description                                    |
| --------------- | ---------------------------------------------- |
| Generate Codes  | Modal: enter count (1-20), generates new codes |
| Copy Code       | Copy individual code to clipboard              |
| Export          | Download CSV of all codes with usage status    |

#### Generation Modal

- Input: Number of codes to generate (1-20).
- Optional: Add a label/note for the batch.
- Output: List of generated codes with copy-all button.

---

## 5. Navigation Structure

### Sidebar Navigation

```
Artisanal Lane Admin
├── Dashboard          (/)
├── Vendor Applications (/applications)
├── Products           (/products)
├── Orders             (/orders)
├── Disputes           (/disputes)
├── Analytics          (/analytics)
├── Invite Codes       (/invites)
└── Settings           (/settings)
    ├── Profile
    └── Platform Config
```

### Header

- Artisanal Lane logo and "Admin" label.
- Notification bell with unread count (pending applications + open disputes).
- Admin user avatar and name with dropdown (Profile, Sign Out).

---

## 6. Data Refresh and Real-Time

### Automatic Refresh

| Page                 | Refresh Strategy                              |
| -------------------- | --------------------------------------------- |
| Dashboard Home       | Auto-refresh every 60 seconds                 |
| Vendor Applications  | Supabase Realtime subscription on table        |
| Orders               | Supabase Realtime subscription on table        |
| Disputes             | Supabase Realtime subscription on table        |
| Analytics            | Manual refresh button (queries can be heavy)   |
| Invite Codes         | Refresh on generate action                     |

### Realtime Subscriptions

The admin dashboard subscribes to Supabase Realtime for:

- `vendor_applications` table: New applications appear instantly.
- `orders` table: Status changes reflected in real time.
- `disputes` table: New disputes surface immediately.

---

## 7. Responsive Design

While primarily designed for desktop use, the admin dashboard should be functional on tablets.

### Breakpoints

| Breakpoint | Width       | Layout                            |
| ---------- | ----------- | --------------------------------- |
| Desktop    | >= 1200px   | Full sidebar + main content        |
| Tablet     | 768-1199px  | Collapsible sidebar + main content |
| Mobile     | < 768px     | Bottom nav or hamburger menu       |

### Design Priorities

1. **Desktop first:** Primary usage is expected on desktop browsers.
2. **Data tables:** Use horizontal scrolling on smaller screens rather than hiding columns.
3. **Detail views:** Use side panels on desktop, full-screen modals on tablet/mobile.
4. **Charts:** Responsive chart sizing with tooltip support for touch devices.
