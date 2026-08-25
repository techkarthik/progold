import { masterTurso } from "../config/turso.js";
import {
  getTenantDatabaseOverview,
  executeTenantQuery,
  testTursoConnection,
  syncTenantDatabaseSchema,
} from "../services/tursoService.js";

/**
 * Get tenant profile and validity metadata
 */
export async function getProfileController(req, res) {
  try {
    const tenant = req.tenant;
    const today = new Date();
    const validToDate = new Date(tenant.valid_to);
    const validFromDate = new Date(tenant.valid_from);

    const diffTime = validToDate.getTime() - today.getTime();
    const daysRemaining = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

    return res.json({
      success: true,
      role: req.user ? req.user.role : "ADMIN",
      user: req.user || null,
      tenant: {
        id: tenant.id,
        email: tenant.email,
        business_name: tenant.business_name || "ProGold Business",
        business_logo: tenant.business_logo || "",
        contact_number: tenant.contact_number,
        turso_url: tenant.turso_url,
        valid_from: tenant.valid_from,
        valid_to: tenant.valid_to,
        status: tenant.status,
        days_remaining: daysRemaining,
        is_active: daysRemaining >= 0 && today >= validFromDate,
        created_at: tenant.created_at,
      },
    });
  } catch (error) {
    console.error("getProfileController error:", error);
    return res.status(500).json({ success: false, message: "Failed to fetch tenant profile." });
  }
}

/**
 * Update business name and logo
 */
export async function updateProfileController(req, res) {
  try {
    const tenantId = req.tenant.id;
    const { business_name, business_logo, contact_number } = req.body;

    const now = new Date().toISOString();
    await masterTurso.execute({
      sql: `UPDATE tenants 
            SET business_name = COALESCE(?, business_name),
                business_logo = COALESCE(?, business_logo),
                contact_number = COALESCE(?, contact_number),
                updated_at = ?
            WHERE id = ?`,
      args: [business_name || null, business_logo || null, contact_number || null, now, tenantId],
    });

    return res.json({
      success: true,
      message: "Business profile updated successfully!",
      business_name,
      business_logo,
    });
  } catch (error) {
    console.error("updateProfileController error:", error);
    return res.status(500).json({ success: false, message: "Failed to update profile." });
  }
}

/**
 * Get overview of tables in tenant's own Turso database
 */
export async function getTenantDbOverviewController(req, res) {
  try {
    const { turso_url, turso_token } = req.tenant;
    const overview = await getTenantDatabaseOverview(turso_url, turso_token);
    return res.json(overview);
  } catch (error) {
    console.error("getTenantDbOverviewController error:", error);
    return res.status(500).json({ success: false, message: "Failed to fetch database overview." });
  }
}

/**
 * Execute custom SQL query on tenant's private Turso database
 */
export async function executeTenantQueryController(req, res) {
  try {
    const { sql, args = [] } = req.body;
    if (!sql || typeof sql !== "string") {
      return res.status(400).json({ success: false, message: "SQL query string is required." });
    }

    const { turso_url, turso_token } = req.tenant;
    const result = await executeTenantQuery(turso_url, turso_token, sql.trim(), args);
    return res.json(result);
  } catch (error) {
    console.error("executeTenantQueryController error:", error);
    return res.status(500).json({ success: false, message: "Failed to execute database query." });
  }
}

/**
 * Test health of tenant's own Turso database connection
 */
export async function testTenantDbHealthController(req, res) {
  try {
    const { turso_url, turso_token } = req.tenant;
    const result = await testTursoConnection(turso_url, turso_token);
    return res.json(result);
  } catch (error) {
    console.error("testTenantDbHealthController error:", error);
    return res.status(500).json({ success: false, message: "Database health check failed." });
  }
}

/**
 * Reinstall & Synchronize latest ProGold ERP schema into tenant's database on demand
 */
export async function reinstallTenantDbController(req, res) {
  try {
    const { turso_url, turso_token } = req.tenant;
    const syncResult = await syncTenantDatabaseSchema(turso_url, turso_token);
    return res.json(syncResult);
  } catch (error) {
    console.error("reinstallTenantDbController error:", error);
    return res.status(500).json({
      success: false,
      message: `Failed to reinstall schema: ${error?.message || "Internal server error"}`,
      error: error?.message,
    });
  }
}
