import 'package:flutter/material.dart';

class LugarCompraField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> lugaresFiltrados;
  final List<String> historialLugares;
  final ValueChanged<String> onChanged;
  final VoidCallback onTap;
  final ValueChanged<String> onSelectLugar;

  const LugarCompraField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.lugaresFiltrados,
    required this.historialLugares,
    required this.onChanged,
    required this.onTap,
    required this.onSelectLugar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: 'Comercio',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              suffixIcon: const Icon(Icons.location_on),
              isDense: true,
            ),
            onChanged: onChanged,
            onTap: onTap,
          ),
          if (focusNode.hasFocus && lugaresFiltrados.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(5),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: lugaresFiltrados.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    dense: true,
                    title: Text(lugaresFiltrados[index]),
                    onTap: () => onSelectLugar(lugaresFiltrados[index]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
