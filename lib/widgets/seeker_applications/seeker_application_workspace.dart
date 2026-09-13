import 'package:flutter/material.dart';

import '../../theme/home_marketplace_theme.dart';
import '../../utils/seeker_application_pipeline.dart';
import 'seeker_application_pane.dart';
import 'seeker_application_queue.dart';
import 'seeker_application_queue_item.dart';
import 'seeker_pipeline_column.dart';

enum _SeekerNarrowPane { pipeline, queue, workspace }

/// Pipeline → Applications → Workspace (seeker 3-column shell).
class SeekerApplicationWorkspace extends StatefulWidget {
  const SeekerApplicationWorkspace({
    super.key,
    required this.items,
  });

  final List<SeekerApplicationQueueItem> items;

  @override
  State<SeekerApplicationWorkspace> createState() =>
      _SeekerApplicationWorkspaceState();
}

class _SeekerApplicationWorkspaceState extends State<SeekerApplicationWorkspace> {
  static const maxWidth = 1360.0;
  static const narrowBreakpoint = 980.0;

  late SeekerPipelineBuckets _buckets;
  late SeekerPipelineSection _selectedSection;
  String? _selectedApplicationId;
  _SeekerNarrowPane _narrowPane = _SeekerNarrowPane.pipeline;
  bool _rejectedExpanded = false;

  @override
  void initState() {
    super.initState();
    _syncFromItems();
  }

  @override
  void didUpdateWidget(covariant SeekerApplicationWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _syncFromItems(preserveSelection: true);
    }
  }

  void _syncFromItems({bool preserveSelection = false}) {
    _buckets = SeekerApplicationPipeline.bucket(
      [for (final item in widget.items) item.application],
    );
    final previousSection = preserveSelection ? _selectedSection : null;
    final previousId = preserveSelection ? _selectedApplicationId : null;

    _selectedSection = previousSection ?? _buckets.defaultSection();
    if (_selectedSection == SeekerPipelineSection.rejected) {
      _rejectedExpanded = true;
    }

    final filtered = _filteredItems();
    if (previousId != null &&
        filtered.any((item) => item.applicationId == previousId)) {
      _selectedApplicationId = previousId;
    } else if (filtered.isNotEmpty) {
      _selectedApplicationId = filtered.first.applicationId;
    } else {
      _selectedApplicationId = null;
    }
  }

  List<SeekerApplicationQueueItem> _filteredItems() {
    if (_selectedSection == SeekerPipelineSection.rejected &&
        !_rejectedExpanded) {
      return const [];
    }
    final ids = {
      for (final app in _buckets.forSection(_selectedSection)) app.id,
    };
    return [
      for (final item in widget.items)
        if (ids.contains(item.applicationId)) item,
    ];
  }

  SeekerApplicationQueueItem? get _selectedItem {
    final id = _selectedApplicationId;
    if (id == null) return null;
    for (final item in widget.items) {
      if (item.applicationId == id) return item;
    }
    return null;
  }

  void _selectSection(SeekerPipelineSection section) {
    setState(() {
      _selectedSection = section;
      if (section == SeekerPipelineSection.rejected) {
        _rejectedExpanded = true;
      }
      final filtered = _filteredItems();
      _selectedApplicationId =
          filtered.isNotEmpty ? filtered.first.applicationId : null;
      if (MediaQuery.sizeOf(context).width < narrowBreakpoint) {
        _narrowPane = _SeekerNarrowPane.queue;
      }
    });
  }

  void _setRejectedExpanded(bool expanded) {
    setState(() {
      _rejectedExpanded = expanded;
      if (expanded) {
        _selectedSection = SeekerPipelineSection.rejected;
      } else if (_selectedSection == SeekerPipelineSection.rejected) {
        _selectedSection = _defaultNonRejectedSection();
      }
      final filtered = _filteredItems();
      _selectedApplicationId =
          filtered.isNotEmpty ? filtered.first.applicationId : null;
    });
  }

  SeekerPipelineSection _defaultNonRejectedSection() {
    if (_buckets.countFor(SeekerPipelineSection.inProgress) > 0) {
      return SeekerPipelineSection.inProgress;
    }
    if (_buckets.countFor(SeekerPipelineSection.waitingForHost) > 0) {
      return SeekerPipelineSection.waitingForHost;
    }
    return SeekerPipelineSection.inProgress;
  }

  void _selectItem(SeekerApplicationQueueItem item) {
    setState(() {
      _selectedApplicationId = item.applicationId;
      if (MediaQuery.sizeOf(context).width < narrowBreakpoint) {
        _narrowPane = _SeekerNarrowPane.workspace;
      }
    });
  }

  void _narrowBack() {
    setState(() {
      switch (_narrowPane) {
        case _SeekerNarrowPane.workspace:
          _narrowPane = _SeekerNarrowPane.queue;
        case _SeekerNarrowPane.queue:
          _narrowPane = _SeekerNarrowPane.pipeline;
        case _SeekerNarrowPane.pipeline:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: HomeMarketplaceTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: HomeMarketplaceTheme.border),
              boxShadow: HomeMarketplaceTheme.cardShadowRest,
            ),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < narrowBreakpoint;
                if (narrow) {
                  return _buildNarrow(context);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SeekerPipelineColumn(
                      buckets: _buckets,
                      selected: _selectedSection,
                      onSelected: _selectSection,
                      rejectedExpanded: _rejectedExpanded,
                      onRejectedExpandedChanged: _setRejectedExpanded,
                    ),
                    SeekerApplicationQueue(
                      items: _filteredItems(),
                      selectedId: _selectedApplicationId,
                      onSelect: _selectItem,
                      sectionLabel: _selectedSection.label,
                    ),
                    Expanded(
                      child: SeekerApplicationPane(item: _selectedItem),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNarrow(BuildContext context) {
    final showBack = _narrowPane != _SeekerNarrowPane.pipeline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showBack)
          Material(
            color: HomeMarketplaceTheme.surface,
            child: InkWell(
              onTap: _narrowBack,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back, size: 18),
                    const SizedBox(width: 8),
                    Text(switch (_narrowPane) {
                      _SeekerNarrowPane.workspace => 'Applications',
                      _SeekerNarrowPane.queue => 'Applications',
                      _SeekerNarrowPane.pipeline => 'Back',
                    }),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: switch (_narrowPane) {
            _SeekerNarrowPane.pipeline => SeekerPipelineColumn(
                buckets: _buckets,
                selected: _selectedSection,
                onSelected: _selectSection,
                rejectedExpanded: _rejectedExpanded,
                onRejectedExpandedChanged: _setRejectedExpanded,
              ),
            _SeekerNarrowPane.queue => SeekerApplicationQueue(
                items: _filteredItems(),
                selectedId: _selectedApplicationId,
                onSelect: _selectItem,
                sectionLabel: _selectedSection.label,
              ),
            _SeekerNarrowPane.workspace =>
              SeekerApplicationPane(item: _selectedItem),
          },
        ),
      ],
    );
  }
}
