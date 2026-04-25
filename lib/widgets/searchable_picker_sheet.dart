import 'package:flutter/cupertino.dart';

import '../utils/theme.dart';

/// 可搜尋的選擇 sheet：使用者只能從 `catalog` 中挑，不能自己生出新項。
/// 已選中的項目會顯示為 disabled。返回所選的字串；按取消回 null。
Future<String?> showSearchablePickerSheet({
  required BuildContext context,
  required String title,
  required List<String> catalog,
  Set<String> excluded = const {},
}) async {
  return showCupertinoModalPopup<String>(
    context: context,
    builder: (ctx) => _SearchablePickerSheet(
      title: title,
      catalog: catalog,
      excluded: excluded,
    ),
  );
}

class _SearchablePickerSheet extends StatefulWidget {
  const _SearchablePickerSheet({
    required this.title,
    required this.catalog,
    required this.excluded,
  });

  final String title;
  final List<String> catalog;
  final Set<String> excluded;

  @override
  State<_SearchablePickerSheet> createState() => _SearchablePickerSheetState();
}

class _SearchablePickerSheetState extends State<_SearchablePickerSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final filtered = widget.catalog
        .where((s) => q.isEmpty || s.toLowerCase().contains(q))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD4D4D8),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      '取消',
                      style: TextStyle(
                        color: AppColors.brandStart,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoSearchTextField(
                controller: _query,
                placeholder: '搜尋…',
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        '沒有對應的選項',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => Container(
                        margin: const EdgeInsets.only(left: 56),
                        height: 0.5,
                        color: AppColors.border,
                      ),
                      itemBuilder: (ctx, i) {
                        final s = filtered[i];
                        final disabled = widget.excluded.contains(s);
                        return CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: disabled
                              ? null
                              : () => Navigator.pop(context, s),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: disabled
                                        ? AppColors.surfaceMuted
                                        : AppColors.bgAlt,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    disabled
                                        ? CupertinoIcons.checkmark_circle_fill
                                        : CupertinoIcons.heart,
                                    size: 14,
                                    color: disabled
                                        ? AppColors.textTertiary
                                        : AppColors.brandStart,
                                  ),
                                ),
                                AppGaps.w12,
                                Expanded(
                                  child: Text(
                                    s,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: disabled
                                          ? AppColors.textTertiary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (disabled)
                                  const Text(
                                    '已新增',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
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
