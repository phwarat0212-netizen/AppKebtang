import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaction.dart';
import '../state/language_state.dart';
import 'helpers.dart';

class PdfHelper {
  static Future<Uint8List> generateTransactionReport(
    List<Transaction> transactions,
    LanguageState lang,
    String username,
    List<Map<String, dynamic>> monthlyTrend,
  ) async {
    final pdf = pw.Document();
    
    // Load a font that supports Thai and Chinese.
    final font = await PdfGoogleFonts.sarabunRegular();
    final fontBold = await PdfGoogleFonts.sarabunBold();

    // Load App Logo
    final logoData = await rootBundle.load('image/icon.png');
    final logoBytes = logoData.buffer.asUint8List();
    final logoImage = pw.MemoryImage(logoBytes);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        footer: (context) => _buildFooter(context, lang),
        build: (context) => [
          _buildHeader(username, lang, logoImage),
          pw.SizedBox(height: 20),
          _buildSummary(transactions, lang),
          pw.SizedBox(height: 20),
          _buildMonthlyTrendSection(monthlyTrend, lang),
          pw.SizedBox(height: 20),
          _buildVisualAnalytics(transactions, lang),
          pw.SizedBox(height: 20),
          _buildTable(transactions, lang),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildMonthlyTrendSection(List<Map<String, dynamic>> trend, LanguageState lang) {
    if (trend.isEmpty) return pw.SizedBox();
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(lang.t('stats'), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: [lang.t('month'), lang.t('expense')],
          data: trend.map((m) => [m['month'], '฿${formatNum((m['amount'] as num).toDouble())}']).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue600),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellHeight: 20,
        ),
      ],
    );
  }

  static pw.Widget _buildHeader(String username, LanguageState lang, pw.MemoryImage logo) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(
          children: [
            pw.Container(
              width: 50, height: 50,
              child: pw.Image(logo),
            ),
            pw.SizedBox(width: 15),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(lang.t('app_title'), style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                pw.Text('${lang.t('hello')}, $username', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              ],
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(formatDate(DateTime.now()), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildSummary(List<Transaction> transactions, LanguageState lang) {
    final income = transactions.where((t) => t.isIncome).fold(0.0, (s, t) => s + t.amount);
    final expense = transactions.where((t) => !t.isIncome).fold(0.0, (s, t) => s + t.amount);
    final balance = income - expense;

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _summaryItem(lang.t('income'), income, PdfColors.green700),
          pw.VerticalDivider(color: PdfColors.grey400),
          _summaryItem(lang.t('expense'), expense, PdfColors.red700),
          pw.VerticalDivider(color: PdfColors.grey400),
          _summaryItem(lang.t('balance'), balance, balance >= 0 ? PdfColors.blue800 : PdfColors.red800),
        ],
      ),
    );
  }

  static pw.Widget _summaryItem(String label, double amount, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('฿${formatNum(amount)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    );
  }

  // --- Visual Analytics Section (Category Breakdown) ---
  static pw.Widget _buildVisualAnalytics(List<Transaction> transactions, LanguageState lang) {
    final expenseTx = transactions.where((t) => !t.isIncome).toList();
    final Map<String, double> categories = {};
    for (var t in expenseTx) {
      categories[t.category] = (categories[t.category] ?? 0) + t.amount;
    }
    final total = categories.values.fold(0.0, (s, v) => s + v);
    final sorted = categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(lang.t('expense_by_category'), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
        pw.SizedBox(height: 15),
        if (sorted.isEmpty) pw.Text(lang.t('no_data'), style: const pw.TextStyle(color: PdfColors.grey500)),
        ...sorted.take(5).map((e) {
          final percent = total > 0 ? e.value / total : 0.0;
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(lang.t(e.key), style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('฿${formatNum(e.value)} (${(percent * 100).toStringAsFixed(1)}%)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  height: 6,
                  width: double.infinity,
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Container(
                      height: 6,
                      width: 400 * percent, // Dynamic width proportional to percent
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue600,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _buildTable(List<Transaction> transactions, LanguageState lang) {
    final headers = [
      lang.t('today'), 
      lang.t('desc_label'),
      lang.t('category'),
      lang.t('amount_label'),
      lang.t('income'),
      '', 
    ];

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: transactions.map((t) => [
        formatDate(t.date),
        t.title,
        lang.t(t.category.toLowerCase()),
        '฿${formatNum(t.amount)}',
        t.isIncome ? lang.t('income') : lang.t('expense'),
        t.isRecurring ? '(R)' : '',
      ]).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellHeight: 25,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.center,
        5: pw.Alignment.center,
      },
      border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
    );
  }

  static pw.Widget _buildFooter(pw.Context context, LanguageState lang) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
      ),
    );
  }
}
