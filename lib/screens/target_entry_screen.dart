import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/target.dart';
import '../providers/target_provider.dart';
import '../theme/app_theme.dart';

class TargetEntryScreen extends StatefulWidget {
  const TargetEntryScreen({super.key});

  @override
  State<TargetEntryScreen> createState() => _TargetEntryScreenState();
}

class _TargetEntryScreenState extends State<TargetEntryScreen> {
  DateTime _selectedDate = DateTime.now();
  TargetType _selectedCategory = TargetType.mobilFaturali;
  final Map<String, TextEditingController> _controllers = {};
  // Local cache for all categories [PersonnelID][TargetType] -> value
  final Map<String, Map<TargetType, int>> _localData = {};
  bool _isSettingTargets = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    final provider = context.read<TargetProvider>();
    _localData.clear();

    for (var p in provider.personnel) {
      _controllers[p.id] = TextEditingController();
      _localData[p.id] = {};

      for (var type in TargetType.values) {
        int val = 0;
        if (_isSettingTargets) {
          val = provider.getTarget(p.id, _selectedDate, type);
        } else {
          // Günlük değil, o ayın toplam performansını getir (Kümülatif Senaryo)
          val = provider.getAchievement(p.id, _selectedDate, type);
        }
        _localData[p.id]![type] = val;
      }
    }
    _updateControllersFromLocal();
  }

  void _updateControllersFromLocal() {
    _localData.forEach((pId, categoryMap) {
      if (_controllers.containsKey(pId)) {
        _controllers[pId]!.text = (categoryMap[_selectedCategory] ?? 0)
            .toString();
      }
    });
  }

  @override
  void dispose() {
    _controllers.forEach((_, c) => c.dispose());
    super.dispose();
  }

  void _saveAll() async {
    final provider = context.read<TargetProvider>();

    // Save current controller values to local data first (safety)
    _controllers.forEach((pId, controller) {
      _localData[pId]![_selectedCategory] = int.tryParse(controller.text) ?? 0;
    });

    for (var p in provider.personnel) {
      final dataForP = _localData[p.id] ?? {};

      if (_isSettingTargets) {
        await provider.setMonthlyTarget(
          MonthlyTarget(
            personnelId: p.id,
            month: _selectedDate,
            targets: dataForP,
          ),
        );
      } else {
        // Aylık toplam kaydı için tahmin edilebilir bir ID oluştur (Provider ile aynı format)
        final monthlyId = '${p.id}_${_selectedDate.year}${_selectedDate.month.toString().padLeft(2, '0')}';
        
        await provider.addDailyAchievement(
          DailyAchievement(
            id: monthlyId,
            personnelId: p.id,
            date: _selectedDate,
            counts: dataForP,
          ),
        );
      }
    }
    
    // İşlem bittikten sonra TEK BİR bildirim gönder
    if (_isSettingTargets) {
      provider.notifyTeam('Hedefler Güncellendi 🎯', '${_selectedDate.month}/${_selectedDate.year} dönemi hedefleri güncellendi.');
    } else {
      provider.notifyTeam('Satış Verileri Güncellendi 🚀', 'Performans ve satış verileri az önce güncellendi.');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tüm kategorilerdeki veriler başarıyla kaydedildi!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TargetProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isSettingTargets ? 'Hedef Tanımla' : 'Toplam Performans Güncelle',
        ),
        actions: [
          TextButton(
            onPressed: _saveAll,
            child: const Text(
              'KAYDET',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTopHeader(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.personnel.length,
              itemBuilder: (context, index) {
                final p = provider.personnel[index];
                // Dealer Manager (Enver Amil) doesn't have targets
                if (_isSettingTargets && p.name.contains('ENVER AMİL')) {
                  return const SizedBox.shrink();
                }
                return _buildPersonnelInputRow(p);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          _buildToggle(),
          const SizedBox(height: 12),
          _buildDatePicker(),
          const SizedBox(height: 12),
          _buildCategorySelector(),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _toggleItem('Performans Güncelle', !_isSettingTargets)),
          Expanded(child: _toggleItem('Hedef Tanımla', _isSettingTargets)),
        ],
      ),
    );
  }

  Widget _toggleItem(String label, bool active) {
    return GestureDetector(
      onTap: () {
        if (!active) {
          setState(() {
            _isSettingTargets = label == 'Hedef Tanımla';
            _initializeData();
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? AppTheme.ttBlue : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: TargetType.values.map((type) {
          bool isSelected = _selectedCategory == type;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_getLabel(type)),
              selected: isSelected,
              onSelected: (val) {
                if (val) {
                  // Save current category to local data before switching
                  _controllers.forEach((pId, controller) {
                    _localData[pId]![_selectedCategory] =
                        int.tryParse(controller.text) ?? 0;
                  });
                  setState(() {
                    _selectedCategory = type;
                    _updateControllersFromLocal();
                  });
                }
              },
              selectedColor: AppTheme.ttBlue,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontSize: 12,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDatePicker() {
    return ListTile(
      visualDensity: VisualDensity.compact,
      title: Text(
        _isSettingTargets ? 'Hedef Ayı Seç' : 'Performans Ayı Seç',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        _isSettingTargets
            ? '${_selectedDate.year} / ${_selectedDate.month.toString().padLeft(2, '0')}'
            : '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}',
      ),
      trailing: const Icon(
        Icons.edit_calendar,
        color: AppTheme.ttBlue,
        size: 20,
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2023),
          lastDate: DateTime(2030),
        );
        if (picked != null) {
          setState(() {
            _selectedDate = picked;
            _initializeData();
          });
        }
      },
      tileColor: Colors.grey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildPersonnelInputRow(Personnel p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  p.code,
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: TextField(
              controller: _controllers[p.id],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onChanged: (val) {
                _localData[p.id]![_selectedCategory] = int.tryParse(val) ?? 0;
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getLabel(TargetType type) {
    switch (type) {
      case TargetType.mobilFaturali:
        return "Mobil Faturalı";
      case TargetType.mobilFaturasiz:
        return "Mobil Faturasız";
      case TargetType.sabitInternet:
        return "İnternet";
      case TargetType.tivibuIptv:
        return "IPTV";
      case TargetType.tivibuUydu:
        return "Uydu";
      case TargetType.cihazAkilli:
        return "Akıllı Cihaz";
      case TargetType.cihazDiger:
        return "Diğer Cihaz";
    }
  }
}
