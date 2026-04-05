import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/target.dart';
import '../providers/target_provider.dart';
import '../theme/app_theme.dart';

class PersonnelManagementScreen extends StatefulWidget {
  const PersonnelManagementScreen({super.key});

  @override
  State<PersonnelManagementScreen> createState() => _PersonnelManagementScreenState();
}

class _PersonnelManagementScreenState extends State<PersonnelManagementScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  void _showAddPersonnelDialog([Personnel? p]) {
    if (p != null) {
      _nameController.text = p.name;
      _codeController.text = p.code;
    } else {
      _nameController.clear();
      _codeController.clear();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(p == null ? 'Yeni Personel Ekle' : 'Personel Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Ad Soyad'),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'B Kodu (B123456)'),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () {
              if (_nameController.text.isNotEmpty && _codeController.text.isNotEmpty) {
                final newP = Personnel(
                  id: p?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: _nameController.text.toUpperCase(),
                  code: _codeController.text.toUpperCase(),
                );
                context.read<TargetProvider>().addPersonnel(newP);
                Navigator.pop(context);
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TargetProvider>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personel Yönetimi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () => provider.syncLocalToFirebase(),
            tooltip: 'Örnek Verileri Yükle',
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: provider.personnel.length,
              itemBuilder: (context, index) {
                final p = provider.personnel[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.ttBlue,
                    child: Text(p.name[0], style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(p.code),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showAddPersonnelDialog(p),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Silme Onayı'),
                              content: Text('${p.name} isimli personeli silmek istediğinize emin misiniz?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
                                TextButton(
                                  onPressed: () {
                                    provider.deletePersonnel(p.id);
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Sil', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPersonnelDialog(),
        backgroundColor: AppTheme.ttBlue,
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }
}
