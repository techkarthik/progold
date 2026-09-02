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
  verifyEmailController,
} from "./controllers/authController.js";
import {
  getProfileController,
  updateProfileController,
  getTenantDbStatusController,
  optimizeTenantDbController,
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
import {
  getUsersController,
  createUserController,
  updateUserController,
  changePasswordController,
  deleteUserController,
  recoverPasswordOtpController,
} from "./controllers/userController.js";
import {
  getEmployeesController,
  createEmployeeController,
  updateEmployeeController,
  deleteEmployeeController,
} from "./controllers/employeeController.js";
import {
  getAccountHeadsController,
  getAccountHeadOptionsController,
  createAccountHeadOptionController,
  createAccountHeadController,
  updateAccountHeadController,
  deleteAccountHeadController,
} from "./controllers/accountHeadController.js";
import {
  getTaxMasterController,
  createTaxMasterController,
  updateTaxMasterController,
  deleteTaxMasterController,
} from "./controllers/taxMasterController.js";
import {
  getMetalsController,
  createMetalController,
  updateMetalController,
  deleteMetalController,
  getPuritiesController,
  createPurityController,
  updatePurityController,
  deletePurityController,
  getCategoriesController,
  createCategoryController,
  updateCategoryController,
  deleteCategoryController,
  getProductsController,
  createProductController,
  updateProductController,
  deleteProductController,
  getSubProductsController,
  createSubProductController,
  updateSubProductController,
  deleteSubProductController,
} from "./controllers/inventoryMasterController.js";
import {
  getSystemControlsController,
  createSystemControlController,
  updateSystemControlController,
  deleteSystemControlController,
} from "./controllers/systemControlsController.js";
import {
  getEstimatesController,
  createEstimateController,
  updateEstimateController,
  deleteEstimateController,
} from "./controllers/estimateController.js";
import {
  getLatestRatesController,
  getRatesByDateController,
  bulkUpdateRatesController,
  getRateHistoryController,
  deleteRateRecordController,
} from "./controllers/rateMasterController.js";
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
app.post("/api/auth/verify-email", verifyEmailController);
app.post("/api/auth/login", loginController);

// Authenticated Tenant Routes
app.get("/api/tenant/profile", requireAuth, getProfileController);
app.put("/api/tenant/profile", requireAuth, updateProfileController);
app.get("/api/tenant/db/status", requireAuth, getTenantDbStatusController);
app.post("/api/tenant/db/optimize", requireAuth, optimizeTenantDbController);
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

// Tenant User Master CRUD & Password Management Routes
app.get("/api/tenant/users", requireAuth, getUsersController);
app.post("/api/tenant/users", requireAuth, createUserController);
app.put("/api/tenant/users/:id", requireAuth, updateUserController);
app.delete("/api/tenant/users/:id", requireAuth, deleteUserController);
app.post("/api/tenant/users/:id/change-password", requireAuth, changePasswordController);
app.post("/api/tenant/users/recover-password", requireAuth, recoverPasswordOtpController);

// Tenant Employee Master CRUD Routes
app.get("/api/tenant/employees", requireAuth, getEmployeesController);
app.post("/api/tenant/employees", requireAuth, createEmployeeController);
app.put("/api/tenant/employees/:id", requireAuth, updateEmployeeController);
app.delete("/api/tenant/employees/:id", requireAuth, deleteEmployeeController);

// Tenant Account Head CRUD Routes
app.get("/api/tenant/account-heads", requireAuth, getAccountHeadsController);
app.get("/api/tenant/account-heads/options", requireAuth, getAccountHeadOptionsController);
app.post("/api/tenant/account-heads/options", requireAuth, createAccountHeadOptionController);
app.post("/api/tenant/account-heads", requireAuth, createAccountHeadController);
app.put("/api/tenant/account-heads/:id", requireAuth, updateAccountHeadController);
app.delete("/api/tenant/account-heads/:id", requireAuth, deleteAccountHeadController);

// Tenant Tax Master CRUD Routes
app.get("/api/tenant/tax-master", requireAuth, getTaxMasterController);
app.post("/api/tenant/tax-master", requireAuth, createTaxMasterController);
app.put("/api/tenant/tax-master/:id", requireAuth, updateTaxMasterController);
app.delete("/api/tenant/tax-master/:id", requireAuth, deleteTaxMasterController);

// Tenant Metals CRUD Routes
app.get("/api/tenant/metals", requireAuth, getMetalsController);
app.post("/api/tenant/metals", requireAuth, createMetalController);
app.put("/api/tenant/metals/:id", requireAuth, updateMetalController);
app.delete("/api/tenant/metals/:id", requireAuth, deleteMetalController);

// Tenant Purities CRUD Routes
app.get("/api/tenant/purities", requireAuth, getPuritiesController);
app.post("/api/tenant/purities", requireAuth, createPurityController);
app.put("/api/tenant/purities/:id", requireAuth, updatePurityController);
app.delete("/api/tenant/purities/:id", requireAuth, deletePurityController);

// Tenant Categories CRUD Routes
app.get("/api/tenant/categories", requireAuth, getCategoriesController);
app.post("/api/tenant/categories", requireAuth, createCategoryController);
app.put("/api/tenant/categories/:id", requireAuth, updateCategoryController);
app.delete("/api/tenant/categories/:id", requireAuth, deleteCategoryController);

// Tenant Products CRUD Routes (4th Master under Inventory)
app.get("/api/tenant/products", requireAuth, getProductsController);
app.post("/api/tenant/products", requireAuth, createProductController);
app.put("/api/tenant/products/:id", requireAuth, updateProductController);
app.delete("/api/tenant/products/:id", requireAuth, deleteProductController);

// Tenant Sub-Products CRUD Routes (5th Master under Inventory)
app.get("/api/tenant/subproducts", requireAuth, getSubProductsController);
app.post("/api/tenant/subproducts", requireAuth, createSubProductController);
app.put("/api/tenant/subproducts/:id", requireAuth, updateSubProductController);
app.delete("/api/tenant/subproducts/:id", requireAuth, deleteSubProductController);

// Tenant System Controls CRUD Routes (4th Menu under Settings)
app.get("/api/tenant/system-controls", requireAuth, getSystemControlsController);
app.post("/api/tenant/system-controls", requireAuth, createSystemControlController);
app.put("/api/tenant/system-controls/:id", requireAuth, updateSystemControlController);
app.delete("/api/tenant/system-controls/:id", requireAuth, deleteSystemControlController);

// Tenant Estimates / Quotation Routes (3rd Main Menu)
app.get("/api/tenant/estimates", requireAuth, getEstimatesController);
app.post("/api/tenant/estimates", requireAuth, createEstimateController);
app.put("/api/tenant/estimates/:id", requireAuth, updateEstimateController);
app.delete("/api/tenant/estimates/:id", requireAuth, deleteEstimateController);

// Tenant Daily Purity Rates & History Routes (Sales & Price Master)
app.get("/api/tenant/rates/latest", requireAuth, getLatestRatesController);
app.get("/api/tenant/rates/by-date", requireAuth, getRatesByDateController);
app.post("/api/tenant/rates/bulk-update", requireAuth, bulkUpdateRatesController);
app.get("/api/tenant/rates/history", requireAuth, getRateHistoryController);
app.delete("/api/tenant/rates/:id", requireAuth, deleteRateRecordController);

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
