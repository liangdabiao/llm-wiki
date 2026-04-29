---
title: "phase-b: 知识库主线与外挂进料分离（Phase 1）"
type: architecture
status: implemented
date: 2026-04-06
origin: docs/brainstorms/2026-04-06-project-cleanup-and-restructuring-requirements.md
---

# phase-b: 知识库主线与外挂进料分离（Phase 1）

## Overview

这份计划只回答一个问题：如何在不拆掉“全家桶体验”的前提下，把**知识库主线**和**外挂进料能力**切开。

Phase 1 的目标不是做完整插件系统，而是先让核心路径单独成立，再让外挂变成真正可插拔的入口。用户几乎感觉不到重构，但核心更稳，后续维护也不会因为某个外接 skill 失效而把整套系统拖垮。

## Problem Frame

当前仓库已经隐含了两种不同职责：

- 一种是**知识库主线**：初始化、本地文件/纯文本 ingest、已有知识库的 query / digest / lint / status / graph
- 一种是**外挂进料**：网页、X/Twitter、微信公众号、YouTube、知乎这类外部来源提取

问题不在于功能不够，而在于边界还没被正式写死。现在这些事实分散在 `SKILL.md`、`README.md`、`install.sh`、`templates/schema-template.md`、`tests/regression.sh` 等多个位置。只要继续这样演进，未来每增减一个外挂，都有机会让文档、安装、状态提示和主线行为慢慢漂移。

## Decision Summary

Phase 1 锁定以下判断：

1. **知识库主线是底线**
   - 本地文件、纯文本、已有知识库操作必须独立可用。

2. **外挂只负责“翻译”外部内容**
   - 外挂的唯一职责是把外部来源转成统一素材；进入主线后，处理流程不再分叉。

3. **不先做完整插件平台**
   - Phase 1 不做自动发现、插件市场、复杂启停界面，也不追求完整升级/回退系统。

4. **先立边界，再动结构**
   - 先做统一素材入口、外挂总表、失败状态表、兼容规则。
   - B1（多文件拆分）和 B3（i18n 外部化）延后。

## Phase 1 Scope

### In Scope

- 明确“核心主线 vs 可选外挂”的固定边界
- 定义统一素材入口的最小字段
- 建立单一来源总表，作为安装、状态、路由的共同依据
- 定义外挂失败状态和统一回退路径
- 明确旧知识库的兼容和迁移规则
- 补足对应回归测试，优先覆盖主线不回退

### Out of Scope

- 自动发现外挂
- 插件市场
- 复杂开关管理界面
- 完整升级/回退/卸载系统
- 为所有工作流做多文件拆分
- 双语文案全面外部化

## Success Criteria

- 拆掉任意单个外挂后，核心主线仍可完整工作
- 用户能分清“核心可用”和“某个外挂不可用”是两件事
- 所有外挂都通过同一种素材入口进入主线
- 安装、说明、状态检查不再各自维护一套来源定义
- 旧知识库和既有目录结构可以继续使用，不需要强制迁移

## Required Contracts

### 1. 统一素材入口

所有来源在进入主线前，至少要具备这些信息：

| 字段 | 说明 |
|------|------|
| `source_id` | 来源类型唯一标识 |
| `source_label` | 面向用户的来源名称 |
| `source_category` | `core_builtin` / `optional_adapter` / `manual_only` |
| `input_mode` | `url` / `file` / `text` / `asset` |
| `raw_dir` | 原始素材要落到哪个目录 |
| `original_ref` | 原始 URL、文件路径或“用户粘贴” |
| `ingest_text` | 真正进入主线的素材文本 |
| `adapter_name` | 使用了哪个外挂；核心路径为空 |
| `fallback_hint` | 自动提取失败时该怎么退回手动入口 |

### 2. 外挂单一总表

Phase 1 需要一张单一总表，至少描述：

- 来源标识和用户名称
- 属于核心主线、可选外挂还是纯手动入口
- 对应 `raw/` 子目录
- 入口类型（URL / 文件 / 文本）
- 依赖项名称和依赖类型（内置 / 安装时拉取 / 无）
- 回退方式

这张表未来可以落成 `tsv`、`json` 或 shell 可读格式；当前计划不预设具体文件格式，但要求 **bash 3.2 可消费、人工可维护**。

### 3. 外挂失败状态表

Phase 1 统一使用以下五类状态：

| 状态 | 含义 | 用户层行为 |
|------|------|------------|
| `not_installed` | 外挂未安装 | 提示可安装，允许改走手动入口 |
| `env_unavailable` | 环境不满足 | 告知缺什么条件，允许改走手动入口 |
| `runtime_failed` | 外挂执行失败 | 告知提取失败，允许重试或手动继续 |
| `unsupported` | 该来源当前不支持自动提取 | 直接给出手动入口 |
| `empty_result` | 外挂运行了，但没有有效内容 | 不算成功，提示用户手动补全文本 |

