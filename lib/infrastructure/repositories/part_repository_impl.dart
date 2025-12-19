/// Part Repository Implementation
/// 
/// Combines Supabase (source of truth) with Hive cache (offline support).

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/part.dart';
import '../../domain/repositories/part_repository.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../datasources/supabase_part_datasource.dart';
import '../cache/hive_part_cache.dart';
import '../../data/models/part_model.dart';

class PartRepositoryImpl implements PartRepository {
  final SupabasePartDatasource _supabaseDatasource;
  final HivePartCache _cache;
  
  PartRepositoryImpl({
    required SupabasePartDatasource supabaseDatasource,
    required HivePartCache cache,
  })  : _supabaseDatasource = supabaseDatasource,
        _cache = cache;

  @override
  Future<Either<Failure, List<Part>>> getAllParts() async {
    try {
      // Try Supabase first
      final result = await _supabaseDatasource.getAllParts();
      return result.fold(
        (failure) async {
          // If Supabase fails, try cache
          final cachedResult = await _cache.getCachedParts();
          return cachedResult.fold(
            (_) => Left(failure), // Return original failure if cache also fails
            (cachedParts) => Right(cachedParts),
          );
        },
        (parts) async {
          // Update cache with fresh data
          await _cache.saveParts(parts);
          return Right(parts);
        },
      );
    } catch (e) {
      // Fallback to cache
      final cachedResult = await _cache.getCachedParts();
      return cachedResult.fold(
        (_) => Left(UnknownFailure('Unexpected error: $e')),
        (parts) => Right(parts),
      );
    }
  }

  @override
  Future<Either<Failure, Part?>> getPartById(String partId) async {
    try {
      final result = await _supabaseDatasource.getPartById(partId);
      return result.fold(
        (failure) async {
          // Try cache
          final cachedResult = await _cache.getCachedParts();
          return cachedResult.fold(
            (_) => Left(failure),
            (parts) => Right(parts.where((p) => p.id == partId).firstOrNull),
          );
        },
        (part) async {
          if (part != null) {
            await _cache.updatePart(part);
          }
          return Right(part);
        },
      );
    } catch (e) {
      return Left(UnknownFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Part>>> searchParts(String query) async {
    try {
      return await _supabaseDatasource.searchParts(query);
    } catch (e) {
      // Fallback: search in cache
      final cachedResult = await _cache.getCachedParts();
      return cachedResult.fold(
        (failure) => Left(failure),
        (parts) {
          final filtered = parts
              .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
              .toList();
          return Right(filtered);
        },
      );
    }
  }

  @override
  Future<Either<Failure, Part>> createPart(Part part) async {
    final result = await _supabaseDatasource.createPart(part);
    return result.fold(
      (failure) => Left(failure),
      (createdPart) async {
        // Update cache
        await _cache.updatePart(createdPart);
        return Right(createdPart);
      },
    );
  }

  @override
  Future<Either<Failure, Part>> updatePart(Part part) async {
    final result = await _supabaseDatasource.updatePart(part);
    return result.fold(
      (failure) => Left(failure),
      (updatedPart) async {
        // Update cache
        await _cache.updatePart(updatedPart);
        return Right(updatedPart);
      },
    );
  }

  @override
  Future<Either<Failure, void>> deletePart(String partId) async {
    final result = await _supabaseDatasource.deletePart(partId);
    return result.fold(
      (failure) => Left(failure),
      (_) async {
        // Remove from cache
        await _cache.deletePart(partId);
        return Right(null);
      },
    );
  }

  @override
  Stream<Either<Failure, List<Part>>> watchParts() {
    // WHY: Fixed stream error handling - properly wraps errors in Either
    return _supabaseDatasource.watchParts().map((parts) {
      // Update cache when data changes (async but don't await - fire and forget)
      _cache.saveParts(parts).then((_) {
        // Cache updated successfully
      }).catchError((e) {
        // Log cache error but don't fail the stream
        debugPrint('⚠️ Cache update error: $e');
      });
      
      // FIX: Also update partsBox for UI sync
      _updatePartsBox(parts).catchError((e) {
        debugPrint('⚠️ PartsBox update error: $e');
      });
      
      return Right<Failure, List<Part>>(parts);
    }).handleError((error, stackTrace) {
      // Return error as Left
      return Left<Failure, List<Part>>(ServerFailure('Stream error: $error'));
    });
  }
  
  /// Update partsBox with domain parts
  /// FIX: ValueListenableBuilder yangilanishi uchun to'g'ri yozish
  Future<void> _updatePartsBox(List<Part> parts) async {
    try {
      if (!Hive.isBoxOpen('partsBox')) {
        await Hive.openBox<PartModel>('partsBox');
      }
      final box = Hive.box<PartModel>('partsBox');
      
      // FIX: Clear va add o'rniga, mavjud elementlarni yangilash yoki qo'shish
      // Bu ValueListenableBuilder'ni yangilaydi
      final existingParts = <String, int>{}; // partId -> index
      for (int i = 0; i < box.length; i++) {
        final part = box.getAt(i);
        if (part != null) {
          existingParts[part.id] = i;
        }
      }
      
      final newPartIds = parts.map((p) => p.id).toSet();
      
      // Eski elementlarni o'chirish (mavjud bo'lmaganlar) - teskari tartibda
      final keysToDelete = <int>[];
      for (var entry in existingParts.entries) {
        if (!newPartIds.contains(entry.key)) {
          keysToDelete.add(entry.value);
        }
      }
      // Teskari tartibda o'chirish (index o'zgarmasligi uchun)
      keysToDelete.sort((a, b) => b.compareTo(a));
      for (var index in keysToDelete) {
        await box.deleteAt(index);
      }
      
      // Yangi elementlarni qo'shish yoki yangilash
      for (var part in parts) {
        final partModel = PartModel(
          id: part.id,
          name: part.name,
          quantity: part.quantity,
          minQuantity: part.minQuantity ?? 3,
          imagePath: part.imagePath,
          status: part.quantity < (part.minQuantity ?? 3) ? 'lowstock' : 'available',
        );
        
        // Mavjud bo'lsa, yangilash; yo'q bo'lsa, qo'shish
        if (existingParts.containsKey(part.id)) {
          await box.putAt(existingParts[part.id]!, partModel);
        } else {
          await box.add(partModel);
        }
      }
      
      debugPrint('✅ PartsBox updated: ${box.length} parts');
    } catch (e) {
      debugPrint('⚠️ Error updating partsBox: $e');
    }
  }

  @override
  Future<Either<Failure, List<Part>>> getLowStockParts() async {
    return await _supabaseDatasource.getLowStockParts();
  }
}

