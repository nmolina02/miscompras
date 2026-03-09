import 'package:flutter/material.dart';
import 'package:miscompras/presentation/providers/option_provider.dart';

// Boton de opciones en grid
class ButtonsOptionList extends StatelessWidget {
  const ButtonsOptionList({
    super.key,
    required this.optionProvider,
    required this.onOptionSelected,
  });

  final OptionProvider optionProvider;
  final Function(String option) onOptionSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: optionProvider.optionList.length,
      itemBuilder: (context, index) {
        final option = optionProvider.optionList[index];
        final color = optionProvider.getColorForOption(option);
        final icon = optionProvider.getIconForOption(option);

        return GestureDetector(
          onTap: () {
            onOptionSelected(option);
          },
          child: Stack(
            children: [
              // Círculo principal
              Padding(
                padding: const EdgeInsets.only(bottom: 50.0),
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color,
                        width: 4,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.transparent,
                      child: Icon(
                        icon,
                        size: 60,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
              // Texto del label debajo del círculo
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(
                      maxWidth: 150,
                    ),
                    child: Text(
                      option,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}