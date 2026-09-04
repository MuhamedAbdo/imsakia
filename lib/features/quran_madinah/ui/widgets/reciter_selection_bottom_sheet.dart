import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:imsakia/providers/quran_audio_provider.dart';

class ReciterSelectionBottomSheet extends StatelessWidget {
  const ReciterSelectionBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<QuranAudioProvider>(
      builder: (context, audioProvider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'اختر القارئ',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: QuranAudioProvider.reciters.length,
                  itemBuilder: (context, index) {
                    final reciter = QuranAudioProvider.reciters[index];
                    final isSelected = audioProvider.currentReciterFolder == reciter['folder'];
                    
                    return ListTile(
                      title: Text(
                        reciter['name'] ?? '',
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected 
                            ? Theme.of(context).colorScheme.primary 
                            : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      trailing: isSelected 
                        ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) 
                        : null,
                      onTap: () {
                        audioProvider.changeReciter(reciter['folder']!);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
