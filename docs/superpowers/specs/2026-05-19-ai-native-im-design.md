# AI Native IM 客户端改造设计

## 概述

对 fork 自 openim-flutter-demo 的 IM 客户端进行 AI Native 改造，核心能力：

1. **AI 辅助社交** — 基于本地记忆信息，大模型提供话题建议和回复建议
2. **Notion 同步** — 聊天记录自动写入 Notion，Notion 中的长时记忆读取后增强 AI 建议

用户自行配置大模型和 Notion，自行决定 AI 功能是否生效。

## 架构方案：独立 AI Controller 型

在 app.dart 的 InitBinding 中注册全局 `AIAssistantController`，作为 AI 引擎单例。ChatLogic 通过 GetX find 依赖它。LLMService 和 NotionService 由 AIAssistantController 持有和编排。

### 模块结构

```
lib/
  ai_assistant/
    controllers/
      ai_assistant_controller.dart   # 全局 AI 控制器，GetX 单例
    services/
      llm_service.dart               # 大模型调用封装
      notion_service.dart            # Notion API 封装
    models/
      llm_config.dart                # LLM 配置模型
      notion_config.dart             # Notion 配置模型
      memory_context.dart            # 记忆上下文模型
      ai_suggestion.dart             # AI 建议结果模型
    widgets/
      ai_suggestion_bar.dart         # 输入框上方悬浮建议卡片组件
  pages/
    ai_settings/
      ai_settings_binding.dart
      ai_settings_logic.dart
      ai_settings_view.dart
```

### 依赖关系

- `AIAssistantController` 在 `InitBinding` 中注册，全局生命周期
- `ChatLogic` 通过 `Get.find<AIAssistantController>()` 依赖 AI 控制器
- `LLMService` 和 `NotionService` 由 `AIAssistantController` 持有和编排
- 非敏感配置持久化复用 `DataSp`（SharedPreferences）
- 敏感配置（API Key、Notion Token）使用 `flutter_secure_storage` 加密存储

### 数据流

```
聊天消息 → AIAssistantController 构建记忆上下文 → LLMService 调用大模型 → 返回建议 → UI 展示
聊天消息 → AIAssistantController → NotionService → 写入 Notion Page
Notion 手动笔记 → AIAssistantController 启动时读取 → 合入本地记忆上下文
```

## AI 辅助社交 — 建议生成与展示

### 触发机制（半自动）

1. **话题建议** — 进入聊天页面时自动触发。`ChatLogic.onInit()` 中延迟 1.5 秒调用 `AIAssistantController.generateTopicSuggestions(conversationID)`，基于最近 N 条消息 + 联系人画像 + Notion 长时记忆生成 3-5 个话题建议
2. **回复建议** — 收到新消息时自动触发。`ChatLogic` 的 `onRecvNewMessage` 回调中，2 秒防抖后调用 `AIAssistantController.generateReplySuggestions(conversationID, newMessage)`，生成 3 个回复建议

### 记忆上下文构建

每次调用 LLM 前，`AIAssistantController` 按以下优先级组装 prompt 上下文：

1. **近期聊天记录** — 当前会话最近 20 条消息（文本类型优先，过滤通知类消息）
2. **联系人画像** — 好友备注、群名、群成员角色等元数据（通过 OpenIM SDK 现有接口获取）
3. **Notion 长时记忆** — 启动时从 Notion 读取该联系人/群组对应 Page 的内容，缓存在本地；每次生成建议时作为上下文注入

### 建议卡片 UI（AiSuggestionBar）

- 位置：`ChatInputBox` 上方，`ChatListView` 下方
- 形态：水平可滑动的卡片列表，每张卡片显示一条建议文本
- 交互：点击卡片 → 文本填入输入框 → 卡片栏收起；右侧有关闭按钮可整体收起
- 状态：加载中显示 shimmer 占位；无建议时不显示；出错时显示重试按钮
- 区分：话题建议卡片带 💡 前缀图标，回复建议卡片带 💬 前缀图标

### 防抖与节流

- 话题建议：进入聊天页面后 1.5 秒延迟触发（等待消息列表加载完成）
- 回复建议：收到新消息后 2 秒防抖，避免连续消息导致重复调用
- 同一会话同一时刻只允许一个 LLM 请求在飞行中

## Notion 同步 — 聊天记录写入与长时记忆读取

### Notion 配置

