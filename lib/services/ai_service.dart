import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/target.dart';

class AIService {
  static const String _apiKey = 'AIzaSyDKxQi-p6FBJIH7n_RZKbfNy94_faNUuPw';
  final GenerativeModel _model;

  AIService() : _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);

  Future<String> generatePerformanceReport({
    required String pName,
    required Map<TargetType, int> achievements,
    required Map<TargetType, int> targets,
    required double monthProgress,
  }) async {
    try {
      String dataTable = "";
      targets.forEach((type, target) {
        int achieved = achievements[type] ?? 0;
        double percent = target == 0 ? 0 : (achieved / target) * 100;
        dataTable += "${_getLabel(type)}: Hedef $target, Gerçekleşen $achieved (%${percent.toStringAsFixed(1)})\n";
      });

      final prompt = """
Sen bir Türk Telekom Bayi Satış Koçusun. Aşağıdaki performans verilerini analiz et ve personelim için samimi, motive edici ama aynı zamanda eksikleri net gösteren bir rapor hazırla.
Rapor mutlaka şu kısımları içermeli:
1. Genel durum özeti.
2. En başarılı olduğu alanlar.
3. Hızlanması gereken alanlar (Kritik eksikler).
4. Satışlarını nasıl artıracağına dair 3-4 adet nokta atışı teknik tavsiye.

Personel: $pName
Ayın Geçen Kısmı: %${(monthProgress * 100).toStringAsFixed(0)}
Performans Tablosu:
$dataTable

Lütfen Türkçe dilinde, profesyonel ama içten bir üslupla cevap ver.
""";

      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? "Rapor oluşturulamadı.";
    } catch (e) {
      return "Hata oluştu: $e";
    }
  }

  String _getLabel(TargetType type) {
    switch (type) {
      case TargetType.mobilFaturali: return "Mobil Faturalı";
      case TargetType.mobilFaturasiz: return "Mobil Faturasız";
      case TargetType.sabitInternet: return "İnternet";
      case TargetType.tivibuIptv: return "IPTV";
      case TargetType.tivibuUydu: return "Uydu";
      case TargetType.cihazAkilli: return "Akıllı Cihaz";
      case TargetType.cihazDiger: return "Diğer Cihaz";
    }
  }
}
