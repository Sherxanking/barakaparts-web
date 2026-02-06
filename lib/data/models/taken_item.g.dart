// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'taken_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TakenItemAdapter extends TypeAdapter<TakenItem> {
  @override
  final int typeId = 5;

  @override
  TakenItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TakenItem(
      courierId: fields[0] as String,
      quantity: fields[1] as int,
      takenAt: fields[2] as DateTime?,
      notes: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TakenItem obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.courierId)
      ..writeByte(1)
      ..write(obj.quantity)
      ..writeByte(2)
      ..write(obj.takenAt)
      ..writeByte(3)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TakenItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
