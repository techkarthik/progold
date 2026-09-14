import { createTenantClient } from "../config/turso.js";
import { ensureTableOnce } from "../utils/schemaCache.js";

/**
 * Ensures stock_tagged_items table exists in tenant Turso DB.
 */
export async function ensureStockTaggingTables(client, tenantUrl = "") {
  const key = tenantUrl || client?.config?.url || "default";
  await ensureTableOnce(`stock_tagging:${key}`, async () => {
    await client.execute(`
      CREATE TABLE IF NOT EXISTS stock_tagged_items (
        item_id INTEGER PRIMARY KEY AUTOINCREMENT,
        sku_code TEXT UNIQUE NOT NULL,
        lot_id INTEGER NOT NULL,
        lot_number TEXT NOT NULL,
        companyid TEXT NOT NULL,
        branchid TEXT NOT NULL,
        designerid INTEGER NOT NULL,
        productid INTEGER NOT NULL,
        subproductid INTEGER,
        purityid INTEGER NOT NULL,
        pcs INTEGER NOT NULL DEFAULT 1,
        gross_weight REAL NOT NULL DEFAULT 0.0,
        net_weight REAL NOT NULL DEFAULT 0.0,
        
        stone_pcs INTEGER DEFAULT 0,
        stone_weight REAL DEFAULT 0.0,
        stone_amt REAL DEFAULT 0.0,
        stone_details_json TEXT DEFAULT '[]',
        
        diamond_pcs INTEGER DEFAULT 0,
        diamond_weight REAL DEFAULT 0.0,
        diamond_amt REAL DEFAULT 0.0,
        diamond_details_json TEXT DEFAULT '[]',
        
        -- Sales Pricing Details
        board_rate REAL DEFAULT 0.0,
        sales_va_percent REAL DEFAULT 0.0,
        sales_wastage REAL DEFAULT 0.0,
        sales_mc_per_gram REAL DEFAULT 0.0,
        sales_m_charge REAL DEFAULT 0.0,
        sales_total_amt REAL DEFAULT 0.0,
        
        -- Purchase / Smith Inward Costing Details
        purchase_touch_pct REAL DEFAULT 0.0,
        purchase_gold_rate REAL DEFAULT 0.0,
        purchase_mc REAL DEFAULT 0.0,
        purchase_stone_cost REAL DEFAULT 0.0,
        purchase_diamond_cost REAL DEFAULT 0.0,
        purchase_total_cost REAL DEFAULT 0.0,
        
        huid TEXT DEFAULT '',
        status TEXT NOT NULL DEFAULT 'IN_STOCK',
        tag_printed_count INTEGER DEFAULT 0,
        tag_last_printed_at DATETIME,
        remarks TEXT DEFAULT '',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (lot_id) REFERENCES prepare_sku_lots(lot_id) ON DELETE CASCADE
      );
    `);

    // Add safe indexes
    try { await client.execute(`CREATE INDEX IF NOT EXISTS idx_stock_tags_sku ON stock_tagged_items (sku_code);`); } catch (_) {}
    try { await client.execute(`CREATE INDEX IF NOT EXISTS idx_stock_tags_lot ON stock_tagged_items (lot_id);`); } catch (_) {}
    try { await client.execute(`CREATE INDEX IF NOT EXISTS idx_stock_tags_company ON stock_tagged_items (companyid);`); } catch (_) {}
    try { await client.execute(`CREATE INDEX IF NOT EXISTS idx_stock_tags_branch ON stock_tagged_items (branchid);`); } catch (_) {}
    try { await client.execute(`CREATE INDEX IF NOT EXISTS idx_stock_tags_status ON stock_tagged_items (status);`); } catch (_) {}
  });
}

/**
 * Generates sequential SKU Code for a Lot e.g. 'SKU-2627-1-001', 'SKU-2627-1-002'
 */
