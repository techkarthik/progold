import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tenant_model.dart';
import '../providers/auth_provider.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';
import 'company_master_screen.dart';
import 'branch_master_screen.dart';
import 'user_master_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedModule = "HOME"; // e.g. MenuRegistry.MENU_MASTER, etc.
  String _masterSubmenu = "HUB"; // e.g. MenuRegistry.MASTER_ORGANIZATION, etc.
  int _organizationTab = 0; // 0 = Company Master, 1 = Store Profile & Setup

  // Live gold & silver rate states
  double _gold24k = 7250.0;
  double _gold22k = 6650.0;
  double _silver = 88.50;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final tenant = auth.currentTenant;

    if (tenant == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: GlassTheme.bgDark,
      drawer: _buildLeftDrawer(context, auth, tenant),
      appBar: _buildAppBar(context, auth, tenant),
      body: Stack(
        children: [
          // Ambient neon glow backgrounds
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GlassTheme.primaryNeon.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -80,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GlassTheme.accentEmerald.withValues(alpha: 0.1),
              ),
            ),
          ),

          // Main Screen Content
          SafeArea(
            child: _selectedModule == "HOME"
                ? _buildMobileRoundMenuLauncher(context, auth, tenant)
                : _buildModuleWorkspace(context, auth, tenant, _selectedModule),
          ),
        ],
      ),
    );
  }

  // ================= APP BAR =================
  PreferredSizeWidget _buildAppBar(BuildContext context, AuthProvider auth, Tenant tenant) {
    return AppBar(
      backgroundColor: Colors.white.withValues(alpha: 0.95),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE2E8F0), height: 1),
      ),
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: GlassTheme.textPrimary, size: 26),
          tooltip: "Open Navigation Menu",
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Row(
        children: [
          // Business Logo Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: GlassTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: GlassTheme.primaryNeon.withValues(alpha: 0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: tenant.businessLogo.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        tenant.businessLogo,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded, size: 18, color: Colors.white),
                      ),
                    )
                  : const Icon(Icons.diamond_rounded, size: 18, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tenant.businessName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: GlassTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: GlassTheme.accentEmerald,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    "Billing Software • Valid until ${tenant.validTo}",
                    style: const TextStyle(fontSize: 11, color: GlassTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (_selectedModule != "HOME")
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: GlassTheme.primaryNeon),
            icon: const Icon(Icons.apps_rounded, size: 18),
            label: const Text("Main Menu"),
            onPressed: () {
              setState(() {
                _selectedModule = "HOME";
                _masterSubmenu = "HUB";
              });
            },
          ),
        IconButton(
          tooltip: "Business Profile",
          icon: const Icon(Icons.account_circle_outlined, color: GlassTheme.textPrimary, size: 24),
          onPressed: () => _showProfileDialog(context, auth, tenant),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ================= LEFT DRAWER WITH BUSINESS PROFILE & SUBMENUS =================
  Widget _buildLeftDrawer(BuildContext context, AuthProvider auth, Tenant tenant) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Drawer Header: Business Profile & Logo
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  GlassTheme.primaryNeon.withValues(alpha: 0.08),
                  Colors.white,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: const Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Glowing Business Logo Avatar
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: GlassTheme.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: GlassTheme.primaryNeon.withValues(alpha: 0.35),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: tenant.businessLogo.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  tenant.businessLogo,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded, size: 28, color: Colors.white),
                                ),
                              )
                            : const Icon(Icons.diamond_rounded, size: 28, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tenant.businessName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: GlassTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tenant.email,
                            style: const TextStyle(fontSize: 12, color: GlassTheme.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: GlassTheme.accentEmerald.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: GlassTheme.accentEmerald.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              "Active • ${tenant.daysRemaining} Days",
                              style: const TextStyle(fontSize: 10, color: GlassTheme.accentEmerald, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Edit Profile Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0x33FFFFFF)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 16, color: GlassTheme.accentCyan),
                    label: const Text("Edit Business Profile & Logo", style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      Navigator.pop(context);
                      _showProfileDialog(context, auth, tenant);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Drawer Navigation Links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildDrawerTile(
                  icon: Icons.apps_rounded,
                  title: "App Launcher",
                  color: GlassTheme.accentCyan,
                  selected: _selectedModule == "HOME",
                  onTap: () {
                    setState(() {
                      _selectedModule = "HOME";
                      _masterSubmenu = "HUB";
                    });
                    Navigator.pop(context);
                  },
                ),

                const Divider(color: Color(0x18FFFFFF), indent: 16, endIndent: 16),

                // MASTER with Submenus
                Theme(
                  data: ThemeData.dark().copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: _selectedModule == "MASTER",
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: GlassTheme.primaryNeon.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.account_balance_rounded, color: GlassTheme.primaryNeon, size: 20),
                    ),
                    title: const Text(
                      "MASTER",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
                    ),
                    subtitle: const Text("Organization, Inventory & Rates", style: TextStyle(fontSize: 11, color: GlassTheme.textMuted)),
                    children: [
                      _buildDrawerSubTile("🏢 ORGANIZATION", () {
                        setState(() {
                          _selectedModule = "MASTER";
                          _masterSubmenu = "ORGANIZATION";
                        });
                        Navigator.pop(context);
                      }, _selectedModule == "MASTER" && (_masterSubmenu == "ORGANIZATION" || _masterSubmenu == "COMPANY" || _masterSubmenu == "BRANCHES")),
                      _buildDrawerSubTile("    🏛️ COMPANY", () {
                        setState(() {
                          _selectedModule = "MASTER";
                          _masterSubmenu = "COMPANY";
                        });
                        Navigator.pop(context);
                      }, _selectedModule == "MASTER" && _masterSubmenu == "COMPANY"),
                      _buildDrawerSubTile("    🏬 BRANCHES", () {
                        setState(() {
                          _selectedModule = "MASTER";
                          _masterSubmenu = "BRANCHES";
                        });
                        Navigator.pop(context);
                      }, _selectedModule == "MASTER" && _masterSubmenu == "BRANCHES"),
                      _buildDrawerSubTile("📦 INVENTORY", () {
                        setState(() {
                          _selectedModule = "MASTER";
                          _masterSubmenu = "INVENTORY";
                        });
                        Navigator.pop(context);
                      }, _selectedModule == "MASTER" && _masterSubmenu == "INVENTORY"),
                      _buildDrawerSubTile("🏷️ SALES AND PRICE", () {
                        setState(() {
                          _selectedModule = "MASTER";
                          _masterSubmenu = "SALESANDPRICE";
                        });
                        Navigator.pop(context);
                      }, _selectedModule == "MASTER" && _masterSubmenu == "SALESANDPRICE"),
                      _buildDrawerSubTile("🔐 LOGIN USERS", () {
                        setState(() {
                          _selectedModule = "MASTER";
                          _masterSubmenu = "LOGINUSERS";
                        });
                        Navigator.pop(context);
                      }, _selectedModule == "MASTER" && _masterSubmenu == "LOGINUSERS"),
                      _buildDrawerSubTile("👥 EMPLOYEES", () {
                        setState(() {
                          _selectedModule = "MASTER";
                          _masterSubmenu = "EMPLOYEES";
                        });
                        Navigator.pop(context);
                      }, _selectedModule == "MASTER" && _masterSubmenu == "EMPLOYEES"),
                    ],
                  ),
                ),

                _buildDrawerTile(
                  icon: Icons.inventory_2_rounded,
                  title: "STOCK",
                  subtitle: "Live Inventory & RFID Tags",
                  color: GlassTheme.accentEmerald,
                  selected: _selectedModule == "STOCK",
                  onTap: () {
                    setState(() => _selectedModule = "STOCK");
                    Navigator.pop(context);
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.point_of_sale_rounded,
                  title: "POS",
                  subtitle: "Gold Billing, GST & Invoices",
                  color: GlassTheme.accentRose,
                  selected: _selectedModule == "POS",
                  onTap: () {
                    setState(() => _selectedModule = "POS");
                    Navigator.pop(context);
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.analytics_rounded,
                  title: "REPORT",
                  subtitle: "Sales, Day Book & Ledger",
                  color: GlassTheme.accentAmber,
                  selected: _selectedModule == "REPORT",
                  onTap: () {
                    setState(() => _selectedModule = "REPORT");
                    Navigator.pop(context);
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.monetization_on_rounded,
                  title: "DIGIGOLD",
                  subtitle: "Digital Vault & Gold SIP",
                  color: const Color(0xFFFFD700), // Gold
                  selected: _selectedModule == "DIGIGOLD",
                  onTap: () {
                    setState(() => _selectedModule = "DIGIGOLD");
                    Navigator.pop(context);
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.settings_suggest_rounded,
                  title: "SETTINGS",
                  subtitle: "Store Config & Print Formats",
                  color: GlassTheme.accentCyan,
                  selected: _selectedModule == "SETTINGS",
                  onTap: () {
                    setState(() => _selectedModule = "SETTINGS");
                    Navigator.pop(context);
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.groups_rounded,
                  title: "CRM",
                  subtitle: "Customers & 11M Schemes",
                  color: GlassTheme.secondaryNeon,
                  selected: _selectedModule == "CRM",
                  onTap: () {
                    setState(() => _selectedModule = "CRM");
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),

          // Logout Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0x18FFFFFF))),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: GlassTheme.accentRose),
              title: const Text("Sign Out", style: TextStyle(color: GlassTheme.accentRose, fontWeight: FontWeight.w600)),
              onTap: () => auth.logout(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: selected ? Border.all(color: color.withValues(alpha: 0.3)) : null,
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: selected ? color : GlassTheme.textPrimary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: subtitle != null
            ? Text(subtitle, style: const TextStyle(fontSize: 11, color: GlassTheme.textMuted))
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildDrawerSubTile(String title, VoidCallback onTap, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(left: 36, right: 12, bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? GlassTheme.primaryNeon.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? GlassTheme.primaryNeon : GlassTheme.textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  // ================= MOBILE PHONE STYLE ROUND MENUS LAUNCHER =================
  Widget _buildMobileRoundMenuLauncher(BuildContext context, AuthProvider auth, Tenant tenant) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    final List<Map<String, dynamic>> menuItems = [
      {
        "id": "MASTER",
        "name": "MASTER",
        "desc": "Org, Stock & Rates",
        "icon": Icons.account_balance_rounded,
        "gradient": const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        "glow": const Color(0xFF6366F1),
        "badge": "5 Modules",
      },
      {
        "id": "STOCK",
        "name": "STOCK",
        "desc": "Inventory & Tags",
        "icon": Icons.inventory_2_rounded,
        "gradient": const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        "glow": const Color(0xFF10B981),
        "badge": "Live",
      },
      {
        "id": "POS",
        "name": "POS",
        "desc": "Billing & Invoices",
        "icon": Icons.point_of_sale_rounded,
        "gradient": const LinearGradient(
          colors: [Color(0xFFEC4899), Color(0xFFBE185D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        "glow": const Color(0xFFEC4899),
        "badge": "Fast",
      },
      {
        "id": "REPORT",
        "name": "REPORT",
        "desc": "Sales & Ledger",
        "icon": Icons.analytics_rounded,
        "gradient": const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        "glow": const Color(0xFFF59E0B),
        "badge": "GST",
      },
      {
        "id": "DIGIGOLD",
        "name": "DIGIGOLD",
        "desc": "Digital Vault",
        "icon": Icons.monetization_on_rounded,
        "gradient": const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        "glow": const Color(0xFFFFD700),
        "badge": "99.9%",
      },
      {
        "id": "SETTINGS",
        "name": "SETTINGS",
        "desc": "Store & Printing",
        "icon": Icons.settings_suggest_rounded,
        "gradient": const LinearGradient(
          colors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        "glow": const Color(0xFF06B6D4),
        "badge": null,
      },
      {
        "id": "CRM",
        "name": "CRM",
        "desc": "Clients & Schemes",
        "icon": Icons.groups_rounded,
        "gradient": const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        "glow": const Color(0xFF8B5CF6),
        "badge": "VIP",
      },
      {
        "id": "ADD_MORE",
        "name": "+ MORE",
        "desc": "Add Custom App",
        "icon": Icons.add_circle_outline_rounded,
        "gradient": const LinearGradient(
          colors: [Color(0xFF334155), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        "glow": const Color(0xFF64748B),
        "badge": "Expand",
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesktop ? 960 : 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Gold Rate Live Ticker Banner
              _buildRateTicker(),
              const SizedBox(height: 28),

              // Title Section
              Text(
                "Welcome to ${tenant.businessName}",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                "Jewellery Retail ERP & Multi-Tenant Billing System",
                style: TextStyle(fontSize: 14, color: GlassTheme.textSecondary),
              ),

              const SizedBox(height: 36),

              // Mobile Phone Style Round Icons Grid
              Wrap(
                spacing: isDesktop ? 36 : 24,
                runSpacing: isDesktop ? 36 : 28,
                alignment: WrapAlignment.center,
                children: menuItems.map((item) {
                  return _buildRoundAppIcon(
                    item: item,
                    onTap: () {
                      if (item["id"] == "ADD_MORE") {
                        _showAddModuleDialog(context);
                      } else {
                        setState(() {
                          _selectedModule = item["id"];
                          _masterSubmenu = "HUB";
                        });
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= RATE TICKER BANNER =================
  Widget _buildRateTicker() {
    return GlassContainer(
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      gradient: LinearGradient(
        colors: [
          const Color(0xFFFFD700).withValues(alpha: 0.15),
          GlassTheme.primaryNeon.withValues(alpha: 0.08),
        ],
      ),
      borderColor: const Color(0x33FFD700),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildRateItem("GOLD 24K", "₹${_gold24k.toStringAsFixed(0)}/g", Icons.trending_up_rounded, GlassTheme.accentEmerald),
          Container(width: 1, height: 24, color: const Color(0x22FFFFFF)),
          _buildRateItem("GOLD 22K (916)", "₹${_gold22k.toStringAsFixed(0)}/g", Icons.trending_up_rounded, GlassTheme.accentEmerald),
          Container(width: 1, height: 24, color: const Color(0x22FFFFFF)),
          _buildRateItem("SILVER", "₹${_silver.toStringAsFixed(2)}/g", Icons.trending_flat_rounded, GlassTheme.accentCyan),
        ],
      ),
    );
  }

  Widget _buildRateItem(String title, String value, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontSize: 10, color: GlassTheme.textMuted, fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
          ],
        ),
      ],
    );
  }

  // ================= ROUND APP ICON WIDGET =================
  Widget _buildRoundAppIcon({
    required Map<String, dynamic> item,
    required VoidCallback onTap,
  }) {
    final String name = item["name"];
    final String desc = item["desc"];
    final IconData icon = item["icon"];
    final Gradient gradient = item["gradient"];
    final Color glow = item["glow"];
    final String? badge = item["badge"];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Round Icon Badge with Glow Shadow
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: gradient,
                    boxShadow: [
                      BoxShadow(
                        color: glow.withValues(alpha: 0.45),
                        blurRadius: 20,
                        spreadRadius: 1,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.8,
                    ),
                  ),
                  child: Center(
                    child: Icon(icon, size: 34, color: Colors.white),
                  ),
                ),

                // Optional Mini Status Badge
                if (badge != null)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: glow, width: 1),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: glow,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Name
            Text(
              name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            // Description
            Text(
              desc,
              style: const TextStyle(
                fontSize: 11,
                color: GlassTheme.textMuted,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ================= MODULE WORKSPACE ROUTER =================
  Widget _buildModuleWorkspace(BuildContext context, AuthProvider auth, Tenant tenant, String module) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button & Module Breadcrumb
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () {
                      if (module == "MASTER" && _masterSubmenu != "HUB") {
                        setState(() => _masterSubmenu = "HUB");
                      } else {
                        setState(() => _selectedModule = "HOME");
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    module == "MASTER" && _masterSubmenu != "HUB"
                        ? "MASTER > $_masterSubmenu"
                        : "$module Workspace",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const Spacer(),
                  StatusBadge(label: "Jewellery Billing Core", color: GlassTheme.accentEmerald),
                ],
              ),
              const SizedBox(height: 20),

              // Dynamic Module Content Panel
              _buildModuleSpecificContent(module, auth, tenant),
            ],
          ),
        ),
      ),
    );
  }

  // Specific Workspace Content for each module
  Widget _buildModuleSpecificContent(String module, AuthProvider auth, Tenant tenant) {
    switch (module) {
      case "MASTER":
        return _buildMasterHubWithSubmenus(auth, tenant);
      case "STOCK":
        return _buildStockWorkspace(auth);
      case "POS":
        return _buildPosWorkspace(auth);
      case "REPORT":
        return _buildReportWorkspace(auth);
      case "DIGIGOLD":
        return _buildDigiGoldWorkspace(auth);
      case "SETTINGS":
        return _buildSettingsWorkspace(auth, tenant);
      case "CRM":
        return _buildCrmWorkspace(auth);
      default:
        return GlassContainer(
          borderRadius: 16,
          child: Center(
            child: Text("Workspace for $module is active.", style: const TextStyle(color: Colors.white)),
          ),
        );
    }
  }

  // ================= MASTER HUB & 5 SUB-MENUS =================
  Widget _buildMasterHubWithSubmenus(AuthProvider auth, Tenant tenant) {
    switch (_masterSubmenu) {
      case "COMPANY":
        return CompanyMasterScreen(
          onBack: () => setState(() => _masterSubmenu = "HUB"),
        );
      case "BRANCHES":
        return BranchMasterScreen(
          onBack: () => setState(() => _masterSubmenu = "HUB"),
        );
      case "ORGANIZATION":
        return _buildOrganizationSubmenu(auth, tenant);
      case "INVENTORY":
        return _buildInventorySubmenu(auth);
      case "SALESANDPRICE":
        return _buildSalesAndPriceSubmenu(auth);
      case "LOGINUSERS":
        return UserMasterScreen(
          onBack: () => setState(() => _masterSubmenu = "HUB"),
        );
      case "EMPLOYEES":
        return _buildEmployeesSubmenu(auth);
      case "HUB":
      default:
        return _buildMasterSubmenuGrid();
    }
  }

  // Master 5 Sub-menu Cards Hub
  Widget _buildMasterSubmenuGrid() {
    final List<Map<String, dynamic>> submenus = [
      {
        "id": "ORGANIZATION",
        "name": "ORGANIZATION",
        "title": "Company & Branch Master",
        "desc": "Add & manage Corporate Companies, Outlets, Branches, State IDs & Accounts",
        "icon": Icons.business_rounded,
        "color": GlassTheme.primaryNeon,
        "isCompany": true,
      },
      {
        "id": "INVENTORY",
        "name": "INVENTORY",
        "title": "Item & Ornament Master",
        "desc": "Manage Gold/Silver/Diamond categories, metal purities (24K/22K 916/18K) & HSN",
        "icon": Icons.category_rounded,
        "color": GlassTheme.accentEmerald,
      },
      {
        "id": "SALESANDPRICE",
        "name": "SALES AND PRICE",
        "title": "Metal Rates & Pricing Rules",
        "desc": "Daily Gold & Silver board rates, making charges per gram, wastage % & discounts",
        "icon": Icons.price_change_rounded,
        "color": GlassTheme.accentAmber,
      },
      {
        "id": "LOGINUSERS",
        "name": "LOGIN USERS",
        "title": "User Accounts & Security",
        "desc": "Billing operators, Cashiers, Appraisers, Managers & access permissions",
        "icon": Icons.admin_panel_settings_rounded,
        "color": GlassTheme.accentCyan,
      },
      {
        "id": "EMPLOYEES",
        "name": "EMPLOYEES",
        "title": "Staff & Karigar Master",
        "desc": "Sales executives, Goldsmiths / Karigars, commissions & attendance",
        "icon": Icons.badge_rounded,
        "color": GlassTheme.secondaryNeon,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassContainer(
          borderRadius: 18,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_rounded, color: GlassTheme.primaryNeon, size: 24),
                  const SizedBox(width: 10),
                  const Text("MASTER CONFIGURATION", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Spacer(),
                  // Quick Direct Company Master button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlassTheme.primaryNeon,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.apartment_rounded, size: 15),
                    label: const Text("Company Master", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    onPressed: () => setState(() => _masterSubmenu = "COMPANY"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlassTheme.accentEmerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.storefront_rounded, size: 15),
                    label: const Text("Branch Master", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    onPressed: () => setState(() => _masterSubmenu = "BRANCHES"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlassTheme.accentCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.admin_panel_settings_rounded, size: 15),
                    label: const Text("User Master", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    onPressed: () => setState(() => _masterSubmenu = "LOGINUSERS"),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                "Select a master category to manage foundational data for your jewellery billing & retail operations:",
                style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary),
              ),
              const SizedBox(height: 20),

              // 5 Submenu cards
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: submenus.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = submenus[index];
                  final Color col = item["color"];
                  final bool isOrg = item["isCompany"] == true;

                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0x10FFFFFF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: col.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => setState(() => _masterSubmenu = item["id"]),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: col.withValues(alpha: 0.18),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: col.withValues(alpha: 0.4)),
                                  ),
                                  child: Icon(item["icon"], color: col, size: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            item["name"],
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: col, letterSpacing: 0.5),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "• ${item["title"]}",
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item["desc"],
                                        style: const TextStyle(fontSize: 12, color: GlassTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: col),
                              ],
                            ),
                          ),
                        ),

                        // If ORGANIZATION, show quick action chips directly on the card
                        if (isOrg) ...[
                          const Divider(height: 1, color: Color(0x18FFFFFF)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text("Quick Launch: ", style: TextStyle(fontSize: 12, color: GlassTheme.textMuted, fontWeight: FontWeight.w600)),
                                InkWell(
                                  onTap: () => setState(() => _masterSubmenu = "COMPANY"),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: GlassTheme.primaryNeon.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: GlassTheme.primaryNeon.withValues(alpha: 0.5)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.apartment_rounded, size: 14, color: GlassTheme.primaryNeon),
                                        SizedBox(width: 6),
                                        Text("🏛️ Company Master", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => setState(() => _masterSubmenu = "BRANCHES"),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: GlassTheme.accentEmerald.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: GlassTheme.accentEmerald.withValues(alpha: 0.5)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.storefront_rounded, size: 14, color: GlassTheme.accentEmerald),
                                        SizedBox(width: 6),
                                        Text("🏬 Branch Master", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => setState(() {
                                    _masterSubmenu = "ORGANIZATION";
                                    _organizationTab = 2;
                                  }),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0x15FFFFFF),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0x33FFFFFF)),
                                    ),
                                    child: const Text("🏪 Store Setup", style: TextStyle(fontSize: 12, color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 1. SUBMENU: ORGANIZATION
  Widget _buildOrganizationSubmenu(AuthProvider auth, Tenant tenant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Navigation Tabs Bar: [ 🏛️ Company Master | 🏬 Branch Master | 🏪 Store Setup ]
        GlassContainer(
          borderRadius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  tooltip: "Back to Master Hub",
                  onPressed: () => setState(() => _masterSubmenu = "HUB"),
                ),
                const SizedBox(width: 8),
                const Text(
                  "ORGANIZATION",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Container(height: 24, width: 1, color: const Color(0x22FFFFFF)),
                const SizedBox(width: 14),

                // Tab 0: Company Master
                InkWell(
                  onTap: () => setState(() => _organizationTab = 0),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _organizationTab == 0
                          ? GlassTheme.primaryNeon
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _organizationTab == 0
                            ? GlassTheme.primaryNeon
                            : const Color(0x22FFFFFF),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.apartment_rounded,
                          size: 16,
                          color: _organizationTab == 0 ? Colors.white : GlassTheme.primaryNeon,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Company Master",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _organizationTab == 0 ? Colors.white : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Tab 1: Branch Master
                InkWell(
                  onTap: () => setState(() => _organizationTab = 1),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _organizationTab == 1
                          ? GlassTheme.accentEmerald
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _organizationTab == 1
                            ? GlassTheme.accentEmerald
                            : const Color(0x22FFFFFF),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.storefront_rounded,
                          size: 16,
                          color: _organizationTab == 1 ? Colors.white : GlassTheme.accentEmerald,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Branch Master",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _organizationTab == 1 ? Colors.white : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Tab 2: Store Profile & Counters
                InkWell(
                  onTap: () => setState(() => _organizationTab = 2),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _organizationTab == 2
                          ? GlassTheme.primaryNeon
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _organizationTab == 2
                            ? GlassTheme.primaryNeon
                            : const Color(0x22FFFFFF),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.settings_suggest_rounded,
                          size: 16,
                          color: _organizationTab == 2 ? Colors.white : GlassTheme.accentCyan,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Store Profile",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _organizationTab == 2 ? Colors.white : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Active Tab Content
        if (_organizationTab == 0)
          CompanyMasterScreen(
            onBack: () => setState(() => _masterSubmenu = "HUB"),
          )
        else if (_organizationTab == 1)
          BranchMasterScreen(
            onBack: () => setState(() => _masterSubmenu = "HUB"),
          )
        else
          _buildStoreProfileContent(tenant),
      ],
    );
  }

  // Store Profile & Counters Content
  Widget _buildStoreProfileContent(Tenant tenant) {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_rounded, color: GlassTheme.accentCyan, size: 24),
              const SizedBox(width: 10),
              const Text("STORE & BILLING COUNTER SETUP", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              const StatusBadge(label: "Head Office", color: GlassTheme.accentEmerald),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Overview of default head office store details, contact information, and billing terminal configuration:",
            style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary),
          ),
          const SizedBox(height: 20),

          // Current Tenant Store Overview Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0x0EFFFFFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x22FFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(tenant.businessName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                    StatusBadge(label: "ID #${tenant.id}", color: GlassTheme.accentCyan),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.phone_rounded, size: 14, color: GlassTheme.textMuted),
                    const SizedBox(width: 6),
                    Text("Contact: ${tenant.contactNumber}", style: const TextStyle(fontSize: 12, color: Colors.white)),
                    const SizedBox(width: 20),
                    const Icon(Icons.email_rounded, size: 14, color: GlassTheme.textMuted),
                    const SizedBox(width: 6),
                    Text("Registered Email: ${tenant.email}", style: const TextStyle(fontSize: 12, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: Color(0x18FFFFFF)),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Icon(Icons.point_of_sale_rounded, size: 16, color: GlassTheme.accentCyan),
                    SizedBox(width: 8),
                    Text("Configured Billing Counters: Counter 01 (Gold/Diamond), Counter 02 (Silver/Coins)", style: TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. SUBMENU: INVENTORY
  Widget _buildInventorySubmenu(AuthProvider auth) {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.category_rounded, color: GlassTheme.accentEmerald, size: 24),
              const SizedBox(width: 10),
              const Text("INVENTORY MASTER", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: GlassTheme.accentEmerald, foregroundColor: Colors.white),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text("New Item / Ornament"),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Configure metal types, Karat purities (24K, 22K 916, 18K, 14K), ornament classifications, and stone grades.",
            style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildCategoryPill("Bangles & Bracelets", "22K / 18K", GlassTheme.accentEmerald),
              _buildCategoryPill("Necklaces & Harams", "22K (916)", GlassTheme.accentEmerald),
              _buildCategoryPill("Earrings & Studs", "22K / 18K Diamond", GlassTheme.accentEmerald),
              _buildCategoryPill("Rings & Solitaires", "18K / 14K Platinum", GlassTheme.accentCyan),
              _buildCategoryPill("Silver Articles & Utensils", "Fine 999 / 925", GlassTheme.accentAmber),
              _buildCategoryPill("Gold Coins & Bullion", "24K 99.9%", const Color(0xFFFFD700)),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: GlassTheme.accentEmerald, side: const BorderSide(color: GlassTheme.accentEmerald)),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text("Back to Master Menu"),
            onPressed: () => setState(() => _masterSubmenu = "HUB"),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill(String title, String purity, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x10FFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 2),
          Text(purity, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // 3. SUBMENU: SALES AND PRICE
  Widget _buildSalesAndPriceSubmenu(AuthProvider auth) {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.price_change_rounded, color: GlassTheme.accentAmber, size: 24),
              const SizedBox(width: 10),
              const Text("SALES AND PRICE MASTER", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Manage live board rates, making charge tables (per gram / % of gold), wastage calculation rules, and stone pricing.",
            style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildRateEditCard("Gold 24K (Pure)", _gold24k, (v) => setState(() => _gold24k = v)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRateEditCard("Gold 22K (916)", _gold22k, (v) => setState(() => _gold22k = v)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRateEditCard("Silver (Fine)", _silver, (v) => setState(() => _silver = v)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GlassButton(
            label: "Update Today's Board Rates",
            icon: Icons.save_rounded,
            gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Board rates updated successfully!")),
              );
            },
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: GlassTheme.accentAmber, side: const BorderSide(color: GlassTheme.accentAmber)),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text("Back to Master Menu"),
            onPressed: () => setState(() => _masterSubmenu = "HUB"),
          ),
        ],
      ),
    );
  }

  Widget _buildRateEditCard(String label, double val, ValueChanged<double> onChanged) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x10FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: GlassTheme.textMuted)),
          const SizedBox(height: 4),
          Text("₹${val.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
        ],
      ),
    );
  }

  // 5. SUBMENU: EMPLOYEES
  Widget _buildEmployeesSubmenu(AuthProvider auth) {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_rounded, color: GlassTheme.secondaryNeon, size: 24),
              const SizedBox(width: 10),
              const Text("EMPLOYEES & KARIGARS MASTER", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: GlassTheme.secondaryNeon, foregroundColor: Colors.white),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text("Add Staff / Karigar"),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Manage store sales executives, goldsmiths / karigars, artisan accounts, commission %, and staff contact info.",
            style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0x0EFFFFFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  backgroundColor: GlassTheme.secondaryNeon,
                  child: Icon(Icons.engineering_rounded, color: Colors.white),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Artisan / Karigar Directory", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text("Track issue/receive metal weights, stone wastage, and crafting labor charges", style: TextStyle(color: GlassTheme.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: GlassTheme.secondaryNeon, side: const BorderSide(color: GlassTheme.secondaryNeon)),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text("Back to Master Menu"),
            onPressed: () => setState(() => _masterSubmenu = "HUB"),
          ),
        ],
      ),
    );
  }

  // ================= OTHER MODULE WORKSPACES =================
  // 1. STOCK WORKSPACE
  Widget _buildStockWorkspace(AuthProvider auth) {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2_rounded, color: GlassTheme.accentEmerald, size: 24),
              SizedBox(width: 10),
              Text("Stock Inventory & Barcode Tracking", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Manage item gross weights, net gold weights, stone charges, and RFID/Barcode tag assignments.",
            style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          GlassButton(
            label: "Open Stock Entry & Tagging Console",
            icon: Icons.qr_code_scanner_rounded,
            gradient: GlassTheme.emeraldGradient,
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // 2. POS WORKSPACE
  Widget _buildPosWorkspace(AuthProvider auth) {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.point_of_sale_rounded, color: GlassTheme.accentRose, size: 24),
              SizedBox(width: 10),
              Text("Point of Sale (POS) Billing & Invoicing", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Generate instant tax invoices with making charges, wastage calculation, hallmarking charges, and GST breakdown.",
            style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          GlassButton(
            label: "New Jewellery Billing Invoice",
            icon: Icons.receipt_long_rounded,
            gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF9333EA)]),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // 3. REPORT WORKSPACE
  Widget _buildReportWorkspace(AuthProvider auth) {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_rounded, color: GlassTheme.accentAmber, size: 24),
              SizedBox(width: 10),
              Text("Business Reports & Financial Ledger", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Access Day Book summaries, Sales Registers, Metal Stock Balance Reports, and GST GSTR-1 summaries.",
            style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  // 4. DIGIGOLD WORKSPACE
  Widget _buildDigiGoldWorkspace(AuthProvider auth) {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 24),
              SizedBox(width: 10),
              Text("DigiGold Digital Vault & Micro-SIP", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Offer 24K 99.9% Pure Digital Gold investment schemes, customer vault passbooks, and monthly SIP accumulation.",
            style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  // 5. SETTINGS WORKSPACE
  Widget _buildSettingsWorkspace(AuthProvider auth, Tenant tenant) {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings_suggest_rounded, color: GlassTheme.accentCyan, size: 24),
              SizedBox(width: 10),
              Text("System Settings & Preferences", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          Text("Store: ${tenant.businessName}", style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13)),
          const SizedBox(height: 6),
          Text("Subscription Period: ${tenant.validFrom} to ${tenant.validTo}", style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  // 6. CRM WORKSPACE
  Widget _buildCrmWorkspace(AuthProvider auth) {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.groups_rounded, color: GlassTheme.secondaryNeon, size: 24),
              SizedBox(width: 10),
              Text("CRM, Gold Schemes & Customer Directory", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Track customer purchase histories, 11-month gold savings schemes, automated WhatsApp/SMS birthday & anniversary reminders.",
            style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  // ================= PROFILE & LOGO MODAL DIALOG =================
  void _showProfileDialog(BuildContext context, AuthProvider auth, Tenant tenant) {
    final nameCtrl = TextEditingController(text: tenant.businessName);
    final logoCtrl = TextEditingController(text: tenant.businessLogo);
    final phoneCtrl = TextEditingController(text: tenant.contactNumber);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: GlassTheme.bgDarkSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0x33FFFFFF)),
              ),
              title: const Row(
                children: [
                  Icon(Icons.business_center_rounded, color: GlassTheme.primaryNeon, size: 22),
                  SizedBox(width: 10),
                  Text("Business Profile & Branding", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlassTextField(
                      controller: nameCtrl,
                      label: "Business / Store Name",
                      hint: "e.g. TechKarthik Jewellers",
                      prefixIcon: Icons.store_rounded,
                    ),
                    const SizedBox(height: 14),
                    GlassTextField(
                      controller: logoCtrl,
                      label: "Business Logo Image URL",
                      hint: "https://example.com/logo.png",
                      prefixIcon: Icons.image_rounded,
                    ),
                    const SizedBox(height: 14),
                    GlassTextField(
                      controller: phoneCtrl,
                      label: "Contact Number",
                      hint: "+91 9876543210",
                      prefixIcon: Icons.phone_rounded,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0x10FFFFFF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Tenant Email: ${tenant.email}", style: const TextStyle(fontSize: 11, color: GlassTheme.textMuted)),
                          const SizedBox(height: 4),
                          Text("Subscription: ${tenant.validFrom} to ${tenant.validTo} (${tenant.daysRemaining} days remaining)",
                              style: const TextStyle(fontSize: 11, color: GlassTheme.accentEmerald)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel", style: TextStyle(color: GlassTheme.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlassTheme.primaryNeon,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    await auth.updateBusinessProfile(
                      businessName: nameCtrl.text.trim(),
                      businessLogo: logoCtrl.text.trim(),
                      contactNumber: phoneCtrl.text.trim(),
                    );
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Business profile updated successfully!")),
                      );
                    }
                  },
                  child: const Text("Save Changes"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Add more module modal dialog
  void _showAddModuleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GlassTheme.bgDarkSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x33FFFFFF)),
        ),
        title: const Row(
          children: [
            Icon(Icons.extension_rounded, color: GlassTheme.accentCyan),
            SizedBox(width: 10),
            Text("Module Marketplace", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "You can add more specialized business modules here in future releases (e.g. Karatmeter Integration, Hallmarking HUID sync, e-Way Bill, E-Commerce sync, Multi-branch sync).",
          style: TextStyle(color: GlassTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close", style: TextStyle(color: GlassTheme.accentCyan)),
          ),
        ],
      ),
    );
  }
}
