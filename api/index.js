import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import { initMasterSchema } from "../backend/src/config/schema.js";
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

// Enable CORS for web clients
app.use(
  cors({
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

app.use(express.json());

// Lazy-initialize Master DB Schema
let schemaInitialized = false;
let schemaPromise = null;

async function ensureSchema() {
  if (!schemaInitialized) {
    if (!schemaPromise) {
      schemaPromise = initMasterSchema()
        .then(() => {
          schemaInitialized = true;
        })
        .catch((err) => {
          console.error("Master DB Schema initialization failed:", err);
          schemaPromise = null;
        });
    }
    await schemaPromise;
  }
}

app.use(async (req, res, next) => {
  if (req.path !== "/api/health") {
    await ensureSchema();
  }
  next();
});

// API Health Check
app.get("/api/health", (req, res) => {
  res.json({
    status: "online",
    message: "ProGold Multi-Tenant Turso Backend API is running smoothly on Vercel.",
    timestamp: new Date().toISOString(),
  });
});

// Authentication Routes
app.post("/api/auth/send-otp", sendOtpController);
app.post("/api/auth/verify-otp", verifyOtpController);
app.post("/api/auth/test-turso", testTursoController);
app.post("/api/auth/register", registerController);
app.post("/api/auth/login", loginController);

// Authenticated Tenant Routes
app.get("/api/tenant/profile", requireAuth, getProfileController);
app.put("/api/tenant/profile", requireAuth, updateProfileController);
app.get("/api/tenant/db/overview", requireAuth, getTenantDbOverviewController);
app.get("/api/tenant/db/health", requireAuth, testTenantDbHealthController);
app.post("/api/tenant/db/query", requireAuth, executeTenantQueryController);

// Error handling middleware
app.use((err, req, res, next) => {
  console.error("Unhandled server error:", err);
  res.status(500).json({ success: false, message: "Internal server error." });
});

export default app;
