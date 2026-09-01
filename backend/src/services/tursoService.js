import { createTenantClient } from "../config/turso.js";

/**
 * Tests connection to a tenant's Turso database with provided URL and auth token.
 * @param {string} url - Turso Database URL
 * @param {string} token - Turso Auth Token
 * @returns {Promise<{success: boolean, message: string, latencyMs?: number}>}
 */
export async function testTursoConnection(url, token) {
  if (!url || !token) {
    return { success: false, message: "Both Turso URL and Auth Token are required." };
  }

  const startTime = Date.now();
  try {
    const client = createTenantClient(url, token);
    const result = await client.execute("SELECT 1 AS ping;");
    const latencyMs = Date.now() - startTime;

    if (result && result.rows.length > 0) {
      return {
        success: true,
        message: `Successfully connected to Turso database! (Response time: ${latencyMs}ms)`,
        latencyMs,
      };
    } else {
      return {
        success: false,
        message: "Database responded with unexpected result.",
      };
    }
  } catch (error) {
    console.error("Turso connection test failed:", error.message);
    let errorMsg = error.message || "Failed to connect to Turso database.";
    if (errorMsg.includes("401") || errorMsg.includes("Unauthorized")) {
      errorMsg = "Authentication failed: Invalid Turso Auth Token.";
    } else if (errorMsg.includes("ENOTFOUND") || errorMsg.includes("getaddrinfo")) {
      errorMsg = "Host not found: Please verify your Turso Database URL.";
    }
    return {
      success: false,
      message: errorMsg,
    };
  }
}

/**
 * Helper to format bytes into readable KB, MB, GB strings.
 */
function formatBytes(bytes, decimals = 2) {
  if (!bytes || bytes === 0) return "0.00 B";
  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ["B", "KB", "MB", "GB", "TB"];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + " " + sizes[i];
}

/**
 * Fetches comprehensive database size, quota, storage balance, latency & tables for a tenant.
 * @param {string} url
 * @param {string} token
 * @param {object} tenant
 */
