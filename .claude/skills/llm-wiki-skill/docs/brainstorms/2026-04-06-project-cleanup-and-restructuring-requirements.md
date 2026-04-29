---
date: 2026-04-06
topic: project-cleanup-and-restructuring
---

# llm-wiki-skill 项目整理与重构规划

## Problem Frame

llm-wiki-skill 经过 4 个版本的迭代（v0.1→v0.4），功能已经完整（8 个工作流、多平台、双语），但内部结构积累了重复和不一致。核心问题：SKILL.md 930 行、CWD 检查重复 7 次、双语输出占 40% 篇幅、英文种子文件硬编码、安装脚本复制了非运行时文件。这些让维护和迭代越来越难（每次修改工作流需同步更新多处内容，增加了引入不一致行为的风险）。

分两阶段处理：**阶段 A（立即执行）** 是整理清洁，不改变功能；**阶段 B（记录备查）** 是结构重构，供未来参考。

---

## 阶段 A：整理清洁（立即执行）

### SKILL.md 瘦身

**R1. CWD 前置检查去重**
- 在 SKILL.md 的「工作流路由」段之后、各工作流定义之前，新增一个「通用前置检查」段
- 内容：完整的 CWD 检查逻辑（检查 `.wiki-schema.md` → 回退 `~/.llm-wiki-path` → 无则提示初始化）+ `WIKI_LANG` 读取规则
- 各工作流的「前置检查」段改为一行引用：「执行**通用前置检查**（见上方定义）」
- 涉及 7 个工作流：ingest、batch-ingest、query、lint、status、digest、graph（init 的前置检查逻辑不同，保持独立）

**R2. 双语输出精简**
- 在「通用前置检查」段或紧邻位置，新增「输出语言规则」段：
  - 说明所有工作流的用户输出都按 `WIKI_LANG` 选择语言
  - 给出英文输出的通用格式规则（结构一致，用英文措辞）
  - 列出英文专有术语对照表（如 素材→Source, 实体→Entity, 主题→Topic, 摘要→Summary, 综合→Synthesis）
- 各工作流的输出段：只保留中文示例，加一句注释「（英文版按输出语言规则生成，结构相同）」
- 涉及工作流：init、ingest（完整+简化）、batch-ingest、lint、status、digest、graph（注：query 仅有单行 `WIKI_LANG` 切换指令，无独立双语输出块，不在精简范围）

**R3. init 英文种子文件外移**
- 将 SKILL.md 中 init 工作流的英文种子文件内容（index.md en、overview.md en、log.md en 三个代码块）移到 `templates/` 目录
- 新增文件：`templates/index-en-template.md`、`templates/overview-en-template.md`、`templates/log-en-template.md`（与现有 `*-template.md` 命名规则一致）
- init 工作流中改为：「如果 `WIKI_LANG=en`，使用 `templates/index-en-template.md`、`templates/overview-en-template.md`、`templates/log-en-template.md` 替换对应中文模板」
- 保持 init-wiki.sh 不变（它只处理目录创建和通用变量替换）

### 安装脚本精简

**R4. install.sh MANAGED_ITEMS 审查**
- 检查当前 `MANAGED_ITEMS` 数组，确认每项是否为运行时必需
- 当前数组：`SKILL.md`、`README.md`、`CLAUDE.md`、`AGENTS.md`、`CHANGELOG.md`、`install.sh`、`setup.sh`、`scripts`、`templates`、`deps`、`platforms`
- `platforms/` **必须保留**：README.md（4处）、CLAUDE.md（1处）、AGENTS.md（1处）中包含指向 platforms/ 下文件的链接，安装后这些链接必须有效
- `docs/` 不在当前 MANAGED_ITEMS 中，无需操作
- 可评估移除的候选项：`CHANGELOG.md`（安装后无运行时引用）、`install.sh` 自身（安装已完成）——但保留更安全，不做移除
- 验证：运行 `tests/regression.sh` 确保安装功能正常

