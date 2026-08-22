import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import { initMasterSchema } from "./config/schema.js";
import {
  sendOtpController,
  verifyOtpController,
  testTursoController,
  registerController,
  loginController,
} from "./controllers/authController.js";
import {
  getProfileController,
  updateProfileController,
  getTenantDbOverviewController,
  executeTenantQueryController,
  testTenantDbHealthController,
  reinstallTenantDbController,
} from "./controllers/tenantController.js";
import {
  getCompaniesController,
  createCompanyController,
  updateCompanyController,
  deleteCompanyController,
} from "./controllers/companyController.js";
import {
  getBranchesController,
  createBranchController,
  updateBranchController,
  deleteBranchController,
} from "./controllers/branchController.js";
import { requireAuth } from "./middleware/authMiddleware.js";

import path from "path";
import { fileURLToPath } from "url";

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const webBuildPath = path.resolve(__dirname, "../../frontend/build/web");

const app = express();
const PORT = process.env.PORT || 5000;

// Enable CORS for web clients
app.use(
  cors({
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

app.use(express.json());

// Serve compiled Flutter web app
app.use(express.static(webBuildPath));

// API Health Check
app.get("/api/health", (req, res) => {
  res.json({
    status: "online",
    message: "ProGold Multi-Tenant Turso Backend API is running smoothly.",
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
app.post("/api/tenant/db/reinstall", requireAuth, reinstallTenantDbController);

// Tenant Company Master CRUD Routes
app.get("/api/tenant/companies", requireAuth, getCompaniesController);
app.post("/api/tenant/companies", requireAuth, createCompanyController);
app.put("/api/tenant/companies/:id", requireAuth, updateCompanyController);
app.delete("/api/tenant/companies/:id", requireAuth, deleteCompanyController);

// Tenant Branch Master CRUD Routes
app.get("/api/tenant/branches", requireAuth, getBranchesController);
app.post("/api/tenant/branches", requireAuth, createBranchController);
app.put("/api/tenant/branches/:id", requireAuth, updateBranchController);
app.delete("/api/tenant/branches/:id", requireAuth, deleteBranchController);

// SPA fallback to index.html
app.get("*", (req, res, next) => {
  if (req.path.startsWith("/api/")) return next();
  res.sendFile(path.join(webBuildPath, "index.html"), (err) => {
    if (err) next();
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error("Unhandled server error:", err);
  res.status(500).json({ success: false, message: "Internal server error." });
});

// Initialize Schema and Start Server
async function startServer() {
  try {
    await initMasterSchema();
    app.listen(PORT, "0.0.0.0", () => {
      console.log(`\n======================================================`);
      console.log(` ProGold Multi-Tenant Server running on http://localhost:${PORT}`);
      console.log(` Master Turso DB: Connected`);
      console.log(` Ready for Flutter Web & Desktop requests!`);
      console.log(`======================================================\n`);
    });
  } catch (error) {
    console.error("Failed to start server due to Master Turso DB error:", error);
    process.exit(1);
  }
}

startServer();
