import { createTenantClient } from "../config/turso.js";
import { ensureTableOnce } from "../utils/schemaCache.js";

/**
 * Helper to ensure estimates table exists in tenant Turso DB.
 */
async function ensureEstimateTables(client, tenantUrl = "") {
  const key = tenantUrl || client?.config?.url || "default";
  await ensureTableOnce(`estimates:${key}`, async () => {
    await client.execute(`
      CREATE TABLE IF NOT EXISTS estimates (
        estimate_id INTEGER PRIMARY KEY AUTOINCREMENT,
        estimate_no TEXT UNIQUE NOT NULL,
        customer_name TEXT NOT NULL,
        customer_mobile TEXT NOT NULL DEFAULT '',
        customer_address TEXT DEFAULT '',
        gross_weight REAL DEFAULT 0.0,
        net_weight REAL DEFAULT 0.0,
        total_metal_value REAL DEFAULT 0.0,
        total_making_charges REAL DEFAULT 0.0,
        total_stone_charges REAL DEFAULT 0.0,
        taxable_amount REAL DEFAULT 0.0,
        tax_amount REAL DEFAULT 0.0,
        net_amount REAL DEFAULT 0.0,
        valid_days INTEGER DEFAULT 7,
        status TEXT NOT NULL DEFAULT 'OPEN',
        items_json TEXT NOT NULL DEFAULT '[]',
        notes TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);
  });
}

/**
 * Helper to generate Next Estimate Number e.g. 'EST-1001'
 */
function generateEstimateNo(lastId) {
  const nextNum = (lastId || 0) + 1001;
  return `EST-${nextNum}`;
}

/**
 * GET /api/tenant/estimates
 * Retrieves all estimates / quotations with metadata.
 */
export async function getEstimatesController(req, res) {
  try {
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureEstimateTables(client);

    const result = await client.execute(`
      SELECT * FROM estimates ORDER BY estimate_id DESC;
    `);

    const metaResult = await client.execute(`
      SELECT MAX(estimate_id) AS max_id, COUNT(*) AS total_count,
             SUM(CASE WHEN status = 'OPEN' THEN 1 ELSE 0 END) AS open_count,
             SUM(net_amount) AS total_val
      FROM estimates;
    `);

    const maxId = Number(metaResult.rows[0]?.max_id || 0);
    const totalCount = Number(metaResult.rows[0]?.total_count || 0);
    const openCount = Number(metaResult.rows[0]?.open_count || 0);
    const totalValue = Number(metaResult.rows[0]?.total_val || 0);

    const nextEstimateNo = generateEstimateNo(maxId);

    return res.json({
      success: true,
      estimates: result.rows || [],
      last_estimate_id: maxId,
      next_estimate_no: nextEstimateNo,
      total_count: totalCount,
      open_count: openCount,
      total_value: totalValue,
    });
  } catch (error) {
    console.error("getEstimates error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

/**
 * POST /api/tenant/estimates
 * Creates a new estimate quotation record.
 */
export async function createEstimateController(req, res) {
  try {
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureEstimateTables(client);

    const {
      customer_name,
      customer_mobile = "",
      customer_address = "",
      gross_weight = 0.0,
      net_weight = 0.0,
      total_metal_value = 0.0,
      total_making_charges = 0.0,
      total_stone_charges = 0.0,
      taxable_amount = 0.0,
      tax_amount = 0.0,
      net_amount = 0.0,
      valid_days = 7,
      status = "OPEN",
      items_json = "[]",
      notes = "",
    } = req.body;

    if (!customer_name || !customer_name.trim()) {
      return res.status(400).json({ success: false, message: "Customer Name is required for estimate quotation." });
    }

    // Get max ID for next estimate_no
    const metaResult = await client.execute(`SELECT MAX(estimate_id) AS max_id FROM estimates;`);
    const maxId = Number(metaResult.rows[0]?.max_id || 0);
    const estimateNo = generateEstimateNo(maxId);

    const now = new Date().toISOString();

    const insertResult = await client.execute({
      sql: `
        INSERT INTO estimates (
          estimate_no, customer_name, customer_mobile, customer_address,
          gross_weight, net_weight, total_metal_value, total_making_charges, total_stone_charges,
          taxable_amount, tax_amount, net_amount, valid_days, status, items_json, notes, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      `,
      args: [
        estimateNo,
        customer_name.trim(),
        customer_mobile.trim(),
        customer_address.trim(),
        Number(gross_weight) || 0.0,
        Number(net_weight) || 0.0,
        Number(total_metal_value) || 0.0,
        Number(total_making_charges) || 0.0,
        Number(total_stone_charges) || 0.0,
        Number(taxable_amount) || 0.0,
        Number(tax_amount) || 0.0,
        Number(net_amount) || 0.0,
        Number(valid_days) || 7,
        status.toUpperCase(),
        typeof items_json === "string" ? items_json : JSON.stringify(items_json),
        notes.trim(),
        now,
        now,
      ],
    });

    const newId = insertResult.lastInsertRowid ? Number(insertResult.lastInsertRowid) : null;

    return res.status(201).json({
      success: true,
      message: `Estimate ${estimateNo} generated successfully!`,
      estimate_id: newId,
      estimate_no: estimateNo,
    });
  } catch (error) {
    console.error("createEstimate error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

/**
 * PUT /api/tenant/estimates/:id
 * Updates an existing estimate.
 */
export async function updateEstimateController(req, res) {
  try {
    const { id } = req.params;
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureEstimateTables(client);

    const {
      customer_name,
      customer_mobile = "",
      customer_address = "",
      gross_weight = 0.0,
      net_weight = 0.0,
      total_metal_value = 0.0,
      total_making_charges = 0.0,
      total_stone_charges = 0.0,
      taxable_amount = 0.0,
      tax_amount = 0.0,
      net_amount = 0.0,
      valid_days = 7,
      status = "OPEN",
      items_json = "[]",
      notes = "",
    } = req.body;

    if (!customer_name || !customer_name.trim()) {
      return res.status(400).json({ success: false, message: "Customer Name is required." });
    }

    const now = new Date().toISOString();

    await client.execute({
      sql: `
        UPDATE estimates
        SET customer_name = ?,
            customer_mobile = ?,
            customer_address = ?,
            gross_weight = ?,
            net_weight = ?,
            total_metal_value = ?,
            total_making_charges = ?,
            total_stone_charges = ?,
            taxable_amount = ?,
            tax_amount = ?,
            net_amount = ?,
            valid_days = ?,
            status = ?,
            items_json = ?,
            notes = ?,
            updated_at = ?
        WHERE estimate_id = ?;
      `,
      args: [
        customer_name.trim(),
        customer_mobile.trim(),
        customer_address.trim(),
        Number(gross_weight) || 0.0,
        Number(net_weight) || 0.0,
        Number(total_metal_value) || 0.0,
        Number(total_making_charges) || 0.0,
        Number(total_stone_charges) || 0.0,
        Number(taxable_amount) || 0.0,
        Number(tax_amount) || 0.0,
        Number(net_amount) || 0.0,
        Number(valid_days) || 7,
        status.toUpperCase(),
        typeof items_json === "string" ? items_json : JSON.stringify(items_json),
        notes.trim(),
        now,
        Number(id),
      ],
    });

    return res.json({ success: true, message: "Estimate quotation updated successfully!" });
  } catch (error) {
    console.error("updateEstimate error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

/**
 * DELETE /api/tenant/estimates/:id
 * Deletes an estimate quotation.
 */
export async function deleteEstimateController(req, res) {
  try {
    const { id } = req.params;
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureEstimateTables(client);

    await client.execute({
      sql: `DELETE FROM estimates WHERE estimate_id = ?;`,
      args: [Number(id)],
    });

    return res.json({ success: true, message: "Estimate deleted successfully!" });
  } catch (error) {
    console.error("deleteEstimate error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}