**R5. setup.sh 标记废弃**
- 在 setup.sh 文件头部加注释：`# 已废弃：请使用 bash install.sh --platform claude`
- 不删除文件（保持向后兼容）
- README 中如果有单独提到 setup.sh 的地方，更新为推荐 install.sh

### Success Criteria

- SKILL.md 行数减少至 ~750 行以下（CWD 去重复用约 40 行、英文输出块删除约 120 行、英文种子外移约 115 行，总计节省约 200 行）
- 每个修改后的工作流功能与修改前完全一致
- `tests/regression.sh` 全部通过
- `bash install.sh --platform claude --dry-run` 输出中 platforms/ 仍被正确复制（因含运行时引用）
- 对 `WIKI_LANG=en` 的 init 执行，手动验证 index.md、overview.md、log.md 的英文内容与修改前一致（此验证需人工执行，regression.sh 无法覆盖 AI 驱动的模板替换）

### Scope Boundaries

- 不改变任何工作流的功能逻辑
- 不拆分 SKILL.md 为多个文件
- 不修改 deps/ 结构
- 不增加版本管理/升级机制
- 不修改 init-wiki.sh

### Key Decisions

- **内部去重而非拆文件**：CWD 检查提取为共享段落但保持在同一文件内，避免引入多文件加载机制
- **单语展示 + 统一规则**：双语输出只展示中文版，英文版通过顶部规则推导，大幅减少重复
- **英文种子文件走模板系统**：与中文模板保持一致的机制，init 工作流逻辑更统一。英文模板和中文模板走不同的变量替换路径（AI vs 脚本），这个不一致在当前「不修改 init-wiki.sh」的约束下可接受——init-wiki.sh 仍处理中文模板，AI 在后续步骤中读取 `templates/*-en-template.md`，替换 `{{DATE}}`/`{{TOPIC}}` 后覆盖对应文件
- **platforms/ 必须保留在安装包中**：README.md（4处）、CLAUDE.md（1处）、AGENTS.md（1处）含运行时链接

---

## 阶段 B：结构重构（记录备查）

以下项目不在本次清洁范围内，记录供未来参考。

### 阶段 B 的共享约束

阶段 B 不是为了先做一个“更像插件系统”的外壳，而是先把**知识库主线**和**外挂进料能力**切开。

**底线**：
- 知识库主线必须独立成立：本地文件、纯文本、已有知识库的 `query / digest / lint / status / graph` 不能依赖外挂
- 所有外挂都只负责把外部内容转换成统一素材；一旦进入主线，后续整理流程完全一致
- 拆掉任意一个外挂，不得让核心知识库能力失效
- Phase 1 不做自动发现、插件市场、复杂启停界面；先做边界、降级、兼容

**Phase 1 开工前必须补齐的文档钉子**：
- 统一素材入口定义：最小字段、由谁填充、进入主线前必须具备什么信息
- 外挂单一总表：来源、分类、依赖、原始目录、回退方式
- 外挂失败状态表：未安装 / 环境不满足 / 运行失败 / 来源不支持 / 提取为空
- 旧知识库兼容与迁移规则：老目录、老素材、老安装继续可用

### B1. SKILL.md 多文件拆分（维护态拆分，交付态保留单入口）

> **与阶段 A 的关系**：阶段 A 的去重不会阻碍 B1；但 B1 不应抢在边界稳定之前执行。

**现状**：核心说明集中在单文件中，维护时改一处容易漏多处。

**目标**：
- 维护态可以拆成主路由 + `workflows/` 子文件，降低修改时的心智负担
- 对外仍保留一个稳定入口，不要求运行时依赖多文件引用机制

**好处**：
- 改动隔离，更容易审查
- 主路由和具体工作流职责更清楚

**风险**：
- 不同 agent 对 skill 文件引用的支持程度不一致
- 如果把运行时也做成多文件，安装体验可能变脆

**结论**：B1 不是 Phase 1。先把边界、总表和失败状态钉死，再决定是否拆文件。

