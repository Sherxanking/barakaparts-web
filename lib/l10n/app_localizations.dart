/// AppLocalizations - Multi-language support service
/// 
/// This class provides localized strings for the app.
/// Supports: Uzbek, Russian, English
/// 
/// Usage:
/// ```dart
/// AppLocalizations.of(context)!.translate('orders')
/// ```
import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  
  AppLocalizations(this.locale);
  
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }
  
  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();
  
  // Language names
  static const Map<String, String> supportedLanguages = {
    'uz': 'O\'zbek',
    'ru': 'Русский',
    'en': 'English',
  };
  
  // Translations map
  static const Map<String, Map<String, String>> _localizedValues = {
    'uz': {
      'orders': 'Buyurtmalar',
      'departments': 'Bo\'limlar',
      'products': 'Mahsulotlar',
      'parts': 'Qismlar',
      'settings': 'Sozlamalar',
      'add': 'Qo\'shish',
      'edit': 'Tahrirlash',
      'delete': 'O\'chirish',
      'save': 'Saqlash',
      'cancel': 'Bekor qilish',
      'search': 'Qidirish',
      'filter': 'Filter',
      'sort': 'Tartiblash',
      'all': 'Barchasi',
      'name': 'Nomi',
      'quantity': 'Miqdori',
      'minQuantity': 'Minimal miqdor',
      'status': 'Holat',
      'available': 'Mavjud',
      'unavailable': 'Mavjud emas',
      'lowStock': 'Kam qolgan',
      'lowStockAlert': 'Kam qolgan ogohlantirish',
      'viewAll': 'Barchasini ko\'rish',
      'order': 'Buyurtma',
      'createOrder': 'Buyurtma yaratish',
      'orderDetails': 'Buyurtma tafsilotlari',
      'orderStatus': 'Buyurtma holati',
      'pending': 'Kutilmoqda',
      'completed': 'Tugallangan',
      'cancelled': 'Bekor qilingan',
      'orderDate': 'Buyurtma sanasi',
      'totalProducts': 'Jami mahsulotlar',
      'product': 'Mahsulot',
      'productName': 'Mahsulot nomi',
      'addProduct': 'Mahsulot qo\'shish',
      'editProduct': 'Mahsulotni tahrirlash',
      'deleteProduct': 'Mahsulotni o\'chirish',
      'selectParts': 'Qismlarni tanlash',
      'partsCount': 'Qismlar soni',
      'selectDepartment': 'Bo\'limni tanlash',
      'department': 'Bo\'lim',
      'noProducts': 'Mahsulotlar yo\'q',
      'noProductsMatch': 'Mos mahsulotlar topilmadi',
      'addFirstProduct': '+ tugmasini bosing',
      'part': 'Qism',
      'partName': 'Qism nomi',
      'addPart': 'Qism qo\'shish',
      'editPart': 'Qismni tahrirlash',
      'deletePart': 'Qismni o\'chirish',
      'noParts': 'Qismlar yo\'q',
      'noPartsMatch': 'Mos qismlar topilmadi',
      'noPartsAvailable': 'Qismlar mavjud emas. Avval qism qo\'shing',
      'addFirstPart': '+ tugmasini bosing',
      'alertThreshold': 'Ogohlantirish chegarasi',
      'image': 'Rasm',
      'addImage': 'Rasm qo\'shish',
      'changeImage': 'Rasmni o\'zgartirish',
      'deleteImage': 'Rasmni o\'chirish',
      'selectImageSource': 'Rasm manbasini tanlash',
      'camera': 'Kamera',
      'gallery': 'Galereya',
      'departmentName': 'Bo\'lim nomi',
      'addDepartment': 'Bo\'lim qo\'shish',
      'editDepartment': 'Bo\'limni tahrirlash',
      'deleteDepartment': 'Bo\'limni o\'chirish',
      'noDepartments': 'Bo\'limlar yo\'q',
      'productsInDepartment': 'Bo\'limdagi mahsulotlar',
      'language': 'Til',
      'selectLanguage': 'Tilni tanlash',
      'appSettings': 'Ilova sozlamalari',
      'confirmDelete': 'O\'chirishni tasdiqlaysizmi?',
      'productAdded': 'Mahsulot qo\'shildi',
      'productUpdated': 'Mahsulot yangilandi',
      'productUpdateFailed': 'Mahsulot yangilanmadi',
      'productDeleted': 'Mahsulot o\'chirildi',
      'partAdded': 'Qism qo\'shildi',
      'partUpdated': 'Qism yangilandi',
      'partDeleted': 'Qism o\'chirildi',
      'orderCreated': 'Buyurtma yaratildi',
      'orderCompleted': 'Buyurtma tugallandi',
      'orderDeleted': 'Buyurtma o\'chirildi',
      'enterProductName': 'Mahsulot nomini kiriting',
      'pleaseSelectDepartment': 'Bo\'limni tanlang',
      'selectAtLeastOnePart': 'Kamida bitta qism tanlang',
      'enterPartName': 'Qism nomini kiriting',
      'invalidQuantity': 'Noto\'g\'ri miqdor',
      'imageUpdated': 'Rasm yangilandi',
      'imageDeleted': 'Rasm o\'chirildi',
    },
    'ru': {
      'orders': 'Заказы',
      'departments': 'Отделы',
      'products': 'Продукты',
      'parts': 'Детали',
      'settings': 'Настройки',
      'add': 'Добавить',
      'edit': 'Редактировать',
      'delete': 'Удалить',
      'save': 'Сохранить',
      'cancel': 'Отмена',
      'search': 'Поиск',
      'filter': 'Фильтр',
      'sort': 'Сортировка',
      'all': 'Все',
      'name': 'Название',
      'quantity': 'Количество',
      'minQuantity': 'Минимальное количество',
      'status': 'Статус',
      'available': 'Доступно',
      'unavailable': 'Недоступно',
      'lowStock': 'Низкий запас',
      'lowStockAlert': 'Предупреждение о низком запасе',
      'viewAll': 'Посмотреть все',
      'order': 'Заказ',
      'createOrder': 'Создать заказ',
      'orderDetails': 'Детали заказа',
      'orderStatus': 'Статус заказа',
      'pending': 'В ожидании',
      'completed': 'Завершено',
      'cancelled': 'Отменено',
      'orderDate': 'Дата заказа',
      'totalProducts': 'Всего продуктов',
      'product': 'Продукт',
      'productName': 'Название продукта',
      'addProduct': 'Добавить продукт',
      'editProduct': 'Редактировать продукт',
      'deleteProduct': 'Удалить продукт',
      'selectParts': 'Выбрать детали',
      'partsCount': 'Количество деталей',
      'selectDepartment': 'Выбрать отдел',
      'department': 'Отдел',
      'noProducts': 'Нет продуктов',
      'noProductsMatch': 'Продукты не найдены',
      'addFirstProduct': 'Нажмите кнопку +',
      'part': 'Деталь',
      'partName': 'Название детали',
      'addPart': 'Добавить деталь',
      'editPart': 'Редактировать деталь',
      'deletePart': 'Удалить деталь',
      'noParts': 'Нет деталей',
      'noPartsMatch': 'Детали не найдены',
      'noPartsAvailable': 'Детали недоступны. Сначала добавьте детали',
      'addFirstPart': 'Нажмите кнопку +',
      'alertThreshold': 'Порог предупреждения',
      'image': 'Изображение',
      'addImage': 'Добавить изображение',
      'changeImage': 'Изменить изображение',
      'deleteImage': 'Удалить изображение',
      'selectImageSource': 'Выбрать источник изображения',
      'camera': 'Камера',
      'gallery': 'Галерея',
      'departmentName': 'Название отдела',
      'addDepartment': 'Добавить отдел',
      'editDepartment': 'Редактировать отдел',
      'deleteDepartment': 'Удалить отдел',
      'noDepartments': 'Нет отделов',
      'productsInDepartment': 'Продукты в отделе',
      'language': 'Язык',
      'selectLanguage': 'Выбрать язык',
      'appSettings': 'Настройки приложения',
      'confirmDelete': 'Вы уверены, что хотите удалить?',
      'productAdded': 'Продукт добавлен',
      'productUpdated': 'Продукт обновлен',
      'productUpdateFailed': 'Не удалось обновить продукт',
      'productDeleted': 'Продукт удален',
      'partAdded': 'Деталь добавлена',
      'partUpdated': 'Деталь обновлена',
      'partDeleted': 'Деталь удалена',
      'orderCreated': 'Заказ создан',
      'orderCompleted': 'Заказ завершен',
      'orderDeleted': 'Заказ удален',
      'enterProductName': 'Введите название продукта',
      'pleaseSelectDepartment': 'Выберите отдел',
      'selectAtLeastOnePart': 'Выберите хотя бы одну деталь',
      'enterPartName': 'Введите название детали',
      'invalidQuantity': 'Неверное количество',
      'imageUpdated': 'Изображение обновлено',
      'imageDeleted': 'Изображение удалено',
    },
    'en': {
      'orders': 'Orders',
      'departments': 'Departments',
      'products': 'Products',
      'parts': 'Parts',
      'settings': 'Settings',
      'add': 'Add',
      'edit': 'Edit',
      'delete': 'Delete',
      'save': 'Save',
      'cancel': 'Cancel',
      'search': 'Search',
      'filter': 'Filter',
      'sort': 'Sort',
      'all': 'All',
      'name': 'Name',
      'quantity': 'Quantity',
      'minQuantity': 'Min Quantity',
      'status': 'Status',
      'available': 'Available',
      'unavailable': 'Unavailable',
      'lowStock': 'Low Stock',
      'lowStockAlert': 'Low Stock Alert',
      'viewAll': 'View All',
      'order': 'Order',
      'createOrder': 'Create Order',
      'orderDetails': 'Order Details',
      'orderStatus': 'Order Status',
      'pending': 'Pending',
      'completed': 'Completed',
      'cancelled': 'Cancelled',
      'orderDate': 'Order Date',
      'totalProducts': 'Total Products',
      'product': 'Product',
      'productName': 'Product Name',
      'addProduct': 'Add Product',
      'editProduct': 'Edit Product',
      'deleteProduct': 'Delete Product',
      'selectParts': 'Select Parts',
      'partsCount': 'Parts Count',
      'selectDepartment': 'Select Department',
      'department': 'Department',
      'noProducts': 'No products yet',
      'noProductsMatch': 'No products match your filters',
      'addFirstProduct': 'Tap the + button to add a product',
      'part': 'Part',
      'partName': 'Part Name',
      'addPart': 'Add Part',
      'editPart': 'Edit Part',
      'deletePart': 'Delete Part',
      'noParts': 'No parts yet',
      'noPartsMatch': 'No parts match your filters',
      'noPartsAvailable': 'No parts available. Please add parts first',
      'addFirstPart': 'Tap the + button to add a part',
      'alertThreshold': 'Alert Threshold',
      'image': 'Image',
      'addImage': 'Add Image',
      'changeImage': 'Change Image',
      'deleteImage': 'Delete Image',
      'selectImageSource': 'Select Image Source',
      'camera': 'Camera',
      'gallery': 'Gallery',
      'departmentName': 'Department Name',
      'addDepartment': 'Add Department',
      'editDepartment': 'Edit Department',
      'deleteDepartment': 'Delete Department',
      'noDepartments': 'No departments yet',
      'productsInDepartment': 'Products in Department',
      'language': 'Language',
      'selectLanguage': 'Select Language',
      'appSettings': 'App Settings',
      'confirmDelete': 'Are you sure you want to delete?',
      'productAdded': 'Product added successfully',
      'productUpdated': 'Product updated successfully',
      'productUpdateFailed': 'Failed to update product',
      'productDeleted': 'Product deleted',
      'partAdded': 'Part added successfully',
      'partUpdated': 'Part updated successfully',
      'partDeleted': 'Part deleted',
      'orderCreated': 'Order created successfully',
      'orderCompleted': 'Order completed',
      'orderDeleted': 'Order deleted',
      'enterProductName': 'Please enter a product name',
      'pleaseSelectDepartment': 'Please select a department',
      'selectAtLeastOnePart': 'Please select at least one part',
      'enterPartName': 'Please enter a part name',
      'invalidQuantity': 'Invalid quantity',
      'imageUpdated': 'Image updated',
      'imageDeleted': 'Image deleted',
    },
  };
  
  /// Get translated string by key
  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? 
           _localizedValues['en']?[key] ?? 
           key;
  }
  
  // Convenience getters for common translations
  String get orders => translate('orders');
  String get departments => translate('departments');
  String get products => translate('products');
  String get parts => translate('parts');
  String get settings => translate('settings');
  String get add => translate('add');
  String get edit => translate('edit');
  String get delete => translate('delete');
  String get save => translate('save');
  String get cancel => translate('cancel');
  String get search => translate('search');
}

/// Localizations delegate for AppLocalizations
class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();
  
  @override
  bool isSupported(Locale locale) {
    return ['uz', 'ru', 'en'].contains(locale.languageCode);
  }
  
  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }
  
  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
