import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { masterTurso } from "../config/turso.js";
import { sendOtp, verifyOtp, isEmailVerified } from "../services/otpService.js";
import { testTursoConnection, syncTenantDatabaseSchema } from "../services/tursoService.js";

const JWT_SECRET = process.env.JWT_SECRET || "progold_super_secure_jwt_secret_key_2026_turso_multitenant";

/**
 * Send OTP to email for registration
 */
export async function sendOtpController(req, res) {
  try {
    const { email } = req.body;
    if (!email || !email.includes("@")) {
      return res.status(400).json({ success: false, message: "Valid email is required." });
    }

    const result = await sendOtp(email);
    return res.json(result);
  } catch (error) {
    console.error("sendOtpController error:", error);
    return res.status(500).json({ success: false, message: "Failed to send verification code." });
  }
}

/**
 * Verify OTP entered by user
 */
export async function verifyOtpController(req, res) {
  try {
    const { email, code } = req.body;
    if (!email || !code) {
      return res.status(400).json({ success: false, message: "Email and OTP code are required." });
    }

    const result = await verifyOtp(email, code);
    if (!result.valid) {
      return res.status(400).json({ success: false, message: result.message });
    }

    return res.json({ success: true, message: result.message });
  } catch (error) {
    console.error("verifyOtpController error:", error);
    return res.status(500).json({ success: false, message: "Failed to verify OTP." });
  }
}

/**
 * Test connectivity for tenant's Turso database
 */
export async function testTursoController(req, res) {
  try {
    const { turso_url, turso_token } = req.body;
    if (!turso_url || !turso_token) {
      return res.status(400).json({ success: false, message: "Both Turso URL and Auth Token are required." });
    }

    const result = await testTursoConnection(turso_url, turso_token);
    return res.json(result);
  } catch (error) {
    console.error("testTursoController error:", error);
    return res.status(500).json({ success: false, message: "Failed to test Turso connection." });
  }
}

/**
 * Register a new multi-tenant account
 */
export async function registerController(req, res) {
  try {
    const {
      email,
      password,
      contact_number,
      turso_url,
      turso_token,
      valid_from,
      valid_to,
    } = req.body;

    // Basic Validations
    if (!email || !password || !contact_number || !turso_url || !turso_token || !valid_from || !valid_to) {
      return res.status(400).json({
        success: false,
        message: "All fields are required (Email, Password, Contact, Turso URL, Turso Token, Valid From, Valid To).",
      });
    }

    const normalizedEmail = email.trim().toLowerCase();

    // 1. Verify OTP was completed
    const verified = await isEmailVerified(normalizedEmail);
    if (!verified) {
      return res.status(400).json({
        success: false,
        message: "Email has not been verified with OTP. Please complete OTP verification first.",
      });
    }

    // 2. Check if email already exists
    const existing = await masterTurso.execute({
      sql: `SELECT id FROM tenants WHERE email = ? LIMIT 1`,
      args: [normalizedEmail],
    });
    if (existing.rows.length > 0) {
      return res.status(409).json({
        success: false,
        message: "An account with this email is already registered.",
      });
    }

    // 3. Test tenant Turso connectivity before persisting
    const dbTest = await testTursoConnection(turso_url, turso_token);
    if (!dbTest.success) {
      return res.status(400).json({
        success: false,
        message: `Database connectivity test failed: ${dbTest.message}`,
      });
    }

    // 4. Hash password
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    const now = new Date().toISOString();

    // 5. Store in Master Turso DB
    const insertResult = await masterTurso.execute({
      sql: `INSERT INTO tenants (
              email, password_hash, contact_number, turso_url, turso_token,
              valid_from, valid_to, status, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, 'ACTIVE', ?, ?)`,
      args: [
        normalizedEmail,
        passwordHash,
        contact_number.trim(),
        turso_url.trim(),
        turso_token.trim(),
        valid_from.trim(),
        valid_to.trim(),
        now,
        now,
      ],
    });

    const tenantId = Number(insertResult.lastInsertRowid);

    // 6. Automatically Initialize & Provision the tenant's private Turso database schema
    try {
      await syncTenantDatabaseSchema(turso_url.trim(), turso_token.trim());
    } catch (schemaErr) {
      console.warn("Notice: Non-fatal schema sync warning on register:", schemaErr.message);
    }

    // 7. Generate JWT token
    const token = jwt.sign(
      { id: tenantId, email: normalizedEmail },
      JWT_SECRET,
      { expiresIn: "7d" }
    );

    return res.status(201).json({
      success: true,
      message: "Tenant registered successfully!",
      token,
      tenant: {
        id: tenantId,
        email: normalizedEmail,
        contact_number: contact_number.trim(),
        turso_url: turso_url.trim(),
        valid_from: valid_from.trim(),
        valid_to: valid_to.trim(),
        status: "ACTIVE",
        created_at: now,
      },
    });
  } catch (error) {
    console.error("registerController error:", error);
    return res.status(500).json({
      success: false,
      message: `Registration failed: ${error?.message || "Internal server error"}`,
      error: error?.message,
    });
  }
}

/**
 * Tenant login handler
 */
export async function loginController(req, res) {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ success: false, message: "Email and password are required." });
    }

    const normalizedEmail = email.trim().toLowerCase();

    // 1. Fetch tenant
    const result = await masterTurso.execute({
      sql: `SELECT * FROM tenants WHERE email = ? LIMIT 1`,
      args: [normalizedEmail],
    });

    if (result.rows.length === 0) {
      return res.status(401).json({ success: false, message: "Invalid email or password." });
    }

    const tenant = result.rows[0];

    // 2. Compare password
    const isMatch = await bcrypt.compare(password, tenant.password_hash);
    if (!isMatch) {
      return res.status(401).json({ success: false, message: "Invalid email or password." });
    }

    // 3. Check status
    if (tenant.status !== "ACTIVE") {
      return res.status(403).json({ success: false, message: "Your tenant account is inactive or suspended." });
    }

    // 4. Check validity period
    const today = new Date().toISOString().split("T")[0];
    const isExpired = today < tenant.valid_from || today > tenant.valid_to;

    if (isExpired) {
      return res.status(403).json({
        success: false,
        message: `Your account subscription has expired (Validity period: ${tenant.valid_from} to ${tenant.valid_to}). Please contact support.`,
        isExpired: true,
        validFrom: tenant.valid_from,
        validTo: tenant.valid_to,
      });
    }

    // 5. Generate JWT token
    const token = jwt.sign(
      { id: tenant.id, email: tenant.email },
      JWT_SECRET,
      { expiresIn: "7d" }
    );

    return res.json({
      success: true,
      message: "Login successful!",
      token,
      tenant: {
        id: tenant.id,
        email: tenant.email,
        contact_number: tenant.contact_number,
        turso_url: tenant.turso_url,
        valid_from: tenant.valid_from,
        valid_to: tenant.valid_to,
        status: tenant.status,
        created_at: tenant.created_at,
      },
    });
  } catch (error) {
    console.error("loginController error:", error);
    return res.status(500).json({
      success: false,
      message: `Login failed: ${error?.message || "Internal server error"}`,
      error: error?.message,
    });
  }
}