用户在 AI 设置页配置：

- **Notion Integration Token** — 通过 Notion Integration 生成的 Internal Integration Token
- **Root Page ID** — 用户在 Notion 中创建的根页面，AI 助手在此页面下创建子页面

### 聊天记录写入（IM → Notion）

- **同步时机**：采用批量延迟写入。`AIAssistantController` 维护一个待同步队列，每 30 秒或队列累积 20 条消息时触发一次写入
- **组织方式**：每个联系人/群组对应 Notion 根页面下的一个子 Page，Page 标题为联系人昵称或群名（含 userID/groupID 后缀去重）
- **Page 内容格式**：聊天记录按日期分组，每天一个二级标题，每条消息格式为 `[HH:mm] 昵称: 内容`，仅同步文本类型消息
- **去重**：每条消息以 `clientMsgID` 作为唯一标识，写入时在 Page 的属性中记录最后同步的 `clientMsgID`，下次从该 ID 之后继续追加
- **首次同步**：新配置 Notion 后，仅同步最近 7 天的聊天记录，不回溯全部历史

### 长时记忆读取（Notion → 本地）

- **读取时机**：`AIAssistantController` 初始化时，以及每次进入聊天页面时（如果该联系人的 Page 有更新）
- **读取内容**：获取该联系人 Page 的全部文本内容，作为 `memoryContext` 缓存在本地内存中
- **缓存策略**：本地维护一个 `Map<String, String>`（key 为 conversationID），每次读取后缓存，同一会话内不重复读取；应用重启时清空缓存重新读取
- **用途**：读取到的内容注入 LLM prompt 的长时记忆部分，用户在 Notion 中手动添加的笔记、备忘等自然被包含在内

### 错误处理

- Notion API 调用失败时静默重试 3 次，间隔 5s/15s/30s
- 所有 Notion 操作不影响主流程，失败仅记录日志，不弹错误提示
- Token 失效时在 AI 设置页显示警告状态

## LLM 服务 — 多供应商配置与调用

### 配置模型（LlmConfig）

```
LlmConfig {
  vendor: String          // 预设供应商标识
  apiKey: String          // API Key（加密存储）
  apiBaseUrl: String      // API Base URL（预设供应商自动填充，custom 需手动输入）
  modelName: String       // 模型名称（预设供应商提供默认值，可覆盖）
  maxTokens: int          // 单次请求最大 token，默认 2048
  temperature: double     // 温度参数，默认 0.7
}
```

### 预设供应商列表

| vendor | apiBaseUrl 默认值 | modelName 默认值 |
|--------|-------------------|-------------------|
| openai | https://api.openai.com/v1 | gpt-4o-mini |
| azure | 用户填写 endpoint | 用户填写 deployment |
| qwen | https://dashscope.aliyuncs.com/compatible-mode/v1 | qwen-plus |
| zhipu | https://open.bigmodel.cn/api/paas/v4 | glm-4-flash |
| deepseek | https://api.deepseek.com/v1 | deepseek-chat |
| custom | 用户填写 | 用户填写 |

### 调用方式

- 统一使用 OpenAI Chat Completions 兼容格式（`/chat/completions`），所有预设供应商均兼容此格式
- `LLMService` 内部用 `dio`（项目已有依赖）发送 HTTP 请求
- 请求头：`Authorization: Bearer {apiKey}`，Azure 额外添加 `api-key` 头
- 流式响应暂不启用，使用普通同步请求

### Prompt 模板

`LLMService` 内置两套 prompt 模板：

1. **话题建议模板**：System prompt 定义角色为"社交助手"，注入记忆上下文 + 近期消息，要求输出 JSON 数组 `["话题1", "话题2", ...]`
2. **回复建议模板**：System prompt 定义角色为"社交助手"，注入记忆上下文 + 近期消息 + 最新收到的消息，要求输出 JSON 数组 `["回复1", "回复2", ...]`

### 错误处理

- API Key 无效 / 余额不足：在 AI 设置页显示连接状态（红/绿指示灯），点击可查看错误详情
- 请求超时：15 秒超时，超时后静默失败，不弹提示
- 响应解析失败：尝试从原始文本中提取建议，提取失败则返回空列表

## AI 设置页 — 用户自主可控

### AI 功能总开关

