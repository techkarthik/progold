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
        employee_id INTEGER,
        employee_code TEXT DEFAULT '',
        employee_name TEXT DEFAULT '',
        gross_weight REAL DEFAULT 0.0,
        net_weight REAL DEFAULT 0.0,
        total_metal_value REAL DEFAULT 0.0,
        total_making_charges REAL DEFAULT 0.0,
        total_stone_charges REAL DEFAULT 0.0,
        total_diamond_charges REAL DEFAULT 0.0,
        total_va_charges REAL DEFAULT 0.0,
        taxable_amount REAL DEFAULT 0.0,
        gst_rate REAL DEFAULT 3.0,
        tax_amount REAL DEFAULT 0.0,
        net_amount REAL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'OPEN',
        items_json TEXT NOT NULL DEFAULT '[]',
        notes TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // Safe column migrations for existing installations
    try { await client.execute(`ALTER TABLE estimates ADD COLUMN employee_id INTEGER;`); } catch (_) {}
    try { await client.execute(`ALTER TABLE estimates ADD COLUMN employee_code TEXT DEFAULT '';`); } catch (_) {}
    try { await client.execute(`ALTER TABLE estimates ADD COLUMN employee_name TEXT DEFAULT '';`); } catch (_) {}
    try { await client.execute(`ALTER TABLE estimates ADD COLUMN total_diamond_charges REAL DEFAULT 0.0;`); } catch (_) {}
    try { await client.execute(`ALTER TABLE estimates ADD COLUMN total_va_charges REAL DEFAULT 0.0;`); } catch (_) {}
    try { await client.execute(`ALTER TABLE estimates ADD COLUMN gst_rate REAL DEFAULT 3.0;`); } catch (_) {}
    try { await client.execute(`CREATE INDEX IF NOT EXISTS idx_estimates_date ON estimates (created_at);`); } catch (_) {}
    try { await client.execute(`CREATE INDEX IF NOT EXISTS idx_estimates_no ON estimates (estimate_no);`); } catch (_) {}
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
 * Retrieves all estimates / quotations with optional filters and metadata.
 */
