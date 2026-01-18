/// Part History Page
/// 
/// WHY: Shows who added/updated parts and when
/// Displays: User name, action type, quantity changes, timestamp

import 'package:flutter/material.dart';
import '../../domain/entities/part_history.dart';
import '../../infrastructure/datasources/supabase_part_history_datasource.dart';
import '../../infrastructure/datasources/supabase_part_datasource.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class PartHistoryPage extends StatefulWidget {
  final String partId;
  final String partName;

  const PartHistoryPage({
    super.key,
    required this.partId,
    required this.partName,
  });

  @override
  State<PartHistoryPage> createState() => _PartHistoryPageState();
}

class _PartHistoryPageState extends State<PartHistoryPage> {
  final SupabasePartHistoryDatasource _historyDatasource = SupabasePartHistoryDatasource();
  bool _isLoading = true;
  List<PartHistory> _history = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _historyDatasource.getPartHistory(widget.partId);

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isLoading = false;
          _errorMessage = failure.message;
        });
      },
      (history) {
        setState(() {
          _isLoading = false;
          _history = history;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Part History'),
            Text(
              widget.partName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[700]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadHistory,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No history available',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final entry = _history[index];
                          return _buildHistoryCard(entry);
                        },
                      ),
                    ),
    );
  }

  Widget _buildHistoryCard(PartHistory entry) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final isAddition = entry.isAddition;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isAddition ? Colors.green : Colors.blue,
          child: Icon(
            isAddition ? Icons.add : Icons.edit,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          entry.userName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(entry.getDescription()),
            if (entry.notes != null) ...[
              const SizedBox(height: 4),
              Text(
                entry.notes!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              dateFormat.format(entry.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isAddition ? Colors.green[50] : Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isAddition ? '+${entry.quantityChange}' : '${entry.quantityChange}',
            style: TextStyle(
              color: isAddition ? Colors.green[700] : Colors.blue[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

















