# Artisanal Lane

**A curated craft marketplace connecting approved artisan vendors with buyers across South Africa.**

Artisanal Lane is a premium, Flutter-based two-sided marketplace application. It features dedicated vendor shops for storytelling and branding, a curated browsing experience for high-quality handmade items, secure escrow-based payments via PayFast, and an invite-only vendor model that maintains high marketplace standards.

---

## Tech Stack

| Component       | Technology        | Benefit                                                        |
| --------------- | ----------------- | -------------------------------------------------------------- |
| Mobile App      | Flutter           | Native performance on iOS & Android from a single codebase     |
| Backend         | Supabase          | Scalable, real-time database and secure authentication         |
| Database        | PostgreSQL        | Industry-standard reliability for transaction data             |
| Storage         | Supabase Storage  | High-speed hosting for product images and branding assets      |
| Payments        | PayFast           | Trusted South African payment gateway with escrow support      |
| Admin Dashboard | Flutter Web       | Shared codebase with the mobile app for rapid development      |

---

## Documentation

All project documentation lives in the [`docs/`](docs/) directory:

| #  | Document                                                              | Description                                         |
| -- | --------------------------------------------------------------------- | --------------------------------------------------- |
| 01 | [Product Requirements](docs/01-product-requirements.md)               | PRD with vision, features, and scope                |
| 02 | [Technical Architecture](docs/02-technical-architecture.md)           | System design, auth strategy, and infrastructure    |
| 03 | [API Specification](docs/03-api-specification.md)                     | REST endpoints, request/response schemas, webhooks  |
| 04 | [Database Schema](docs/04-database-schema.md)                        | PostgreSQL tables, ER diagram, RLS policies         |
| 05 | [User Flows](docs/05-user-flows.md)                                  | Buyer, Vendor, and Admin journey flowcharts         |
| 06 | [Flutter Project Structure](docs/06-flutter-project-structure.md)    | Folder architecture, conventions, state management  |
| 07 | [Admin Dashboard Spec](docs/07-admin-dashboard-spec.md)              | Web-based admin panel pages and functionality       |
| 08 | [Deployment Guide](docs/08-deployment-guide.md)                      | CI/CD, app store submissions, Supabase setup        |

---

## Quick Start

Refer to the [Deployment Guide](docs/08-deployment-guide.md) for full setup instructions covering:

- Supabase project creation and configuration
- Flutter development environment setup
- PayFast sandbox and production integration
- CI/CD pipeline with GitHub Actions
- App Store and Google Play submission

---

## Project Status

This project is currently in the **design and documentation phase** (Phase 1). Development will begin once designs are signed off.

---

## License

Proprietary -- All rights reserved. This project is developed for Nicolette Hendricks by The Online Agency.
