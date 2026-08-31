import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';

class DatabaseStatusScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const DatabaseStatusScreen({super.key, this.onBack});

  @override
  State<DatabaseStatusScreen> createState() => _DatabaseStatusScreenState();
}

class _DatabaseStatusScreenState extends State<DatabaseStatusScreen> {
  final ApiService _api = ApiService();

  bool _isLoading = false;
  bool _isOptimizing = false;
  Map<String, dynamic>? _dbStatus;
  List<Map<String, dynamic>> _tables = [];
  List<Map<String, dynamic>> _filteredTables = [];
  String _tableSearch = '';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDatabaseStatus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDatabaseStatus() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final res = await _api.getTenantDbStatus(token);
      if (mounted) {
        if (res['success'] == true) {
          setState(() {
            _dbStatus = res['database'] as Map<String, dynamic>?;
            _tables = (res['tables'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
            _applyTableFilter(_tableSearch);
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message']?.toString() ?? "Failed to load database status"),
              backgroundColor: GlassTheme.accentRose,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: GlassTheme.accentRose),
        );
      }
    }
  }

  void _applyTableFilter(String query) {
    _tableSearch = query.trim().toLowerCase();
    if (_tableSearch.isEmpty) {
      _filteredTables = List.from(_tables);
    } else {
      _filteredTables = _tables.where((t) {
        final name = (t['name'] ?? '').toString().toLowerCase();
        return name.contains(_tableSearch);
      }).toList();
    }
  }

  Future<void> _optimizeDatabase() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isOptimizing = true);

