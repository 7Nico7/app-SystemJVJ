import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:systemjvj/schedule/providers/schedule_provider.dart';

class FilterDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ScheduleProvider>(
      builder: (context, provider, _) {
        return Drawer(
          child: Column(
            children: [
              AppBar(title: Text('Filtros')),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(16),
                  children: [
                    _buildStatusFilter(context),
                    if (provider.isAdmin) ...[
                      _buildServiceTypeFilter(context),
                      _buildTechnicianFilter(context),
                    ],
                    _buildDateRangeFilter(context),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: () => _applyFilters(context),
                      child: Text('APLICAR'),
                    ),
                    TextButton(
                      onPressed: () => _clearFilters(context),
                      child: Text('QUITAR FILTROS'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusFilter(BuildContext context) {
    final provider = Provider.of<ScheduleProvider>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Estatus', style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButtonFormField<int>(
          value: provider.status,
          items: [
            DropdownMenuItem(value: 1, child: Text('PENDIENTE')),
            DropdownMenuItem(value: 2, child: Text('CANCELADO')),
            DropdownMenuItem(value: 3, child: Text('AUTORIZADO')),
            DropdownMenuItem(value: 4, child: Text('COMPLETADO')),
            DropdownMenuItem(value: null, child: Text('TODOS')),
          ],
          onChanged: (value) => provider.setStatus(value),
          decoration: InputDecoration(border: OutlineInputBorder()),
        ),
      ],
    );
  }

  Widget _buildServiceTypeFilter(BuildContext context) {
    return SizedBox.shrink();
  }

  Widget _buildTechnicianFilter(BuildContext context) {
    return SizedBox.shrink();
  }

  Widget _buildDateRangeFilter(BuildContext context) {
    final provider = Provider.of<ScheduleProvider>(context, listen: false);

    return Consumer<ScheduleProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rango de fechas',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(labelText: 'Desde'),
                    readOnly: true,
                    onTap: () => _selectDate(context, isStartDate: true),
                    controller: TextEditingController(
                      text: provider.startInDate != null
                          ? '${provider.startInDate!.day}/${provider.startInDate!.month}/${provider.startInDate!.year}'
                          : '',
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(labelText: 'Hasta'),
                    readOnly: true,
                    onTap: () => _selectDate(context, isStartDate: false),
                    controller: TextEditingController(
                      text: provider.endInDate != null
                          ? '${provider.endInDate!.day}/${provider.endInDate!.month}/${provider.endInDate!.year}'
                          : '',
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context,
      {required bool isStartDate}) async {
    final provider = Provider.of<ScheduleProvider>(context, listen: false);
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selectedDate != null) {
      if (isStartDate) {
        provider.setDateRange(selectedDate, provider.endInDate);
      } else {
        if (provider.startInDate != null &&
            selectedDate.isBefore(provider.startInDate!)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('La fecha final no puede ser anterior a la inicial')),
          );
          return;
        }
        provider.setDateRange(provider.startInDate, selectedDate);
      }
    }
  }

  void _applyFilters(BuildContext context) {
    final provider = Provider.of<ScheduleProvider>(context, listen: false);

    if (provider.startInDate != null &&
        provider.endInDate != null &&
        provider.endInDate!.isBefore(provider.startInDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('La fecha final no puede ser anterior a la inicial')),
      );
      return;
    }

    provider.fetchActivities();
    Navigator.pop(context);
  }

  void _clearFilters(BuildContext context) {
    Provider.of<ScheduleProvider>(context, listen: false).resetFilters();
    Navigator.pop(context);
  }
}
