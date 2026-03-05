import 'dart:typed_data';
import 'dart:io';

import 'package:mi_compra_mayorista/data/local/compra_repository.dart';
import 'package:mi_compra_mayorista/data/local/item_ticket_repository.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TicketPdfBuild {
  final String fileName;
  final Uint8List bytes;

  const TicketPdfBuild({
    required this.fileName,
    required this.bytes,
  });
}

class TicketPdfExporter {
  TicketPdfExporter._();

  static final TicketPdfExporter instance = TicketPdfExporter._();

  final ItemTicketRepository _itemTicketRepository = ItemTicketRepository.instance;

  Future<String> compartirCompra(Compra compra) async {
    final pdfBuild = await _buildCompraPdf(compra);
    await Printing.sharePdf(bytes: pdfBuild.bytes, filename: pdfBuild.fileName);
    return pdfBuild.fileName;
  }

  Future<String> guardarCompraEnSistema(Compra compra) async {
    final pdfBuild = await _buildCompraPdf(compra);
    final saveDir = await _resolveSaveDirectory();
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }

    final filePath = p.join(saveDir.path, pdfBuild.fileName);
    final file = File(filePath);
    await file.writeAsBytes(pdfBuild.bytes, flush: true);
    return filePath;
  }

  Future<Directory> _resolveSaveDirectory() async {
    if (Platform.isAndroid) {
      const publicCandidates = [
        '/storage/emulated/0/Download/TicketsSupermercado',
        '/sdcard/Download/TicketsSupermercado',
      ];

      for (final candidatePath in publicCandidates) {
        final candidate = Directory(candidatePath);
        if (await _canWriteDirectory(candidate)) {
          return candidate;
        }
      }

      final appExternalDownloads = await getExternalStorageDirectories(type: StorageDirectory.downloads);
      if (appExternalDownloads != null && appExternalDownloads.isNotEmpty) {
        final fallbackExternal = Directory(
          p.join(appExternalDownloads.first.path, 'TicketsSupermercado'),
        );
        if (await _canWriteDirectory(fallbackExternal)) {
          return fallbackExternal;
        }
      }
    }

    final appDocs = await getApplicationDocumentsDirectory();
    return Directory(p.join(appDocs.path, 'tickets_pdf'));
  }

  Future<bool> _canWriteDirectory(Directory dir) async {
    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final probeFile = File(p.join(dir.path, '.write_probe'));
      await probeFile.writeAsString('ok', flush: true);
      if (await probeFile.exists()) {
        await probeFile.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> guardarCompraComoImagenEnGaleria(Compra compra) async {
    final pdfBuild = await _buildCompraPdf(compra);
    final page = await Printing.raster(
      pdfBuild.bytes,
      pages: const [0],
      dpi: 220,
    ).first;

    final pngBytes = await page.toPng();
    final tempDir = await getTemporaryDirectory();
    final imageFileName = _buildImageFileName(compra.ticketId, compra.fecha);
    final imagePath = p.join(tempDir.path, imageFileName);
    final imageFile = File(imagePath);
    await imageFile.writeAsBytes(pngBytes, flush: true);

    final saved = await GallerySaver.saveImage(
      imageFile.path,
      albumName: 'Tickets Supermercado',
      toDcim: true,
    );

    if (saved != true) {
      throw Exception('No se pudo guardar en galeria (permiso o almacenamiento no disponible).');
    }

    return imageFileName;
  }

  Future<String> exportCompra(Compra compra) async {
    final pdfBuild = await _buildCompraPdf(compra);
    await Printing.sharePdf(bytes: pdfBuild.bytes, filename: pdfBuild.fileName);
    return pdfBuild.fileName;
  }

  Future<TicketPdfBuild> _buildCompraPdf(Compra compra) async {
    final items = await _itemTicketRepository.listByTicketId(compra.ticketId.toString());
    final pdf = pw.Document();
    final ticketFont = pw.Font.courier();
    const ticketWidth = 80 * PdfPageFormat.mm;
    final ticketHeight = _estimateTicketHeight(items.length, compra.confirmado);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(ticketWidth, ticketHeight),
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Container(
          color: PdfColors.white,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
            pw.Center(
              child: pw.Text(
                compra.comercio.toUpperCase(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: ticketFont,
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Center(
              child: pw.Text(
                'TICKET #${compra.ticketId}',
                style: pw.TextStyle(font: ticketFont, fontSize: 10),
              ),
            ),
            pw.Center(
              child: pw.Text(
                _formatDisplayDate(compra.fecha),
                style: pw.TextStyle(font: ticketFont, fontSize: 9),
              ),
            ),
            pw.SizedBox(height: 6),
            _lineaSeparadora(ticketFont),
            pw.SizedBox(height: 4),
            pw.Text(
              'ARTICULO                     IMPORTE',
              style: pw.TextStyle(font: ticketFont, fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            ...items.expand((item) {
              final total = _totalItem(
                item.cantidad,
                item.cantidadDescuento,
                item.precioUnitarioAplicado,
                item.precioDescuento,
              );

              return [
                pw.Text(
                  _truncate(item.producto.nombre.toUpperCase(), 30),
                  style: pw.TextStyle(font: ticketFont, fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '${item.cantidad} x \$${item.precioUnitarioAplicado.toStringAsFixed(2)}',
                      style: pw.TextStyle(font: ticketFont, fontSize: 9),
                    ),
                    pw.Text(
                      '\$${total.toStringAsFixed(2)}',
                      style: pw.TextStyle(font: ticketFont, fontSize: 9),
                    ),
                  ],
                ),
                if (item.cantidadDescuento > 0 && item.precioDescuento > 0)
                  pw.Text(
                    'DESC: desde ${item.cantidadDescuento} a \$${item.precioDescuento.toStringAsFixed(2)}',
                    style: pw.TextStyle(font: ticketFont, fontSize: 8),
                  ),
                pw.SizedBox(height: 4),
              ];
            }),
            _lineaSeparadora(ticketFont),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL CALCULADO',
                  style: pw.TextStyle(font: ticketFont, fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  '\$${compra.importeTotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(font: ticketFont, fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
            if (compra.confirmado) ...{
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('DIFERENCIA', style: pw.TextStyle(font: ticketFont, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      '\$${compra.recargoAplicado.toStringAsFixed(2)}',
                      style: pw.TextStyle(font: ticketFont, fontSize: 9, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL ABONADO', style: pw.TextStyle(font: ticketFont, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      '\$${compra.montoRealPagado.toStringAsFixed(2)}',
                      style: pw.TextStyle(font: ticketFont, fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
            },
            pw.SizedBox(height: 6),
            _lineaSeparadora(ticketFont),
            pw.SizedBox(height: 5),
            pw.Center(
              child: pw.Text(
                'Gracias por su compra',
                style: pw.TextStyle(font: ticketFont, fontSize: 9),
              ),
            ),
            ],
          ),
        ),
      ),
    );

    final fileName = _buildFileName(compra.ticketId, compra.fecha);
    return TicketPdfBuild(
      fileName: fileName,
      bytes: await pdf.save(),
    );
  }

  String _buildFileName(int ticketId, String fechaRaw) {
    final safeDate = _safeFileDate(fechaRaw);
    return 'ticket_${ticketId}_$safeDate.pdf';
  }

  String _buildImageFileName(int ticketId, String fechaRaw) {
    final safeDate = _safeFileDate(fechaRaw);
    return 'ticket_${ticketId}_$safeDate.png';
  }

  String _safeFileDate(String fechaRaw) {
    try {
      final dt = DateTime.parse(fechaRaw);
      return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}_${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      final normalized = fechaRaw.replaceAll(RegExp(r'[^0-9A-Za-z]'), '_');
      return normalized.isEmpty ? 'sin_fecha' : normalized;
    }
  }

  String _formatDisplayDate(String fechaRaw) {
    try {
      final dt = DateTime.parse(fechaRaw);
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yyyy = dt.year.toString();
      final hh = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$dd/$mm/$yyyy $hh:$min';
    } catch (_) {
      return fechaRaw;
    }
  }

  pw.Widget _lineaSeparadora(pw.Font font) {
    return pw.Text(
      '--------------------------------------',
      style: pw.TextStyle(font: font, fontSize: 9),
    );
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value;
    }

    return '${value.substring(0, maxLength - 1)}.';
  }

  double _totalItem(
    int cantidad,
    int cantidadDescuento,
    double precioUnitario,
    double precioDescuento,
  ) {
    if (cantidadDescuento > 0 && precioDescuento > 0 && cantidad >= cantidadDescuento) {
      return cantidad * precioDescuento;
    }

    return cantidad * precioUnitario;
  }

  double _estimateTicketHeight(int itemsCount, bool confirmado) {
    final lineasPorItem = 3.0;
    final lineasBase = confirmado ? 23.0 : 21.0;
    final lineasEstimadas = lineasBase + (itemsCount * lineasPorItem);
    final alto = lineasEstimadas * 12;
    if (alto < 260) {
      return 260;
    }
    return alto;
  }
}
