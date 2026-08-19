import { createClient } from "@libsql/client";
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
dotenv.config({ path: path.resolve(__dirname, "../../.env") });

const MASTER_URL = process.env.MASTER_TURSO_URL || "libsql://gold-techkarthik.aws-ap-south-1.turso.io";
const MASTER_TOKEN = process.env.MASTER_TURSO_AUTH_TOKEN || "";

if (!MASTER_TOKEN) {
  console.warn("WARNING: MASTER_TURSO_AUTH_TOKEN is not set in environment.");
}

// Master Turso Database Client
export const masterTurso = createClient({
  url: MASTER_URL,
  authToken: MASTER_TOKEN,
});

/**
 * Creates a dynamic Turso client for a specific tenant database.
 * @param {string} url - The tenant's Turso database URL (e.g. libsql://tenant.turso.io)
 * @param {string} authToken - The tenant's Turso auth token
 * @returns {Client}
 */
export function createTenantClient(url, authToken) {
  let formattedUrl = url.trim();
  // Ensure valid protocol
  if (!formattedUrl.startsWith("libsql://") && !formattedUrl.startsWith("https://") && !formattedUrl.startsWith("http://")) {
    formattedUrl = `libsql://${formattedUrl}`;
  }
  return createClient({
    url: formattedUrl,
    authToken: authToken.trim(),
  });
}
