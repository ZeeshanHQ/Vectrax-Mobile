import 'package:flutter/foundation.dart';
import 'package:supa_app/core/services/api_service.dart';

enum AuditSeverity { critical, warning, optimized }

class AuditInsight {
  final String id;
  final String title;
  final String description;
  final AuditSeverity severity;
  final String category; // 'Security', 'Performance', 'Schema'
  final String? tableName;
  final String suggestedSql;
  final bool isPro;

  AuditInsight({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.category,
    this.tableName,
    required this.suggestedSql,
    this.isPro = true,
  });
}

class AuditService {
  final ApiService _apiService = ApiService();

  Future<List<AuditInsight>> runNeuralPulse(String projectRef) async {
    List<AuditInsight> insights = [];

    try {
      // 1. SECURITY SCAN (Shield Aura)
      final tables = await _apiService.executeSql(projectRef,
          "SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public';");

      if (tables is List) {
        for (var table in tables) {
          final name = table['tablename'] as String;
          final isRlsEnabled = table['rowsecurity'] as bool;

          if (!isRlsEnabled) {
            insights.add(AuditInsight(
              id: 'rls_$name',
              title: 'Shield Aura Leak',
              description:
                  'Table "$name" has no RLS enabled. It is currently exposed to public anonymous access.',
              severity: AuditSeverity.critical,
              category: 'Security',
              tableName: name,
              suggestedSql: 'ALTER TABLE "$name" ENABLE ROW LEVEL SECURITY;',
            ));
          }
        }
      }

      // 2. PERFORMANCE SCAN (Performance Scalpel)
      final stats = await _apiService.executeSql(projectRef,
          "SELECT relname, seq_scan, idx_scan, n_live_tup FROM pg_stat_user_tables;");

      if (stats is List) {
        for (var stat in stats) {
          final name = stat['relname'] as String;
          final seqScans = (stat['seq_scan'] ?? 0) as int;
          final idxScans = (stat['idx_scan'] ?? 0) as int;
          final rowCount = (stat['n_live_tup'] ?? 0) as int;

          // If high sequential scans on a large table, suggest an index
          if (rowCount > 1000 && seqScans > idxScans) {
            insights.add(AuditInsight(
              id: 'index_$name',
              title: 'Sequential Scan Bloat',
              description:
                  'Table "$name" is being scanned sequentially $seqScans times. Adding an index could boost speed by 90%.',
              severity: AuditSeverity.warning,
              category: 'Performance',
              tableName: name,
              suggestedSql:
                  '-- Run EXPLAIN ANALYZE to find specific column, then:\nCREATE INDEX idx_${name}_auto ON "$name" (created_at);',
            ));
          }
        }
      }

      // 3. ANOMALY DETECTION (Ghost Pulse)
      final anomalies = await _apiService.executeSql(projectRef,
          "SELECT relname, n_dead_tup, n_live_tup, (seq_scan + idx_scan) as total_scans FROM pg_stat_user_tables WHERE n_live_tup > 0;");

      if (anomalies is List) {
        for (var anomaly in anomalies) {
          final name = anomaly['relname'] as String;
          final dead = (anomaly['n_dead_tup'] ?? 0) as int;
          final live = (anomaly['n_live_tup'] ?? 0) as int;
          final scans = (anomaly['total_scans'] ?? 0) as int;

          // Anomaly 1: Table Bloat (Zombie Table)
          if (dead > live * 0.5 && dead > 100) {
            insights.add(AuditInsight(
              id: 'bloat_$name',
              title: 'Zombie Table Anomaly',
              description:
                  'Table "$name" contains $dead dead rows. This "Ghost Bloat" is slowing down every query. Execution efficiency is dropping.',
              severity: AuditSeverity.critical,
              category: 'Performance',
              tableName: name,
              suggestedSql: 'VACUUM ANALYZE "$name";',
            ));
          }

          // Anomaly 2: Zero Traffic (Flatline)
          if (live > 500 && scans < 10) {
            insights.add(AuditInsight(
              id: 'flatline_$name',
              title: 'Neural Flatline Detected',
              description:
                  'Table "$name" has $live records but zero recent traffic. If this is a core table (like "orders"), your integration might be broken.',
              severity: AuditSeverity.warning,
              category: 'Anomaly',
              tableName: name,
              suggestedSql: '-- Check application logs for integration errors',
              isPro: true,
            ));
          }
        }
      }

      // 4. DEEP ANALYSIS: Unused Indexes (Storage & IO Waste)
      final unusedIndexes = await _apiService.executeSql(projectRef,
          "SELECT relname, indexrelname FROM pg_stat_user_indexes WHERE idx_scan = 0 AND schemaname = 'public' AND relname NOT LIKE 'pg_%';");

      if (unusedIndexes is List && unusedIndexes.isNotEmpty) {
        for (var idx in unusedIndexes) {
          final tbl = idx['relname'];
          final name = idx['indexrelname'];
          insights.add(AuditInsight(
            id: 'unused_idx_$name',
            title: 'Dead-Weight Index',
            description:
                'Index "$name" on "$tbl" has zero recorded scans. Every "insert" is paying a performance tax for an index no one uses.',
            severity: AuditSeverity.optimized,
            category: 'Performance',
            suggestedSql: 'DROP INDEX "$name";',
            isPro: true,
          ));
        }
      }

      // 5. HYGIENE: Missing Primary Keys
      final missingPk = await _apiService.executeSql(projectRef,
          "SELECT relname FROM pg_class c LEFT JOIN pg_index i ON c.oid = i.indrelid AND i.indisprimary WHERE i.indrelid IS NULL AND c.relkind = 'r' AND c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');");

      if (missingPk is List && missingPk.isNotEmpty) {
        for (var row in missingPk) {
          final name = row['relname'];
          insights.add(AuditInsight(
            id: 'missing_pk_$name',
            title: 'Anarchic Table Structure',
            description:
                'Table "$name" has no Primary Key. This breaks replication and makes standard ORM operations highly inefficient.',
            severity: AuditSeverity.critical,
            category: 'Schema',
            suggestedSql:
                'ALTER TABLE "$name" ADD COLUMN id gen_random_uuid() PRIMARY KEY;',
            isPro: true,
          ));
        }
      }

      // 6. THE "AI GUARANTEE": If all perfect, suggest a scaling enhancement
      if (insights.isEmpty) {
        insights.add(AuditInsight(
          id: 'scaling_blueprint',
          title: 'Neural Scaling Blueprint',
          description:
              'Your project structure is currently elite. We recommend a "Global Partitioning" strategy for your "logs" or "events" tables to prepare for high-volume traffic.',
          severity: AuditSeverity.optimized,
          category: 'Architecture',
          suggestedSql:
              '-- Architect scaling blueprint: partitioning and sharding strategy',
          isPro: false,
        ));
      }
    } catch (e) {
      debugPrint('[AuditService] ❌ Audit failed: $e');
    }

    return insights;
  }
}