    try {
      final res = await _api.optimizeTenantDb(token);
      if (mounted) {
        final isOk = res['success'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? (isOk ? "Database optimized successfully!" : "Optimization failed")),
            backgroundColor: isOk ? GlassTheme.accentEmerald : GlassTheme.accentRose,
          ),
        );
        if (isOk) {
          await _loadDatabaseStatus();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Optimization error: $e"), backgroundColor: GlassTheme.accentRose),
        );
      }
    } finally {
      if (mounted) setState(() => _isOptimizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 750;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header Bar
        _buildHeaderBar(isMobile),
        const SizedBox(height: 16),

        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator(color: GlassTheme.primaryNeon)),
          )
        else if (_dbStatus == null)
          _buildErrorState()
        else ...[
          // 2. Storage & Quota Hero Gauges
          _buildStorageGauges(isMobile),
          const SizedBox(height: 16),

          // 3. Database Connection & System Metadata
          _buildConnectionMetadataCard(isMobile),
          const SizedBox(height: 16),

          // 4. Tables Storage Breakdown
          _buildTablesSection(isMobile),
        ],
      ],
    );
  }

  // ================= HEADER BAR =================
  Widget _buildHeaderBar(bool isMobile) {
    return GlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onBack != null) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: GlassTheme.textPrimary),
                  tooltip: "Back to Settings Menu",
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF0E7490)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.storage_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        "Database Status & Storage",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      StatusBadge(label: "Turso Cloud", color: Color(0xFF06B6D4)),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Monitor database storage consumption, remaining quota balance, and table metrics",
                    style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlassSecondaryButton(
                label: _isOptimizing ? "Optimizing..." : "Optimize Storage",
                icon: Icons.auto_fix_high_rounded,
                onPressed: _isOptimizing ? () {} : _optimizeDatabase,
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text("Refresh Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: _loadDatabaseStatus,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= STORAGE & QUOTA HERO GAUGES =================
  Widget _buildStorageGauges(bool isMobile) {
    final totalSizeFormatted = _dbStatus?['total_size_formatted'] ?? '0.00 KB';
    final availableFormatted = _dbStatus?['available_formatted'] ?? '9.00 GB';
    final quotaFormatted = _dbStatus?['quota_formatted'] ?? '9.00 GB';
    final usedPercentage = (_dbStatus?['used_percentage'] as num?)?.toDouble() ?? 0.0;
    final latencyMs = _dbStatus?['latency_ms'] ?? 0;
    final totalTables = _dbStatus?['total_tables'] ?? 0;
    final totalRows = _dbStatus?['total_rows'] ?? 0;

    return Column(
      children: [
        // 4 KPI Summary Cards
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = isMobile ? constraints.maxWidth : (constraints.maxWidth - 36) / 4;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildKpiCard(
                  width: cardWidth,
                  title: "Current Database Size",
                  value: totalSizeFormatted,
                  subtext: "Allocated page blocks",
                  icon: Icons.data_usage_rounded,
                  color: const Color(0xFF3B82F6),
                ),
                _buildKpiCard(
                  width: cardWidth,
                  title: "Balance Storage Available",
                  value: availableFormatted,
                  subtext: "of $quotaFormatted cloud quota",
                  icon: Icons.cloud_done_rounded,
                  color: const Color(0xFF10B981),
                ),
                _buildKpiCard(
                  width: cardWidth,
                  title: "Cloud Connection Latency",
                  value: "$latencyMs ms",
                  subtext: latencyMs < 100 ? "Superfast Response" : "Normal Response",
                  icon: Icons.speed_rounded,
                  color: const Color(0xFFF59E0B),
                ),
                _buildKpiCard(
                  width: cardWidth,
                  title: "Active Schema Data",
                  value: "$totalTables Tables",
                  subtext: "$totalRows Total Records",
                  icon: Icons.table_chart_rounded,
                  color: const Color(0xFF8B5CF6),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        // Storage Quota Progress Bar Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.pie_chart_rounded, color: Color(0xFF06B6D4), size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Storage Quota Utilization",
                        style: TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  Text(
                    "$totalSizeFormatted used / $quotaFormatted limit (${usedPercentage.toStringAsFixed(3)}%)",
                    style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (usedPercentage / 100.0).clamp(0.005, 1.0),
                  minHeight: 12,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "0 MB (Start)",
                    style: const TextStyle(fontSize: 11, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    "Remaining Balance: $availableFormatted",
                    style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w800),
                  ),
                  Text(
                    "$quotaFormatted (Total Quota)",
                    style: const TextStyle(fontSize: 11, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required double width,
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x080F172A), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: GlassTheme.textPrimary, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: const TextStyle(fontSize: 11, color: GlassTheme.textMuted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ================= CONNECTION & ENGINE DETAILS =================
  Widget _buildConnectionMetadataCard(bool isMobile) {
    final maskedUrl = _dbStatus?['url'] ?? '';
    final rawUrl = _dbStatus?['raw_url'] ?? '';
    final engine = _dbStatus?['engine'] ?? 'Turso libSQL';
    final sqliteVer = _dbStatus?['sqlite_version'] ?? '3.45.1';
    final pageSize = _dbStatus?['page_size'] ?? 4096;
    final pageCount = _dbStatus?['page_count'] ?? 0;
    final status = _dbStatus?['status'] ?? 'ONLINE';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.hub_rounded, color: Color(0xFF6366F1), size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Database Engine & Connection Info",
                    style: TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                    const SizedBox(width: 5),
                    Text(
                      status,
                      style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w800, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFE2E8F0)),

          Wrap(
            spacing: 24,
            runSpacing: 14,
            children: [
              _buildMetaField("Database Engine", engine),
              _buildMetaField("SQLite Core Version", sqliteVer),
              _buildMetaField("Page Block Size", "$pageSize bytes"),
              _buildMetaField("Allocated Pages", "$pageCount blocks"),
              _buildMetaFieldWithCopy("Connection Host URL", maskedUrl, rawUrl),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildMetaFieldWithCopy(String label, String displayValue, String copyValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(displayValue, style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: copyValue));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Connection URL copied to clipboard!"), duration: Duration(seconds: 2)),
                );
              },
              child: const Icon(Icons.copy_rounded, size: 15, color: GlassTheme.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  // ================= TABLES STORAGE BREAKDOWN =================
  Widget _buildTablesSection(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: const [
          BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Search Toolbar
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Database Tables & Row Metrics",
                        style: TextStyle(color: GlassTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "List of all provisioned tables, column structures, row counts, and storage weights",
                        style: TextStyle(color: GlassTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: isMobile ? 180 : 280,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _applyTableFilter(val)),
                    style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: GlassTheme.textSecondary),
                      hintText: "Search tables...",
                      hintStyle: const TextStyle(color: GlassTheme.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF06B6D4))),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // DataTable
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                dataRowColor: WidgetStateProperty.all(Colors.white),
                columns: const [
                  DataColumn(label: Text("TABLE NAME", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
                  DataColumn(label: Text("TYPE", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
                  DataColumn(label: Text("RECORDS / ROWS", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
                  DataColumn(label: Text("COLUMNS", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
                  DataColumn(label: Text("ESTIMATED SIZE", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
                  DataColumn(label: Text("STATUS", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
                ],
                rows: _filteredTables.map((t) {
                  final name = t['name']?.toString() ?? '';
                  final type = t['type']?.toString() ?? 'table';
                  final rowCount = t['rowCount'] ?? 0;
                  final columnCount = t['columnCount'] ?? 0;
                  final sizeFormatted = t['estimatedSizeFormatted']?.toString() ?? '4.00 KB';

                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.table_chart_rounded, size: 16, color: Color(0xFF06B6D4)),
                            const SizedBox(width: 8),
                            Text(name, style: const TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                          ],
                        ),
                      ),
                      DataCell(Text(type.toUpperCase(), style: const TextStyle(color: GlassTheme.textSecondary, fontWeight: FontWeight.w700, fontSize: 12))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "$rowCount records",
                            style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ),
                      ),
                      DataCell(Text("$columnCount cols", style: const TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 12))),
                      DataCell(Text(sizeFormatted, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w800, fontSize: 12))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            const Text("Active", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= ERROR STATE =================
  Widget _buildErrorState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: GlassTheme.accentRose),
            const SizedBox(height: 12),
            const Text("Unable to fetch database status", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary)),
            const SizedBox(height: 6),
            const Text("Check backend server connection and Turso credentials.", style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _loadDatabaseStatus,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
              child: const Text("Retry Connection", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