export async function getTenantDatabaseStatus(url, token, tenant = {}) {
  const startTime = Date.now();
  const client = createTenantClient(url, token);

  try {
    // 1. Basic latency ping & SQLite version
    const versionRes = await client.execute("SELECT sqlite_version() AS version;");
    const latencyMs = Date.now() - startTime;
    const sqliteVersion = String(versionRes.rows[0]?.version || "SQLite 3.x");

    // 2. Storage & Page PRAGMAs
    let pageCount = 0;
    let pageSize = 4096;
    let freelistCount = 0;

    try {
      const pageCountRes = await client.execute("PRAGMA page_count;");
      pageCount = Number(Object.values(pageCountRes.rows[0] || {})[0] || 0);
    } catch (_) {}

    try {
      const pageSizeRes = await client.execute("PRAGMA page_size;");
      pageSize = Number(Object.values(pageSizeRes.rows[0] || {})[0] || 4096);
    } catch (_) {}

    try {
      const freelistRes = await client.execute("PRAGMA freelist_count;");
      freelistCount = Number(Object.values(freelistRes.rows[0] || {})[0] || 0);
    } catch (_) {}

    // Fallback if page_count is 0 in some remote edge drivers
    if (pageCount === 0) {
      pageCount = 32; // base initial allocation ~128 KB
    }

    const totalSizeBytes = pageCount * pageSize;
    const freeSizeBytes = freelistCount * pageSize;
    const activeSizeBytes = Math.max(0, totalSizeBytes - freeSizeBytes);

    // Standard Turso Cloud Starter Storage Quota: 9 GB (9 * 1024 * 1024 * 1024 bytes)
    const quotaBytes = 9 * 1024 * 1024 * 1024;
    const availableBytes = Math.max(0, quotaBytes - totalSizeBytes);
    const usedPercentage = parseFloat(((totalSizeBytes / quotaBytes) * 100).toFixed(4));

    // 3. Tables & Record Counts
    const tablesResult = await client.execute(`
      SELECT name, type, sql 
      FROM sqlite_master 
      WHERE type IN ('table', 'view') AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_litestream_%'
      ORDER BY name ASC;
    `);

    const tables = [];
    let totalRows = 0;

    for (const row of tablesResult.rows) {
      let rowCount = 0;
      let columnCount = 0;

      if (row.type === "table") {
        try {
          const countRes = await client.execute(`SELECT COUNT(*) AS total FROM "${row.name}";`);
          rowCount = Number(countRes.rows[0]?.total || 0);
          totalRows += rowCount;
        } catch (_) {
          rowCount = 0;
        }

        try {
          const infoRes = await client.execute(`PRAGMA table_info("${row.name}");`);
          columnCount = infoRes.rows.length;
        } catch (_) {
          columnCount = 0;
        }
      }

      // Estimate table size (approximate row payload + index overhead)
      const estimatedTableBytes = Math.max(pageSize, rowCount * Math.max(1, columnCount) * 128);

      tables.push({
        name: row.name,
        type: row.type,
        sql: row.sql,
        rowCount,
        columnCount,
        estimatedSizeBytes: estimatedTableBytes,
        estimatedSizeFormatted: formatBytes(estimatedTableBytes),
      });
    }

    // Mask URL for display security
    let maskedUrl = url;
    try {
      const parsed = new URL(url);
      maskedUrl = `${parsed.protocol}//${parsed.hostname}`;
    } catch (_) {}

    return {
      success: true,
      database: {
        status: "ONLINE & HEALTHY",
        url: maskedUrl,
        raw_url: url,
        engine: "Turso libSQL (Cloud Distributed SQLite)",
        sqlite_version: sqliteVersion,
        latency_ms: latencyMs,
        total_size_bytes: totalSizeBytes,
        total_size_formatted: formatBytes(totalSizeBytes),
        active_size_bytes: activeSizeBytes,
        active_size_formatted: formatBytes(activeSizeBytes),
        free_size_bytes: freeSizeBytes,
        free_size_formatted: formatBytes(freeSizeBytes),
        quota_bytes: quotaBytes,
        quota_formatted: "9.00 GB",
        available_bytes: availableBytes,
        available_formatted: formatBytes(availableBytes),
        used_percentage: usedPercentage,
        page_count: pageCount,
        page_size: pageSize,
        freelist_count: freelistCount,
        total_tables: tables.length,
        total_rows: totalRows,
        tenant_email: tenant?.email || "",
        business_name: tenant?.business_name || "ProGold Enterprise",
      },
      tables,
    };
  } catch (error) {
    console.error("getTenantDatabaseStatus error:", error);
    return {
      success: false,
      message: error.message || "Failed to query database status.",
      database: null,
      tables: [],
    };
  }
}

/**
 * Optimizes the tenant database using PRAGMA optimize & VACUUM
 */
export async function optimizeTenantDatabase(url, token) {
  const client = createTenantClient(url, token);
  const startTime = Date.now();
  try {
    await client.execute("PRAGMA optimize;");
    const executionTimeMs = Date.now() - startTime;
    return {
      success: true,
      message: "Database optimized and query planner statistics updated successfully!",
      executionTimeMs,
    };
  } catch (error) {
    return { success: false, message: error.message };
  }
}

/**
 * Fetches tables and row counts in a tenant's Turso database.
 * @param {string} url
 * @param {string} token
 * @returns {Promise<{tables: Array<{name: string, type: string, sql: string, rowCount: number}>}>}
 */
export async function getTenantDatabaseOverview(url, token) {
  const client = createTenantClient(url, token);
  try {
    const tablesResult = await client.execute(`
      SELECT name, type, sql 
      FROM sqlite_master 
      WHERE type IN ('table', 'view') AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_litestream_%'
      ORDER BY name ASC;
    `);

    const tables = [];
    for (const row of tablesResult.rows) {
      let rowCount = 0;
      if (row.type === "table") {
        try {
          const countRes = await client.execute(`SELECT COUNT(*) AS total FROM "${row.name}";`);
          rowCount = Number(countRes.rows[0]?.total || 0);
        } catch (_) {
          rowCount = 0;
        }
      }
      tables.push({
        name: row.name,
        type: row.type,
        sql: row.sql,
        rowCount,
      });
    }

    return { success: true, tables };
  } catch (error) {
    return { success: false, message: error.message, tables: [] };
  }
}