async function generateNextSkuCodes(client, lotNumber, count = 1) {
  const cleanLot = String(lotNumber || "").trim();
  const prefix = `SKU-${cleanLot}-`;

  const res = await client.execute({
    sql: `SELECT sku_code FROM stock_tagged_items WHERE sku_code LIKE ? ORDER BY item_id DESC;`,
    args: [`${prefix}%`],
  });

  let maxSeq = 0;
  if (res.rows && res.rows.length > 0) {
    for (const row of res.rows) {
      const code = String(row.sku_code || "").trim();
      const match = code.match(new RegExp(`^${prefix}(\\d+)$`));
      if (match && match[1]) {
        const n = parseInt(match[1], 10);
        if (!isNaN(n) && n > maxSeq) {
          maxSeq = n;
        }
      }
    }
  }

  const skuList = [];
  for (let i = 1; i <= count; i++) {
    const seq = String(maxSeq + i).padStart(3, "0");
    skuList.push(`${prefix}${seq}`);
  }
  return skuList;
}

/**
 * GET /api/tenant/stock/va-lookup
 * Looks up matching Value Addition (pricesetting / diamond price) for a smith, product, and weight range.
 */
export async function getVaLookupController(req, res) {
  try {
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);

    const { companyid = "", branchid = "", productid, subproductid, accode = "", weight = 0 } = req.query;
    const grossWeight = parseFloat(weight) || 0.0;
    const prodId = parseInt(productid, 10);
    const subProdId = subproductid ? parseInt(subproductid, 10) : null;
    const cleanAccode = String(accode || "").trim();

    if (!prodId) {
      return res.json({ success: true, matched: false, price_setting: null });
    }

    // Try finding exact match with accode + subproduct + weight range
    let sql = `
      SELECT ps.*, ah.accountname AS dealername, p.productname, sp.subproductname
      FROM pricesetting ps
      LEFT JOIN account_heads ah ON ps.accode = ah.accode
      LEFT JOIN products p ON ps.productid = p.productid
      LEFT JOIN subproducts sp ON ps.subproductid = sp.subproductid
      WHERE ps.productid = ?
        AND (? >= ps.weight_from AND ? <= ps.weight_to)
    `;
    const args = [prodId, grossWeight, grossWeight];

    if (cleanAccode) {
      sql += ` AND (ps.accode = ? OR ps.accode IS NULL OR ps.accode = '')`;
      args.push(cleanAccode);
    }
    if (subProdId) {
      sql += ` AND (ps.subproductid = ? OR ps.subproductid IS NULL OR ps.subproductid = 0)`;
      args.push(subProdId);
    }

    sql += ` ORDER BY ps.accode DESC, ps.subproductid DESC, ps.id DESC LIMIT 1;`;

    let result = await client.execute({ sql, args });

    // Fallback if no exact weight range match: find closest for same product/accode
    if (!result.rows || result.rows.length === 0) {
      const fallbackSql = `
        SELECT ps.*, ah.accountname AS dealername, p.productname, sp.subproductname
        FROM pricesetting ps
        LEFT JOIN account_heads ah ON ps.accode = ah.accode
        LEFT JOIN products p ON ps.productid = p.productid
        LEFT JOIN subproducts sp ON ps.subproductid = sp.subproductid
        WHERE ps.productid = ?
        ORDER BY ps.accode DESC, ps.id DESC LIMIT 1;
      `;
      result = await client.execute({ sql: fallbackSql, args: [prodId] });
    }

    if (result.rows && result.rows.length > 0) {
      const row = result.rows[0];
      return res.json({
        success: true,
        matched: true,
        price_setting: {
          id: row.id,
          productid: row.productid,
          productname: row.productname || "",
          subproductid: row.subproductid,
          subproductname: row.subproductname || "",
          accode: row.accode || "",
          dealername: row.dealername || "",
          weight_from: Number(row.weight_from || 0.0),
          weight_to: Number(row.weight_to || 0.0),
          va_percent: Number(row.va_percent || 0.0),
          wastage: Number(row.wastage || 0.0),
          mc_per_gram: Number(row.mc_per_gram || 0.0),
          m_charge: Number(row.m_charge || 0.0),
        },
      });
    }

    return res.json({
      success: true,
      matched: false,
      price_setting: null,
    });
  } catch (error) {
    console.error("Error in getVaLookupController:", error);
    return res.status(500).json({ success: false, message: error?.message || "Failed to lookup VA." });
  }
}

