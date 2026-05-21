import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:shimmer/shimmer.dart';
import '../controllers/ai_assistant_controller.dart';
import '../models/ai_suggestion.dart';

class AiSuggestionBar extends StatelessWidget {
  final TextEditingController? inputController;

  const AiSuggestionBar({super.key, this.inputController});

  @override
  Widget build(BuildContext context) {
    final aiLogic = Get.find<AIAssistantController>();

    return Obx(() {
      final suggestions = aiLogic.suggestions;
      final isLoading = aiLogic.isLoadingSuggestions.value;
      final hasError = aiLogic.suggestionError.value.isNotEmpty;

      if (!isLoading && suggestions.isEmpty && !hasError) return const SizedBox.shrink();

      return Container(
        constraints: BoxConstraints(minHeight: 44.h),
        color: Styles.c_F0F2F6,
        padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 8.w),
        child: isLoading
            ? _buildShimmer()
            : hasError
                ? _buildErrorRow(aiLogic)
                : Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: suggestions.map((s) => _buildSuggestionChip(s, aiLogic)).toList(),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => aiLogic.clearSuggestions(),
                        child: Padding(
                          padding: EdgeInsets.only(left: 8.w),
                          child: Icon(Icons.close, size: 18.w, color: Styles.c_8E9AB0),
                        ),
                      ),
                    ],
                  ),
      );
    });
  }

  Widget _buildErrorRow(AIAssistantController aiLogic) {
    return Row(
      children: [
        Icon(Icons.error_outline, size: 16.w, color: Styles.c_8E9AB0),
        6.horizontalSpace,
        Expanded(
          child: Text(
            '建议生成失败',
            style: Styles.ts_8E9AB0_12sp,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: () => aiLogic.retryLastSuggestion(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            child: Text('重试', style: TextStyle(fontSize: 12.sp, color: Styles.c_0089FF)),
          ),
        ),
        GestureDetector(
          onTap: () => aiLogic.clearSuggestions(),
          child: Padding(
            padding: EdgeInsets.only(left: 4.w),
            child: Icon(Icons.close, size: 18.w, color: Styles.c_8E9AB0),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionChip(AiSuggestion suggestion, AIAssistantController aiLogic) {
    final icon = suggestion.type == AiSuggestionType.topic ? '💡' : '💬';
    return GestureDetector(
      onTap: () {
        if (inputController != null) {
          inputController!.text = suggestion.text;
          inputController!.selection = TextSelection.fromPosition(
            TextPosition(offset: suggestion.text.length),
          );
        }
        aiLogic.clearSuggestions();
      },
      child: Container(
        margin: EdgeInsets.only(right: 8.w),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: Styles.c_FFFFFF,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Styles.c_E8EAEF, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: TextStyle(fontSize: 14.sp)),
            4.horizontalSpace,
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 200.w),
              child: Text(
                suggestion.text,
                style: Styles.ts_0C1C33_14sp,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Styles.c_FFFFFF,
      highlightColor: Styles.c_F0F2F6,
      child: Row(
        children: List.generate(
          3,
          (_) => Container(
            margin: EdgeInsets.only(right: 8.w),
            width: 120.w,
            height: 32.h,
            decoration: BoxDecoration(
              color: Styles.c_FFFFFF,
              borderRadius: BorderRadius.circular(16.r),
            ),
          ),
        ),
      ),
    );
  }
}
