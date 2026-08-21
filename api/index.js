import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import { initMasterSchema } from "../backend/src/config/schema.js";
import { masterTurso } from "../backend/src/config/turso.js";
import {
  sendOtpController,
  verifyOtpController,
  testTursoController,
  registerController,
  loginController,
} from "../backend/src/controllers/authController.js";
import {
  getProfileController,
  updateProfileController,
  getTenantDbOverviewController,
  executeTenantQueryController,
  testTenantDbHealthController,
} from "../backend/src/controllers/tenantController.js";
import { requireAuth } from "../backend/src/middleware/authMiddleware.js";

dotenv.config();

const app = express();

// Enable CORS for all web clients & preflight
app.use(
  cors({
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "Accept", "Origin", "X-Requested-With"],
    credentials: true,
  })
);

app.options("*", cors());
app.use(express.json());

// Lazy-initialize Master DB Schema
let schemaInitialized = false;
let schemaPromise = null;

async function ensureSchema() {
  if (!process.env.MASTER_TURSO_AUTH_TOKEN) {
    console.warn("[WARNING] MASTER_TURSO_AUTH_TOKEN is not set in environment variables.");
    return;
  }
  if (!schemaInitialized) {
    if (!schemaPromise) {
      schemaPromise = initMasterSchema()
        .then(() => {
          schemaInitialized = true;
        })
        .catch((err) => {
          console.error("Master DB Schema initialization failed:", err.message);
          schemaPromise = null;
        });
    }
    await schemaPromise;
  }
}

// Router containing all API endpoints
const router = express.Router();

// Middleware to ensure schema is initialized before handling route
router.use(async (req, res, next) => {
  if (req.path !== "/health" && req.path !== "/api/health") {
    await ensureSchema();
  }
  next();
});

// Comprehensive Diagnostic Health Check Endpoint
router.get("/health", async (req, res) => {
  let dbStatus = "unknown";
  let dbError = null;
  let dbLatencyMs = null;

  const hasToken = !!process.env.MASTER_TURSO_AUTH_TOKEN;
  const hasUrl = !!process.env.MASTER_TURSO_URL;

  if (!hasToken) {
    dbStatus = "missing_environment_variables";
    dbError = "MASTER_TURSO_AUTH_TOKEN is missing in Vercel Environment Variables.";
  } else {
    try {
      const start = Date.now();
      await masterTurso.execute("SELECT 1 AS ping;");
      dbLatencyMs = Date.now() - start;
      dbStatus = "connected";
    } catch (err) {
      dbStatus = "connection_failed";
      dbError = err.message;
    }
  }

  const isHealthy = dbStatus === "connected";

  res.status(isHealthy ? 200 : 503).json({
    status: isHealthy ? "online" : "degraded",
    message: isHealthy
      ? "ProGold Multi-Tenant Turso Backend API is running smoothly on Vercel."
      : "ProGold API is running, but database connection needs configuration.",
    diagnostics: {
      database: {
        status: dbStatus,
        latencyMs: dbLatencyMs,
        error: dbError,
        urlConfigured: hasUrl,
        tokenConfigured: hasToken,
      },
      smtp: {
        configured: !!(process.env.SMTP_USER && process.env.SMTP_PASS),
        host: process.env.SMTP_HOST || "smtp.gmail.com",
        userConfigured: !!process.env.SMTP_USER,
      },
      environment: process.env.NODE_ENV || "production",
      timestamp: new Date().toISOString(),
    },
  });
});

// Authentication Routes
router.post("/auth/send-otp", sendOtpController);
router.post("/auth/verify-otp", verifyOtpController);
router.post("/auth/test-turso", testTursoController);
router.post("/auth/register", registerController);
router.post("/auth/login", loginController);

// Authenticated Tenant Routes
router.get("/tenant/profile", requireAuth, getProfileController);
router.put("/tenant/profile", requireAuth, updateProfileController);
router.get("/tenant/db/overview", requireAuth, getTenantDbOverviewController);
router.get("/tenant/db/health", requireAuth, testTenantDbHealthController);
router.post("/tenant/db/query", requireAuth, executeTenantQueryController);

// Mount router on both '/api' and '/' to ensure all rewrite scenarios work
app.use("/api", router);
app.use("/", router);

// Error handling middleware
app.use((err, req, res, next) => {
  console.error("Unhandled server error:", err);
  const isMissingToken = !process.env.MASTER_TURSO_AUTH_TOKEN;
  res.status(500).json({
    success: false,
    message: isMissingToken
      ? "Server configuration error: MASTER_TURSO_AUTH_TOKEN is missing in Vercel environment variables."
      : err?.message || "Internal server error.",
    error: err?.message,
  });
});

export default app;