/**
 * GET /api/tenant/stock/tags
 * Retrieves stock tagged items with joins for product, subproduct, smith, and purity.
 */
export async function getStockTagsController(req, res) {
  try {
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureStockTaggingTables(client);

    const { companyid = "", branchid = "", lot_id, status = "", search = "" } = req.query;

    let query = `
      SELECT 
        t.*,
        d.designername,
        d.designershortname,
        d.accode AS designer_accode,
        p.productname,
        sp.subproductname,
        pu.purityname,
        pu.purityshortname,
        pu.purity,
        pu.type AS purity_type,
        b.branchname,
        c.companyname
      FROM stock_tagged_items t
      LEFT JOIN designers d ON t.designerid = d.designerid
      LEFT JOIN products p ON t.productid = p.productid
      LEFT JOIN subproducts sp ON t.subproductid = sp.subproductid
      LEFT JOIN purities pu ON t.purityid = pu.purityid
      LEFT JOIN branches b ON t.branchid = b.branchid
      LEFT JOIN company c ON t.companyid = c.companyid
      WHERE 1=1
    `;
    const args = [];

    if (companyid && String(companyid).trim() !== "") {
      query += ` AND t.companyid = ?`;
      args.push(String(companyid).trim());
    }
    if (branchid && String(branchid).trim() !== "") {
      query += ` AND t.branchid = ?`;
      args.push(String(branchid).trim());
    }
    if (lot_id) {
      query += ` AND t.lot_id = ?`;
      args.push(parseInt(lot_id, 10));
    }
    if (status && String(status).trim() !== "") {
      query += ` AND t.status = ?`;
      args.push(String(status).trim());
    }
    if (search && String(search).trim() !== "") {
      const s = `%${String(search).trim()}%`;
      query += ` AND (t.sku_code LIKE ? OR t.lot_number LIKE ? OR p.productname LIKE ? OR d.designername LIKE ?)`;
      args.push(s, s, s, s);
    }

    query += ` ORDER BY t.item_id DESC;`;

    const result = await client.execute({ sql: query, args });

    const rows = (result.rows || []).map((row) => ({
      item_id: row.item_id,
      sku_code: row.sku_code,
      lot_id: row.lot_id,
      lot_number: row.lot_number,
      companyid: row.companyid,
      branchid: row.branchid,
      designerid: row.designerid,
      designername: row.designername || "",
      designer_accode: row.designer_accode || "",
      productid: row.productid,
      productname: row.productname || "",
      subproductid: row.subproductid,
      subproductname: row.subproductname || "",
      purityid: row.purityid,
      purityname: row.purityname || "",
      purity: Number(row.purity || 0.0),
      pcs: Number(row.pcs || 1),
      gross_weight: Number(row.gross_weight || 0.0),
      net_weight: Number(row.net_weight || 0.0),
      stone_pcs: Number(row.stone_pcs || 0),
      stone_weight: Number(row.stone_weight || 0.0),
      stone_amt: Number(row.stone_amt || 0.0),
      stone_details: (() => {
        try {
          return typeof row.stone_details_json === "string" ? JSON.parse(row.stone_details_json) : row.stone_details_json || [];
        } catch (_) { return []; }
      })(),
      diamond_pcs: Number(row.diamond_pcs || 0),
      diamond_weight: Number(row.diamond_weight || 0.0),
      diamond_amt: Number(row.diamond_amt || 0.0),
      diamond_details: (() => {
        try {
          return typeof row.diamond_details_json === "string" ? JSON.parse(row.diamond_details_json) : row.diamond_details_json || [];
        } catch (_) { return []; }
      })(),
      board_rate: Number(row.board_rate || 0.0),
      sales_va_percent: Number(row.sales_va_percent || 0.0),
      sales_wastage: Number(row.sales_wastage || 0.0),
      sales_mc_per_gram: Number(row.sales_mc_per_gram || 0.0),
      sales_m_charge: Number(row.sales_m_charge || 0.0),
      sales_total_amt: Number(row.sales_total_amt || 0.0),
      purchase_touch_pct: Number(row.purchase_touch_pct || 0.0),
      purchase_gold_rate: Number(row.purchase_gold_rate || 0.0),
      purchase_mc: Number(row.purchase_mc || 0.0),
      purchase_stone_cost: Number(row.purchase_stone_cost || 0.0),
      purchase_diamond_cost: Number(row.purchase_diamond_cost || 0.0),
      purchase_total_cost: Number(row.purchase_total_cost || 0.0),
      huid: row.huid || "",
      status: row.status || "IN_STOCK",
      tag_printed_count: Number(row.tag_printed_count || 0),
      tag_last_printed_at: row.tag_last_printed_at,
      remarks: row.remarks || "",
      created_at: row.created_at,
      updated_at: row.updated_at,
      branchname: row.branchname || "",
      companyname: row.companyname || "",
    }));

    return res.json({
      success: true,
      tags: rows,
      total_count: rows.length,
    });
  } catch (error) {
    console.error("Error in getStockTagsController:", error);
    return res.status(500).json({ success: false, message: error?.message || "Failed to fetch stock tags." });
  }
}

