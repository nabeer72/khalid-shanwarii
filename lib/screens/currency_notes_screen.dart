import 'package:flutter/material.dart';
import 'package:mobile_app/providers/theme_provider.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';

class CurrencyNotesScreen extends StatefulWidget {
  const CurrencyNotesScreen({super.key});

  @override
  State<CurrencyNotesScreen> createState() => _CurrencyNotesScreenState();
}

class _CurrencyNotesScreenState extends State<CurrencyNotesScreen> {
  final theme = ThemeProvider.instance;
  final db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    final notes = await db.getCurrencyNotes();
    setState(() {
      _notes = notes;
      _isLoading = false;
    });
  }

  void _showAddEditNoteDialog([Map<String, dynamic>? note]) {
    final valueCtrl = TextEditingController(text: note?['value']?.toString() ?? '');
    final labelCtrl = TextEditingController(text: note?['label'] ?? '');
    bool isActive = note?['status'] == 1 || note == null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Text(note == null ? 'Add Currency Note' : 'Edit Currency Note', 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: valueCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: theme.glassInputDecoration('Value (e.g. 500)', Icons.money_rounded),
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: labelCtrl,
                decoration: theme.glassInputDecoration('Label (e.g. Five Hundred)', Icons.label_rounded),
                style: const TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Is Active', style: TextStyle(fontWeight: FontWeight.w600)),
                value: isActive,
                activeColor: theme.switchActiveColor,
                onChanged: (val) => setDialogState(() => isActive = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.highlight,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final val = double.tryParse(valueCtrl.text);
                if (val == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid value'), backgroundColor: Colors.red));
                  return;
                }

                final noteData = {
                  'business_id': BusinessConfig.instance.businessId,
                  'value': val,
                  'label': labelCtrl.text.isEmpty ? val.toString() : labelCtrl.text,
                  'status': isActive ? 1 : 0,
                };

                if (note == null) {
                  await db.insertCurrencyNote(noteData);
                } else {
                  await db.updateCurrencyNote(note['id'], noteData);
                }

                Navigator.pop(ctx);
                _loadNotes();
              },
              child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteNote(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note?'),
        content: const Text('Are you sure you want to delete this currency note?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await db.deleteCurrencyNote(id);
      _loadNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Currency Notes', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900)),
        leading: BackButton(color: theme.textPrimary),
      ),
      body: theme.glassBackground(
        child: SafeArea(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.money_off_rounded, size: 64, color: theme.textSecondary.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text('No currency notes defined', style: TextStyle(color: theme.textSecondary, fontSize: 16)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showAddEditNoteDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Note'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notes.length,
                  itemBuilder: (ctx, i) {
                    final note = _notes[i];
                    final isActive = note['status'] == 1;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        decoration: theme.glassDecoration,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.whiteAlpha(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.payments_rounded, color: theme.highlight),
                          ),
                          title: Text('${BusinessConfig.instance.currency} ${note['value']}', 
                            style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                          subtitle: Text(note['label'] ?? '', style: TextStyle(color: theme.textSecondary)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('INACTIVE', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 20),
                                onPressed: () => _showAddEditNoteDialog(note),
                                color: theme.textSecondary,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                onPressed: () => _deleteNote(note['id']),
                                color: Colors.redAccent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditNoteDialog(),
        backgroundColor: theme.highlight,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}
