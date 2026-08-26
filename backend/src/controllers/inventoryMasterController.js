import { createTenantClient } from "../config/turso.js";

/**
 * Helper to ensure metals, purities, and categories tables exist in the tenant Turso DB.
 */
async function ensureInventoryTables(client) {
  // Metals
  await client.execute(`
    CREATE TABLE IF NOT EXISTS metals (
      metalid TEXT PRIMARY KEY NOT NULL,
      metalname TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  `);

  // Purities
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

  // Categories (Refactored)
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
}

/**
 * Helper to determine Category Code Prefix (2 characters)
 * e.g., 'G' + 'ORNAMENTS' => 'GO'
 *       'G' + 'METAL'     => 'GB' (Gold Bar/Bullion)
 */
function getCategoryPrefix(metalId, categoryType) {
  const m = String(metalId).trim().toUpperCase().substring(0, 1);
  const typeClean = String(categoryType).trim().toUpperCase();
  const t = typeClean.includes("ORNAMENT") ? "O" : "B";
  return m + t;
}

// ==========================================
// 1. METALS CRUD CONTROLLERS
// ==========================================

export async function getMetalsController(req, res) {
  try {
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureInventoryTables(client);

    const result = await client.execute(`SELECT * FROM metals ORDER BY metalname ASC;`);
    return res.json({ success: true, metals: result.rows || [] });
  } catch (error) {
    console.error("getMetals error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function createMetalController(req, res) {
  try {
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureInventoryTables(client);

    const { metalid, metalname } = req.body;

    if (!metalid || !metalid.trim()) {
      return res.status(400).json({ success: false, message: "Metal ID is required." });
    }
    const cleanId = metalid.trim().toUpperCase();
    if (cleanId.length > 2) {
      return res.status(400).json({ success: false, message: "Metal ID must be max 2 characters." });
    }

    if (!metalname || !metalname.trim()) {
      return res.status(400).json({ success: false, message: "Metal Name is required." });
    }

    // Check duplicate
    const checkDup = await client.execute({
      sql: `SELECT metalid FROM metals WHERE metalid = ? LIMIT 1;`,
      args: [cleanId],
    });
    if (checkDup.rows.length > 0) {
      return res.status(409).json({ success: false, message: `Metal ID "${cleanId}" already exists.` });
    }

    const now = new Date().toISOString();
    await client.execute({
      sql: `INSERT INTO metals (metalid, metalname, created_at, updated_at) VALUES (?, ?, ?, ?);`,
      args: [cleanId, metalname.trim(), now, now],
    });

    return res.status(201).json({
      success: true,
      message: "Metal created successfully!",
      metal: { metalid: cleanId, metalname: metalname.trim(), created_at: now, updated_at: now }
    });
  } catch (error) {
    console.error("createMetal error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function updateMetalController(req, res) {
  try {
    const { id } = req.params; // metalid
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureInventoryTables(client);

    const { metalname } = req.body;
    if (!metalname || !metalname.trim()) {
      return res.status(400).json({ success: false, message: "Metal Name is required." });
    }

    const now = new Date().toISOString();
    await client.execute({
      sql: `UPDATE metals SET metalname = ?, updated_at = ? WHERE metalid = ?;`,
      args: [metalname.trim(), now, id.toUpperCase()],
    });

    return res.json({ success: true, message: "Metal updated successfully!" });
  } catch (error) {
    console.error("updateMetal error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function deleteMetalController(req, res) {
  try {
    const { id } = req.params; // metalid
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureInventoryTables(client);

    // Verify dependencies in purities & categories
    const checkPurity = await client.execute({
      sql: `SELECT purityid FROM purities WHERE metalid = ? LIMIT 1;`,
      args: [id.toUpperCase()],
    });
    if (checkPurity.rows.length > 0) {
      return res.status(400).json({ success: false, message: "Cannot delete metal as it is linked to Purity master records." });
    }

    const checkCat = await client.execute({
      sql: `SELECT id FROM categories WHERE metalid = ? LIMIT 1;`,
      args: [id.toUpperCase()],
    });
    if (checkCat.rows.length > 0) {
      return res.status(400).json({ success: false, message: "Cannot delete metal as it is linked to Category master records." });
    }

    await client.execute({
      sql: `DELETE FROM metals WHERE metalid = ?;`,
      args: [id.toUpperCase()],
    });

    return res.json({ success: true, message: "Metal deleted successfully!" });
  } catch (error) {
    console.error("deleteMetal error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

// ==========================================
// 2. PURITIES CRUD CONTROLLERS
// ==========================================

export async function getPuritiesController(req, res) {
  try {
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureInventoryTables(client);

    const result = await client.execute(`
      SELECT p.*, m.metalname 
      FROM purities p
      JOIN metals m ON p.metalid = m.metalid
      ORDER BY p.purity DESC;
    `);
    return res.json({ success: true, purities: result.rows || [] });
  } catch (error) {
    console.error("getPurities error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function createPurityController(req, res) {
  try {
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureInventoryTables(client);

    const { metalid, purityname, purityshortname, purity, type } = req.body;

    if (!metalid) return res.status(400).json({ success: false, message: "Metal ID selection is required." });
    if (!purityname || !purityname.trim()) return res.status(400).json({ success: false, message: "Purity Name is required." });
    if (!purityshortname || !purityshortname.trim()) return res.status(400).json({ success: false, message: "Purity Short Name is required." });
    if (purity === undefined || isNaN(Number(purity))) return res.status(400).json({ success: false, message: "Purity percentage numeric value is required." });
    if (!type || (type !== 'ORNAMENT' && type !== 'METAL')) return res.status(400).json({ success: false, message: "Purity Type must be ORNAMENT or METAL." });

    const now = new Date().toISOString();
    await client.execute({
      sql: `
        INSERT INTO purities (metalid, purityname, purityshortname, purity, type, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?);
      `,
      args: [
        metalid.toUpperCase(),
        purityname.trim(),
        purityshortname.trim(),
        Number(purity),
        type,
        now,
        now,
      ],
    });

    return res.status(201).json({ success: true, message: "Purity Master record created successfully!" });
  } catch (error) {
    console.error("createPurity error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function updatePurityController(req, res) {
  try {
    const { id } = req.params;
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureInventoryTables(client);

    const { metalid, purityname, purityshortname, purity, type } = req.body;

    if (!metalid) return res.status(400).json({ success: false, message: "Metal ID selection is required." });
    if (!purityname || !purityname.trim()) return res.status(400).json({ success: false, message: "Purity Name is required." });
    if (!purityshortname || !purityshortname.trim()) return res.status(400).json({ success: false, message: "Purity Short Name is required." });
    if (purity === undefined || isNaN(Number(purity))) return res.status(400).json({ success: false, message: "Purity value is required." });
    if (!type || (type !== 'ORNAMENT' && type !== 'METAL')) return res.status(400).json({ success: false, message: "Purity Type must be ORNAMENT or METAL." });

    const now = new Date().toISOString();
    await client.execute({
      sql: `
        UPDATE purities
        SET metalid = ?,
            purityname = ?,
            purityshortname = ?,
            purity = ?,
            type = ?,
            updated_at = ?
        WHERE purityid = ?;
      `,
      args: [
        metalid.toUpperCase(),
        purityname.trim(),
        purityshortname.trim(),
        Number(purity),
        type,
        now,
        Number(id),
      ],
    });

    return res.json({ success: true, message: "Purity updated successfully!" });
  } catch (error) {
    console.error("updatePurity error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function deletePurityController(req, res) {
  try {
    const { id } = req.params;
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureInventoryTables(client);

    await client.execute({
      sql: `DELETE FROM purities WHERE purityid = ?;`,
      args: [Number(id)],
    });

    return res.json({ success: true, message: "Purity record deleted successfully!" });
  } catch (error) {
    console.error("deletePurity error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

// ==========================================
// 3. CATEGORIES CRUD CONTROLLERS
// ==========================================

export async function getCategoriesController(req, res) {
  try {
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureInventoryTables(client);

    const result = await client.execute(`
      SELECT c.*, m.metalname 
      FROM categories c
      JOIN metals m ON c.metalid = m.metalid
      ORDER BY c.created_at DESC;
    `);
    return res.json({ success: true, categories: result.rows || [] });
  } catch (error) {
    console.error("getCategories error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function createCategoryController(req, res) {
  try {
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureInventoryTables(client);

    const {
      metalid,
      catname,
      categorytype,
      sgst_per = 0.0,
      cgst_per = 0.0,
      igst_per = 0.0,
      sgstacname = "",
      cgstacname = "",
      igstacname = "",
    } = req.body;

    if (!metalid) return res.status(400).json({ success: false, message: "Metal ID selection is required." });
    if (!catname || !catname.trim()) return res.status(400).json({ success: false, message: "Category Name is required." });
    if (!categorytype || (categorytype !== 'METAL' && categorytype !== 'ORNAMENTS/STONE')) {
      return res.status(400).json({ success: false, message: "Category Type must be METAL or ORNAMENTS/STONE." });
    }

    const cleanMetalId = metalid.trim().toUpperCase();

    // Generate unique sequential alphanumeric Category Code
    const prefix = getCategoryPrefix(cleanMetalId, categorytype);
    const codeQuery = await client.execute({
      sql: `SELECT catcode FROM categories WHERE catcode LIKE ? ORDER BY catcode DESC LIMIT 1;`,
      args: [`${prefix}%`],
    });

    let nextNum = 1;
    if (codeQuery.rows.length > 0) {
      const lastCode = String(codeQuery.rows[0].catcode);
      const numberPart = lastCode.substring(prefix.length);
      const parsed = parseInt(numberPart, 10);
      if (!isNaN(parsed)) {
        nextNum = parsed + 1;
      }
    }
    const catcode = prefix + String(nextNum).padStart(5, '0');

    const now = new Date().toISOString();
    await client.execute({
      sql: `
        INSERT INTO categories (
          metalid, catcode, catname, categorytype, sgst_per, cgst_per, igst_per, sgstacname, cgstacname, igstacname, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      `,
      args: [
        cleanMetalId,
        catcode,
        catname.trim(),
        categorytype,
        Number(sgst_per) || 0.0,
        Number(cgst_per) || 0.0,
        Number(igst_per) || 0.0,
        sgstacname.trim(),
        cgstacname.trim(),
        igstacname.trim(),
        now,
        now,
      ],
    });

    return res.status(201).json({
      success: true,
      message: "Category created successfully!",
      catcode: catcode,
    });
  } catch (error) {
    console.error("createCategory error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function updateCategoryController(req, res) {
  try {
    const { id } = req.params; // category table auto-increment id
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureInventoryTables(client);

    const {
      metalid,
      catname,
      categorytype,
      sgst_per,
      cgst_per,
      igst_per,
      sgstacname,
      cgstacname,
      igstacname,
    } = req.body;

    if (!metalid) return res.status(400).json({ success: false, message: "Metal ID selection is required." });
    if (!catname || !catname.trim()) return res.status(400).json({ success: false, message: "Category Name is required." });
    if (!categorytype || (categorytype !== 'METAL' && categorytype !== 'ORNAMENTS/STONE')) {
      return res.status(400).json({ success: false, message: "Category Type must be METAL or ORNAMENTS/STONE." });
    }

    // Verify existing category
    const checkCat = await client.execute({
      sql: `SELECT metalid, categorytype, catcode FROM categories WHERE id = ? LIMIT 1;`,
      args: [Number(id)],
    });

    if (checkCat.rows.length === 0) {
      return res.status(404).json({ success: false, message: "Category record not found." });
    }

    let finalCatcode = checkCat.rows[0].catcode;
    const oldMetalid = checkCat.rows[0].metalid;
    const oldType = checkCat.rows[0].categorytype;

    // If metal id or category type is updated, regenerate code
    if (oldMetalid !== metalid.toUpperCase() || oldType !== categorytype) {
      const prefix = getCategoryPrefix(metalid, categorytype);
      const codeQuery = await client.execute({
        sql: `SELECT catcode FROM categories WHERE catcode LIKE ? ORDER BY catcode DESC LIMIT 1;`,
        args: [`${prefix}%`],
      });

      let nextNum = 1;
      if (codeQuery.rows.length > 0) {
        const lastCode = String(codeQuery.rows[0].catcode);
        const numberPart = lastCode.substring(prefix.length);
        const parsed = parseInt(numberPart, 10);
        if (!isNaN(parsed)) {
          nextNum = parsed + 1;
        }
      }
      finalCatcode = prefix + String(nextNum).padStart(5, '0');
    }

    const now = new Date().toISOString();
    await client.execute({
      sql: `
        UPDATE categories
        SET metalid = ?,
            catcode = ?,
            catname = ?,
            categorytype = ?,
            sgst_per = ?,
            cgst_per = ?,
            igst_per = ?,
            sgstacname = ?,
            cgstacname = ?,
            igstacname = ?,
            updated_at = ?
        WHERE id = ?;
      `,
      args: [
        metalid.toUpperCase(),
        finalCatcode,
        catname.trim(),
        categorytype,
        sgst_per !== undefined ? Number(sgst_per) : 0.0,
        cgst_per !== undefined ? Number(cgst_per) : 0.0,
        igst_per !== undefined ? Number(igst_per) : 0.0,
        sgstacname !== undefined ? sgstacname.trim() : "",
        cgstacname !== undefined ? cgstacname.trim() : "",
        igstacname !== undefined ? igstacname.trim() : "",
        now,
        Number(id),
      ],
    });

    return res.json({ success: true, message: "Category updated successfully!", catcode: finalCatcode });
  } catch (error) {
    console.error("updateCategory error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function deleteCategoryController(req, res) {
  try {
    const { id } = req.params;
    const { turso_url, turso_token } = req.tenant;
    const client = createTenantClient(turso_url, turso_token);
    await ensureInventoryTables(client);

    await client.execute({
      sql: `DELETE FROM categories WHERE id = ?;`,
      args: [Number(id)],
    });

    return res.json({ success: true, message: "Category deleted successfully!" });
  } catch (error) {
    console.error("deleteCategory error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}
