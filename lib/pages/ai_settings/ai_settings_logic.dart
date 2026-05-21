import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import '../../ai_assistant/controllers/ai_assistant_controller.dart';
import '../../ai_assistant/models/llm_config.dart';
import '../../ai_assistant/models/notion_config.dart';

class AiSettingsLogic extends GetxController {
  final aiLogic = Get.find<AIAssistantController>();

  final vendorList = LlmVendorPreset.all;
  final selectedVendorIndex = 0.obs;

  final apiKeyCtrl = TextEditingController();
  final apiBaseUrlCtrl = TextEditingController();
  final modelNameCtrl = TextEditingController();
  final maxTokensCtrl = TextEditingController(text: '2048');
  final temperatureCtrl = TextEditingController(text: '0.7');

  final notionTokenCtrl = TextEditingController();
  final notionRootPageIdCtrl = TextEditingController();

  final isTestingLlm = false.obs;
  final isTestingNotion = false.obs;
  final obscureApiKey = true.obs;
  final obscureNotionToken = true.obs;

  @override
  void onInit() {
    super.onInit();
    _loadCurrentConfig();
  }

  void _loadCurrentConfig() {
    final config = aiLogic.llmConfig.value;
    final vendorIndex = vendorList.indexWhere((e) => e.config.vendor == config.vendor);
    selectedVendorIndex.value = vendorIndex >= 0 ? vendorIndex : 0;

    apiKeyCtrl.text = config.apiKey;
    apiBaseUrlCtrl.text = config.apiBaseUrl;
    modelNameCtrl.text = config.modelName;
    maxTokensCtrl.text = config.maxTokens.toString();
    temperatureCtrl.text = config.temperature.toString();

    final nConfig = aiLogic.notionConfig.value;
    notionTokenCtrl.text = nConfig.integrationToken;
    notionRootPageIdCtrl.text = nConfig.rootPageId;
  }

  void onVendorChanged(int index) {
    selectedVendorIndex.value = index;
    final preset = vendorList[index].config;
    apiBaseUrlCtrl.text = preset.apiBaseUrl;
    modelNameCtrl.text = preset.modelName;
  }

  Future<void> saveLlmConfig() async {
    final config = LlmConfig(
      vendor: vendorList[selectedVendorIndex.value].config.vendor,
      apiKey: apiKeyCtrl.text.trim(),
      apiBaseUrl: apiBaseUrlCtrl.text.trim(),
      modelName: modelNameCtrl.text.trim(),
      maxTokens: int.tryParse(maxTokensCtrl.text.trim()) ?? 2048,
      temperature: double.tryParse(temperatureCtrl.text.trim()) ?? 0.7,
    );
    await aiLogic.saveLlmConfig(config);
  }

  Future<void> saveNotionConfig() async {
    final config = NotionConfig(
      integrationToken: notionTokenCtrl.text.trim(),
      rootPageId: notionRootPageIdCtrl.text.trim(),
    );
    await aiLogic.saveNotionConfig(config);
  }

  Future<void> testLlmConnection() async {
    isTestingLlm.value = true;
    await saveLlmConfig();
    final success = await aiLogic.testLlmConnection();
    isTestingLlm.value = false;
    IMViews.showToast(success ? 'LLM 连接成功' : 'LLM 连接失败，请检查配置');
  }

  Future<void> testNotionConnection() async {
    isTestingNotion.value = true;
    await saveNotionConfig();
    final success = await aiLogic.testNotionConnection();
    isTestingNotion.value = false;
    IMViews.showToast(success ? 'Notion 连接成功' : 'Notion 连接失败，请检查配置');
  }

  @override
  void onClose() {
    apiKeyCtrl.dispose();
    apiBaseUrlCtrl.dispose();
    modelNameCtrl.dispose();
    maxTokensCtrl.dispose();
    temperatureCtrl.dispose();
    notionTokenCtrl.dispose();
    notionRootPageIdCtrl.dispose();
    super.onClose();
  }
}
