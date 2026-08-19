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
} from "./controllers/tenantController.js";
import { requireAuth } from "./middleware/authMiddleware.js";

dotenv.config();

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