- AI 设置页顶部有一个"启用 AI 助手"总开关，默认关闭
- 总开关关闭时，不生成任何建议，不同步 Notion，`AIAssistantController` 不执行任何 LLM/Notion 调用
- 总开关开启的前提：至少配置了 LLM（Notion 可选）

### 配置的独立性

- **LLM 配置**：独立生效。配置完成后即可使用话题建议和回复建议功能，记忆上下文仅基于聊天记录 + 联系人画像
- **Notion 配置**：独立生效。配置 Notion 后，聊天记录自动同步到 Notion。若同时配置了 LLM，Notion 中的长时记忆会注入 LLM 上下文增强建议质量；若未配置 LLM，Notion 同步仍可独立工作，只是长时记忆无法用于 AI 建议
- **两者关系**：LLM 和 Notion 各自独立。用户可以只配 LLM、只配 Notion、或两者都配。两者都配时效果最佳（长时记忆增强 AI 建议）

### AI 设置页结构

```
[启用 AI 助手]  ← 总开关

── 大模型配置 ──
  供应商: [下拉选择: OpenAI / Azure / 通义千问 / 智谱 / DeepSeek / 自定义]
  API Key: [输入框]
  API Base URL: [自动填充 / 手动输入]
  模型名称: [自动填充 / 手动输入]
  [测试连接]  ← 点击后调用一次简单请求验证配置是否正确
  连接状态: 🟢 已连接 / 🔴 连接失败 / ⚪ 未配置

── Notion 配置 ──
  Integration Token: [输入框]
  根页面 ID: [输入框]
  [测试连接]  ← 点击后查询根页面是否可访问
  连接状态: 🟢 已连接 / 🔴 连接失败 / ⚪ 未配置
  同步状态: 上次同步 2026-05-19 14:30 / 未同步

── 高级设置 ──
  话题建议: [开关] ← 独立控制是否自动生成话题建议
  回复建议: [开关] ← 独立控制是否自动生成回复建议
  聊天记录同步: [开关] ← 独立控制是否同步聊天记录到 Notion
```

### 配置持久化

- 非敏感配置（供应商选择、开关状态、模型名称等）通过 `DataSp` 存储到 SharedPreferences
- 敏感配置（API Key、Notion Token）使用 `flutter_secure_storage` 加密存储
- 配置变更后立即生效，无需重启应用

### 功能降级逻辑

| LLM 已配置 | Notion 已配置 | 可用功能 |
|:---:|:---:|:---|
| ✅ | ✅ | 话题建议 + 回复建议 + Notion 同步 + 长时记忆增强 |
| ✅ | ❌ | 话题建议 + 回复建议（仅基于聊天记录 + 联系人画像） |
| ❌ | ✅ | Notion 同步（仅写入，不读取增强） |
| ❌ | ❌ | AI 功能不可用 |

## 与现有代码的集成点

### 1. InitBinding 注册（lib/app.dart）

在现有 `InitBinding.dependencies()` 中新增：
```dart
Get.put<AIAssistantController>(AIAssistantController());
```

### 2. ChatLogic 集成（lib/pages/chat/chat_logic.dart）

- `onInit()` 中获取 AI 控制器：`final aiLogic = Get.find<AIAssistantController>();`
- 进入聊天页面 1.5s 后调用 `aiLogic.generateTopicSuggestions()`
- `onRecvNewMessage` 回调中，2s 防抖后调用 `aiLogic.generateReplySuggestions()`
- 新增响应式变量监听 AI 建议状态，驱动 UI 更新

### 3. ChatPage / ChatInputBox 集成（lib/pages/chat/chat_view.dart）

- 在 `ChatInputBox` 上方、`ChatListView` 下方插入 `AiSuggestionBar` 组件
- `AiSuggestionBar` 通过 `Obx` 监听 `AIAssistantController` 的建议列表状态

### 4. MinePage 集成（lib/pages/mine/mine_view.dart）

- 在"我的信息"和"账号设置"之间新增"AI 助手"菜单项，点击跳转 AI 设置页

### 5. 路由注册（lib/routes/app_routes.dart）

- 新增 `static const aiSettings = '/ai_settings';`

### 6. DataSp 扩展

- 新增非敏感配置的存取方法：AI 总开关、各子开关、供应商选择、模型名称等
- 敏感配置通过新的 `SecureStorage` 工具类存取

### 7. 新增依赖

- `flutter_secure_storage: ^9.2.4` — 敏感配置加密存储
