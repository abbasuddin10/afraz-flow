import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/pos/data/sale.dart';
import '../models/tenant.dart';
import '../utils/formatters.dart';

/// Generates a compact A5 receipt/invoice and hands it to the platform print
/// dialog. Works on Android, iOS, web, Windows, macOS and Linux via `printing`.
class ReceiptService {
  const ReceiptService._();

  static Future<void> printInvoice({
    required Tenant tenant,
    required Sale sale,
  }) async {
    final bytes = await buildInvoice(tenant: tenant, sale: sale);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: '${sale.invoiceNo}.pdf',
    );
  }

  static Future<void> shareInvoice({
    required Tenant tenant,
    required Sale sale,
  }) async {
    final bytes = await buildInvoice(tenant: tenant, sale: sale);
    await Printing.sharePdf(bytes: bytes, filename: '${sale.invoiceNo}.pdf');
  }

  static Future<Uint8List> buildInvoicePreview({
    required Tenant tenant,
    required Sale sale,
  }) => buildInvoice(tenant: tenant, sale: sale);

  static String _money(String currency, num value) {
    // Use the ISO code so glyphs always render in the bundled PDF font.
    return '$currency ${Formats.number(value, decimals: 2)}';
  }

  static Future<Uint8List> buildInvoice({
    required Tenant tenant,
    required Sale sale,
  }) async {
    final doc = pw.Document(
      title: 'Invoice ${sale.invoiceNo}',
      author: tenant.name,
      creator: 'Afraz Flow',
    );

    final logoData = await rootBundle.load('assets/images/app_logo_mark.png');
    final logo = pw.MemoryImage(
      logoData.buffer.asUint8List(
        logoData.offsetInBytes,
        logoData.lengthInBytes,
      ),
    );

    const ink = PdfColor.fromInt(0xFF16263D);
    const muted = PdfColor.fromInt(0xFF68788D);
    const border = PdfColor.fromInt(0xFFE2E8F0);
    const navy = PdfColor.fromInt(0xFF0F2C4C);
    const teal = PdfColor.fromInt(0xFF0FA3A3);

    pw.Widget labeled(String label, String value) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: const pw.TextStyle(
            fontSize: 6.5,
            color: muted,
            letterSpacing: 0.8,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(value, style: const pw.TextStyle(fontSize: 9, color: ink)),
      ],
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Image(logo, width: 34, height: 34, fit: pw.BoxFit.cover),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        tenant.name,
                        style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          color: ink,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        [
                          tenant.businessType,
                          if (tenant.phone != null) tenant.phone!,
                          if (tenant.email != null) tenant.email!,
                        ].join('  ·  '),
                        style: const pw.TextStyle(fontSize: 7, color: muted),
                      ),
                      if (tenant.address != null) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          tenant.address!,
                          style: const pw.TextStyle(fontSize: 7, color: muted),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'INVOICE',
                      style: pw.TextStyle(
                        fontSize: 13,
                        letterSpacing: 1.6,
                        fontWeight: pw.FontWeight.bold,
                        color: teal,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      sale.invoiceNo,
                      style: const pw.TextStyle(fontSize: 8.5, color: ink),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      Formats.dateTime(sale.createdAt),
                      style: const pw.TextStyle(fontSize: 7.5, color: muted),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      sale.status.label.toUpperCase(),
                      style: const pw.TextStyle(fontSize: 7, color: muted),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Container(height: 1, color: border),
            pw.SizedBox(height: 12),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'BILLED TO',
                        style: const pw.TextStyle(
                          fontSize: 6.5,
                          color: muted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        sale.customerName,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                ),
                labeled('Payment', sale.paymentMethod.label),
                pw.SizedBox(width: 18),
                labeled('Items', '${sale.items.length}'),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Table(
              columnWidths: const {
                0: pw.FlexColumnWidth(2.9),
                1: pw.FlexColumnWidth(1.0),
                2: pw.FlexColumnWidth(0.65),
                3: pw.FlexColumnWidth(1.15),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: navy),
                  children: [
                    _cell('ITEM', header: true, align: pw.Alignment.centerLeft),
                    _cell('PRICE', header: true),
                    _cell('QTY', header: true),
                    _cell('TOTAL', header: true),
                  ],
                ),
                ...sale.items.asMap().entries.map((entry) {
                  final item = entry.value;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: entry.key.isEven
                          ? PdfColors.white
                          : const PdfColor.fromInt(0xFFF7F9FC),
                    ),
                    children: [
                      _cell(item.productName, align: pw.Alignment.centerLeft),
                      _cell(Formats.number(item.unitPrice, decimals: 2)),
                      _cell(item.quantityLabel),
                      _cell(Formats.number(item.lineTotal, decimals: 2)),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(9),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFFF4F7FB),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'THANK YOU',
                          style: pw.TextStyle(
                            fontSize: 7,
                            letterSpacing: 0.8,
                            fontWeight: pw.FontWeight.bold,
                            color: navy,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          sale.note?.isNotEmpty == true
                              ? sale.note!
                              : 'Goods sold are checked at the counter. '
                                    'Keep this receipt for returns within 7 days.',
                          style: const pw.TextStyle(
                            fontSize: 7,
                            color: muted,
                            lineSpacing: 2,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'Powered by Afraz Flow',
                          style: const pw.TextStyle(
                            fontSize: 6.5,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 14),
                pw.SizedBox(
                  width: 150,
                  child: pw.Column(
                    children: [
                      _totalRow(
                        'Subtotal',
                        _money(tenant.currency, sale.subtotal),
                        ink: ink,
                      ),
                      if (sale.discount > 0)
                        _totalRow(
                          'Discount',
                          '- ${_money(tenant.currency, sale.discount)}',
                          ink: ink,
                        ),
                      _totalRow(
                        'Tax (${tenant.taxRate.toStringAsFixed(1)}%)',
                        _money(tenant.currency, sale.tax),
                        ink: ink,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Container(height: 1, color: border),
                      pw.SizedBox(height: 4),
                      _totalRow(
                        'Total',
                        _money(tenant.currency, sale.total),
                        strong: true,
                        ink: ink,
                      ),
                      _totalRow(
                        'Paid',
                        _money(tenant.currency, sale.paidAmount),
                        ink: ink,
                      ),
                      _totalRow(
                        'Due',
                        _money(tenant.currency, sale.dueAmount),
                        strong: true,
                        color: sale.dueAmount > 0
                            ? const PdfColor.fromInt(0xFFD64545)
                            : teal,
                        ink: ink,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.Spacer(),
            pw.Container(height: 1, color: border),
            pw.SizedBox(height: 6),
            pw.Text(
              '${tenant.name} · Generated by Afraz Flow · ${Formats.dateTime(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 6.5, color: muted),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static pw.Widget _cell(
    String text, {
    bool header = false,
    pw.Alignment align = pw.Alignment.centerRight,
    PdfColor color = const PdfColor.fromInt(0xFF16263D),
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Align(
      alignment: align,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: header ? 6.5 : 7.5,
          color: header ? PdfColors.white : color,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          letterSpacing: header ? 0.6 : 0,
        ),
      ),
    ),
  );

  static pw.Widget _totalRow(
    String label,
    String value, {
    bool strong = false,
    PdfColor? color,
    required PdfColor ink,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: strong ? 9 : 7.5,
            color: strong ? ink : const PdfColor.fromInt(0xFF68788D),
            fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: strong ? 9 : 7.5,
            color: color ?? ink,
            fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    ),
  );
}
