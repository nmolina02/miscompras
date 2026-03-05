import 'package:mi_compra_mayorista/data/local/compra_repository.dart';
import 'package:mi_compra_mayorista/presentation/screens/home/hamburger_accions/ticket_pdf_exporter.dart';
import 'package:flutter/material.dart';

class TicketExporterProvider {
  TicketExporterProvider._();

  static final TicketExporterProvider instance = TicketExporterProvider._();

  static const String _accionCompartir = 'compartir';
  static const String _accionGuardar = 'guardar';
  static const String _accionGaleria = 'galeria';

  Future<void> exportarTicket(BuildContext context) async {
      try {
        final compras = await CompraRepository.instance.listarCompras();
        if (!context.mounted) {
          return;
        }

        final messenger = ScaffoldMessenger.of(context);
        if (compras.isEmpty) {
          messenger.showSnackBar(
            const SnackBar(content: Text('No hay tickets para exportar.')),
          );
          return;
        }

        final compraSeleccionada = await showModalBottomSheet<Compra>(
          context: context,
          showDragHandle: true,
          builder: (modalContext) {
            return SafeArea(
              child: ListView.builder(
                itemCount: compras.length,
                itemBuilder: (context, index) {
                  final compra = compras[index];
                  return ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: Text('Ticket #${compra.ticketId}'),
                    subtitle: Text('${compra.comercio} · ${_formatearFecha(compra.fecha)}'),
                    onTap: () => Navigator.of(modalContext).pop(compra),
                  );
                },
              ),
            );
          },
        );

        if (compraSeleccionada == null) {
          return;
        }

        if (!context.mounted) {
          return;
        }

        final accion = await _seleccionarAccionExportacion(context);
        if (accion == null) {
          return;
        }

        final resultado = accion == _accionGuardar
          ? await TicketPdfExporter.instance.guardarCompraEnSistema(compraSeleccionada)
          : accion == _accionGaleria
            ? await TicketPdfExporter.instance.guardarCompraComoImagenEnGaleria(compraSeleccionada)
            : await TicketPdfExporter.instance.compartirCompra(compraSeleccionada);

        if (!context.mounted) {
          return;
        }
        final updatedMessenger = ScaffoldMessenger.of(context);
        updatedMessenger.showSnackBar(
          SnackBar(
            content: Text(
              accion == _accionGuardar
                  ? 'Ticket guardado en: $resultado'
                  : accion == _accionGaleria
                    ? 'Ticket guardado en galeria: $resultado'
                  : 'Ticket listo para compartir: $resultado',
            ),
          ),
        );
      } catch (error) {
        if (!context.mounted) {
          return;
        }
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(content: Text('No se pudo exportar el ticket: $error')),
        );
      }
    }

  Future<String?> _seleccionarAccionExportacion(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (modalContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Compartir'),
                onTap: () => Navigator.of(modalContext).pop(_accionCompartir),
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Guardar en descargas'),
                onTap: () => Navigator.of(modalContext).pop(_accionGuardar),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Guardar como imagen'),
                onTap: () => Navigator.of(modalContext).pop(_accionGaleria),
              ),
            ],
          ),
        );
      },
    );
  }

    String _formatearFecha(String fecha) {
      try {
        final dateTime = DateTime.parse(fecha);
        final dd = dateTime.day.toString().padLeft(2, '0');
        final mm = dateTime.month.toString().padLeft(2, '0');
        final yyyy = dateTime.year.toString();
        final hh = dateTime.hour.toString().padLeft(2, '0');
        final min = dateTime.minute.toString().padLeft(2, '0');
        return '$dd/$mm/$yyyy $hh:$min';
      } catch (_) {
        return fecha;
      }
    }
}