/**
 * POST /api/tenant/stock/tags/generate-from-lot
 * Creates individual or batch SKU tagged items from a Prepare SKU Lot.
 */
export async function generateTagsFromLotController(req, res) {
  try {
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureStockTaggingTables(client);

    const {
      lot_id,
      tag_items = [], // Array of individual tag breakdowns
      // Global defaults if tag_items is not an array of individual items
      tags_count = 1,
      board_rate = 0.0,
      sales_va_percent = 0.0,
      sales_wastage = 0.0,
      sales_mc_per_gram = 0.0,
      sales_m_charge = 0.0,
      purchase_touch_pct = 0.0,
      purchase_gold_rate = 0.0,
      purchase_mc = 0.0,
      purchase_stone_cost = 0.0,
      purchase_diamond_cost = 0.0,
      huid = "",
      remarks = "",
    } = req.body;

    const lotId = parseInt(lot_id, 10);
    if (isNaN(lotId)) {
      return res.status(400).json({ success: false, message: "Valid Lot ID is required." });
    }

    // Fetch parent lot info
    const lotRes = await client.execute({
      sql: `SELECT * FROM prepare_sku_lots WHERE lot_id = ?;`,
      args: [lotId],
    });

    if (!lotRes.rows || lotRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: "Source SKU Lot not found." });
    }

    const lot = lotRes.rows[0];
    const lotNumber = lot.lot_number;

    let itemsToInsert = [];

    if (Array.isArray(tag_items) && tag_items.length > 0) {
      // User provided explicit piece-by-piece breakdown
      const skuCodes = await generateNextSkuCodes(client, lotNumber, tag_items.length);
      itemsToInsert = tag_items.map((item, idx) => {
        const grs = parseFloat(item.gross_weight) || 0.0;
        const net = parseFloat(item.net_weight) || grs;
        const stnPcs = parseInt(item.stone_pcs, 10) || 0;
        const stnWt = parseFloat(item.stone_weight) || 0.0;
        const stnAmt = parseFloat(item.stone_amt) || 0.0;
        const dmdPcs = parseInt(item.diamond_pcs, 10) || 0;
        const dmdWt = parseFloat(item.diamond_weight) || 0.0;
        const dmdAmt = parseFloat(item.diamond_amt) || 0.0;

        const bRate = parseFloat(item.board_rate !== undefined ? item.board_rate : board_rate) || 0.0;
        const vaPct = parseFloat(item.sales_va_percent !== undefined ? item.sales_va_percent : sales_va_percent) || 0.0;
        const wst = parseFloat(item.sales_wastage !== undefined ? item.sales_wastage : sales_wastage) || 0.0;
        const mcGram = parseFloat(item.sales_mc_per_gram !== undefined ? item.sales_mc_per_gram : sales_mc_per_gram) || 0.0;
        const mCharge = parseFloat(item.sales_m_charge !== undefined ? item.sales_m_charge : sales_m_charge) || 0.0;

        // Calculate sales total
        const pureGoldCost = net * bRate;
        const vaAmount = pureGoldCost * (vaPct / 100.0);
        const wastageAmount = pureGoldCost * (wst / 100.0);
        const mcAmount = (net * mcGram) + mCharge;
        const salesTotal = item.sales_total_amt !== undefined 
          ? parseFloat(item.sales_total_amt) 
          : (pureGoldCost + vaAmount + wastageAmount + mcAmount + stnAmt + dmdAmt);

        // Purchase Costing
        const pTouch = parseFloat(item.purchase_touch_pct !== undefined ? item.purchase_touch_pct : purchase_touch_pct) || 0.0;
        const pGoldRate = parseFloat(item.purchase_gold_rate !== undefined ? item.purchase_gold_rate : (purchase_gold_rate || bRate)) || 0.0;
        const pMc = parseFloat(item.purchase_mc !== undefined ? item.purchase_mc : purchase_mc) || 0.0;
        const pStone = parseFloat(item.purchase_stone_cost !== undefined ? item.purchase_stone_cost : purchase_stone_cost) || 0.0;
        const pDmd = parseFloat(item.purchase_diamond_cost !== undefined ? item.purchase_diamond_cost : purchase_diamond_cost) || 0.0;

        const pGoldCost = pTouch > 0 ? (net * (pTouch / 100.0) * pGoldRate) : (net * pGoldRate);
        const purchaseTotal = item.purchase_total_cost !== undefined
          ? parseFloat(item.purchase_total_cost)
          : (pGoldCost + pMc + pStone + pDmd);

        return {
          sku_code: skuCodes[idx],
          lot_id: lotId,
          lot_number: lotNumber,
          companyid: lot.companyid,
          branchid: lot.branchid,
          designerid: lot.designerid,
          productid: lot.productid,
          subproductid: lot.subproductid,
          purityid: lot.purityid,
          pcs: parseInt(item.pcs, 10) || 1,
          gross_weight: grs,
          net_weight: net,
          stone_pcs: stnPcs,
          stone_weight: stnWt,
          stone_amt: stnAmt,
          stone_details_json: JSON.stringify(item.stone_details || []),
          diamond_pcs: dmdPcs,
          diamond_weight: dmdWt,
          diamond_amt: dmdAmt,
          diamond_details_json: JSON.stringify(item.diamond_details || []),
          board_rate: bRate,
          sales_va_percent: vaPct,
          sales_wastage: wst,
          sales_mc_per_gram: mcGram,
          sales_m_charge: mCharge,
          sales_total_amt: salesTotal,
          purchase_touch_pct: pTouch,
          purchase_gold_rate: pGoldRate,
          purchase_mc: pMc,
          purchase_stone_cost: pStone,
          purchase_diamond_cost: pDmd,
          purchase_total_cost: purchaseTotal,
          huid: item.huid || huid || "",
          remarks: item.remarks || remarks || "",
        };
      });
    } else {
      // Auto-generate tags based on lot pieces and total weight
      const count = Math.max(1, parseInt(tags_count, 10) || parseInt(lot.total_pcs, 10) || 1);
      const skuCodes = await generateNextSkuCodes(client, lotNumber, count);

      const grsPerTag = (Number(lot.total_gross_weight || 0.0) / count);
      const netPerTag = (Number(lot.total_net_weight || 0.0) / count);
      const stnPcsPerTag = Math.floor((Number(lot.total_stone_pcs || 0) / count));
      const stnWtPerTag = (Number(lot.total_stone_weight || 0.0) / count);
      const dmdPcsPerTag = Math.floor((Number(lot.total_diamond_pcs || 0) / count));
      const dmdWtPerTag = (Number(lot.total_diamond_weight || 0.0) / count);

      const bRate = parseFloat(board_rate || lot.rate) || 0.0;
      const vaPct = parseFloat(sales_va_percent) || 0.0;
      const wst = parseFloat(sales_wastage) || 0.0;
      const mcGram = parseFloat(sales_mc_per_gram) || 0.0;
      const mCharge = parseFloat(sales_m_charge) || 0.0;

      const pureGoldCost = netPerTag * bRate;
      const vaAmount = pureGoldCost * (vaPct / 100.0);
      const wastageAmount = pureGoldCost * (wst / 100.0);
      const mcAmount = (netPerTag * mcGram) + mCharge;
      const salesTotal = pureGoldCost + vaAmount + wastageAmount + mcAmount;

      const pTouch = parseFloat(purchase_touch_pct) || 0.0;
      const pGoldRate = parseFloat(purchase_gold_rate || bRate) || 0.0;
      const pMc = parseFloat(purchase_mc) || 0.0;
      const pStone = parseFloat(purchase_stone_cost) || 0.0;
      const pDmd = parseFloat(purchase_diamond_cost) || 0.0;
      const pGoldCost = pTouch > 0 ? (netPerTag * (pTouch / 100.0) * pGoldRate) : (netPerTag * pGoldRate);
      const purchaseTotal = pGoldCost + pMc + pStone + pDmd;

      for (let i = 0; i < count; i++) {
        itemsToInsert.push({
          sku_code: skuCodes[i],
          lot_id: lotId,
          lot_number: lotNumber,
          companyid: lot.companyid,
          branchid: lot.branchid,
          designerid: lot.designerid,
          productid: lot.productid,
          subproductid: lot.subproductid,
          purityid: lot.purityid,
          pcs: 1,
          gross_weight: grsPerTag,
          net_weight: netPerTag,
          stone_pcs: stnPcsPerTag,
          stone_weight: stnWtPerTag,
          stone_amt: 0.0,
          stone_details_json: lot.stone_items_json || "[]",
          diamond_pcs: dmdPcsPerTag,
          diamond_weight: dmdWtPerTag,
          diamond_amt: 0.0,
          diamond_details_json: lot.diamond_items_json || "[]",
          board_rate: bRate,
          sales_va_percent: vaPct,
          sales_wastage: wst,
          sales_mc_per_gram: mcGram,
          sales_m_charge: mCharge,
          sales_total_amt: salesTotal,
          purchase_touch_pct: pTouch,
          purchase_gold_rate: pGoldRate,
          purchase_mc: pMc,
          purchase_stone_cost: pStone,
          purchase_diamond_cost: pDmd,
          purchase_total_cost: purchaseTotal,
          huid: huid || "",
          remarks: remarks || "",
        });
      }
    }

    const createdIds = [];
    for (const item of itemsToInsert) {
      const resInsert = await client.execute({
        sql: `
          INSERT INTO stock_tagged_items (
            sku_code, lot_id, lot_number, companyid, branchid, designerid, productid, subproductid, purityid,
            pcs, gross_weight, net_weight, stone_pcs, stone_weight, stone_amt, stone_details_json,
            diamond_pcs, diamond_weight, diamond_amt, diamond_details_json,
            board_rate, sales_va_percent, sales_wastage, sales_mc_per_gram, sales_m_charge, sales_total_amt,
            purchase_touch_pct, purchase_gold_rate, purchase_mc, purchase_stone_cost, purchase_diamond_cost, purchase_total_cost,
            huid, status, remarks, created_at, updated_at
          ) VALUES (
            ?, ?, ?, ?, ?, ?, ?, ?, ?,
            ?, ?, ?, ?, ?, ?, ?,
            ?, ?, ?, ?,
            ?, ?, ?, ?, ?, ?,
            ?, ?, ?, ?, ?, ?,
            ?, 'IN_STOCK', ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
          );
        `,
        args: [
          item.sku_code,
          item.lot_id,
          item.lot_number,
          item.companyid,
          item.branchid,
          item.designerid,
          item.productid,
          item.subproductid,
          item.purityid,
          item.pcs,
          item.gross_weight,
          item.net_weight,
          item.stone_pcs,
          item.stone_weight,
          item.stone_amt,
          item.stone_details_json,
          item.diamond_pcs,
          item.diamond_weight,
          item.diamond_amt,
          item.diamond_details_json,
          item.board_rate,
          item.sales_va_percent,
          item.sales_wastage,
          item.sales_mc_per_gram,
          item.sales_m_charge,
          item.sales_total_amt,
          item.purchase_touch_pct,
          item.purchase_gold_rate,
          item.purchase_mc,
          item.purchase_stone_cost,
          item.purchase_diamond_cost,
          item.purchase_total_cost,
          item.huid,
          item.remarks,
        ],
      });
      createdIds.push(Number(resInsert.lastInsertRowid));
    }

    // Update parent lot status to TAGGED
    await client.execute({
      sql: `UPDATE prepare_sku_lots SET status = 'TAGGED', updated_at = CURRENT_TIMESTAMP WHERE lot_id = ?;`,
      args: [lotId],
    });

    return res.status(201).json({
      success: true,
      message: `${itemsToInsert.length} SKU Tag(s) generated successfully for Lot ${lotNumber}!`,
      count: itemsToInsert.length,
      created_ids: createdIds,
      sku_codes: itemsToInsert.map((i) => i.sku_code),
    });
  } catch (error) {
    console.error("Error in generateTagsFromLotController:", error);
    return res.status(500).json({ success: false, message: error?.message || "Failed to generate tags." });
  }
}

