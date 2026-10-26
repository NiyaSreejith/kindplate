import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/order_model.dart';

class PdfInvoiceService {
  static Future<Uint8List> generateInvoicePdf(Order order) async {
    final pdf = pw.Document();

    final sym = order.currencySymbol;
    final curr = order.currencyCode;
    final invoiceNumber = 'INV-${order.orderNumber.replaceAll('KP-', '')}-${order.createdAt.millisecondsSinceEpoch.toString().substring(7)}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'KindPlate',
                        style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#2C6E49'),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Zero-Waste Surplus & Community Meal Network',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#E8F5E9'),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Text(
                          'OFFICIAL INVOICE',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#2C6E49'),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Invoice #: $invoiceNumber', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Order ID: #${order.orderNumber}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('Date: ${order.createdAt.toLocal().toString().split('.').first}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColor.fromHex('#2C6E49')),
              pw.SizedBox(height: 14),

              // Buyer & Restaurant Details
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('ISSUED TO (BUYER):', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                          pw.SizedBox(height: 4),
                          pw.Text(order.userName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 2),
                          pw.Text('Contact: ${order.contactPhone}', style: const pw.TextStyle(fontSize: 10)),
                          if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty)
                            pw.Text('Address: ${order.deliveryAddress}', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 14),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('FOOD PROVIDER / DONOR:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                          pw.SizedBox(height: 4),
                          pw.Text(order.sellerName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 2),
                          pw.Text('Fulfilment: ${order.fulfilmentMethodDisplay}', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('Verification Code: ${order.handoverCode}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2C6E49'))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Line Items Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(1.8),
                  3: const pw.FlexColumnWidth(1.8),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#2C6E49')),
                    children: [
                      _th('Item Description'),
                      _th('Qty', align: pw.TextAlign.center),
                      _th('Unit Price ($curr)', align: pw.TextAlign.right),
                      _th('Total ($curr)', align: pw.TextAlign.right),
                    ],
                  ),
                  ...order.items.map((item) {
                    return pw.TableRow(
                      children: [
                        _td(item.title),
                        _td('${item.quantity}', align: pw.TextAlign.center),
                        _td(item.isFreeDonation ? 'FREE' : '$sym${item.price.toStringAsFixed(2)}', align: pw.TextAlign.right),
                        _td(item.isFreeDonation ? 'FREE' : '$sym${item.totalPrice.toStringAsFixed(2)}', align: pw.TextAlign.right),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 16),

              // Summary & Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 240,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey50,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Column(
                      children: [
                        _summaryRow('Subtotal:', order.isFreeDonation ? 'FREE' : '$sym${order.subtotal.toStringAsFixed(2)}'),
                        if (order.deliveryFee > 0)
                          _summaryRow('Delivery Fee:', '$sym${order.deliveryFee.toStringAsFixed(2)}'),
                        if (order.tokenDiscount > 0)
                          _summaryRow('Green Token Discount:', '-$sym${order.tokenDiscount.toStringAsFixed(2)}'),
                        pw.Divider(color: PdfColors.grey400),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Grand Total ($curr):', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2C6E49'))),
                            pw.Text(
                              order.isFreeDonation ? 'FREE 💚' : '$sym${order.finalTotal.toStringAsFixed(2)}',
                              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2C6E49')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),

              // Footer
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Tokens Earned: +${order.tokensEarned} Green Tokens 🪙', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Payment Status: ${order.isFreeDonation ? "100% Care Donation" : "Confirmed / Handover Payment"}', style: pw.TextStyle(fontSize: 9)),
                    pw.Text('Thank you for rescuing food with KindPlate! 🌿', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#2C6E49'))),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _th(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      ),
    );
  }

  static pw.Widget _td(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: const pw.TextStyle(fontSize: 9),
      ),
    );
  }

  static pw.Widget _summaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  /// Download / Print / Share PDF Invoice directly on mobile, desktop, or web
  static Future<void> printOrShareInvoice(BuildContext context, Order order) async {
    final pdfBytes = await generateInvoicePdf(order);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'KindPlate_Invoice_${order.orderNumber}.pdf',
    );
  }
}