### B2. deps/ 依赖管理重构（先立边界，再决定外拉）

**现状**：`baoyu-url-to-markdown` 和 `youtube-transcript` 直接嵌在 repo 中，`wechat-article-to-markdown` 则在安装时外拉。

**目标**：
- 先明确“核心内置”和“可选外挂依赖”的边界
- 再决定哪些依赖继续内置，哪些允许安装时拉取
- 安装、状态检查、未来升级逻辑都读取同一份来源总表

**好处**：
- 后续接入或移除外挂时，不会牵动核心功能
- 依赖策略更一致，不会出现一半内置、一半散落脚本里的状态

**风险**：
- 如果过早把依赖全部外拉，会引入网络和安装不稳定性
- submodule 会提高维护复杂度

**结论**：Phase 1 只做边界和总表，不急着把依赖全部外拉。

### B3. 双语 i18n 外部化（延后）

**现状**：双语内容已经比之前更收敛，但仍分散在核心说明中。

**目标**：未来可用 `locales/zh.md` 和 `locales/en.md` 集中管理输出模板。

**好处**：
- 新增语言时不会反复改主文件
- 文案维护更集中

**风险**：
- 在边界未稳定前继续拆文案，会放大维护面
- 依赖文件引用能力，和 B1 有同样的兼容顾虑

**结论**：B3 不进入 Phase 1，等核心/外挂边界稳定后再做。

### B4. 版本管理与升级（先做轻量版）

**现状**：重复安装会覆盖文件，但用户不知道当前版本、也不知道外挂状态。

**目标**：
- 先让版本和已安装能力可见
- 再考虑升级、回退、卸载等完整生命周期命令

**第一步只做**：
- 能看见当前 skill 版本
- 能看见当前有哪些可选外挂处于可用 / 不可用状态
- 为后续 `doctor / upgrade / uninstall` 留出入口

**结论**：B4 值得做，但先做轻量版，不在 Phase 1 里追求完整回退系统。

### B5. 确定性逻辑脚本化（Phase 1 第一优先级）

**现状**：CWD 检查、素材分类、状态判断等确定性动作仍主要靠说明文字驱动。

**目标**：
- 先把最容易漂移的确定性逻辑收成脚本或统一规则
- AI 只负责分析和生成，不负责反复做相同判断

**Phase 1 优先脚本化的内容**：
- CWD / 知识库根路径判断
- 来源总表读取与原始目录映射
- 状态检查分类（核心可用、外挂缺失、环境不满足、运行失败）

**Phase 1 暂不强求脚本化的内容**：
- `index.md` / `log.md` 的完整更新流程
- 复杂的批量修复逻辑

**结论**：B5 是 Phase 1 的起点。先做它，后续 B2/B4 才有稳定落点。

### 阶段 B 推荐执行顺序

1. B5：先把确定性边界、总表、状态判断立住
2. B4（轻量版）：让版本和外挂状态可见
3. B2：在统一总表下重构依赖管理策略
4. B1：边界稳定后再考虑维护态拆分
5. B3：最后处理更深的双语外部化

---

## Outstanding Questions

### Resolve Before Planning

- [Resolved] Phase 1 的目标不是完整插件平台，而是“核心主线独立 + 外挂可插拔”
- [Resolved] 需要先补统一素材入口、外挂总表、失败状态表、兼容规则，再进入实现
- [Resolved] 自动发现、插件市场、复杂启停不属于 Phase 1

### Deferred to Planning
- [Phase 1][Technical] 统一来源总表最终以哪种格式落地，既便于维护，又兼容 bash 3.2
- [Phase 1][Technical] `status` 是否直接展示五种外挂失败状态，还是先保留为内部规则
- [Phase 1][Compatibility] 老知识库若缺少新字段或新目录，采用惰性兼容还是显式 migrate

## Next Steps

→ 先完成 `docs/plans/2026-04-06-002-phase-b-core-and-adapter-separation-plan.md`
→ 再按该计划生成 Phase 1 的执行待办，按依赖顺序推进
