/// Hive Part Cache
/// 
/// MVP: Simple cache implementation for offline support
/// Stores Part entities in Hive for offline access

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/part.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';

class HivePartCache {
  static const String _boxName = 'partsCache';
  Box<Map>? _box;

  /// Initialize cache box
  Future<void> init() async {
    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box<Map>(_boxName);
      return;
    }
    _box = await Hive.openBox<Map>(_boxName);
  }

  /// Get cached parts
  Future<Either<Failure, List<Part>>> getCachedParts() async {
    try {
      if (_box == null || !Hive.isBoxOpen(_boxName)) {
        await init();
      }
      
      final box = _box ?? Hive.box<Map>(_boxName);
      final parts = <Part>[];
      
      for (var key in box.keys) {
        final data = box.get(key) as Map<String, dynamic>?;
        if (data != null) {
          try {
            parts.add(_mapToPart(data));
          } catch (e) {
            // Skip invalid entries
            continue;
          }
        }
      }
      
      return Right(parts);
    } catch (e) {
      return Left(CacheFailure('Failed to get cached parts: $e'));
    }
  }

  /// Save parts to cache
  Future<void> saveParts(List<Part> parts) async {
    try {
      if (_box == null || !Hive.isBoxOpen(_boxName)) {
        await init();
      }
      
      final box = _box ?? Hive.box<Map>(_boxName);
      await box.clear();
      
      for (var part in parts) {
        await box.put(part.id, _partToMap(part));
      }
    } catch (e) {
      // Cache errors should not break the app
      debugPrint('⚠️ Cache save error: $e');
    }
  }

  /// Update single part in cache
  Future<void> updatePart(Part part) async {
    try {
      if (_box == null || !Hive.isBoxOpen(_boxName)) {
        await init();
      }
      
      final box = _box ?? Hive.box<Map>(_boxName);
      await box.put(part.id, _partToMap(part));
    } catch (e) {
      debugPrint('⚠️ Cache update error: $e');
    }
  }

  /// Delete part from cache
  Future<void> deletePart(String partId) async {
    try {
      if (_box == null || !Hive.isBoxOpen(_boxName)) {
        await init();
      }
      
      final box = _box ?? Hive.box<Map>(_boxName);
      await box.delete(partId);
    } catch (e) {
      debugPrint('⚠️ Cache delete error: $e');
    }
  }

  /// Convert Part entity to Map for Hive storage
  Map<String, dynamic> _partToMap(Part part) {
    return {
      'id': part.id,
      'name': part.name,
      'quantity': part.quantity,
      'minQuantity': part.minQuantity,
      'imagePath': part.imagePath,
      'createdBy': part.createdBy,
      'createdAt': part.createdAt.toIso8601String(),
      'updatedAt': part.updatedAt?.toIso8601String(),
    };
  }

  /// Convert Map from Hive to Part entity
  Part _mapToPart(Map<String, dynamic> map) {
    return Part(
      id: map['id'] as String,
      name: map['name'] as String,
      quantity: map['quantity'] as int,
      minQuantity: map['minQuantity'] as int? ?? 3,
      imagePath: map['imagePath'] as String?,
      createdBy: map['createdBy'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null 
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }
}