/**
 * PUT /api/tenant/stock/tags/:id
 */
export async function updateStockTagController(req, res) {
  try {
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureStockTaggingTables(client);

    const { id } = req.params;
    const itemId = parseInt(id, 10);
    if (isNaN(itemId)) {
      return res.status(400).json({ success: false, message: "Invalid Tag Item ID." });
    }

    const {
      pcs,
      gross_weight,
      net_weight,
      stone_pcs,
      stone_weight,
      stone_amt,
      diamond_pcs,
      diamond_weight,
      diamond_amt,
      board_rate,
      sales_va_percent,
      sales_wastage,
      sales_mc_per_gram,
      sales_m_charge,
      sales_total_amt,
      purchase_touch_pct,
      purchase_gold_rate,
      purchase_mc,
      purchase_stone_cost,
      purchase_diamond_cost,
      purchase_total_cost,
      huid,
      status,
      remarks,
    } = req.body;

    const result = await client.execute({
      sql: `
        UPDATE stock_tagged_items SET
          pcs = COALESCE(?, pcs),
          gross_weight = COALESCE(?, gross_weight),
          net_weight = COALESCE(?, net_weight),
          stone_pcs = COALESCE(?, stone_pcs),
          stone_weight = COALESCE(?, stone_weight),
          stone_amt = COALESCE(?, stone_amt),
          diamond_pcs = COALESCE(?, diamond_pcs),
          diamond_weight = COALESCE(?, diamond_weight),
          diamond_amt = COALESCE(?, diamond_amt),
          board_rate = COALESCE(?, board_rate),
          sales_va_percent = COALESCE(?, sales_va_percent),
          sales_wastage = COALESCE(?, sales_wastage),
          sales_mc_per_gram = COALESCE(?, sales_mc_per_gram),
          sales_m_charge = COALESCE(?, sales_m_charge),
          sales_total_amt = COALESCE(?, sales_total_amt),
          purchase_touch_pct = COALESCE(?, purchase_touch_pct),
          purchase_gold_rate = COALESCE(?, purchase_gold_rate),
          purchase_mc = COALESCE(?, purchase_mc),
          purchase_stone_cost = COALESCE(?, purchase_stone_cost),
          purchase_diamond_cost = COALESCE(?, purchase_diamond_cost),
          purchase_total_cost = COALESCE(?, purchase_total_cost),
          huid = COALESCE(?, huid),
          status = COALESCE(?, status),
          remarks = COALESCE(?, remarks),
          updated_at = CURRENT_TIMESTAMP
        WHERE item_id = ?;
      `,
      args: [
        pcs !== undefined ? parseInt(pcs, 10) : null,
        gross_weight !== undefined ? parseFloat(gross_weight) : null,
        net_weight !== undefined ? parseFloat(net_weight) : null,
        stone_pcs !== undefined ? parseInt(stone_pcs, 10) : null,
        stone_weight !== undefined ? parseFloat(stone_weight) : null,
        stone_amt !== undefined ? parseFloat(stone_amt) : null,
        diamond_pcs !== undefined ? parseInt(diamond_pcs, 10) : null,
        diamond_weight !== undefined ? parseFloat(diamond_weight) : null,
        diamond_amt !== undefined ? parseFloat(diamond_amt) : null,
        board_rate !== undefined ? parseFloat(board_rate) : null,
        sales_va_percent !== undefined ? parseFloat(sales_va_percent) : null,
        sales_wastage !== undefined ? parseFloat(sales_wastage) : null,
        sales_mc_per_gram !== undefined ? parseFloat(sales_mc_per_gram) : null,
        sales_m_charge !== undefined ? parseFloat(sales_m_charge) : null,
        sales_total_amt !== undefined ? parseFloat(sales_total_amt) : null,
        purchase_touch_pct !== undefined ? parseFloat(purchase_touch_pct) : null,
        purchase_gold_rate !== undefined ? parseFloat(purchase_gold_rate) : null,
        purchase_mc !== undefined ? parseFloat(purchase_mc) : null,
        purchase_stone_cost !== undefined ? parseFloat(purchase_stone_cost) : null,
        purchase_diamond_cost !== undefined ? parseFloat(purchase_diamond_cost) : null,
        purchase_total_cost !== undefined ? parseFloat(purchase_total_cost) : null,
        huid !== undefined ? String(huid).trim() : null,
        status !== undefined ? String(status).trim() : null,
        remarks !== undefined ? String(remarks).trim() : null,
        itemId,
      ],
    });

    if (result.rowsAffected === 0) {
      return res.status(404).json({ success: false, message: "Tagged item not found." });
    }

    return res.json({ success: true, message: "Tagged item updated successfully." });
  } catch (error) {
    console.error("Error in updateStockTagController:", error);
    return res.status(500).json({ success: false, message: error?.message || "Failed to update tag." });
  }
}

