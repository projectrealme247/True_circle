import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart' show AppButtonStyles;
import '../../utils/viewing_invitation.dart';
import 'landlord_dashboard_theme.dart';

/// Date, time, and meeting location for a viewing invitation / reschedule.
class InviteViewingSheet extends StatefulWidget {
  const InviteViewingSheet({
    super.key,
    this.initial,
    this.updateMode = false,
  });

  final ViewingInvitation? initial;
  final bool updateMode;

  static Future<ViewingInvitation?> show(
    BuildContext context, {
    ViewingInvitation? initial,
    bool updateMode = false,
  }) {
    return showModalBottomSheet<ViewingInvitation>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => InviteViewingSheet(
        initial: initial,
        updateMode: updateMode,
      ),
    );
  }

  @override
  State<InviteViewingSheet> createState() => _InviteViewingSheetState();
}

class _InviteViewingSheetState extends State<InviteViewingSheet> {
  DateTime? _date;
  TimeOfDay? _time;
  late final TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _locationController = TextEditingController(text: initial?.location ?? '');
    if (initial != null) {
      _date = ViewingInvitation.tryParseDateLabel(initial.dateLabel);
      final parts = ViewingInvitation.tryParseTimeParts(initial.timeLabel);
      if (parts != null) {
        _time = TimeOfDay(hour: parts.$1, minute: parts.$2);
      }
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  bool get _ready {
    return _date != null &&
        _time != null &&
        _locationController.text.trim().isNotEmpty;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? first.add(const Duration(days: 1)),
      firstDate: first,
      lastDate: first.add(const Duration(days: 180)),
    );
    if (picked == null) return;
    setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 18, minute: 0),
    );
    if (picked == null) return;
    setState(() => _time = picked);
  }

  void _submit() {
    if (!_ready) return;
    Navigator.of(context).pop(
      ViewingInvitation(
        dateLabel: ViewingInvitation.formatDate(_date!),
        timeLabel: ViewingInvitation.formatTimeOfDay(_time!.hour, _time!.minute),
        location: _locationController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.updateMode ? 'Reschedule Viewing' : 'Invite Viewing',
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: LandlordDashboardTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _PickerField(
            label: 'Date',
            value: _date == null ? '' : ViewingInvitation.formatDate(_date!),
            placeholder: '12 Sep 2026',
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          _PickerField(
            label: 'Time',
            value: _time == null
                ? ''
                : ViewingInvitation.formatTimeOfDay(_time!.hour, _time!.minute),
            placeholder: '18:00',
            onTap: _pickTime,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Meeting Location',
              hintText: 'Main entrance, Cookstown Road',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _ready ? _submit : null,
              style: AppButtonStyles.primaryFilled,
              child: Text(
                widget.updateMode
                    ? 'Update Viewing'
                    : 'Send Viewing Invitation',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final String label;
  final String value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(
          value.isEmpty ? placeholder : value,
          style: TextStyle(
            fontSize: 16,
            color: value.isEmpty
                ? LandlordDashboardTheme.textMuted
                : LandlordDashboardTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
