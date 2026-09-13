import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/branch_model.dart';
import '../models/inventory_models.dart';
import '../models/rate_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';

class PrepareSkuScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const PrepareSkuScreen({super.key, this.onBack});

  @override
  State<PrepareSkuScreen> createState() => _PrepareSkuScreenState();
}

class _PrepareSkuScreenState extends State<PrepareSkuScreen> {
  final ApiService _api = ApiService();

  // Data collections
  List<PrepareSkuLotRecord> _lots = [];
  List<PrepareSkuLotRecord> _filteredLots = [];
  List<DesignerRecord> _allDesigners = [];
  List<ProductRecord> _allProducts = [];
  List<SubProductRecord> _allSubProducts = [];
  List<Purity> _allOrnamentPurities = [];
  List<Branch> _allBranches = [];
  LatestRatesSummary _latestRates = LatestRatesSummary();

  // Screen UI State
  bool _isLoading = false;
  bool _isSaving = false;
  bool _showForm = false;
  bool _isTableView = true;
  bool _stoneExpanded = false;
  bool _diamondExpanded = false;

  // Search & Filter State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterBranchId = 'ALL';
  int? _filterDesignerId;
  int? _filterProductId;
  String _filterIsAssorted = 'ALL';

  // Form State
  final _formKey = GlobalKey<FormState>();
  PrepareSkuLotRecord? _editingRecord;

  String? _selectedBranchId;
  int? _selectedDesignerId;
  int? _selectedProductId;
  int? _selectedSubProductId;
  int? _selectedPurityId;
  String _isAssorted = 'NO';

  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _totalPcsController = TextEditingController(text: '1');
  final TextEditingController _totalGrossWtController = TextEditingController(text: '0.000');
  final TextEditingController _totalNetWtController = TextEditingController(text: '0.000');
  final TextEditingController _remarksController = TextEditingController();

