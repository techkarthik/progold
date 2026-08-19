import { masterTurso } from "./turso.js";

/**
 * Initializes the required database tables in Master Turso DB.
 */
export async function initMasterSchema() {
  console.log("Initializing Master Turso Schema...");
  try {
    // 1. Create tenants table
    await masterTurso.execute(`
      CREATE TABLE IF NOT EXISTS tenants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        contact_number TEXT NOT NULL,
        turso_url TEXT NOT NULL,
        turso_token TEXT NOT NULL,
        valid_from TEXT NOT NULL,
        valid_to TEXT NOT NULL,
        status TEXT DEFAULT 'ACTIVE',
        business_name TEXT DEFAULT 'ProGold Business',
        business_logo TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // Safe column additions for existing installations
    try {
      await masterTurso.execute(`ALTER TABLE tenants ADD COLUMN business_name TEXT DEFAULT 'ProGold Business';`);
    } catch (_) {}

    try {
      await masterTurso.execute(`ALTER TABLE tenants ADD COLUMN business_logo TEXT DEFAULT '';`);
    } catch (_) {}

    // 2. Create email_otps table
    await masterTurso.execute(`
      CREATE TABLE IF NOT EXISTS email_otps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL,
        otp_code TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        is_verified INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      );
    `);

    // Create index on email for quick lookups
    await masterTurso.execute(`
      CREATE INDEX IF NOT EXISTS idx_tenants_email ON tenants (email);
    `);
    await masterTurso.execute(`
      CREATE INDEX IF NOT EXISTS idx_otps_email ON email_otps (email);
    `);

    console.log(" Master Turso Database Schema initialized successfully.");
  } catch (error) {
    console.error(" Error initializing Master Turso Database Schema:", error);
    throw error;
  }
}
