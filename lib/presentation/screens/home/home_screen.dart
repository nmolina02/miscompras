import 'package:flutter/material.dart';
import 'package:mi_compra_mayorista/presentation/screens/actions/actions_screen.dart';
import 'package:mi_compra_mayorista/presentation/screens/database_edit/product_edit.dart';
import 'package:mi_compra_mayorista/presentation/screens/home/home_options_list_screen.dart';
import 'package:mi_compra_mayorista/presentation/screens/home/hamburger_menu_screen.dart';
import 'package:mi_compra_mayorista/presentation/providers/option_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const HamburgerDrawer(),
      body: _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  final OptionProvider optionProvider = OptionProvider();

  @override
  Widget build(BuildContext context) {
    final productEdit = InfoProductEditScreen();

    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              // Header con menú
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  children: [
                    Builder(
                      builder: (context) => IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () {
                          Scaffold.of(context).openDrawer();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'MiCompraMayorista',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Lista de opciones en grid
              Expanded(
                child: ButtonsOptionList(
                  optionProvider: optionProvider,
                  onOptionSelected: (option) {
                    _navigateToOption(context, option);
                  },
                ),
              ),
            ],
          ),
          // Botón flotante del database edit
          productEdit.productEditButton(context),
        ],
      ),
    );
  }

  void _navigateToOption(BuildContext context, String option) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActionsScreen(actionName: option),
      ),
    );
  }
}