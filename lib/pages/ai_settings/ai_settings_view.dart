import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import '../../ai_assistant/controllers/ai_assistant_controller.dart';
import 'ai_settings_logic.dart';

class AiSettingsPage extends StatelessWidget {
  final logic = Get.put(AiSettingsLogic());
  final aiLogic = Get.find<AIAssistantController>();

  AiSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Styles.c_F8F9FA,
      appBar: TitleBar(title: 'AI 助手'),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMasterSwitch(),
            10.verticalSpace,
            Obx(() => Opacity(
                  opacity: aiLogic.aiEnabled.value ? 1.0 : 0.4,
                  child: AbsorbPointer(
                    absorbing: !aiLogic.aiEnabled.value,
                    child: Column(
                      children: [
                        _buildLlmSection(),
                        10.verticalSpace,
                        _buildNotionSection(),
                        10.verticalSpace,
                        _buildAdvancedSection(),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterSwitch() => Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Styles.c_FFFFFF,
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Row(
          children: [
            Expanded(child: '启用 AI 助手'.toText..style = Styles.ts_0C1C33_17sp_medium),
            Obx(() => Switch(
                  value: aiLogic.aiEnabled.value,
                  onChanged: (v) => aiLogic.setAIEnabled(v),
                )),
          ],
        ),
      );

  Widget _buildSectionTitle(String title) => Padding(
        padding: EdgeInsets.only(left: 16.w, bottom: 8.h),
        child: title.toText..style = Styles.ts_8E9AB0_14sp,
      );

  Widget _buildLlmSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('大模型配置'),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: Styles.c_FFFFFF,
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Column(
              children: [
                _buildDropdownField(
                  label: '供应商',
                  child: Obx(() => DropdownButton<int>(
                        value: logic.selectedVendorIndex.value,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: logic.vendorList
                            .asMap()
                            .entries
                            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.value.key)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) logic.onVendorChanged(v);
                        },
                      )),
                ),
                _buildTextField(label: 'API Key', controller: logic.apiKeyCtrl, obscure: true),
                _buildTextField(label: 'API Base URL', controller: logic.apiBaseUrlCtrl),
                _buildTextField(label: '模型名称', controller: logic.modelNameCtrl),
                _buildTextField(label: 'Max Tokens', controller: logic.maxTokensCtrl, keyboardType: TextInputType.number),
                _buildTextField(label: 'Temperature', controller: logic.temperatureCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                _buildTestButton(
                  isTesting: logic.isTestingLlm,
                  onTest: logic.testLlmConnection,
                  status: aiLogic.llmConnected,
                ),
              ],
            ),
          ),
        ],
      );

  Widget _buildNotionSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Notion 配置'),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: Styles.c_FFFFFF,
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Column(
              children: [
                _buildTextField(label: 'Integration Token', controller: logic.notionTokenCtrl, obscure: true),
                _buildTextField(label: '根页面 ID', controller: logic.notionRootPageIdCtrl),
                _buildTestButton(
                  isTesting: logic.isTestingNotion,
                  onTest: logic.testNotionConnection,
                  status: aiLogic.notionConnected,
                ),
                Obx(() => Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: '上次同步: ${aiLogic.lastSyncTime.value.isEmpty ? "未同步" : aiLogic.lastSyncTime.value}'
                          .toText..style = Styles.ts_8E9AB0_12sp,
                    )),
              ],
            ),
          ),
        ],
      );

  Widget _buildAdvancedSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('高级设置'),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: Styles.c_FFFFFF,
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Column(
              children: [
                _buildSwitchRow('话题建议', aiLogic.topicEnabled, aiLogic.setTopicEnabled),
                _buildSwitchRow('回复建议', aiLogic.replyEnabled, aiLogic.setReplyEnabled),
                _buildSwitchRow('聊天记录同步', aiLogic.notionSyncEnabled, aiLogic.setNotionSyncEnabled),
              ],
            ),
          ),
        ],
      );

  Widget _buildSwitchRow(String label, RxBool value, Function(bool) onChanged) => Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          children: [
            Expanded(child: label.toText..style = Styles.ts_0C1C33_17sp),
            Obx(() => Switch(value: value.value, onChanged: onChanged)),
          ],
        ),
      );

  Widget _buildDropdownField({required String label, required Widget child}) => Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          children: [
            SizedBox(width: 100.w, child: label.toText..style = Styles.ts_8E9AB0_14sp),
            Expanded(child: child),
          ],
        ),
      );

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool obscure = false,
    TextInputType? keyboardType,
  }) =>
      Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          children: [
            SizedBox(width: 100.w, child: label.toText..style = Styles.ts_8E9AB0_14sp),
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: obscure,
                keyboardType: keyboardType,
                style: Styles.ts_0C1C33_14sp,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4.r)),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildTestButton({
    required RxBool isTesting,
    required VoidCallback onTest,
    required RxBool status,
  }) =>
      Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          children: [
            Obx(() => ElevatedButton(
                  onPressed: isTesting.value ? null : onTest,
                  child: isTesting.value
                      ? SizedBox(width: 16.w, height: 16.h, child: const CircularProgressIndicator(strokeWidth: 2))
                      : '测试连接'.toText..style = Styles.ts_FFFFFF_14sp,
                )),
            12.horizontalSpace,
            Obx(() => Icon(
                  status.value ? Icons.check_circle : Icons.cancel,
                  color: status.value ? Colors.green : Colors.grey,
                  size: 20.w,
                )),
          ],
        ),
      );
}
