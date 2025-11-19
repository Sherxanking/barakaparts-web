// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'part_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PartModelAdapter extends TypeAdapter<PartModel> {
  @override
  final int typeId = 1;

  @override
  PartModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PartModel(
      id: fields[0] as String,
      name: fields[1] as String,
      quantity: fields[2] as int,
      status: fields[3] as String,
      imagePath: fields[4] as String?,
      minQuantity: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, PartModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.quantity)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.imagePath)
      ..writeByte(5)
      ..write(obj.minQuantity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PartModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
