import 'package:miscompras/config/theme/app_theme.dart';
import 'package:miscompras/presentation/providers/database_backup_provider.dart';
import 'package:miscompras/presentation/providers/ticket_exporter_provider.dart';
import 'package:miscompras/presentation/providers/theme_settings_provider.dart';
import 'package:flutter/material.dart';

// Menú Hamburguesa Lateral
class HamburgerDrawer extends StatelessWidget {
  const HamburgerDrawer({super.key});

  Future<void> _showThemeSelector(BuildContext context) async {
    final themeSettings = ThemeSettingsProvider.instance;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (modalContext) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: appColorThemes.length,
            itemBuilder: (context, index) {
              final themeOption = appColorThemes[index];
              final selected = themeSettings.selectedColorIndex == index;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: themeOption.color,
                  radius: 10,
                ),
                title: Text(themeOption.name),
                trailing: selected ? const Icon(Icons.check) : null,
                onTap: () {
                  themeSettings.setSelectedColorIndex(index);
                  Navigator.of(modalContext).pop();
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showThemeModeSelector(BuildContext context) async {
    final themeSettings = ThemeSettingsProvider.instance;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (modalContext) {
        return SafeArea(
          child: RadioGroup<ThemeMode>(
            groupValue: themeSettings.themeMode,
            onChanged: (value) {
              themeSettings.setThemeMode(value);
              Navigator.of(modalContext).pop();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  title: Text('Usar modo del sistema'),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  title: Text('Modo claro'),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  title: Text('Modo oscuro'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rootContext = Navigator.of(context, rootNavigator: true).context;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              height: 60,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Menú',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            _SettingsOptions(
              title: 'Temas',
              icon: Icons.format_color_fill_rounded,
              onTap: () => _showThemeSelector(rootContext),
            ).toListTile(context),
            _SettingsOptions(
              title: 'Modo Oscuro/Claro',
              icon: Icons.contrast_rounded,
              onTap: () => _showThemeModeSelector(rootContext),
            ).toListTile(context),
            _SettingsOptions(
              title: 'Exportar Ticket',
              icon: Icons.file_open_rounded,
              onTap: () => TicketExporterProvider.instance.exportarTicket(rootContext),
            ).toListTile(context),
            _SettingsOptions(
              title: 'Exportar Base de Datos',
              icon: Icons.file_download_outlined,
              onTap: () => DatabaseBackupProvider.instance.exportarBaseDeDatos(rootContext),
            ).toListTile(context),
            _SettingsOptions(
              title: 'Importar Base de Datos',
              icon: Icons.file_upload_outlined,
              onTap: () => DatabaseBackupProvider.instance.importarBaseDeDatos(rootContext),
            ).toListTile(context),
          ],
        ),
      ),
    );
  }
}

class _SettingsOptions {
  // Aquí puedes agregar opciones de configuración si es necesario
  final String title;
  final IconData icon;
  final VoidCallback? onTap;

  _SettingsOptions({
    required this.title,
    required this.icon,
    this.onTap,
  });

  ListTile toListTile(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pop(context); // Cierra el drawer
        onTap?.call();
      },
    );
  }
}