### 4. 兼容与迁移规则

- 现有知识库目录结构继续可读
- 老素材文件不要求重写或搬迁
- 新字段缺失时，应优先采用惰性兼容，而不是强制 migrate
- 只有在未来出现确实无法兼容的新结构时，才引入显式迁移命令

## Planned Implementation Order

### Unit 1. 冻结边界与总表

**Goal:** 把来源边界和统一入口先定死，避免后续实现各写一套。

**Likely files:**
- `docs/brainstorms/2026-04-06-project-cleanup-and-restructuring-requirements.md`
- `docs/plans/2026-04-06-002-phase-b-core-and-adapter-separation-plan.md`
- 未来新增的来源总表文件

**Exit criteria:**
- 三类来源（核心 / 可选外挂 / 手动）有明确清单
- 统一入口字段写死
- 后续实现不再争论“某来源是不是插件”

### Unit 2. 让主线路由先独立

**Goal:** 先保证本地文件和纯文本直接进入主线，不经过外挂判断。

**Likely files:**
- `SKILL.md`
- 未来的来源总表读取脚本
- `tests/regression.sh`

**Exit criteria:**
- 本地文件 / 纯文本不依赖外挂
- 外挂判断只发生在 URL 类来源

### Unit 3. 引入外挂状态模型

**Goal:** 把“没装、环境不行、运行失败、不支持、空结果”分开处理。

**Likely files:**
- `install.sh`
- `SKILL.md`
- 未来的 `status` / `doctor` 辅助脚本
- `tests/regression.sh`

**Exit criteria:**
- 用户层提示不再把所有失败都说成“提取失败”
- 安装输出和状态输出对同一来源给出一致分类

### Unit 4. 锁住兼容路径

**Goal:** 新结构不能破坏老知识库。

**Likely files:**
- `scripts/init-wiki.sh`
- `templates/schema-template.md`
- `SKILL.md`
- `tests/regression.sh`

**Exit criteria:**
- 旧目录继续可读
- 没有新字段时仍有默认行为
- 不要求老用户先跑迁移才能继续用

### Unit 5. 对齐安装、状态与测试

**Goal:** 同一份来源定义被安装、状态、说明、回归检查共同复用。

**Likely files:**
- `install.sh`
- `README.md`
- `SKILL.md`
- `templates/schema-template.md`
- `tests/regression.sh`

**Exit criteria:**
- 安装、说明、状态、测试使用同一份来源定义
- 回归测试覆盖主线不依赖外挂的底线

## Risks and Guardrails

### Risk 1: 过早平台化

如果一开始就追求“完整插件系统”，工作量会从“切边界”膨胀成“造平台”。

**Guardrail:** 所有实现都要回答一句话：这一步是在保护核心主线，还是在提前造插件平台？后者一律延后。

### Risk 2: 文档先变，行为没跟上

如果 README / SKILL / install / tests 没有一起收口，会出现“看起来可插拔，实际还是绑死”的假象。

**Guardrail:** 只有当安装、状态、回归检查都一起对齐时，才算某个边界已经落地。

### Risk 3: 旧知识库被新规则惊动

如果新结构要求老用户先迁移，Phase 1 就违背了“用户几乎无感”的目标。

**Guardrail:** 兼容优先于整洁；能惰性兼容就不要强制迁移。

## Verification Plan

Phase 1 开始实施时，至少要有这几类验证：

- 核心路径回归：本地文件 / 纯文本在没有外挂时仍可用
- 外挂缺失回归：某个外挂不存在时，安装和状态提示明确，但主线不受影响
- 状态分类回归：五种失败状态不会混成一个模糊错误
- 兼容回归：旧知识库目录和旧素材仍可继续工作

## Recommended Execution Order After This Plan

1. 先落单一来源总表和统一素材入口
2. 再做外挂状态分类和回退路径
3. 然后补兼容逻辑
4. 最后统一安装、说明和测试

## Implementation Status

Phase 1 已按上述顺序落地：

- 来源总表和统一素材入口已落到 `scripts/source-registry.tsv`、`scripts/source-record-contract.tsv`、`scripts/source-registry.sh`
- 外挂状态和回退路径已落到 `scripts/adapter-state.sh`
- 旧知识库兼容规则已落到 `scripts/wiki-compat.sh`
- 安装、说明、模板和回归测试已对齐到同一份来源定义

验证命令：

- `bash tests/adapter-state.sh`
- `bash tests/regression.sh`
- `bash -n install.sh scripts/source-registry.sh scripts/adapter-state.sh scripts/wiki-compat.sh scripts/shared-config.sh tests/regression.sh tests/adapter-state.sh`
