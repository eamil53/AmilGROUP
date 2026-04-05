import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/product.dart';

class PdfHelper {
  static Future<void> generateStockPdf(List<Product> products) async {
    final pdf = pw.Document();
    final format = NumberFormat.currency(locale: 'tr_TR', symbol: 'TL');
    final date = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TURK TELEKOM STOK RAPORU', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                  pw.Text(date),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Kategori', 'Marka', 'Model', 'IMEI/SN', 'Adet', 'Satis Fiyati'],
              data: products.map((p) {
                String label = 'Diger';
                if (p.category == ProductCategory.phone) label = 'Telefon';
                else if (p.category == ProductCategory.headset) label = 'Kulaklik';
                else if (p.category == ProductCategory.watch) label = 'Saat';
                else if (p.category == ProductCategory.modem) label = 'Modem';

                return [
                  label,
                  p.brand,
                  p.model,
                  p.imei1 ?? p.serialNumber ?? '-',
                  p.quantity.toString(),
                  format.format(p.salePrice),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('Toplam Urun Adedi: ${products.fold(0, (sum, p) => sum + p.quantity)}', 
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}