/**
 * DELETE /api/tenant/stock/tags/:id
 */
export async function deleteStockTagController(req, res) {
  try {
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureStockTaggingTables(client);

    const { id } = req.params;
    const itemId = parseInt(id, 10);
    if (isNaN(itemId)) {
      return res.status(400).json({ success: false, message: "Invalid Tag Item ID." });
    }

    const result = await client.execute({
      sql: `DELETE FROM stock_tagged_items WHERE item_id = ?;`,
      args: [itemId],
    });

    if (result.rowsAffected === 0) {
      return res.status(404).json({ success: false, message: "Tagged item not found." });
    }

    return res.json({ success: true, message: "Tagged item deleted successfully." });
  } catch (error) {
    console.error("Error in deleteStockTagController:", error);
    return res.status(500).json({ success: false, message: error?.message || "Failed to delete tag." });
  }
}

/**
 * POST /api/tenant/stock/tags/mark-printed
 */
export async function markStockTagsPrintedController(req, res) {
  try {
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureStockTaggingTables(client);

    const { item_ids = [], sku_codes = [] } = req.body;

    if (Array.isArray(item_ids) && item_ids.length > 0) {
      for (const id of item_ids) {
        await client.execute({
          sql: `UPDATE stock_tagged_items SET tag_printed_count = tag_printed_count + 1, tag_last_printed_at = CURRENT_TIMESTAMP WHERE item_id = ?;`,
          args: [parseInt(id, 10)],
        });
      }
    } else if (Array.isArray(sku_codes) && sku_codes.length > 0) {
      for (const sku of sku_codes) {
        await client.execute({
          sql: `UPDATE stock_tagged_items SET tag_printed_count = tag_printed_count + 1, tag_last_printed_at = CURRENT_TIMESTAMP WHERE sku_code = ?;`,
          args: [String(sku).trim()],
        });
      }
    }

    return res.json({ success: true, message: "Tag print counts updated." });
  } catch (error) {
    console.error("Error in markStockTagsPrintedController:", error);
    return res.status(500).json({ success: false, message: error?.message || "Failed to update print status." });
  }
}
