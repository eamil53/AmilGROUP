import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/internet_sale.dart';
import '../providers/internet_sale_provider.dart';
import '../theme/app_theme.dart';
import '../providers/target_provider.dart';
import '../models/target.dart';

class InternetSaleEntryScreen extends StatefulWidget {
  final InternetSale? initialSale;
  const InternetSaleEntryScreen({super.key, this.initialSale});

  @override
  State<InternetSaleEntryScreen> createState() => _InternetSaleEntryScreenState();
}

class _InternetSaleEntryScreenState extends State<InternetSaleEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _tcController = TextEditingController();
  final _nameController = TextEditingController();
  final _xdslController = TextEditingController();
  final _accountController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  InternetSaleStatus _status = InternetSaleStatus.beklemede;
  bool _hasOldInternet = false;

  final List<String> _campaignOptions = ['TİVİBULU AİLE HD', '4 MEVSİM', 'FİBER GÜCÜ'];
  final List<String> _speedOptions = ['16', '24', '50', '100', '200', '500', '1000'];
  
  String? _selectedCampaign = 'TİVİBULU AİLE HD';
  String? _selectedSpeed = '24';
  String? _selectedSeller;
  String? _selectedSoldUser;

  @override
  void initState() {
    super.initState();
    if (widget.initialSale != null) {
      final sale = widget.initialSale!;
      _tcController.text = sale.customerTc;
      _nameController.text = sale.customerFullName;
      _xdslController.text = sale.xdslNo;
      _accountController.text = sale.accountNo;
      _phoneController.text = sale.phoneNo;
      _descriptionController.text = sale.description;
      _selectedDate = sale.date;
      _status = sale.status;
      _hasOldInternet = sale.hasOldInternet;
      _selectedCampaign = sale.campaign;
      _selectedSpeed = sale.speed;
      _selectedSeller = sale.sellerName;
      _selectedSoldUser = sale.soldUser;
    }
  }

  @override
  void dispose() {
    _tcController.dispose();
    _nameController.dispose();
    _xdslController.dispose();
    _accountController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.ttBlue,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      if (_selectedSeller == null || _selectedSoldUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen satış yapan ve katılım sağlayan personeli seçin!'), backgroundColor: Colors.red),
        );
        return;
      }
      
      final newSale = InternetSale(
        id: widget.initialSale?.id ?? const Uuid().v4(),
        customerTc: _tcController.text,
        customerFullName: _nameController.text,
        date: _selectedDate,
        campaign: _selectedCampaign ?? '',
        xdslNo: _xdslController.text,
        accountNo: _accountController.text,
        phoneNo: _phoneController.text,
        sellerName: _selectedSeller ?? '',
        soldUser: _selectedSoldUser ?? '',
        speed: _selectedSpeed ?? '',
        status: _status,
        hasOldInternet: _hasOldInternet,
        description: _descriptionController.text,
        createdAt: widget.initialSale?.createdAt ?? DateTime.now(),
      );

      final saleProvider = Provider.of<InternetSaleProvider>(context, listen: false);
      if (widget.initialSale != null) {
        saleProvider.updateSale(newSale);
      } else {
        saleProvider.addSale(newSale);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Satış başarıyla kaydedildi!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // Formu temizle ve yeni kayda hazır hale getir
      _formKey.currentState?.reset();
      _tcController.clear();
      _nameController.clear();
      _xdslController.clear();
      _accountController.clear();
      _phoneController.clear();
      _descriptionController.clear();
      
      setState(() {
         _selectedDate = DateTime.now();
         _status = InternetSaleStatus.beklemede;
         _hasOldInternet = false;
         _selectedSeller = null;
         _selectedSoldUser = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final personnelList = context.watch<TargetProvider>().personnel;
    final personnelNames = personnelList.map((p) => p.name).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(widget.initialSale != null ? 'Satış Kaydını Düzenle' : 'Yeni İnternet Satışı Girişi'),
        actions: [
          IconButton(
            onPressed: _saveForm,
            icon: const Icon(Icons.check_circle, size: 28),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Müşteri Bilgileri', Icons.person),
              _buildCard([
                _buildTextField('Müşteri T.C. Kimlik No', _tcController, Icons.badge, keyboardType: TextInputType.number, maxLength: 11),
                _buildTextField('İsim Soyisim', _nameController, Icons.person_outline),
                _buildTextField('İrtibat Telefon No', _phoneController, Icons.phone, keyboardType: TextInputType.phone),
              ]),
              const SizedBox(height: 20),
              
              _buildSectionHeader('Abonelik Bilgileri', Icons.router),
              _buildCard([
                _buildDateField('Satış Tarihi'),
                _buildDropdownField('Kampanya Adı', _selectedCampaign, _campaignOptions, Icons.campaign, (val) => setState(() => _selectedCampaign = val)),
                Row(
                  children: [
                    Expanded(child: _buildTextField('XDSL No', _xdslController, Icons.numbers, keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('Hesap No', _accountController, Icons.account_box, keyboardType: TextInputType.number)),
                  ],
                ),
                _buildDropdownField('Paket Hızı (Mbps)', _selectedSpeed, _speedOptions, Icons.speed, (val) => setState(() => _selectedSpeed = val)),
              ]),
              const SizedBox(height: 20),
              
              _buildSectionHeader('Satış Detayları', Icons.sell),
              _buildCard([
                _buildDropdownField('Satış Yapan Kişi', _selectedSeller, personnelNames, Icons.assignment_ind, (val) => setState(() => _selectedSeller = val), hint: 'Satıcı Seçin'),
                _buildDropdownField('Satış Yapılan Kullanıcı Adı', _selectedSoldUser, personnelNames, Icons.verified_user, (val) => setState(() => _selectedSoldUser = val), hint: 'Kullanıcı Seçin'),
                _buildStatusDropdown(),
                _buildSwitchField('Eski İnterneti Var mı?', _hasOldInternet, (val) => setState(() => _hasOldInternet = val)),
                _buildTextField('Açıklama', _descriptionController, Icons.description, maxLines: 3, isRequired: false),
              ]),
              
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.ttBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: const Text('KAYDET VE GÖNDER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.ttBlue, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(children: children.map((w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w)).toList()),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {TextInputType? keyboardType, int? maxLines = 1, int? maxLength, bool isRequired = true}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.ttBlue.withOpacity(0.7)),
        counterText: '',
      ),
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'Bu alan boş bırakılamaz';
        }
        return null;
      },
    );
  }

  Widget _buildDateField(String label) {
    return InkWell(
      onTap: () => _selectDate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: AppTheme.ttBlue.withOpacity(0.7), size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(DateFormat('dd.MM.yyyy').format(_selectedDate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<InternetSaleStatus>(
          value: _status,
          isExpanded: true,
          items: InternetSaleStatus.values.map((status) {
            return DropdownMenuItem(
              value: status,
              child: Text(status.name.toUpperCase()),
            );
          }).toList(),
          onChanged: (val) => setState(() => _status = val!),
        ),
      ),
    );
  }

  Widget _buildSwitchField(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.ttBlue,
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String? value, List<String> items, IconData icon, Function(String?) onChanged, {String? hint}) {
    // If the value isn't strictly inside items, reset it to null to avoid Dropdown errors.
    final currentValue = (value != null && items.contains(value)) ? value : null;

    return DropdownButtonFormField<String>(
      value: currentValue,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.ttBlue.withOpacity(0.7)),
      ),
      hint: hint != null ? Text(hint) : null,
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (val) => (val == null || val.isEmpty) ? 'Lütfen seçim yapınız' : null,
    );
  }
}
