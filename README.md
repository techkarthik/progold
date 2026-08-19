# ProGold ERP & Multi-Tenant Platform

ProGold is an enterprise-grade ERP and gold management system built with Flutter (Frontend) and Node.js / Express with Turso multi-tenant database (Backend).

## Architecture

- **`frontend/`**: Flutter Web & Mobile Application featuring responsive UI, POS & billing, tenant management, catalogue, and scheme management.
- **`backend/`**: Node.js & Express REST API powered by Turso LibSQL multi-tenant database architecture, JWT authentication, and automated email services.

## Getting Started

### Prerequisites
- Node.js (v18+)
- Flutter SDK (v3.0+)
- Turso CLI / LibSQL

### Backend Setup
1. Navigate to backend:
   ```bash
   cd backend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Copy environment variables:
   ```bash
   cp .env.example .env
   ```
   Configure your Turso and SMTP credentials.
4. Run server:
   ```bash
   npm start
   ```

### Frontend Setup
1. Navigate to frontend:
   ```bash
   cd frontend
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run app:
   ```bash
   flutter run -d chrome
   ```
