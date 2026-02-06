// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OrderAdapter extends TypeAdapter<Order> {
  @override
  final int typeId = 3;

  @override
  Order read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Order(
      id: fields[0] as String,
      departmentId: fields[1] as String,
      productName: fields[2] as String,
      quantity: fields[3] as int,
      status: fields[4] as String,
      createdAt: fields[5] as DateTime?,
      soldTo: fields[6] as String?,
      workerId: fields[7] as String?,
      completedQuantity: fields[8] as int,
      updatedAt: fields[9] as DateTime?,
      completedAt: fields[10] as DateTime?,
      completedBy: fields[11] as String?,
      notes: fields[12] as String?,
      partsRequired: (fields[13] as Map?)?.cast<dynamic, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, Order obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.departmentId)
      ..writeByte(2)
      ..write(obj.productName)
      ..writeByte(3)
      ..write(obj.quantity)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.soldTo)
      ..writeByte(7)
      ..write(obj.workerId)
      ..writeByte(8)
      ..write(obj.completedQuantity)
      ..writeByte(9)
      ..write(obj.updatedAt)
      ..writeByte(10)
      ..write(obj.completedAt)
      ..writeByte(11)
      ..write(obj.completedBy)
      ..writeByte(12)
      ..write(obj.notes)
      ..writeByte(13)
      ..write(obj.partsRequired);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
