import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import '../models/invoice.dart';
import 'currency_format.dart';

class PdfGenerator {
  static Future<File> generateInvoice(
    Invoice invoice, {
    required String shopName,
    required String shopAddress,
    required String shopPhone,
  }) async {
    final pdf = pw.Document();

    // Colors
    final primaryColor = PdfColor.fromHex('#6C63FF');
    final lightBg = PdfColor.fromHex('#F8F9FF');
    final textPrimary = PdfColor.fromHex('#2D3142');
    final textSecondary = PdfColor.fromHex('#9093A4');
    final dividerColor = PdfColor.fromHex('#EEEEF5');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: primaryColor,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(shopName,
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold)),
                      if (shopAddress.isNotEmpty)
                        pw.Text(shopAddress,
                            style: pw.TextStyle(
                                color: PdfColor.fromHex('#B3FFFFFF'), fontSize: 10)),
                      if (shopPhone.isNotEmpty)
                        pw.Text(shopPhone,
                            style: pw.TextStyle(
                                color: PdfColor.fromHex('#B3FFFFFF'), fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('INVOICE',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 28,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text(invoice.invoiceNumber,
                          style: pw.TextStyle(
                              color: PdfColor.fromHex('#B3FFFFFF'), fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Invoice info row
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Bill To',
                        style: pw.TextStyle(
                            color: textSecondary,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold)),
                    pw.Text(invoice.customerName ?? 'Walk-in Customer',
                        style: pw.TextStyle(
                            color: textPrimary,
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold)),
                    if (invoice.customerPhone != null &&
                        invoice.customerPhone!.isNotEmpty)
                      pw.Text(invoice.customerPhone!,
                          style: pw.TextStyle(
                              color: textSecondary, fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Date',
                        style: pw.TextStyle(
                            color: textSecondary,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold)),
                    pw.Text(DateFormat2.format(invoice.createdAt),
                        style: pw.TextStyle(
                            color: textPrimary, fontSize: 12)),
                    pw.SizedBox(height: 6),
                    pw.Text('Status',
                        style: pw.TextStyle(
                            color: textSecondary,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold)),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: invoice.status == InvoiceStatus.paid
                            ? PdfColor.fromHex('#E8F5E9')
                            : PdfColor.fromHex('#FFF3E0'),
                        borderRadius: pw.BorderRadius.circular(20),
                      ),
                      child: pw.Text(
                        invoice.status.name.toUpperCase(),
                        style: pw.TextStyle(
                          color: invoice.status == InvoiceStatus.paid
                              ? PdfColor.fromHex('#2E7D32')
                              : PdfColor.fromHex('#E65100'),
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Items table
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: dividerColor),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  // Table header
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: pw.BoxDecoration(
                      color: lightBg,
                      borderRadius: const pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(8),
                        topRight: pw.Radius.circular(8),
                      ),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                            flex: 4,
                            child: pw.Text('Item',
                                style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: textSecondary))),
                        pw.Expanded(
                            flex: 1,
                            child: pw.Text('Qty',
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: textSecondary))),
                        pw.Expanded(
                            flex: 2,
                            child: pw.Text('Price',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: textSecondary))),
                        pw.Expanded(
                            flex: 2,
                            child: pw.Text('Total',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: textSecondary))),
                      ],
                    ),
                  ),
                  pw.Divider(color: dividerColor, height: 0),
                  // Table rows
                  ...invoice.items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    return pw.Container(
                      color: idx % 2 == 0 ? PdfColors.white : lightBg,
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                              flex: 4,
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(item.productName,
                                      style: pw.TextStyle(
                                          fontSize: 11,
                                          fontWeight: pw.FontWeight.bold,
                                          color: textPrimary)),
                                  if (item.discount > 0)
                                    pw.Text('${item.discount}% off',
                                        style: pw.TextStyle(
                                            fontSize: 9, color: textSecondary)),
                                ],
                              )),
                          pw.Expanded(
                              flex: 1,
                              child: pw.Text(
                                  '${item.quantity} ${item.unit}',
                                  textAlign: pw.TextAlign.center,
                                  style: pw.TextStyle(
                                      fontSize: 10, color: textPrimary))),
                          pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                  CurrencyFormat.format(item.price),
                                  textAlign: pw.TextAlign.right,
                                  style: pw.TextStyle(
                                      fontSize: 10, color: textPrimary))),
                          pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                  CurrencyFormat.format(item.total),
                                  textAlign: pw.TextAlign.right,
                                  style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                      color: textPrimary))),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Totals
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.SizedBox(
                  width: 220,
                  child: pw.Column(
                    children: [
                      _buildTotalRow(
                          'Subtotal', CurrencyFormat.format(invoice.subtotal),
                          textSecondary, textPrimary),
                      if (invoice.discountAmount > 0)
                        _buildTotalRow(
                            'Discount',
                            '- ${CurrencyFormat.format(invoice.discountAmount)}',
                            PdfColor.fromHex('#E53935'),
                            PdfColor.fromHex('#E53935')),
                      if (invoice.taxAmount > 0)
                        _buildTotalRow(
                            'Tax (${invoice.taxPercent}%)',
                            CurrencyFormat.format(invoice.taxAmount),
                            textSecondary, textPrimary),
                      pw.Divider(color: dividerColor),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          color: primaryColor,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Total',
                                style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Text(
                                CurrencyFormat.format(invoice.totalAmount),
                                style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                      if (invoice.dueAmount > 0) ...[
                        pw.SizedBox(height: 6),
                        _buildTotalRow(
                            'Paid', CurrencyFormat.format(invoice.paidAmount),
                            textSecondary, PdfColor.fromHex('#2E7D32')),
                        _buildTotalRow(
                            'Due', CurrencyFormat.format(invoice.dueAmount),
                            PdfColor.fromHex('#E53935'),
                            PdfColor.fromHex('#E53935')),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Payment method
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: lightBg,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                children: [
                  pw.Text('Payment Method: ',
                      style: pw.TextStyle(
                          color: textSecondary, fontSize: 10)),
                  pw.Text(
                      invoice.paymentMethod.name.toUpperCase(),
                      style: pw.TextStyle(
                          color: textPrimary,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Notes:',
                        style: pw.TextStyle(
                            color: textSecondary, fontSize: 10)),
                    pw.Text(invoice.notes!,
                        style:
                            pw.TextStyle(color: textPrimary, fontSize: 10)),
                  ],
                ),
              ),
            ],

            pw.Spacer(),

            // Footer
            pw.Center(
              child: pw.Text('Thank you for your business!',
                  style: pw.TextStyle(
                      color: primaryColor,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/invoice_${invoice.invoiceNumber}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _buildTotalRow(
    String label,
    String value,
    PdfColor labelColor,
    PdfColor valueColor,
  ) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(color: labelColor, fontSize: 11)),
            pw.Text(value,
                style: pw.TextStyle(
                    color: valueColor,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  static Future<void> printInvoice(Invoice invoice,
      {required String shopName,
      required String shopAddress,
      required String shopPhone}) async {
    final file = await generateInvoice(invoice,
        shopName: shopName,
        shopAddress: shopAddress,
        shopPhone: shopPhone);
    await Printing.layoutPdf(onLayout: (_) => file.readAsBytes());
  }

  static Future<void> shareInvoice(Invoice invoice,
      {required String shopName,
      required String shopAddress,
      required String shopPhone}) async {
    final file = await generateInvoice(invoice,
        shopName: shopName,
        shopAddress: shopAddress,
        shopPhone: shopPhone);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Invoice ${invoice.invoiceNumber}',
      text:
          'Invoice ${invoice.invoiceNumber}\nAmount: ${CurrencyFormat.format(invoice.totalAmount)}',
    );
  }
}
