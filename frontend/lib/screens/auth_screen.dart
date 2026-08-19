import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers for Login
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginObscure = true;

  // Controllers for Register
  final _regEmailController = TextEditingController();
  final _regOtpController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();
  final _regContactController = TextEditingController();
  final _regTursoUrlController = TextEditingController(text: "libsql://gold-techkarthik.aws-ap-south-1.turso.io");
  final _regTursoTokenController = TextEditingController(
    text: "eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJhIjoicnciLCJpYXQiOjE3ODcwNDAyMDcsImlkIjoiMDFhMDEzZTUtMWQwMS03NjMzLWExNTYtNTllMWY3NDk4YTkzIiwia2lkIjoibW9sNS1XSE1tQzE3X1BZazJza1M4cXdWOGJ1VnFmY3BQQ3BfMWphYS1nVSIsInJpZCI6Ijk4NDQ2MmE4LTNjMTItNDcyNi1hNTAzLWIzZGQ5YmMzYWRhMCJ9.LHSzWVKA6bSPEcW5deQZ7OVZVqr7Gf6UFrDIAdAiu4_wLY7I42TNKVMCkKRnjHVbtunG_LglAKxIh42pYf--DQ"
  );

  bool _regObscure = true;
  bool _regConfirmObscure = true;
  bool _regTursoTokenObscure = true;

  DateTime _validFrom = DateTime.now();
  DateTime _validTo = DateTime.now().add(const Duration(days: 365));

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _regEmailController.dispose();
    _regOtpController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    _regContactController.dispose();
    _regTursoUrlController.dispose();
    _regTursoTokenController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final initialDate = isFrom ? _validFrom : _validTo;
    final firstDate = isFrom ? DateTime(2020) : _validFrom;
    final lastDate = DateTime(2040);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: GlassTheme.primaryNeon,
              onPrimary: Colors.white,
              surface: GlassTheme.bgSurface,
              onSurface: GlassTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _validFrom = picked;
          if (_validTo.isBefore(_validFrom)) {
            _validTo = _validFrom.add(const Duration(days: 30));
          }
        } else {
          _validTo = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      body: Stack(
        children: [
          // Background ambient gradient mesh
          Container(
            color: GlassTheme.bgDark,
            child: Stack(
              children: [
                // Top Left Orb
                Positioned(
                  top: -120,
                  left: -100,
                  child: Container(
                    width: 500,
                    height: 500,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: GlassTheme.primaryNeon.withOpacity(0.18),
                    ),
                  ),
                ),
                // Bottom Right Orb
                Positioned(
                  bottom: -150,
                  right: -100,
                  child: Container(
                    width: 550,
                    height: 550,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: GlassTheme.accentEmerald.withOpacity(0.14),
                    ),
                  ),
                ),
                // Center Violet Aura
                Positioned(
                  top: size.height * 0.3,
                  left: size.width * 0.3,
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: GlassTheme.accentCyan.withOpacity(0.1),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand Logo & Title
                    _buildHeader(),
                    const SizedBox(height: 28),

                    // Main Glass Card Container
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isDesktop ? 620 : 500,
                      ),
                      child: GlassContainer(
                        borderRadius: 24,
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Tab Selector
                            _buildTabSelector(),
                            const SizedBox(height: 24),

                            // Alert messages
                            if (auth.errorMessage != null) ...[
                              _buildAlertBanner(auth.errorMessage!, isError: true),
                              const SizedBox(height: 16),
                            ],
                            if (auth.successMessage != null) ...[
                              _buildAlertBanner(auth.successMessage!, isError: false),
                              const SizedBox(height: 16),
                            ],

                            // Tab Views
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: _tabController.index == 0
                                  ? _buildLoginForm(auth)
                                  : _buildRegisterForm(auth),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    // Footer
                    const Text(
                      "ProGold Multi-Tenant Cloud • Powered by Turso SQLite & Node.js",
                      style: TextStyle(
                        color: GlassTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: GlassTheme.glassFillHover,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: GlassTheme.primaryNeon.withOpacity(0.4)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hub_rounded, color: GlassTheme.primaryNeon, size: 18),
              SizedBox(width: 8),
              Text(
                "Multi-Tenant Enterprise Portal",
                style: TextStyle(
                  color: GlassTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ShaderMask(
          shaderCallback: (bounds) => GlassTheme.primaryGradient.createShader(bounds),
          child: const Text(
            "ProGold",
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Next-Gen Database Platform for Modern Web & Desktop",
          style: TextStyle(
            fontSize: 14,
            color: GlassTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTabSelector() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x2AFFFFFF)),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (index) {
          setState(() {});
          Provider.of<AuthProvider>(context, listen: false).clearMessages();
        },
        indicator: BoxDecoration(
          gradient: GlassTheme.primaryGradient,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: GlassTheme.primaryNeon.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: GlassTheme.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        tabs: const [
          Tab(text: "Sign In"),
          Tab(text: "Register Tenant"),
        ],
      ),
    );
  }

  Widget _buildAlertBanner(String message, {required bool isError}) {
    final color = isError ? GlassTheme.accentRose : GlassTheme.accentEmerald;
    final icon = isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ================= LOGIN FORM =================
  Widget _buildLoginForm(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassTextField(
          controller: _loginEmailController,
          label: "Tenant Email",
          hint: "tenant@example.com",
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 18),
        GlassTextField(
          controller: _loginPasswordController,
          label: "Password",
          hint: "••••••••",
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _loginObscure,
          suffixIcon: IconButton(
            icon: Icon(
              _loginObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: GlassTheme.textMuted,
              size: 20,
            ),
            onPressed: () => setState(() => _loginObscure = !_loginObscure),
          ),
        ),
        const SizedBox(height: 24),
        GlassButton(
          label: "Sign In to Tenant Portal",
          icon: Icons.login_rounded,
          isLoading: auth.isLoading,
          onPressed: () async {
            final email = _loginEmailController.text.trim();
            final password = _loginPasswordController.text;
            if (email.isEmpty || password.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please fill in email and password")),
              );
              return;
            }
            await auth.login(email: email, password: password);
          },
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.bolt_rounded, size: 16, color: GlassTheme.accentAmber),
            label: const Text(
              "Quick Demo Auto-Fill (Registered Account)",
              style: TextStyle(color: GlassTheme.accentAmber, fontSize: 12),
            ),
            onPressed: () {
              _loginEmailController.text = "tenant_test@example.com";
              _loginPasswordController.text = "Admin@123";
            },
          ),
        ),
      ],
    );
  }

  // ================= REGISTER FORM =================
  Widget _buildRegisterForm(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Email & OTP Verification Section
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 3,
              child: GlassTextField(
                controller: _regEmailController,
                label: "Email Address (Tenant Master)",
                hint: "tenant@domain.com",
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                readOnly: auth.otpVerified,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: GlassButton(
                height: 48,
                label: auth.otpCountdown > 0 ? "Resend (${auth.otpCountdown}s)" : "Send OTP",
                icon: Icons.send_rounded,
                isLoading: auth.isLoading && !auth.otpSent,
                gradient: GlassTheme.cyanGradient,
                onPressed: (auth.otpCountdown > 0 || auth.otpVerified)
                    ? null
                    : () async {
                        final email = _regEmailController.text.trim();
                        final sent = await auth.sendOtp(email);
                        if (sent && auth.devOtpCode != null) {
                          _regOtpController.text = auth.devOtpCode!;
                        }
                      },
              ),
            ),
          ],
        ),

        // OTP Input Row
        if (auth.otpSent || auth.otpVerified) ...[
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 3,
                child: GlassTextField(
                  controller: _regOtpController,
                  label: "6-Digit Email OTP",
                  hint: "123456",
                  prefixIcon: Icons.security_rounded,
                  keyboardType: TextInputType.number,
                  readOnly: auth.otpVerified,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: auth.otpVerified
                    ? Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: GlassTheme.accentEmerald.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: GlassTheme.accentEmerald),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded, color: GlassTheme.accentEmerald, size: 18),
                            SizedBox(width: 6),
                            Text(
                              "Verified",
                              style: TextStyle(color: GlassTheme.accentEmerald, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      )
                    : GlassButton(
                        height: 48,
                        label: "Verify OTP",
                        icon: Icons.check_circle_outline,
                        isLoading: auth.isLoading,
                        gradient: GlassTheme.emeraldGradient,
                        onPressed: () {
                          auth.verifyOtp(
                            _regEmailController.text.trim(),
                            _regOtpController.text.trim(),
                          );
                        },
                      ),
              ),
            ],
          ),
          if (auth.devOtpCode != null && !auth.otpVerified) ...[
            const SizedBox(height: 6),
            Text(
              "🔑 Dev Code: ${auth.devOtpCode} (Auto-filled for testing)",
              style: const TextStyle(color: GlassTheme.accentEmerald, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ],

        const SizedBox(height: 16),
        // 2. Password & Confirm Password
        Row(
          children: [
            Expanded(
              child: GlassTextField(
                controller: _regPasswordController,
                label: "Password",
                hint: "••••••••",
                prefixIcon: Icons.lock_outline,
                obscureText: _regObscure,
                suffixIcon: IconButton(
                  icon: Icon(
                    _regObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: GlassTheme.textMuted,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _regObscure = !_regObscure),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlassTextField(
                controller: _regConfirmPasswordController,
                label: "Confirm Password",
                hint: "••••••••",
                prefixIcon: Icons.lock_outline,
                obscureText: _regConfirmObscure,
                suffixIcon: IconButton(
                  icon: Icon(
                    _regConfirmObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: GlassTheme.textMuted,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _regConfirmObscure = !_regConfirmObscure),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        // 3. Contact Number
        GlassTextField(
          controller: _regContactController,
          label: "Contact Number",
          hint: "+91 9876543210",
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),

        const SizedBox(height: 16),
        // 4. Validation Period (From Date & To Date)
        const Text(
          "Tenant Validation Period (Subscription Range)",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: GlassTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _selectDate(context, true),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0x0FFFFFFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x24FFFFFF)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 16, color: GlassTheme.accentCyan),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("From Date", style: TextStyle(fontSize: 10, color: GlassTheme.textMuted)),
                          Text(
                            _dateFormat.format(_validFrom),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GlassTheme.textPrimary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => _selectDate(context, false),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0x0FFFFFFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x24FFFFFF)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available_rounded, size: 16, color: GlassTheme.accentEmerald),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("To Date", style: TextStyle(fontSize: 10, color: GlassTheme.textMuted)),
                          Text(
                            _dateFormat.format(_validTo),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GlassTheme.textPrimary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),
        // 5. Turso Database Information
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GlassTheme.primaryNeon.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.storage_rounded, size: 18, color: GlassTheme.accentCyan),
                      SizedBox(width: 8),
                      Text(
                        "Tenant Turso SQLite DB",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (auth.tursoTestResult != null)
                    StatusBadge(
                      label: auth.tursoTestResult!.success
                          ? "Connected (${auth.tursoTestResult!.latencyMs}ms)"
                          : "Connection Failed",
                      color: auth.tursoTestResult!.success ? GlassTheme.accentEmerald : GlassTheme.accentRose,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              GlassTextField(
                controller: _regTursoUrlController,
                label: "Turso Database URL",
                hint: "libsql://tenant-name.turso.io",
                prefixIcon: Icons.link_rounded,
              ),
              const SizedBox(height: 12),
              GlassTextField(
                controller: _regTursoTokenController,
                label: "Turso Auth Token",
                hint: "eyJhbGciOi...",
                prefixIcon: Icons.key_rounded,
                obscureText: _regTursoTokenObscure,
                suffixIcon: IconButton(
                  icon: Icon(
                    _regTursoTokenObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: GlassTheme.textMuted,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _regTursoTokenObscure = !_regTursoTokenObscure),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GlassTheme.accentCyan,
                      side: const BorderSide(color: GlassTheme.accentCyan),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: auth.isTestingTurso
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: GlassTheme.accentCyan),
                          )
                        : const Icon(Icons.cable_rounded, size: 16),
                    label: const Text("Test Connection", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    onPressed: auth.isTestingTurso
                        ? null
                        : () {
                            auth.testTursoConnection(
                              _regTursoUrlController.text.trim(),
                              _regTursoTokenController.text.trim(),
                            );
                          },
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        // 6. Register Action Button
        GlassButton(
          label: "Register Tenant Account",
          icon: Icons.app_registration_rounded,
          isLoading: auth.isLoading,
          onPressed: () async {
            final email = _regEmailController.text.trim();
            final password = _regPasswordController.text;
            final confirmPassword = _regConfirmPasswordController.text;
            final contact = _regContactController.text.trim();
            final tursoUrl = _regTursoUrlController.text.trim();
            final tursoToken = _regTursoTokenController.text.trim();

            if (password != confirmPassword) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Passwords do not match.")),
              );
              return;
            }

            if (contact.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Contact number is required.")),
              );
              return;
            }

            await auth.registerTenant(
              email: email,
              password: password,
              contactNumber: contact,
              tursoUrl: tursoUrl,
              tursoToken: tursoToken,
              validFrom: _dateFormat.format(_validFrom),
              validTo: _dateFormat.format(_validTo),
            );
          },
        ),
      ],
    );
  }
}
