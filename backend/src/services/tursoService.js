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
