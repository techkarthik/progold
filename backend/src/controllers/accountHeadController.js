import { createTenantClient } from "../config/turso.js";

/**
 * Helper to ensure the account_heads table exists in the tenant's private Turso database.
 */
async function ensureAccountHeadsTable(client) {
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
}

/**
 * Helper to generate a 7-character alphanumeric code.
 */
function generateAccode() {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let result = "";
  for (let i = 0; i < 7; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

/**
 * GET /api/tenant/account-heads
 * Retrieves all account heads for the authenticated tenant.
 */
export async function getAccountHeadsController(req, res) {
  try {
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureAccountHeadsTable(client);

    const result = await client.execute(`
      SELECT * FROM account_heads 
      ORDER BY created_at DESC;
    `);

    return res.json({
      success: true,
      accountHeads: result.rows || [],
    });
  } catch (error) {
    console.error("getAccountHeadsController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to fetch account heads.",
    });
  }
}

/**
 * POST /api/tenant/account-heads
 * Inserts a new account head. Autogenerates a 7-digit alphanumeric accode.
 */
export async function createAccountHeadController(req, res) {
  try {
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureAccountHeadsTable(client);

    const {
      groupname,
      accountname,
      state = "",
      country = "India",
      pincode = "",
      active = 1,
      gstno = "",
      panno = "",
    } = req.body;

    if (!groupname || !groupname.trim()) {
      return res.status(400).json({
        success: false,
        message: "Group name is required.",
      });
    }

    if (!accountname || !accountname.trim()) {
      return res.status(400).json({
        success: false,
        message: "Account name is required.",
      });
    }

    // Generate a unique 7-digit alphanumeric accode
    let accode = "";
    let isUnique = false;
    let attempts = 0;
    while (!isUnique && attempts < 10) {
      accode = generateAccode();
      const existing = await client.execute({
        sql: "SELECT id FROM account_heads WHERE accode = ? LIMIT 1;",
        args: [accode],
      });
      if (existing.rows.length === 0) {
        isUnique = true;
      }
      attempts++;
    }

    if (!isUnique) {
      return res.status(500).json({
        success: false,
        message: "Failed to generate a unique account code.",
      });
    }

    const now = new Date().toISOString();

    const insertResult = await client.execute({
      sql: `
        INSERT INTO account_heads (
          accode, groupname, accountname, state, country, pincode, active, gstno, panno, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `,
      args: [
        accode,
        groupname.trim(),
        accountname.trim(),
        state.trim(),
        country.trim(),
        pincode.trim(),
        Number(active) === 0 ? 0 : 1,
        gstno.trim(),
        panno.trim(),
        now,
        now,
      ],
    });

    const newId = Number(insertResult.lastInsertRowid);

    return res.status(201).json({
      success: true,
      message: "Account Head created successfully!",
      accountHead: {
        id: newId,
        accode,
        groupname: groupname.trim(),
        accountname: accountname.trim(),
        state: state.trim(),
        country: country.trim(),
        pincode: pincode.trim(),
        active: Number(active) === 0 ? 0 : 1,
        gstno: gstno.trim(),
        panno: panno.trim(),
        created_at: now,
        updated_at: now,
      },
    });
  } catch (error) {
    console.error("createAccountHeadController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to create account head.",
    });
  }
}

/**
 * PUT /api/tenant/account-heads/:id
 * Updates an existing account head by ID.
 */
export async function updateAccountHeadController(req, res) {
  try {
    const { id } = req.params;
    if (!id) {
      return res.status(400).json({ success: false, message: "Account Head ID is required." });
    }

    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureAccountHeadsTable(client);

    const {
      groupname,
      accountname,
      state,
      country,
      pincode,
      active,
      gstno,
      panno,
    } = req.body;

    if (groupname !== undefined && (!groupname || !groupname.trim())) {
      return res.status(400).json({
        success: false,
        message: "Group name cannot be empty.",
      });
    }

    if (accountname !== undefined && (!accountname || !accountname.trim())) {
      return res.status(400).json({
        success: false,
        message: "Account name cannot be empty.",
      });
    }

    const now = new Date().toISOString();

    await client.execute({
      sql: `
        UPDATE account_heads
        SET groupname = COALESCE(?, groupname),
            accountname = COALESCE(?, accountname),
            state = COALESCE(?, state),
            country = COALESCE(?, country),
            pincode = COALESCE(?, pincode),
            active = COALESCE(?, active),
            gstno = COALESCE(?, gstno),
            panno = COALESCE(?, panno),
            updated_at = ?
        WHERE id = ?
      `,
      args: [
        groupname !== undefined ? groupname.trim() : null,
        accountname !== undefined ? accountname.trim() : null,
        state !== undefined ? state.trim() : null,
        country !== undefined ? country.trim() : null,
        pincode !== undefined ? pincode.trim() : null,
        active !== undefined ? (Number(active) === 0 ? 0 : 1) : null,
        gstno !== undefined ? gstno.trim() : null,
        panno !== undefined ? panno.trim() : null,
        now,
        Number(id),
      ],
    });

    return res.json({
      success: true,
      message: "Account Head updated successfully!",
    });
  } catch (error) {
    console.error("updateAccountHeadController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to update account head.",
    });
  }
}

/**
 * DELETE /api/tenant/account-heads/:id
 * Deletes an account head by ID.
 */
export async function deleteAccountHeadController(req, res) {
  try {
    const { id } = req.params;
    if (!id) {
      return res.status(400).json({ success: false, message: "Account Head ID is required." });
    }

    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureAccountHeadsTable(client);

    const result = await client.execute({
      sql: `DELETE FROM account_heads WHERE id = ?;`,
      args: [Number(id)],
    });

    return res.json({
      success: true,
      message: "Account Head deleted successfully!",
      rowsAffected: result.rowsAffected,
    });
  } catch (error) {
    console.error("deleteAccountHeadController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to delete account head.",
    });
  }
}