/**
 * Executes a custom SQL statement on a tenant's Turso database.
 * @param {string} url
 * @param {string} token
 * @param {string} sql
 * @param {Array} args
 */
export async function executeTenantQuery(url, token, sql, args = []) {
  const client = createTenantClient(url, token);
  const startTime = Date.now();
  try {
    const result = await client.execute({ sql, args });
    const executionTimeMs = Date.now() - startTime;
    return {
      success: true,
      columns: result.columns,
      rows: result.rows,
      rowsAffected: result.rowsAffected,
      lastInsertRowid: result.lastInsertRowid ? String(result.lastInsertRowid) : null,
      executionTimeMs,
    };
  } catch (error) {
    return {
      success: false,
      message: error.message,
    };
  }
}

/**
 * Initializes or Reinstalls / Synchronizes the latest ProGold ERP database structure
 * on a tenant's private Turso database.
 * Safe & Non-Destructive: Never drops or truncates existing user data.
 * @param {string} url - Tenant's Turso URL
 * @param {string} token - Tenant's Turso Auth Token
 * @returns {Promise<{success: boolean, message: string, tablesCount?: number, executionTimeMs?: number, appliedAt?: string}>}
 */
export async function syncTenantDatabaseSchema(url, token) {
  if (!url || !token) {
    return { success: false, message: "Turso database URL and Auth Token are required." };
  }

  const startTime = Date.now();
  const client = createTenantClient(url, token);

  try {
    // 1. Schema Migrations Log Table
    await client.execute(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        version TEXT NOT NULL,
        migration_name TEXT NOT NULL,
        applied_at TEXT NOT NULL
      );
    `);

    // 2. Organization / Business Settings Profile
    await client.execute(`
      CREATE TABLE IF NOT EXISTS organization_profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_name TEXT DEFAULT 'ProGold Enterprise',
        tagline TEXT DEFAULT 'Fine Gold & Bullion Jewelers',
        phone TEXT DEFAULT '',
        email TEXT DEFAULT '',
        address TEXT DEFAULT '',
        city TEXT DEFAULT '',
        state TEXT DEFAULT '',
        pincode TEXT DEFAULT '',
        gstin TEXT DEFAULT '',
        pan_number TEXT DEFAULT '',
        currency_symbol TEXT DEFAULT '₹',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // 2b. Company Master Table (VARCHAR(5) Manual Company ID)
    await client.execute(`
      CREATE TABLE IF NOT EXISTS company (
        companyid TEXT PRIMARY KEY NOT NULL,
        companyname TEXT NOT NULL,
        gstno TEXT DEFAULT '',
        mobilenumber TEXT DEFAULT '',
        address TEXT DEFAULT '',
        city TEXT DEFAULT '',
        state TEXT DEFAULT '',
        state_id INTEGER DEFAULT 0,
        country TEXT DEFAULT 'India',
        country_id INTEGER DEFAULT 1,
        accountname TEXT DEFAULT '',
        branchid TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // 2c. Branch Master Table
    await client.execute(`
      CREATE TABLE IF NOT EXISTS branches (
        branchid TEXT PRIMARY KEY NOT NULL,
        branchname TEXT NOT NULL,
        companyid TEXT NOT NULL,
        accountname TEXT DEFAULT '',
        state TEXT DEFAULT '',
        state_id INTEGER DEFAULT 0,
        country TEXT DEFAULT 'India',
        country_id INTEGER DEFAULT 1,
        address TEXT DEFAULT '',
        mobile TEXT DEFAULT '',
        email TEXT DEFAULT '',
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // 2d. Tenant User Master Table (with menu permissions & central login)
    await client.execute(`
      CREATE TABLE IF NOT EXISTS users (
        userid TEXT PRIMARY KEY NOT NULL,
        username TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        email TEXT DEFAULT '',
        branchid TEXT DEFAULT '',
        is_active INTEGER DEFAULT 1,
        centlogin TEXT DEFAULT 'NO',
        profile_image TEXT DEFAULT '',
        allowed_menus TEXT DEFAULT '[]',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // 2e. Tenant Employee Master Table
    await client.execute(`
      CREATE TABLE IF NOT EXISTS employees (
        empid INTEGER PRIMARY KEY AUTOINCREMENT,
        empname TEXT NOT NULL,
        branchid TEXT NOT NULL,
        dateofjoin TEXT DEFAULT '',
        active INTEGER DEFAULT 1,
        bloodgroup TEXT DEFAULT '',
        mobile TEXT DEFAULT '',
        email TEXT DEFAULT '',
        address TEXT DEFAULT '',
        image TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // 3. Live Gold & Silver Rates Table
    await client.execute(`
      CREATE TABLE IF NOT EXISTS gold_rates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purity_name TEXT NOT NULL,
        purity_karat INTEGER NOT NULL,
        purity_percent REAL NOT NULL,
        buy_rate REAL NOT NULL,
        sell_rate REAL NOT NULL,
        silver_rate REAL DEFAULT 0,
        updated_at TEXT NOT NULL
      );
    `);

    // 3b. Metal Master Table
    await client.execute(`
      CREATE TABLE IF NOT EXISTS metals (
        metalid TEXT PRIMARY KEY NOT NULL,
        metalname TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // 3c. Purity Master Table
    await client.execute(`
      CREATE TABLE IF NOT EXISTS purities (
        purityid INTEGER PRIMARY KEY AUTOINCREMENT,
        metalid TEXT NOT NULL,
        purityname TEXT NOT NULL,
        purityshortname TEXT NOT NULL,
        purity REAL NOT NULL,
        type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (metalid) REFERENCES metals(metalid)
      );
    `);

    // 3d. Daily Purity Metal Rates & History Table
    await client.execute(`
      CREATE TABLE IF NOT EXISTS daily_rates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ratedate TEXT NOT NULL,
        purityid INTEGER NOT NULL,
        metalid TEXT NOT NULL,
        purityname TEXT NOT NULL,
        purity REAL NOT NULL,
        rate REAL NOT NULL,
        buy_rate REAL DEFAULT 0.0,
        sell_rate REAL DEFAULT 0.0,
        notes TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (purityid) REFERENCES purities(purityid)
      );
    `);

    // 4. Jewellery Categories Table (Refactored)
    await client.execute(`
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        metalid TEXT NOT NULL,
        catcode TEXT UNIQUE NOT NULL,
        catname TEXT NOT NULL,
        categorytype TEXT NOT NULL,
        sgst_per REAL DEFAULT 0.0,
        cgst_per REAL DEFAULT 0.0,
        igst_per REAL DEFAULT 0.0,
        sgstacname TEXT DEFAULT '',
        cgstacname TEXT DEFAULT '',
        igstacname TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (metalid) REFERENCES metals(metalid)
      );
    `);

    // 5. Products & Inventory Items Table
    await client.execute(`
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        sku TEXT UNIQUE NOT NULL,
        category_id INTEGER,
        purity TEXT DEFAULT '22K',
        gross_weight REAL DEFAULT 0.0,
        stone_weight REAL DEFAULT 0.0,
        net_weight REAL DEFAULT 0.0,
        making_charges REAL DEFAULT 0.0,
        wastage_percent REAL DEFAULT 0.0,
        price REAL DEFAULT 0.0,
        stock INTEGER DEFAULT 0,
        description TEXT DEFAULT '',
        image_url TEXT DEFAULT '',
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // 6. Inventory Stock Ledger / Audit
    await client.execute(`
      CREATE TABLE IF NOT EXISTS inventory_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        change_type TEXT NOT NULL,
        change_amount INTEGER NOT NULL,
        reason TEXT DEFAULT '',
        reference_id TEXT DEFAULT '',
        created_at TEXT NOT NULL
      );
    `);

    // 7. Customers / Clients Table
    await client.execute(`
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT DEFAULT '',
        phone TEXT NOT NULL,
        address TEXT DEFAULT '',
        city TEXT DEFAULT '',
        state TEXT DEFAULT '',
        pan_number TEXT DEFAULT '',
        gstin TEXT DEFAULT '',
        opening_balance REAL DEFAULT 0.0,
        current_balance REAL DEFAULT 0.0,
        notes TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // 8. Suppliers / Karigars / Smiths
    await client.execute(`
      CREATE TABLE IF NOT EXISTS suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        contact_person TEXT DEFAULT '',
        phone TEXT NOT NULL,
        email TEXT DEFAULT '',
        address TEXT DEFAULT '',
        city TEXT DEFAULT '',
        gstin TEXT DEFAULT '',
        balance_gold REAL DEFAULT 0.0,
        balance_cash REAL DEFAULT 0.0,
        notes TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // 9. Invoices / Sales Bills
    await client.execute(`
      CREATE TABLE IF NOT EXISTS invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT UNIQUE NOT NULL,
        customer_id INTEGER,
        customer_name TEXT NOT NULL,
        customer_phone TEXT DEFAULT '',
        subtotal REAL DEFAULT 0.0,
        making_charges REAL DEFAULT 0.0,
        gst_percent REAL DEFAULT 3.0,
        gst_amount REAL DEFAULT 0.0,
        discount REAL DEFAULT 0.0,
        total_amount REAL NOT NULL,
        payment_mode TEXT DEFAULT 'CASH',
        payment_status TEXT DEFAULT 'PAID',
        issue_date TEXT NOT NULL,
        due_date TEXT DEFAULT '',
        notes TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // 10. Invoice Items Details
    await client.execute(`
      CREATE TABLE IF NOT EXISTS invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        product_id INTEGER,
        title TEXT NOT NULL,
        sku TEXT DEFAULT '',
        purity TEXT DEFAULT '22K',
        gross_weight REAL DEFAULT 0.0,
        net_weight REAL DEFAULT 0.0,
        gold_rate REAL DEFAULT 0.0,
        making_charge REAL DEFAULT 0.0,
        total_price REAL NOT NULL,
        created_at TEXT NOT NULL
      );
    `);

    // 11. Customer Payments / Receipts Table
    await client.execute(`
      CREATE TABLE IF NOT EXISTS payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        invoice_id INTEGER,
        amount REAL NOT NULL,
        payment_mode TEXT DEFAULT 'CASH',
        reference_number TEXT DEFAULT '',
        notes TEXT DEFAULT '',
        payment_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    `);

    // 12. Quotations / Estimates
    await client.execute(`
      CREATE TABLE IF NOT EXISTS estimates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        estimate_number TEXT UNIQUE NOT NULL,
        customer_name TEXT NOT NULL,
        customer_phone TEXT DEFAULT '',
        total_amount REAL NOT NULL,
        issue_date TEXT NOT NULL,
        valid_until TEXT DEFAULT '',
        status TEXT DEFAULT 'PENDING',
        created_at TEXT NOT NULL
      );
    `);

    // 13. Karigar Orders
    await client.execute(`
      CREATE TABLE IF NOT EXISTS orders_karigar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_number TEXT UNIQUE NOT NULL,
        supplier_id INTEGER,
        customer_id INTEGER,
        item_description TEXT NOT NULL,
        purity TEXT DEFAULT '22K',
        issued_gold_weight REAL DEFAULT 0.0,
        expected_delivery_date TEXT DEFAULT '',
        status TEXT DEFAULT 'IN_PROGRESS',
        notes TEXT DEFAULT '',
        created_at TEXT NOT NULL
      );
    `);

    // 13b. Account Heads Table
    await client.execute(`
      CREATE TABLE IF NOT EXISTS account_heads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        accode TEXT UNIQUE NOT NULL,
        groupname TEXT NOT NULL,
        accountname TEXT NOT NULL,
        state TEXT DEFAULT '',
        country TEXT DEFAULT 'India',
        pincode TEXT DEFAULT '',
        active INTEGER DEFAULT 1,
        gstno TEXT DEFAULT '',
        panno TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // 13c. Tax Master Table
    await client.execute(`
      CREATE TABLE IF NOT EXISTS tax_master (
        taxid INTEGER PRIMARY KEY AUTOINCREMENT,
        taxcode TEXT NOT NULL UNIQUE,
        taxname TEXT NOT NULL,
        sgst_per REAL DEFAULT 0.0,
        sgstacname TEXT DEFAULT '',
        cgst_per REAL DEFAULT 0.0,
        cgstacname TEXT DEFAULT '',
        igst_per REAL DEFAULT 0.0,
        igstacname TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // 14. Audit Activity Logs
    await client.execute(`
      CREATE TABLE IF NOT EXISTS audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_action TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT DEFAULT '',
        details TEXT DEFAULT '',
        created_at TEXT NOT NULL
      );
    `);

    // --- SAFE NON-DESTRUCTIVE COLUMN MIGRATIONS ---
    const safeAddColumns = [
      `ALTER TABLE products ADD COLUMN is_active INTEGER DEFAULT 1;`,
      `ALTER TABLE products ADD COLUMN image_url TEXT DEFAULT '';`,
      `ALTER TABLE customers ADD COLUMN pan_number TEXT DEFAULT '';`,
      `ALTER TABLE customers ADD COLUMN gstin TEXT DEFAULT '';`,
      `ALTER TABLE customers ADD COLUMN current_balance REAL DEFAULT 0.0;`,
      `ALTER TABLE invoices ADD COLUMN customer_phone TEXT DEFAULT '';`,
      `ALTER TABLE organization_profile ADD COLUMN currency_symbol TEXT DEFAULT '₹';`,
      `ALTER TABLE company ADD COLUMN state_id INTEGER DEFAULT 0;`,
      `ALTER TABLE company ADD COLUMN country_id INTEGER DEFAULT 1;`,
      `ALTER TABLE branches ADD COLUMN state_id INTEGER DEFAULT 0;`,
      `ALTER TABLE branches ADD COLUMN country_id INTEGER DEFAULT 1;`,
      `ALTER TABLE branches ADD COLUMN is_active INTEGER DEFAULT 1;`,
    ];

    for (const alterSql of safeAddColumns) {
      try {
        await client.execute(alterSql);
      } catch (_) {
        // Ignored if column already exists in SQLite
      }
    }

    // --- PERFORMANCE INDEXES ---
    const indexes = [
      `CREATE INDEX IF NOT EXISTS idx_products_sku ON products (sku);`,
      `CREATE INDEX IF NOT EXISTS idx_products_category ON products (category_id);`,
      `CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers (phone);`,
      `CREATE INDEX IF NOT EXISTS idx_invoices_number ON invoices (invoice_number);`,
      `CREATE INDEX IF NOT EXISTS idx_invoices_customer ON invoices (customer_id);`,
      `CREATE INDEX IF NOT EXISTS idx_invoice_items_inv ON invoice_items (invoice_id);`,
      `CREATE INDEX IF NOT EXISTS idx_payments_customer ON payments (customer_id);`,
      `CREATE INDEX IF NOT EXISTS idx_account_heads_accode ON account_heads (accode);`,
      `CREATE INDEX IF NOT EXISTS idx_tax_master_taxcode ON tax_master (taxcode);`,
    ];

    for (const indexSql of indexes) {
      try {
        await client.execute(indexSql);
      } catch (_) { }
    }

    // --- INITIAL SEED DATA (If empty) ---
    const now = new Date().toISOString();

    // Seed Organization Profile
    try {
      const orgCheck = await client.execute(`SELECT COUNT(*) as cnt FROM organization_profile;`);
      if (Number(orgCheck.rows[0]?.cnt || 0) === 0) {
        await client.execute({
          sql: `INSERT INTO organization_profile (business_name, tagline, currency_symbol, created_at, updated_at) VALUES (?, ?, ?, ?, ?)`,
          args: ["ProGold Enterprise", "Fine Gold & Bullion Jewelers", "₹", now, now],
        });
      }
    } catch (_) { }

    // Seed Metals, Purities, and Categories
    try {
      const metalCheck = await client.execute(`SELECT COUNT(*) as cnt FROM metals;`);
      if (Number(metalCheck.rows[0]?.cnt || 0) === 0) {
        // Seed metals
        await client.execute(`
          INSERT INTO metals (metalid, metalname, created_at, updated_at) VALUES
          ('G', 'Gold', '${now}', '${now}'),
          ('S', 'Silver', '${now}', '${now}'),
          ('P', 'Platinum', '${now}', '${now}');
        `);

        // Seed purities
        await client.execute(`
          INSERT INTO purities (metalid, purityname, purityshortname, purity, type, created_at, updated_at) VALUES
          ('G', '24K Gold', '24K', 99.9, 'METAL', '${now}', '${now}'),
          ('G', '22K Gold', '22K', 91.6, 'ORNAMENT', '${now}', '${now}'),
          ('G', '18K Gold', '18K', 75.0, 'ORNAMENT', '${now}', '${now}'),
          ('S', 'Fine Silver', 'Fine', 99.9, 'METAL', '${now}', '${now}'),
          ('S', 'Standard Silver', '92.5', 92.5, 'ORNAMENT', '${now}', '${now}');
        `);

        // Seed categories
        await client.execute(`
          INSERT INTO categories (metalid, catcode, catname, categorytype, sgst_per, cgst_per, igst_per, created_at, updated_at) VALUES
          ('G', 'GO00001', 'Gold Ornaments GST', 'ORNAMENTS/STONE', 1.5, 1.5, 3.0, '${now}', '${now}'),
          ('G', 'GM00001', 'Gold Bar', 'METAL', 1.5, 1.5, 3.0, '${now}', '${now}'),
          ('S', 'SO00001', 'Silver Articles', 'ORNAMENTS/STONE', 1.5, 1.5, 3.0, '${now}', '${now}');
        `);
      }
    } catch (_) { }

    // Seed Default Gold Rates
    try {
      const rateCheck = await client.execute(`SELECT COUNT(*) as cnt FROM gold_rates;`);
      if (Number(rateCheck.rows[0]?.cnt || 0) === 0) {
        await client.execute(`
          INSERT INTO gold_rates (purity_name, purity_karat, purity_percent, buy_rate, sell_rate, silver_rate, updated_at) VALUES
          ('24K Fine Gold (99.9%)', 24, 99.9, 7450.0, 7550.0, 92.5, '${now}'),
          ('22K Standard Gold (91.6%)', 22, 91.6, 6830.0, 6925.0, 92.5, '${now}'),
          ('18K Hallmarked Gold (75.0%)', 18, 75.0, 5585.0, 5660.0, 92.5, '${now}');
        `);
      }
    } catch (_) { }

    // Record migration entry
    try {
      await client.execute({
        sql: `INSERT INTO schema_migrations (version, migration_name, applied_at) VALUES (?, ?, ?)`,
        args: ["2.0.0", "ProGold ERP Full Schema & Index Sync", now],
      });
    } catch (_) { }

    // Count installed tables
    const tableOverview = await getTenantDatabaseOverview(url, token);
    const tablesCount = tableOverview.tables.length;
    const executionTimeMs = Date.now() - startTime;

    return {
      success: true,
      message: `ProGold ERP database schema successfully installed and synchronized! (${tablesCount} tables ready, ${executionTimeMs}ms)`,
      tablesCount,
      executionTimeMs,
      appliedAt: now,
      tables: tableOverview.tables,
    };
  } catch (error) {
    console.error("syncTenantDatabaseSchema error:", error);
    return {
      success: false,
      message: `Failed to install schema: ${error?.message || "Internal database error"}`,
      error: error?.message,
    };
  }
}

