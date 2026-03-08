import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mi_compra_mayorista/data/local/app_database.dart';

class DatabaseBackupProvider {
  DatabaseBackupProvider._();

  static final DatabaseBackupProvider instance = DatabaseBackupProvider._();

  Future<void> exportarBaseDeDatos(BuildContext context) async {
    try {
      final path = await AppDatabase.instance.exportDatabaseToDeviceStorage();
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Base exportada en: $path')),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo exportar la base de datos: $e')),
      );
    }
  }

  Future<void> importarBaseDeDatos(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        dialogTitle: 'Seleccionar backup de base de datos',
      );

      if (!context.mounted || result == null || result.files.isEmpty) {
        return;
      }

      final sourcePath = result.files.single.path;
      if (sourcePath == null || sourcePath.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo leer la ruta del archivo seleccionado.')),
        );
        return;
      }

      if (!_esArchivoBaseDeDatosValido(sourcePath)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleccione un archivo .db, .sqlite o .sqlite3 valido.')),
        );
        return;
      }

      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Importar base de datos'),
            content: const Text(
              'Se reemplazaran los datos actuales por los del archivo seleccionado. ¿Desea continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Importar'),
              ),
            ],
          );
        },
      );

      if (confirmar != true || !context.mounted) {
        return;
      }

      await AppDatabase.instance.importDatabaseFromPath(sourcePath);

      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Base de datos importada correctamente.')),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo importar la base de datos: $e')),
      );
    }
  }

  bool _esArchivoBaseDeDatosValido(String path) {
    final normalized = path.toLowerCase().trim();
    return normalized.endsWith('.db') ||
        normalized.endsWith('.sqlite') ||
        normalized.endsWith('.sqlite3');
  }
}