  // Multi-Item Stones and Diamonds Lists
  List<SkuLotStoneItem> _stoneItems = [];
  List<SkuLotDiamondItem> _diamondItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _applyFilter();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _rateController.dispose();
    _totalPcsController.dispose();
    _totalGrossWtController.dispose();
    _totalNetWtController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _api.getPrepareSkuLotsData(token, companyId: auth.activeCompanyId),
        _api.getDesigners(token),
        _api.getProducts(token),
        _api.getSubProducts(token),
        _api.getPurities(token),
        _api.getBranches(token, companyId: auth.activeCompanyId),
        _api.getLatestRates(token),
      ]);

      if (mounted) {
        final lotsData = results[0] as Map<String, dynamic>;
        final designers = results[1] as List<DesignerRecord>;
        final products = results[2] as List<ProductRecord>;
        final subProducts = results[3] as List<SubProductRecord>;
        final purities = results[4] as List<Purity>;
        final branches = results[5] as List<Branch>;
        final latestRates = results[6] as LatestRatesSummary;

        // Filter purities for ORNAMENTS only
        final ornamentPurities = purities.where((p) {
          final type = p.type.toUpperCase().trim();
          return type.isEmpty || type == 'ORNAMENT' || type == 'ORNAMENTS';
        }).toList();

        setState(() {
          _lots = lotsData['lots'] as List<PrepareSkuLotRecord>? ?? [];
          _allDesigners = designers;
          _allProducts = products;
          _allSubProducts = subProducts;
          _allOrnamentPurities = ornamentPurities;
          _allBranches = branches;
          _latestRates = latestRates;

          // Default branch selection
          if (_selectedBranchId == null || !_allBranches.any((b) => b.branchId == _selectedBranchId)) {
            if (_allBranches.isNotEmpty) {
              _selectedBranchId = _allBranches.first.branchId;
            }
          }

          // Default designer selection
          if (_selectedDesignerId == null || !_allDesigners.any((d) => d.designerid == _selectedDesignerId)) {
            if (_allDesigners.isNotEmpty) {
              _selectedDesignerId = _allDesigners.first.designerid;
            }
          }

          // Default product selection
          if (_selectedProductId == null || !_allProducts.any((p) => p.productid == _selectedProductId)) {
            if (_allProducts.isNotEmpty) {
              _selectedProductId = _allProducts.first.productid;
            }
          }

          // Default purity matching selected product metal
          _syncPurityWithSelectedProduct();

          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Error loading Prepare SKU data: $e');
      }
    }
  }

  /// Returns purities matching the metal of the currently selected product
  List<Purity> _getMatchingPuritiesForSelectedProduct() {
    if (_selectedProductId == null) return _allOrnamentPurities;

    final selectedProduct = _allProducts.where((p) => p.productid == _selectedProductId).firstOrNull;
    if (selectedProduct == null) return _allOrnamentPurities;

    final productMetal = (selectedProduct.metalid ?? '').trim().toUpperCase();
    final productMetalName = (selectedProduct.metalname ?? '').trim().toUpperCase();
    final productCatName = (selectedProduct.catname ?? '').trim().toUpperCase();
    final prodName = selectedProduct.productname.trim().toUpperCase();

    final isGold = productMetal == 'G' || productMetalName.contains('GOLD') || productCatName.contains('GOLD') || prodName.contains('GOLD');
    final isSilver = productMetal == 'SR' || productMetal == 'S' || productMetalName.contains('SILVER') || productCatName.contains('SILVER') || prodName.contains('SILVER');
    final isPlatinum = productMetal == 'PT' || productMetalName.contains('PLATINUM') || productCatName.contains('PLATINUM');

    if (isGold) {
      final matching = _allOrnamentPurities.where((p) {
        final pMetal = p.metalid.trim().toUpperCase();
        final pName = p.purityname.toUpperCase();
        return pMetal == 'G' ||
            pName.contains('KT') ||
            pName.contains('GOLD') ||
            pName.contains('916') ||
            pName.contains('750') ||
            pName.contains('22') ||
            pName.contains('18') ||
            pName.contains('24') ||
            pName.contains('14') ||
            pName.contains('999');
      }).toList();
      if (matching.isNotEmpty) return matching;
    } else if (isSilver) {
      final matching = _allOrnamentPurities.where((p) {
        final pMetal = p.metalid.trim().toUpperCase();
        final pName = p.purityname.toUpperCase();
        return pMetal == 'SR' || pMetal == 'S' || pName.contains('SILVER') || pName.contains('925') || pName.contains('92.5');
      }).toList();
      if (matching.isNotEmpty) return matching;
    } else if (isPlatinum) {
      final matching = _allOrnamentPurities.where((p) {
        final pMetal = p.metalid.trim().toUpperCase();
        final pName = p.purityname.toUpperCase();
        return pMetal == 'PT' || pName.contains('PLAT');
      }).toList();
      if (matching.isNotEmpty) return matching;
    } else if (productMetal.isNotEmpty) {
      final matching = _allOrnamentPurities.where((p) {
        return p.metalid.trim().toUpperCase() == productMetal;
      }).toList();
      if (matching.isNotEmpty) return matching;
    }

    return _allOrnamentPurities;
  }

  /// Syncs the selected purity and purity rate with the selected product's metal
  void _syncPurityWithSelectedProduct() {
    final matchingPurities = _getMatchingPuritiesForSelectedProduct();
    if (matchingPurities.isNotEmpty) {
      if (_selectedPurityId == null || !matchingPurities.any((p) => p.purityid == _selectedPurityId)) {
        _selectedPurityId = matchingPurities.first.purityid;
      }
    } else if (_allOrnamentPurities.isNotEmpty) {
      _selectedPurityId = _allOrnamentPurities.first.purityid;
    }
    _updatePurityRate(_selectedPurityId, force: true);
  }

  /// Updates the purity rate dynamically whenever purity selection changes
  void _updatePurityRate(int? purityId, {bool force = false}) {
    if (purityId == null) return;
    double foundRate = 0.0;

    // 1. Try to find direct purity rate from daily purity rates list
    for (final r in _latestRates.purityRates) {
      if (r.purityid == purityId && r.rate > 0) {
        foundRate = r.rate;
        break;
      }
    }

    // 2. Derive rate based on metal benchmark rates and purity percentage
    if (foundRate == 0.0) {
      final p = _allOrnamentPurities.where((pur) => pur.purityid == purityId).firstOrNull;
      if (p != null) {
        final pName = p.purityname.toUpperCase();
        final pMetal = p.metalid.toUpperCase();
        final purityPer = p.purity > 0 ? p.purity : 91.6;

        final isGoldPurity = pMetal == 'G' ||
            pName.contains('KT') ||
            pName.contains('GOLD') ||
            pName.contains('916') ||
            pName.contains('750') ||
            pName.contains('22') ||
            pName.contains('18') ||
            pName.contains('24');
        final isSilverPurity = pMetal == 'SR' || pMetal == 'S' || pName.contains('SILVER') || pName.contains('925') || pName.contains('92.5');
        final isPlatinumPurity = pMetal == 'PT' || pName.contains('PLAT');

        if (isGoldPurity) {
          if (pName.contains('24') || pName.contains('999') || purityPer >= 99.0) {
            foundRate = _latestRates.gold24k > 0 ? _latestRates.gold24k : 7450.0;
          } else if (pName.contains('22') || pName.contains('916') || (purityPer >= 91.0 && purityPer <= 92.0)) {
            foundRate = _latestRates.gold22k > 0 ? _latestRates.gold22k : 6850.0;
          } else {
            // Proportional calculation from 24K or 22K rate
            final base24k = _latestRates.gold24k > 0 ? _latestRates.gold24k : (_latestRates.gold22k > 0 ? (_latestRates.gold22k / 0.916) : 7450.0);
            foundRate = base24k * (purityPer / 100.0);
          }
        } else if (isSilverPurity) {
          final baseSilver = _latestRates.silver > 0 ? _latestRates.silver : 92.50;
          foundRate = baseSilver * (purityPer / 92.5);
        } else if (isPlatinumPurity) {
          final basePlat = _latestRates.platinum > 0 ? _latestRates.platinum : 3800.0;
          foundRate = basePlat * (purityPer / 100.0);
        } else {
          final base24k = _latestRates.gold24k > 0 ? _latestRates.gold24k : 7450.0;
          foundRate = base24k * (purityPer / 100.0);
        }
      }
    }

    if (foundRate > 0) {
      if (force || _rateController.text.isEmpty || _rateController.text == '0' || _rateController.text == '0.00') {
        _rateController.text = foundRate.toStringAsFixed(2);
      }
    }
  }

  void _applyFilter() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final activeComp = auth.activeCompanyId.trim().toUpperCase();
    final q = _searchQuery.trim().toLowerCase();

    _filteredLots = _lots.where((lot) {
      // Company filter
      if (activeComp.isNotEmpty) {
        final lotComp = lot.companyid.trim().toUpperCase();
        if (lotComp.isNotEmpty && lotComp != activeComp) return false;
      }

      // Branch filter
      if (_filterBranchId != 'ALL' && lot.branchid.toUpperCase() != _filterBranchId.toUpperCase()) {
        return false;
      }

      // Designer filter
      if (_filterDesignerId != null && lot.designerid != _filterDesignerId) {
        return false;
      }

      // Product filter
      if (_filterProductId != null && lot.productid != _filterProductId) {
        return false;
      }

      // Is Assorted filter
      if (_filterIsAssorted != 'ALL' && lot.isAssorted.toUpperCase() != _filterIsAssorted.toUpperCase()) {
        return false;
      }

      if (q.isEmpty) return true;

      final lotNum = lot.lotNumber.toLowerCase();
      final designer = (lot.designername ?? '').toLowerCase();
      final prod = (lot.productname ?? '').toLowerCase();
      final sub = (lot.subproductname ?? '').toLowerCase();
      final purity = (lot.purityname ?? '').toLowerCase();
      final branch = (lot.branchname ?? '').toLowerCase();
      final status = lot.status.toLowerCase();
      final remarks = lot.remarks.toLowerCase();

      return lotNum.contains(q) ||
          designer.contains(q) ||
          prod.contains(q) ||
          sub.contains(q) ||
          purity.contains(q) ||
          branch.contains(q) ||
          status.contains(q) ||
          remarks.contains(q);
    }).toList();
  }

  /// Automatically calculates net weight by deducting stone and diamond weights in grams
  void _autoCalculateNetWeight() {
    final grs = double.tryParse(_totalGrossWtController.text.trim()) ?? 0.0;

    double totalStoneGrams = 0.0;
    for (final s in _stoneItems) {
      totalStoneGrams += s.weightInGrams;
    }

    double totalDiamondGrams = 0.0;
    for (final d in _diamondItems) {
      totalDiamondGrams += d.weightInGrams;
    }

    double net = grs - totalStoneGrams - totalDiamondGrams;
    if (net < 0) net = 0.0;
    _totalNetWtController.text = net.toStringAsFixed(3);
  }

  void _openCreateForm() {
    setState(() {
      _editingRecord = null;
      _selectedBranchId = _allBranches.isNotEmpty ? _allBranches.first.branchId : null;
      _selectedDesignerId = _allDesigners.isNotEmpty ? _allDesigners.first.designerid : null;
      _selectedProductId = _allProducts.isNotEmpty ? _allProducts.first.productid : null;
      _selectedSubProductId = null;
      _isAssorted = 'NO';
      _rateController.clear();
      _totalPcsController.text = '1';
      _totalGrossWtController.text = '0.000';
      _totalNetWtController.text = '0.000';
      _remarksController.clear();
      _stoneItems = [];
      _diamondItems = [];
      _stoneExpanded = false;
      _diamondExpanded = false;
      _showForm = true;

      _syncPurityWithSelectedProduct();
    });
  }

  void _openEditForm(PrepareSkuLotRecord record) {
    setState(() {
      _editingRecord = record;
      _selectedBranchId = record.branchid;
      _selectedDesignerId = record.designerid;
      _selectedProductId = record.productid;
      _selectedSubProductId = record.subproductid;
      _selectedPurityId = record.purityid;
      _isAssorted = record.isAssorted.toUpperCase();
      _rateController.text = record.rate.toStringAsFixed(2);
      _totalPcsController.text = record.totalPcs.toString();
      _totalGrossWtController.text = record.totalGrossWeight.toStringAsFixed(3);
      _totalNetWtController.text = record.totalNetWeight.toStringAsFixed(3);

      // Populate multi-stone items
      if (record.stoneItems.isNotEmpty) {
        _stoneItems = record.stoneItems
            .map((s) => SkuLotStoneItem(
                  stoneProductId: s.stoneProductId,
                  stoneProductName: s.stoneProductName,
                  stoneSubProductId: s.stoneSubProductId,
                  stoneSubProductName: s.stoneSubProductName,
                  stoneUnit: s.stoneUnit,
                  pcs: s.pcs,
                  weight: s.weight,
                ))
            .toList();
      } else if (record.stoneProductid != null || record.totalStonePcs > 0 || record.totalStoneWeight > 0) {
        _stoneItems = [
          SkuLotStoneItem(
            stoneProductId: record.stoneProductid,
            stoneProductName: record.stoneProductname,
            stoneSubProductId: record.stoneSubproductid,
            stoneSubProductName: record.stoneSubproductname,
            stoneUnit: record.stoneUnit,
            pcs: record.totalStonePcs,
            weight: record.totalStoneWeight,
          ),
        ];
      } else {
        _stoneItems = [];
      }
      _stoneExpanded = _stoneItems.isNotEmpty;

      // Populate multi-diamond items
      if (record.diamondItems.isNotEmpty) {
        _diamondItems = record.diamondItems
            .map((d) => SkuLotDiamondItem(
                  diamondProductId: d.diamondProductId,
                  diamondProductName: d.diamondProductName,
                  diamondSubProductId: d.diamondSubProductId,
                  diamondSubProductName: d.diamondSubProductName,
                  diamondUnit: d.diamondUnit,
                  pcs: d.pcs,
                  weight: d.weight,
                ))
            .toList();
      } else if (record.diamondProductid != null || record.totalDiamondPcs > 0 || record.totalDiamondWeight > 0) {
        _diamondItems = [
          SkuLotDiamondItem(
            diamondProductId: record.diamondProductid,
            diamondProductName: record.diamondProductname,
            diamondSubProductId: record.diamondSubproductid,
            diamondSubProductName: record.diamondSubproductname,
            diamondUnit: record.diamondUnit,
            pcs: record.totalDiamondPcs,
            weight: record.totalDiamondWeight,
          ),
        ];
      } else {
        _diamondItems = [];
      }
      _diamondExpanded = _diamondItems.isNotEmpty;

      _remarksController.text = record.remarks;
      _showForm = true;
    });
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDesignerId == null) {
      _showErrorSnackBar('Please select a Designer');
      return;
    }
    if (_selectedProductId == null) {
      _showErrorSnackBar('Please select a Product');
      return;
    }
    if (_selectedPurityId == null) {
      _showErrorSnackBar('Please select an Ornament Purity');
      return;
    }
    if (_selectedBranchId == null || _selectedBranchId!.isEmpty) {
      _showErrorSnackBar('Please select a Branch');
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isSaving = true);

    final activeComp = auth.activeCompanyId.isNotEmpty ? auth.activeCompanyId : 'COMP01';

    // Calculate aggregated stone and diamond sums
    final totalStonePcsSum = _stoneItems.fold<int>(0, (sum, item) => sum + item.pcs);
    final totalStoneWtSum = _stoneItems.fold<double>(0.0, (sum, item) => sum + item.weight);
    final totalDiamondPcsSum = _diamondItems.fold<int>(0, (sum, item) => sum + item.pcs);
    final totalDiamondWtSum = _diamondItems.fold<double>(0.0, (sum, item) => sum + item.weight);

    final record = PrepareSkuLotRecord(
      lotId: _editingRecord?.lotId,
      lotNumber: _editingRecord?.lotNumber ?? '',
      companyid: activeComp,
      branchid: _selectedBranchId!,
      designerid: _selectedDesignerId!,
      productid: _selectedProductId!,
      subproductid: _selectedSubProductId,
      purityid: _selectedPurityId!,
      rate: double.tryParse(_rateController.text.trim()) ?? 0.0,
      isAssorted: _isAssorted,
      totalPcs: int.tryParse(_totalPcsController.text.trim()) ?? 1,
      totalGrossWeight: double.tryParse(_totalGrossWtController.text.trim()) ?? 0.0,
      totalNetWeight: double.tryParse(_totalNetWtController.text.trim()) ?? 0.0,
      stoneProductid: _stoneItems.isNotEmpty ? _stoneItems.first.stoneProductId : null,
      stoneSubproductid: _stoneItems.isNotEmpty ? _stoneItems.first.stoneSubProductId : null,
      stoneUnit: _stoneItems.isNotEmpty ? _stoneItems.first.stoneUnit : 'G',
      totalStonePcs: totalStonePcsSum,
      totalStoneWeight: totalStoneWtSum,
      stoneItems: _stoneItems,
      diamondProductid: _diamondItems.isNotEmpty ? _diamondItems.first.diamondProductId : null,
      diamondSubproductid: _diamondItems.isNotEmpty ? _diamondItems.first.diamondSubProductId : null,
      diamondUnit: _diamondItems.isNotEmpty ? _diamondItems.first.diamondUnit : 'C',
      totalDiamondPcs: totalDiamondPcsSum,
      totalDiamondWeight: totalDiamondWtSum,
      diamondItems: _diamondItems,
      status: _editingRecord?.status ?? 'PENDING',
      remarks: _remarksController.text.trim(),
    );

    try {
      if (_editingRecord == null) {
        // Create new SKU Lot
        final res = await _api.createPrepareSkuLot(token, record);
        setState(() => _isSaving = false);

        if (res['success'] == true) {
          final lotNumber = res['lot_number']?.toString() ?? res['lot']?['lot_number']?.toString() ?? 'LOT-GENERATED';
          final lotData = res['lot'] != null ? PrepareSkuLotRecord.fromJson(res['lot']) : null;

          setState(() {
            _showForm = false;
          });
          await _loadData();

          if (mounted) {
            _showLotCreatedPopup(lotNumber, lotData ?? record.copyWith(lotNumber: lotNumber));
          }
        } else {
          _showErrorSnackBar(res['message'] ?? 'Failed to create SKU Lot');
        }
      } else {
        // Update existing SKU Lot
        final res = await _api.updatePrepareSkuLot(token, _editingRecord!.lotId!, record);
        setState(() => _isSaving = false);

        if (res['success'] == true) {
          setState(() {
            _showForm = false;
            _editingRecord = null;
          });
          await _loadData();
          if (mounted) {
            _showSuccessSnackBar('SKU Lot ${_editingRecord?.lotNumber ?? ''} updated successfully');
          }
        } else {
          _showErrorSnackBar(res['message'] ?? 'Failed to update SKU Lot');
        }
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showErrorSnackBar('Error saving SKU Lot: $e');
    }
  }

  Future<void> _deleteRecord(PrepareSkuLotRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: GlassTheme.accentRose.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: GlassTheme.accentRose, size: 24),
            ),
            const SizedBox(width: 12),
            const Text("Delete SKU Lot?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
          ],
        ),
        content: Text(
          "Are you sure you want to delete SKU Lot '${record.lotNumber}'?\nThis action cannot be undone.",
          style: const TextStyle(color: Color(0xFF475569), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GlassTheme.accentRose,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete Lot", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoading = true);
    try {
      final res = await _api.deletePrepareSkuLot(token, record.lotId!);
      if (res['success'] == true) {
        _showSuccessSnackBar("SKU Lot ${record.lotNumber} deleted successfully");
        await _loadData();
      } else {
        setState(() => _isLoading = false);
        _showErrorSnackBar(res['message'] ?? "Failed to delete lot");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar("Error deleting lot: $e");
    }
  }

  /// Interactive modal dialog displaying the newly generated Lot Number
  void _showLotCreatedPopup(String lotNumber, PrepareSkuLotRecord lot) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 540),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Celebration Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "SKU Lot Created Successfully!",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "A unique Lot Number has been generated for this inventory batch.",
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),

                  // Lot Number Display Card with Copy
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("GENERATED LOT NUMBER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 1.1)),
                              const SizedBox(height: 4),
                              SelectableText(
                                lotNumber,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFD97706), letterSpacing: 1.2),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: lotNumber));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Lot Number copied to clipboard!"), duration: Duration(seconds: 2)),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text("Copy"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Quick Summary Table
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildModalSummaryRow("Designer", lot.designername ?? "ID: ${lot.designerid}"),
                        const Divider(height: 12, thickness: 0.8, color: Color(0xFFE2E8F0)),
                        _buildModalSummaryRow("Product", "${lot.productname ?? 'ID: ${lot.productid}'} ${lot.subproductname != null ? '(${lot.subproductname})' : ''}"),
                        const Divider(height: 12, thickness: 0.8, color: Color(0xFFE2E8F0)),
                        _buildModalSummaryRow("Purity & Rate", "${lot.purityname ?? 'ID: ${lot.purityid}'} @ ₹${lot.rate.toStringAsFixed(2)}/g"),
                        const Divider(height: 12, thickness: 0.8, color: Color(0xFFE2E8F0)),
                        _buildModalSummaryRow("Quantity & Weights", "${lot.totalPcs} pcs | Grs: ${lot.totalGrossWeight.toStringAsFixed(3)}g | Net: ${lot.totalNetWeight.toStringAsFixed(3)}g"),
                        if (lot.totalStonePcs > 0 || lot.totalDiamondPcs > 0) ...[
                          const Divider(height: 12, thickness: 0.8, color: Color(0xFFE2E8F0)),
                          _buildModalSummaryRow("Stones", "${lot.totalStonePcs} pcs (${lot.totalStoneWeight.toStringAsFixed(3)} ${lot.stoneUnit})"),
                          const Divider(height: 12, thickness: 0.8, color: Color(0xFFE2E8F0)),
                          _buildModalSummaryRow("Diamonds", "${lot.totalDiamondPcs} pcs (${lot.totalDiamondWeight.toStringAsFixed(3)} ${lot.diamondUnit})"),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openCreateForm();
                          },
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text("Prepare Another"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.done_all_rounded, size: 18),
                          label: const Text("View Lots List"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GlassTheme.primaryNeon,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: GlassTheme.accentEmerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: GlassTheme.accentRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint, Widget? prefixIcon, Widget? suffixIcon, Widget? suffix, EdgeInsetsGeometry? contentPadding}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      suffix: suffix,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: GlassTheme.primaryNeon, width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalLotsCount = _lots.length;
    final totalPcsSum = _lots.fold<int>(0, (sum, item) => sum + item.totalPcs);
    final totalGrsWtSum = _lots.fold<double>(0.0, (sum, item) => sum + item.totalGrossWeight);
    final totalNetWtSum = _lots.fold<double>(0.0, (sum, item) => sum + item.totalNetWeight);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          _buildHeaderBar(),
          const SizedBox(height: 20),

          // Statistics Overview Cards
          _buildStatCards(totalLotsCount, totalPcsSum, totalGrsWtSum, totalNetWtSum),
          const SizedBox(height: 24),

          // Collapsible In-Page Form
          if (_showForm) ...[
            _buildFormCard(),
            const SizedBox(height: 24),
          ],

          // Search & Filter Toolbar
          _buildToolbar(),
          const SizedBox(height: 16),

          // Main Lots Data View (Table or Cards)
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(48.0), child: CircularProgressIndicator()))
          else if (_filteredLots.isEmpty)
            _buildEmptyState()
          else if (_isTableView)
            _buildLotsTableView()
          else
            _buildLotsCardView(),
        ],
      ),
    );
  }

  Widget _buildHeaderBar() {
    return LayoutBuilder(builder: (context, constraints) {
      final isCompact = constraints.maxWidth < 650;
      return isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderTitleSection(),
                const SizedBox(height: 12),
                _buildHeaderActionButtons(),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _buildHeaderTitleSection()),
                _buildHeaderActionButtons(),
              ],
            );
    });
  }

  Widget _buildHeaderTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (widget.onBack != null) ...[
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                onPressed: widget.onBack,
                tooltip: "Back",
              ),
              const SizedBox(width: 8),
            ],
            const Text(
              "STOCK / PREPARE FOR SKU",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          "Prepare for SKU (Lot Master)",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
          onPressed: _loadData,
          tooltip: "Refresh Data",
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _showForm ? () => setState(() => _showForm = false) : _openCreateForm,
          icon: Icon(_showForm ? Icons.close_rounded : Icons.add_rounded, size: 18),
          label: Text(_showForm ? "Close Form" : "+ New SKU Lot"),
          style: ElevatedButton.styleFrom(
            backgroundColor: _showForm ? const Color(0xFF64748B) : GlassTheme.primaryNeon,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards(int totalLots, int totalPcs, double totalGrsWt, double totalNetWt) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 800;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildStatCard("Total SKU Lots", totalLots.toString(), Icons.inventory_2_rounded, const Color(0xFF4F46E5), isWide),
          _buildStatCard("Total Pieces", "$totalPcs pcs", Icons.category_rounded, const Color(0xFF059669), isWide),
          _buildStatCard("Gross Weight", "${totalGrsWt.toStringAsFixed(3)} g", Icons.scale_rounded, const Color(0xFFD97706), isWide),
          _buildStatCard("Net Weight", "${totalNetWt.toStringAsFixed(3)} g", Icons.diamond_rounded, const Color(0xFF0284C7), isWide),
        ],
      );
    });
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isWide) {
    return Container(
      width: isWide ? 220 : 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    // Filter subproducts for selected product
    final matchingSubProducts = _allSubProducts.where((sp) {
      if (_selectedProductId == null) return true;
      return sp.productid == _selectedProductId;
    }).toList();

    // Filter purities by selected product's metal
    final matchingOrnamentPurities = _getMatchingPuritiesForSelectedProduct();
    final matchingPurityId = (_selectedPurityId != null && matchingOrnamentPurities.any((p) => p.purityid == _selectedPurityId))
        ? _selectedPurityId
        : (matchingOrnamentPurities.isNotEmpty ? matchingOrnamentPurities.first.purityid : null);

    // Filter stone products where diastone = 'S'
    final stoneProducts = _allProducts.where((p) => p.diastone.toUpperCase().trim() == 'S').toList();

    // Filter diamond products where diastone = 'D'
    final diamondProducts = _allProducts.where((p) => p.diastone.toUpperCase().trim() == 'D').toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Form Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: GlassTheme.primaryNeon.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _editingRecord != null ? Icons.edit_note_rounded : Icons.post_add_rounded,
                        color: GlassTheme.primaryNeon,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _editingRecord != null ? "Edit SKU Lot: ${_editingRecord!.lotNumber}" : "Prepare New SKU Lot",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Configure items, weights, purity, stones & diamonds. Lot Number is generated on save.",
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => setState(() => _showForm = false),
                  tooltip: "Close Form",
                ),
              ],
            ),
            const Divider(height: 28, color: Color(0xFFE2E8F0)),

            // Section 1: Main Identification & Classification
            const Text(
              "1. ITEM & MASTER ATTRIBUTES",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.1),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // Branch Dropdown
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedBranchId,
                    decoration: _inputDecoration("Branch *", prefixIcon: const Icon(Icons.storefront_rounded, size: 20)),
                    items: _allBranches.map((b) {
                      return DropdownMenuItem(value: b.branchId, child: Text(b.branchName, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedBranchId = val),
                    validator: (v) => (v == null || v.isEmpty) ? "Branch is required" : null,
                  ),
                ),

                // Designer Dropdown
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: _selectedDesignerId,
                    decoration: _inputDecoration("Designer *", prefixIcon: const Icon(Icons.design_services_rounded, size: 20)),
                    items: _allDesigners.map((d) {
                      return DropdownMenuItem(
                        value: d.designerid,
                        child: Text("${d.designername} (${d.designershortname})", style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedDesignerId = val),
                    validator: (v) => v == null ? "Designer is required" : null,
                  ),
                ),

                // Product Dropdown
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: _selectedProductId,
                    decoration: _inputDecoration("Product *", prefixIcon: const Icon(Icons.category_rounded, size: 20)),
                    items: _allProducts.map((p) {
                      final mName = (p.metalname != null && p.metalname!.isNotEmpty) ? " [${p.metalname}]" : "";
                      return DropdownMenuItem(
                        value: p.productid,
                        child: Text("${p.productname}$mName", style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedProductId = val;
                        // Reset subproduct if no longer matching
                        if (_selectedSubProductId != null && !_allSubProducts.any((sp) => sp.subproductid == _selectedSubProductId && sp.productid == val)) {
                          _selectedSubProductId = null;
                        }
                        // Filter and auto-sync purity matching product's metal
                        _syncPurityWithSelectedProduct();
                      });
                    },
                    validator: (v) => v == null ? "Product is required" : null,
                  ),
                ),

                // Sub-Product Dropdown
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<int?>(
                    isExpanded: true,
                    value: _selectedSubProductId,
                    decoration: _inputDecoration("Sub-Product (Optional)", prefixIcon: const Icon(Icons.subdirectory_arrow_right_rounded, size: 20)),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text("-- All / None --", style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)))),
                      ...matchingSubProducts.map((sp) {
                        return DropdownMenuItem<int?>(
                          value: sp.subproductid,
                          child: Text(sp.subproductname, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (val) => setState(() => _selectedSubProductId = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 2: Purity & Rate & Assorted (Filtered by Product Metal)
            const Text(
              "2. PURITY, RATE & ASSORTED STATUS",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.1),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // Purity Dropdown (Filtered strictly by selected product's metal)
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: matchingPurityId,
                    decoration: _inputDecoration(
                      "Ornament Purity *",
                      prefixIcon: const Icon(Icons.verified_rounded, size: 20),
                    ),
                    items: matchingOrnamentPurities.map((p) {
                      return DropdownMenuItem(
                        value: p.purityid,
                        child: Text("${p.purityname} (${p.purity.toStringAsFixed(1)}%)", style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedPurityId = val;
                        // Dynamically update rate when purity changes
                        _updatePurityRate(val, force: true);
                      });
                    },
                    validator: (v) => v == null ? "Purity is required" : null,
                  ),
                ),

                // Purity Rate
                SizedBox(
                  width: 260,
                  child: TextFormField(
                    controller: _rateController,
                    decoration: _inputDecoration(
                      "Purity Rate (₹ / g) *",
                      prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 20),
                      hint: "e.g. 7250.00",
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Rate is required";
                      final d = double.tryParse(v.trim());
                      if (d == null || d <= 0) return "Enter valid rate";
                      return null;
                    },
                  ),
                ),

                // IS ASSORTED Dropdown
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _isAssorted,
                    decoration: _inputDecoration("Is Assorted? *", prefixIcon: const Icon(Icons.call_split_rounded, size: 20)),
                    items: const [
                      DropdownMenuItem(value: 'NO', child: Text("NO (Single SKU)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'YES', child: Text("YES (Assorted Lot)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFD97706)), overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) => setState(() => _isAssorted = val ?? 'NO'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 3: Quantity & Weights
            const Text(
              "3. QUANTITY & WEIGHTS",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.1),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // Total Pcs
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    controller: _totalPcsController,
                    decoration: _inputDecoration("Total Pcs *", prefixIcon: const Icon(Icons.tag_rounded, size: 20)),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Pcs required";
                      final n = int.tryParse(v.trim());
                      if (n == null || n <= 0) return "Must be > 0";
                      return null;
                    },
                  ),
                ),

                // Total Gross Weight
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _totalGrossWtController,
                    decoration: _inputDecoration(
                      "Total Gross Wt (g) *",
                      prefixIcon: const Icon(Icons.scale_rounded, size: 20),
                      hint: "0.000",
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}'))],
                    onChanged: (_) => _autoCalculateNetWeight(),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Gross weight required";
                      final d = double.tryParse(v.trim());
                      if (d == null || d <= 0) return "Must be > 0";
                      return null;
                    },
                  ),
                ),

                // Total Net Weight (Auto-calculated with less weight from stones/diamonds)
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _totalNetWtController,
                    decoration: _inputDecoration(
                      "Total Net Wt (g) *",
                      prefixIcon: const Icon(Icons.fitness_center_rounded, size: 20),
                      hint: "0.000",
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}'))],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Net weight required";
                      final d = double.tryParse(v.trim());
                      if (d == null || d < 0) return "Must be >= 0";
                      final grs = double.tryParse(_totalGrossWtController.text.trim()) ?? 0.0;
                      if (grs > 0 && d > grs) return "Cannot exceed Gross Wt";
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section 4: Dynamic Multi-Item Stone Details
            _buildMultiStoneSection(stoneProducts),
            const SizedBox(height: 16),

            // Section 5: Dynamic Multi-Item Diamond Details
            _buildMultiDiamondSection(diamondProducts),
            const SizedBox(height: 20),

            // Remarks
            TextFormField(
              controller: _remarksController,
              decoration: _inputDecoration(
                "Remarks / Lot Notes (Optional)",
                prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                hint: "Add specific instructions, packet details, or supplier info...",
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Form Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() => _showForm = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Cancel"),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveRecord,
                  icon: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(_isSaving ? "Saving..." : (_editingRecord != null ? "Update SKU Lot" : "Save & Generate Lot Number")),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlassTheme.primaryNeon,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================= MULTI-STONE ITEMS SECTION =================
  Widget _buildMultiStoneSection(List<ProductRecord> stoneProducts) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _stoneExpanded = !_stoneExpanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.grain_rounded, color: Color(0xFF059669), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text("STONE DETAILS (DIASTONE = 'S')", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669), letterSpacing: 0.8)),
                            if (_stoneItems.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: const Color(0xFF059669), borderRadius: BorderRadius.circular(10)),
                                child: Text("${_stoneItems.length} items", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        const Text("Add multiple stone line items with Unit (Gram 'G' / Carat 'C') and weight deductions", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Icon(
                    _stoneExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
          if (_stoneExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_stoneItems.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      child: const Text("No stone items added yet. Click '+ Add Stone Item' below if this ornament contains stones.", style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    ),
                  ..._stoneItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final matchingStoneSubProducts = _allSubProducts.where((sp) {
                      if (item.stoneProductId == null) return true;
                      return sp.productid == item.stoneProductId;
                    }).toList();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Item index label
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                            child: Text("Stone #${index + 1}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                          ),

                          // Stone Product
                          SizedBox(
                            width: 200,
                            child: DropdownButtonFormField<int?>(
                              isExpanded: true,
                              value: item.stoneProductId,
                              decoration: _inputDecoration("Stone Product *"),
                              items: stoneProducts.map((p) {
                                return DropdownMenuItem<int?>(value: p.productid, child: Text(p.productname, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis));
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  item.stoneProductId = val;
                                  if (item.stoneSubProductId != null && !matchingStoneSubProducts.any((sp) => sp.subproductid == item.stoneSubProductId && sp.productid == val)) {
                                    item.stoneSubProductId = null;
                                  }
                                });
                              },
                              validator: (v) => v == null ? "Required" : null,
                            ),
                          ),

                          // Stone Sub-Product
                          SizedBox(
                            width: 180,
                            child: DropdownButtonFormField<int?>(
                              isExpanded: true,
                              value: item.stoneSubProductId,
                              decoration: _inputDecoration("Sub-Product"),
                              items: [
                                const DropdownMenuItem<int?>(value: null, child: Text("-- All / None --", style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis)),
                                ...matchingStoneSubProducts.map((sp) {
                                  return DropdownMenuItem<int?>(value: sp.subproductid, child: Text(sp.subproductname, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis));
                                }),
                              ],
                              onChanged: (val) => setState(() => item.stoneSubProductId = val),
                            ),
                          ),

                          // Stone Unit (G / C)
                          SizedBox(
                            width: 120,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: item.stoneUnit.toUpperCase() == 'C' ? 'C' : 'G',
                              decoration: _inputDecoration("Unit *"),
                              items: const [
                                DropdownMenuItem(value: 'G', child: Text("Gram (G)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'C', child: Text("Carat (C)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669)), overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  item.stoneUnit = val ?? 'G';
                                  _autoCalculateNetWeight();
                                });
                              },
                            ),
                          ),

                          // Pcs
                          SizedBox(
                            width: 100,
                            child: TextFormField(
                              initialValue: item.pcs.toString(),
                              decoration: _inputDecoration("Pcs"),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (v) {
                                item.pcs = int.tryParse(v.trim()) ?? 0;
                              },
                            ),
                          ),

                          // Weight
                          SizedBox(
                            width: 130,
                            child: TextFormField(
                              initialValue: item.weight.toStringAsFixed(3),
                              decoration: _inputDecoration("Weight"),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}'))],
                              onChanged: (v) {
                                item.weight = double.tryParse(v.trim()) ?? 0.0;
                                _autoCalculateNetWeight();
                              },
                            ),
                          ),

                          // Remove Row
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: GlassTheme.accentRose, size: 20),
                            tooltip: "Remove Stone Item",
                            onPressed: () {
                              setState(() {
                                _stoneItems.removeAt(index);
                                _autoCalculateNetWeight();
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),

                  // Add Stone Button
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        final defaultProd = stoneProducts.isNotEmpty ? stoneProducts.first.productid : null;
                        _stoneItems.add(SkuLotStoneItem(
                          stoneProductId: defaultProd,
                          stoneUnit: 'G',
                          pcs: 1,
                          weight: 0.0,
                        ));
                      });
                    },
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text("+ Add Stone Item"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF059669),
                      side: const BorderSide(color: Color(0xFF059669)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ================= MULTI-DIAMOND ITEMS SECTION =================
  Widget _buildMultiDiamondSection(List<ProductRecord> diamondProducts) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _diamondExpanded = !_diamondExpanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.diamond_rounded, color: Color(0xFF0284C7), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text("DIAMOND DETAILS (DIASTONE = 'D')", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7), letterSpacing: 0.8)),
                            if (_diamondItems.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: const Color(0xFF0284C7), borderRadius: BorderRadius.circular(10)),
                                child: Text("${_diamondItems.length} items", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        const Text("Add multiple diamond line items with Unit (Carat 'C' / Gram 'G') and weight deductions", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Icon(
                    _diamondExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
          if (_diamondExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_diamondItems.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      child: const Text("No diamond items added yet. Click '+ Add Diamond Item' below if this ornament contains diamonds.", style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    ),
                  ..._diamondItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final matchingDiamondSubProducts = _allSubProducts.where((sp) {
                      if (item.diamondProductId == null) return true;
                      return sp.productid == item.diamondProductId;
                    }).toList();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Item index label
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFF0F9FF), borderRadius: BorderRadius.circular(6)),
                            child: Text("Diamond #${index + 1}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                          ),

                          // Diamond Product
                          SizedBox(
                            width: 200,
                            child: DropdownButtonFormField<int?>(
                              isExpanded: true,
                              value: item.diamondProductId,
                              decoration: _inputDecoration("Diamond Product *"),
                              items: diamondProducts.map((p) {
                                return DropdownMenuItem<int?>(value: p.productid, child: Text(p.productname, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis));
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  item.diamondProductId = val;
                                  if (item.diamondSubProductId != null && !matchingDiamondSubProducts.any((sp) => sp.subproductid == item.diamondSubProductId && sp.productid == val)) {
                                    item.diamondSubProductId = null;
                                  }
                                });
                              },
                              validator: (v) => v == null ? "Required" : null,
                            ),
                          ),

                          // Diamond Sub-Product
                          SizedBox(
                            width: 180,
                            child: DropdownButtonFormField<int?>(
                              isExpanded: true,
                              value: item.diamondSubProductId,
                              decoration: _inputDecoration("Sub-Product"),
                              items: [
                                const DropdownMenuItem<int?>(value: null, child: Text("-- All / None --", style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis)),
                                ...matchingDiamondSubProducts.map((sp) {
                                  return DropdownMenuItem<int?>(value: sp.subproductid, child: Text(sp.subproductname, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis));
                                }),
                              ],
                              onChanged: (val) => setState(() => item.diamondSubProductId = val),
                            ),
                          ),

                          // Diamond Unit (C / G)
                          SizedBox(
                            width: 120,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: item.diamondUnit.toUpperCase() == 'G' ? 'G' : 'C',
                              decoration: _inputDecoration("Unit *"),
                              items: const [
                                DropdownMenuItem(value: 'C', child: Text("Carat (C)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'G', child: Text("Gram (G)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  item.diamondUnit = val ?? 'C';
                                  _autoCalculateNetWeight();
                                });
                              },
                            ),
                          ),

                          // Pcs
                          SizedBox(
                            width: 100,
                            child: TextFormField(
                              initialValue: item.pcs.toString(),
                              decoration: _inputDecoration("Pcs"),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (v) {
                                item.pcs = int.tryParse(v.trim()) ?? 0;
                              },
                            ),
                          ),

                          // Weight
                          SizedBox(
                            width: 130,
                            child: TextFormField(
                              initialValue: item.weight.toStringAsFixed(3),
                              decoration: _inputDecoration("Weight"),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}'))],
                              onChanged: (v) {
                                item.weight = double.tryParse(v.trim()) ?? 0.0;
                                _autoCalculateNetWeight();
                              },
                            ),
                          ),

                          // Remove Row
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: GlassTheme.accentRose, size: 20),
                            tooltip: "Remove Diamond Item",
                            onPressed: () {
                              setState(() {
                                _diamondItems.removeAt(index);
                                _autoCalculateNetWeight();
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),

                  // Add Diamond Button
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        final defaultProd = diamondProducts.isNotEmpty ? diamondProducts.first.productid : null;
                        _diamondItems.add(SkuLotDiamondItem(
                          diamondProductId: defaultProd,
                          diamondUnit: 'C',
                          pcs: 1,
                          weight: 0.0,
                        ));
                      });
                    },
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text("+ Add Diamond Item"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0284C7),
                      side: const BorderSide(color: Color(0xFF0284C7)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search Input
          SizedBox(
            width: 240,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search Lot #, Designer, Product...",
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
          ),

          // Branch Filter
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: _filterBranchId,
              decoration: _inputDecoration("Branch Filter", contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              items: [
                const DropdownMenuItem(value: 'ALL', child: Text("All Branches", style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                ..._allBranches.map((b) => DropdownMenuItem(value: b.branchId, child: Text(b.branchName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (val) {
                setState(() {
                  _filterBranchId = val ?? 'ALL';
                  _applyFilter();
                });
              },
            ),
          ),

          // Designer Filter
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<int?>(
              isExpanded: true,
              value: _filterDesignerId,
              decoration: _inputDecoration("Designer Filter", contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text("All Designers", style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                ..._allDesigners.map((d) => DropdownMenuItem<int?>(value: d.designerid, child: Text(d.designername, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (val) {
                setState(() {
                  _filterDesignerId = val;
                  _applyFilter();
                });
              },
            ),
          ),

          // Is Assorted Filter
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: _filterIsAssorted,
              decoration: _inputDecoration("Assorted Filter", contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text("All Lots", style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'NO', child: Text("Single SKU (NO)", style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'YES', child: Text("Assorted (YES)", style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (val) {
                setState(() {
                  _filterIsAssorted = val ?? 'ALL';
                  _applyFilter();
                });
              },
            ),
          ),

          // View Switcher (Table vs Card)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.table_rows_rounded, color: _isTableView ? GlassTheme.primaryNeon : const Color(0xFF94A3B8)),
                tooltip: "Table View",
                onPressed: () => setState(() => _isTableView = true),
              ),
              IconButton(
                icon: Icon(Icons.grid_view_rounded, color: !_isTableView ? GlassTheme.primaryNeon : const Color(0xFF94A3B8)),
                tooltip: "Card Grid View",
                onPressed: () => setState(() => _isTableView = false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF94A3B8), size: 40),
          ),
          const SizedBox(height: 16),
          const Text("No Prepare SKU Lots Found", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          const Text("Create your first SKU preparation lot or adjust your search filters.", style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _openCreateForm,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text("+ New SKU Lot"),
            style: ElevatedButton.styleFrom(
              backgroundColor: GlassTheme.primaryNeon,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLotsTableView() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
          dataTextStyle: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
          columnSpacing: 24,
          horizontalMargin: 20,
          columns: const [
            DataColumn(label: Text("LOT NUMBER")),
            DataColumn(label: Text("BRANCH")),
            DataColumn(label: Text("DESIGNER")),
            DataColumn(label: Text("PRODUCT & SUBPRODUCT")),
            DataColumn(label: Text("PURITY & RATE")),
            DataColumn(label: Text("ASSORTED")),
            DataColumn(label: Text("PCS")),
            DataColumn(label: Text("GROSS WT")),
            DataColumn(label: Text("NET WT")),
            DataColumn(label: Text("STONES / DIAMONDS")),
            DataColumn(label: Text("ACTIONS")),
          ],
          rows: _filteredLots.map((lot) {
            final stoneSummary = lot.stoneItems.isNotEmpty
                ? "${lot.stoneItems.length} items (${lot.totalStoneWeight.toStringAsFixed(2)}g)"
                : (lot.totalStonePcs > 0 ? "${lot.totalStonePcs}p (${lot.totalStoneWeight.toStringAsFixed(2)}${lot.stoneUnit})" : "-");

            final diamondSummary = lot.diamondItems.isNotEmpty
                ? "${lot.diamondItems.length} items (${lot.totalDiamondWeight.toStringAsFixed(2)}ct)"
                : (lot.totalDiamondPcs > 0 ? "${lot.totalDiamondPcs}p (${lot.totalDiamondWeight.toStringAsFixed(2)}${lot.diamondUnit})" : "-");

            return DataRow(
              cells: [
                // Lot Number with copy
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          lot.lotNumber,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF94A3B8)),
                        tooltip: "Copy Lot Number",
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: lot.lotNumber));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Copied ${lot.lotNumber}"), duration: const Duration(seconds: 1)),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Branch
                DataCell(Text(lot.branchname ?? lot.branchid, style: const TextStyle(fontSize: 12))),

                // Designer
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(lot.designername ?? "ID: ${lot.designerid}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      if (lot.designershortname != null && lot.designershortname!.isNotEmpty)
                        Text(lot.designershortname!, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    ],
                  ),
                ),

                // Product & Subproduct
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(lot.productname ?? "ID: ${lot.productid}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      if (lot.subproductname != null && lot.subproductname!.isNotEmpty)
                        Text(lot.subproductname!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),

                // Purity & Rate
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(lot.purityname ?? "ID: ${lot.purityid}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      Text("₹${lot.rate.toStringAsFixed(2)}/g", style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

                // Is Assorted
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (lot.isAssorted == 'YES') ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      lot.isAssorted,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: (lot.isAssorted == 'YES') ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ),

                // Pcs
                DataCell(Text("${lot.totalPcs} pcs", style: const TextStyle(fontWeight: FontWeight.bold))),

                // Gross Wt
                DataCell(Text("${lot.totalGrossWeight.toStringAsFixed(3)} g", style: const TextStyle(fontWeight: FontWeight.w600))),

                // Net Wt
                DataCell(Text("${lot.totalNetWeight.toStringAsFixed(3)} g", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7)))),

                // Stones / Diamonds summary
                DataCell(
                  Text(
                    "Stn: $stoneSummary\nDia: $diamondSummary",
                    style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                  ),
                ),

                // Actions
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF4F46E5)),
                        tooltip: "Edit Lot",
                        onPressed: () => _openEditForm(lot),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                        tooltip: "Delete Lot",
                        onPressed: () => _deleteRecord(lot),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLotsCardView() {
    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = constraints.maxWidth > 1100 ? 3 : (constraints.maxWidth > 700 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: 340,
        ),
        itemCount: _filteredLots.length,
        itemBuilder: (context, index) {
          final lot = _filteredLots[index];
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Card Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        lot.lotNumber,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (lot.isAssorted == 'YES') ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            lot.isAssorted == 'YES' ? 'ASSORTED' : 'SINGLE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: (lot.isAssorted == 'YES') ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF94A3B8)),
                          tooltip: "Copy Lot Number",
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: lot.lotNumber));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Copied ${lot.lotNumber}")));
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                // Card Details
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${lot.productname ?? 'Product'} ${lot.subproductname != null ? '• ${lot.subproductname}' : ''}",
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Designer: ${lot.designername ?? 'ID ${lot.designerid}'} | Branch: ${lot.branchname ?? lot.branchid}",
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Purity & Rate", style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                              Text(lot.purityname ?? 'Purity', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              Text("₹${lot.rate.toStringAsFixed(2)}/g", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("${lot.totalPcs} Pcs", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                              Text("Grs: ${lot.totalGrossWeight.toStringAsFixed(3)}g", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              Text("Net: ${lot.totalNetWeight.toStringAsFixed(3)}g", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Card Footer Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Stn: ${lot.stoneItems.isNotEmpty ? '${lot.stoneItems.length} items' : '${lot.totalStonePcs}p'}${lot.diamondItems.isNotEmpty ? ' | Dia: ${lot.diamondItems.length} items' : (lot.totalDiamondPcs > 0 ? ' | Dia: ${lot.totalDiamondPcs}p' : '')}",
                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF4F46E5)),
                          tooltip: "Edit Lot",
                          onPressed: () => _openEditForm(lot),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                          tooltip: "Delete Lot",
                          onPressed: () => _deleteRecord(lot),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    });
  }
}
