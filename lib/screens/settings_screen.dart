import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../theme/app_theme.dart';

/// Settings screen for player preferences.
class SettingsScreen extends StatefulWidget {
  final String playerName;
  final GameVariant defaultVariant;
  final bool soundEnabled;
  final Function(String name, GameVariant variant, bool sound)? onSave;

  const SettingsScreen({
    super.key,
    required this.playerName,
    required this.defaultVariant,
    required this.soundEnabled,
    this.onSave,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController;
  late GameVariant _variant;
  late bool _soundEnabled;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.playerName);
    _variant = widget.defaultVariant;
    _soundEnabled = widget.soundEnabled;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.feltGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: AppTheme.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Settings',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Player Name
                    _buildSection(
                      'Player Name',
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Enter your name',
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Default Game Mode
                    _buildSection(
                      'Default Game Mode',
                      Column(
                        children: [
                          _buildRadioTile(
                            'Classic Durak',
                            'Standard rules — defend or pick up',
                            GameVariant.classic,
                          ),
                          _buildRadioTile(
                            'Transfer Durak (Perevodnoy)',
                            'Pass attacks to the next player',
                            GameVariant.transfer,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sound
                    _buildSection(
                      'Sound',
                      SwitchListTile(
                        title: const Text(
                          'Card Sounds',
                          style: TextStyle(color: AppTheme.textPrimary),
                        ),
                        subtitle: const Text(
                          'Play sound effects for card actions',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        value: _soundEnabled,
                        activeThumbColor: AppTheme.gold,
                        onChanged: (v) => setState(() => _soundEnabled = v),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Save
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onSave?.call(
                            _nameController.text.trim(),
                            _variant,
                            _soundEnabled,
                          );
                          Navigator.pop(context);
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(opacity: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textGold,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildRadioTile(String title, String subtitle, GameVariant value) {
    return RadioListTile<GameVariant>(
      title: Text(
        title,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
      value: value,
      groupValue: _variant,
      activeColor: AppTheme.gold,
      onChanged: (v) => setState(() => _variant = v!),
    );
  }
}