export async function getEstimatesController(req, res) {
  try {
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureEstimateTables(client);

    const { search = "", status = "", from_date, fromDate, to_date, toDate, employee_id } = req.query;

    let query = `
      SELECT 
        e.*,
        COALESCE(emp.empname, e.employee_name) AS ref_employee_name
      FROM estimates e
      LEFT JOIN employees emp ON e.employee_id = emp.empid
      WHERE 1=1
    `;
    const args = [];

    if (status && status.trim().toUpperCase() !== "ALL") {
      query += ` AND e.status = ?`;
      args.push(status.trim().toUpperCase());
    }

    if (employee_id) {
      query += ` AND e.employee_id = ?`;
      args.push(Number(employee_id));
    }

    const startDate = (from_date || fromDate || "").toString().trim();
    if (startDate) {
      query += ` AND date(e.created_at) >= date(?)`;
      args.push(startDate.slice(0, 10));
    }

    const endDate = (to_date || toDate || "").toString().trim();
    if (endDate) {
      query += ` AND date(e.created_at) <= date(?)`;
      args.push(endDate.slice(0, 10));
    }

    if (search && search.trim()) {
      const q = `%${search.trim()}%`;
      query += ` AND (e.estimate_no LIKE ? OR e.customer_name LIKE ? OR e.customer_mobile LIKE ? OR e.employee_name LIKE ? OR e.employee_code LIKE ?)`;
      args.push(q, q, q, q, q);
    }

    query += ` ORDER BY e.estimate_id DESC;`;

    const result = await client.execute({ sql: query, args });

    // Meta statistics
    const metaResult = await client.execute(`
      SELECT 
        MAX(estimate_id) AS max_id, 
        COUNT(*) AS total_count,
        SUM(CASE WHEN status = 'OPEN' THEN 1 ELSE 0 END) AS open_count,
        COALESCE(SUM(net_amount), 0.0) AS total_val,
        SUM(CASE WHEN date(created_at) = date('now') THEN 1 ELSE 0 END) AS today_count
      FROM estimates;
    `);

    const maxId = Number(metaResult.rows[0]?.max_id || 0);
    const totalCount = Number(metaResult.rows[0]?.total_count || 0);
    const openCount = Number(metaResult.rows[0]?.open_count || 0);
    const totalValue = Number(metaResult.rows[0]?.total_val || 0);
    const todayCount = Number(metaResult.rows[0]?.today_count || 0);

    const nextEstimateNo = generateEstimateNo(maxId);

    return res.json({
      success: true,
      estimates: result.rows || [],
      last_estimate_id: maxId,
      next_estimate_no: nextEstimateNo,
      total_count: totalCount,
      open_count: openCount,
      total_value: totalValue,
      today_count: todayCount,
    });
  } catch (error) {
    console.error("getEstimates error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

/**
 * GET /api/tenant/estimates/barcode-lookup/:sku
 * Fetches barcode info directly from stock_tagged_items joined with product, category, purity, live rate.
 */
export async function getBarcodeForEstimateController(req, res) {
  try {
    const { sku } = req.params;
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);

    if (!sku || !sku.trim()) {
      return res.status(400).json({ success: false, message: "SKU / Barcode code is required." });
    }

    const cleanSku = sku.trim();

    // Query stock_tagged_items with joins
    const tagResult = await client.execute({
      sql: `
        SELECT 
          t.*,
          p.productname,
          p.hsncode,
          p.categoryid,
          c.catname,
          c.categorytype,
          c.sgst_per,
          c.cgst_per,
          c.igst_per,
          pu.purityname,
          pu.purityshortname,
          pu.purity,
          pu.metalid,
          d.designername,
          d.designershortname,
          COALESCE(dr.rate, 0.0) AS live_board_rate
        FROM stock_tagged_items t
        LEFT JOIN products p ON t.productid = p.productid
        LEFT JOIN categories c ON p.categoryid = c.id
        LEFT JOIN purities pu ON t.purityid = pu.purityid
        LEFT JOIN designers d ON t.designerid = d.designerid
        LEFT JOIN (
          SELECT dr1.purityid, dr1.rate
          FROM daily_rates dr1
          WHERE dr1.id = (
            SELECT MAX(dr2.id) FROM daily_rates dr2 WHERE dr2.purityid = dr1.purityid
          )
        ) dr ON t.purityid = dr.purityid
        WHERE UPPER(TRIM(t.sku_code)) = UPPER(?)
        LIMIT 1;
      `,
      args: [cleanSku],
    });

    if (tagResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: `Barcode / SKU '${cleanSku}' was not found in tagged stock inventory.`,
      });
    }

    const item = tagResult.rows[0];

    // Determine current Board Rate (prefer latest daily_rates, fallback to tag's board_rate or 0)
    const boardRate = Number(item.live_board_rate) > 0 ? Number(item.live_board_rate) : (Number(item.board_rate) || 0.0);
    
    // Determine GST Rate (sum of sgst_per + cgst_per from category, or igst_per, fallback 3.0%)
    const catGst = (Number(item.sgst_per) || 0.0) + (Number(item.cgst_per) || 0.0);
    const gstRate = catGst > 0 ? catGst : (Number(item.igst_per) > 0 ? Number(item.igst_per) : 3.0);

    const grossWeight = Number(item.gross_weight) || 0.0;
    const netWeight = Number(item.net_weight) || 0.0;
    const vaPercent = Number(item.sales_va_percent) || 0.0;
    const mc = Number(item.sales_m_charge) || (Number(item.sales_mc_per_gram) * netWeight) || 0.0;
    const stoneSellingPrice = Number(item.stone_amt) || 0.0;
    const diamondSellingPrice = Number(item.diamond_amt) || 0.0;

    // Calculation
    const metalValue = netWeight * boardRate;
    const vaCharges = metalValue * (vaPercent / 100.0);
    const taxableSubtotal = metalValue + vaCharges + mc + stoneSellingPrice + diamondSellingPrice;
    const gstAmount = taxableSubtotal * (gstRate / 100.0);
    const totalAmount = taxableSubtotal + gstAmount;

    return res.json({
      success: true,
      data: {
        sku_code: item.sku_code,
        item_id: item.item_id,
        lot_id: item.lot_id,
        lot_number: item.lot_number,
        productname: item.productname || "Jewellery Item",
        subproductname: item.stylename ? `${item.stylename}` : (item.sizename ? `${item.sizename}` : ""),
        category_name: item.catname || "",
        purityname: item.purityname || "22K Gold (916)",
        purityshortname: item.purityshortname || "22K",
        metalid: item.metalid || "G",
        gross_weight: grossWeight,
        net_weight: netWeight,
        stone_pcs: Number(item.stone_pcs) || 0,
        stone_weight: Number(item.stone_weight) || 0.0,
        stone_selling_price: stoneSellingPrice,
        diamond_pcs: Number(item.diamond_pcs) || 0,
        diamond_weight: Number(item.diamond_weight) || 0.0,
        diamond_selling_price: diamondSellingPrice,
        va_percent: vaPercent,
        mc: mc,
        board_rate: boardRate,
        metal_value: metalValue,
        va_charges: vaCharges,
        taxable_amount: taxableSubtotal,
        gst_rate: gstRate,
        gst_amount: gstAmount,
        total_amount: totalAmount,
        huid: item.huid || "",
        designername: item.designername || "",
        designershortname: item.designershortname || "",
      },
    });
  } catch (error) {
    console.error("getBarcodeForEstimate error:", error);
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
      employee_id = null,
      employee_code = "",
      employee_name = "",
      gross_weight = 0.0,
      net_weight = 0.0,
      total_metal_value = 0.0,
      total_making_charges = 0.0,
      total_stone_charges = 0.0,
      total_diamond_charges = 0.0,
      total_va_charges = 0.0,
      taxable_amount = 0.0,
      gst_rate = 3.0,
      tax_amount = 0.0,
      net_amount = 0.0,
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
          employee_id, employee_code, employee_name,
          gross_weight, net_weight, total_metal_value, total_making_charges, 
          total_stone_charges, total_diamond_charges, total_va_charges,
          taxable_amount, gst_rate, tax_amount, net_amount, status, items_json, notes, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      `,
      args: [
        estimateNo,
        customer_name.trim(),
        customer_mobile.trim(),
        customer_address.trim(),
        employee_id ? Number(employee_id) : null,
        (employee_code || "").trim(),
        (employee_name || "").trim(),
        Number(gross_weight) || 0.0,
        Number(net_weight) || 0.0,
        Number(total_metal_value) || 0.0,
        Number(total_making_charges) || 0.0,
        Number(total_stone_charges) || 0.0,
        Number(total_diamond_charges) || 0.0,
        Number(total_va_charges) || 0.0,
        Number(taxable_amount) || 0.0,
        Number(gst_rate) || 3.0,
        Number(tax_amount) || 0.0,
        Number(net_amount) || 0.0,
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
      employee_id = null,
      employee_code = "",
      employee_name = "",
      gross_weight = 0.0,
      net_weight = 0.0,
      total_metal_value = 0.0,
      total_making_charges = 0.0,
      total_stone_charges = 0.0,
      total_diamond_charges = 0.0,
      total_va_charges = 0.0,
      taxable_amount = 0.0,
      gst_rate = 3.0,
      tax_amount = 0.0,
      net_amount = 0.0,
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
            employee_id = ?,
            employee_code = ?,
            employee_name = ?,
            gross_weight = ?,
            net_weight = ?,
            total_metal_value = ?,
            total_making_charges = ?,
            total_stone_charges = ?,
            total_diamond_charges = ?,
            total_va_charges = ?,
            taxable_amount = ?,
            gst_rate = ?,
            tax_amount = ?,
            net_amount = ?,
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
        employee_id ? Number(employee_id) : null,
        (employee_code || "").trim(),
        (employee_name || "").trim(),
        Number(gross_weight) || 0.0,
        Number(net_weight) || 0.0,
        Number(total_metal_value) || 0.0,
        Number(total_making_charges) || 0.0,
        Number(total_stone_charges) || 0.0,
        Number(total_diamond_charges) || 0.0,
        Number(total_va_charges) || 0.0,
        Number(taxable_amount) || 0.0,
        Number(gst_rate) || 3.0,
        Number(tax_amount) || 0.0,
        Number(net_amount) || 0.0,
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

/**
 * DELETE /api/tenant/estimates/bulk/date-range
 * Deletes old estimates by date or date range.
 */
export async function bulkDeleteEstimatesByDateController(req, res) {
  try {
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureEstimateTables(client);

    const { from_date, fromDate, to_date, toDate, before_date, beforeDate, date: singleDate } = {
      ...req.query,
      ...req.body,
    };

    const start = (from_date || fromDate || "").toString().trim().slice(0, 10);
    const end = (to_date || toDate || "").toString().trim().slice(0, 10);
    const before = (before_date || beforeDate || "").toString().trim().slice(0, 10);
    const single = (singleDate || "").toString().trim().slice(0, 10);

    if (!start && !end && !before && !single) {
      return res.status(400).json({
        success: false,
        message: "Please specify a Date, Date Range (from_date / to_date), or Before Date to delete estimates.",
      });
    }

    let deleteSql = `DELETE FROM estimates WHERE 1=1`;
    let countSql = `SELECT COUNT(*) as count FROM estimates WHERE 1=1`;
    const args = [];

    if (single) {
      deleteSql += ` AND date(created_at) = date(?)`;
      countSql += ` AND date(created_at) = date(?)`;
      args.push(single);
    } else if (before) {
      deleteSql += ` AND date(created_at) <= date(?)`;
      countSql += ` AND date(created_at) <= date(?)`;
      args.push(before);
    } else {
      if (start) {
        deleteSql += ` AND date(created_at) >= date(?)`;
        countSql += ` AND date(created_at) >= date(?)`;
        args.push(start);
      }
      if (end) {
        deleteSql += ` AND date(created_at) <= date(?)`;
        countSql += ` AND date(created_at) <= date(?)`;
        args.push(end);
      }
    }

    // Check count first
    const countCheck = await client.execute({ sql: countSql, args });
    const countToDelete = Number(countCheck.rows[0]?.count || 0);

    if (countToDelete === 0) {
      return res.json({
        success: true,
        message: "No estimates matched the specified date criteria to delete.",
        deleted_count: 0,
      });
    }

    // Perform deletion
    await client.execute({ sql: deleteSql, args });

    return res.json({
      success: true,
      message: `Successfully deleted ${countToDelete} estimate quotation${countToDelete === 1 ? '' : 's'}.`,
      deleted_count: countToDelete,
    });
  } catch (error) {
    console.error("bulkDeleteEstimatesByDate error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}
