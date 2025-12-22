/// DepartmentDetailsPage - Bo'lim tafsilotlari sahifasi
/// 
/// Bu sahifa quyidagi funksiyalarni ta'minlaydi:
/// - Bo'limga tegishli mahsulotlarni ko'rish
/// - Real-time yangilanishlar
/// 
/// NOTE: Product'lar allaqachon department'ga biriktirilgan (departmentId orqali)
/// Shuning uchun assign funksiyasi keraksiz
import 'package:flutter/material.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/part_repository.dart';
import '../../domain/entities/product.dart' as domain_product;
import '../../domain/entities/part.dart' as domain_part;
import '../../core/di/service_locator.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../core/services/error_handler_service.dart';
import '../../data/models/department_model.dart';
import '../widgets/empty_state_widget.dart';
import '../../l10n/app_localizations.dart';

class DepartmentDetailsPage extends StatefulWidget {
  final Department department;
  const DepartmentDetailsPage({super.key, required this.department});

  @override
  State<DepartmentDetailsPage> createState() => _DepartmentDetailsPageState();
}

class _DepartmentDetailsPageState extends State<DepartmentDetailsPage> {
  // Repositories
  final ProductRepository _productRepository = ServiceLocator.instance.productRepository;
  final PartRepository _partRepository = ServiceLocator.instance.partRepository;

  /// SnackBar ko'rsatish
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final department = widget.department;

    return Scaffold(
      appBar: AppBar(
        title: Text('${department.name} ${AppLocalizations.of(context)?.translate('details') ?? 'Details'}'),
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Department info card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      department.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<Either<Failure, List<domain_product.Product>>>(
                      stream: _productRepository.watchProducts(),
                      builder: (context, snapshot) {
                        final products = snapshot.data?.fold(
                          (failure) => <domain_product.Product>[],
                          (products) => products.where((p) => p.departmentId == department.id).toList(),
                        ) ?? <domain_product.Product>[];
                        
                        return Text(
                          '${AppLocalizations.of(context)?.translate('products') ?? 'Products'}: ${products.length}',
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Products list
            Text(
              '${AppLocalizations.of(context)?.translate('assignedProducts') ?? 'Assigned Products'}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // Products list - Real-time updates using StreamBuilder
            Expanded(
              child: StreamBuilder<Either<Failure, List<domain_product.Product>>>(
                stream: _productRepository.watchProducts(),
                builder: (context, snapshot) {
                  // Handle loading state
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  // Handle error state
                  final products = snapshot.data!.fold(
                    (failure) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          final message = ErrorHandlerService.instance.getErrorMessage(failure);
                          ErrorHandlerService.instance.showErrorSnackBar(context, message);
                        }
                      });
                      return <domain_product.Product>[];
                    },
                    (products) => products.where((p) => p.departmentId == department.id).toList(),
                  );

                  if (products.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.inventory_outlined,
                      title: AppLocalizations.of(context)?.translate('noProductsAssigned') ?? 'No products assigned yet',
                      subtitle: AppLocalizations.of(context)?.translate('productsWillAppearHere') ?? 'Products assigned to this department will appear here',
                    );
                  }

                  return ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.inventory),
                          ),
                          title: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: product.partsRequired.isEmpty
                              ? Text(AppLocalizations.of(context)?.translate('noPartsRequired') ?? 'No parts required')
                              : FutureBuilder<Either<Failure, List<domain_part.Part>>>(
                                  future: _partRepository.getAllParts(),
                                  builder: (context, partsSnapshot) {
                                    if (!partsSnapshot.hasData) {
                                      return Text('${AppLocalizations.of(context)?.translate('parts') ?? 'Parts'}: ${product.partsRequired.length}');
                                    }
                                    
                                    final parts = partsSnapshot.data!.fold(
                                      (_) => <domain_part.Part>[],
                                      (parts) => parts,
                                    );
                                    
                                    final partsText = product.partsRequired.entries
                                        .map((e) {
                                          final part = parts.firstWhere(
                                            (p) => p.id == e.key,
                                            orElse: () => domain_part.Part(
                                              id: e.key,
                                              name: e.key,
                                              quantity: 0,
                                              minQuantity: 3,
                                              createdAt: DateTime.now(),
                                            ),
                                          );
                                          return '${part.name}: ${e.value}';
                                        })
                                        .join(', ');
                                    
                                    return Text(
                                      partsText,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  },
                                ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
