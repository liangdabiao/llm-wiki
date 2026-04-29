---
tags: [model, ai, llm, minimax, moe, open-source]
created: 2026-04-29
updated: 2026-04-29
sources: [minimax-ipo-20251231]
---

# MiniMax M系列模型

## 概述

MiniMax M系列是[[MiniMax]]自主研发的大语言模型，采用MoE（混合专家）架构和混合注意力机制（Hybrid Attention）。M1于2025年6月发布并开源，是公司从abab系列向M系列的全新升级。M2为最新迭代版本，专攻代码和Agent任务。

## 模型详情

### MiniMax M1
- **发布时间**: 2025年6月
- **架构**: MoE + Lightning Attention（混合注意力）
- **上下文窗口**: 100万token
- **特点**: 开源大规模型，混合稀疏/密集注意力机制
- **全球排名**: Artificial Analysis Intelligence Index第5名（评分61），超越Google Gemini 2.5 Pro
- **开源**: 在GitHub等平台开源

### MiniMax M2
- **发布时间**: 2025年下半年（最新）
- **专攻方向**: 代码生成和Agent任务
- **架构**: 高数据利用率MoE架构
- **性能提升**: 推理速度较M1显著提升
- **全球排名**: Artificial Analysis Intelligence Index第5名（并列OpenAI gpt-oss-120B high）

## 技术特点

### MoE架构
- MiniMax是行业内较早采用MoE架构的公司
- MoE通过稀疏激活大幅降低推理成本
- 行业平均推理成本从2022年底~$20/M token降至2024年底<$0.1/M token，年均下降约10倍

### Lightning Attention
- 混合注意力机制（Hybrid Attention）
- 结合Linear Attention实现高效的线性复杂度计算
- 支持超长上下文（100万token）

### CISPO算法
- 自研强化学习算法
- 提升训练稳定性
- 用于模型对齐和推理能力优化

### 自研训练/推理框架
- 算子级优化
- 多级KV缓存
- 分布式专家并行推理
- 统一训练/推理计算资源调度
- 跨集群负载均衡

## 历史模型演进

| 时间 | 模型 | 特点 |
|------|------|------|
| 2022 | abab 1 | 早期大语言模型 |
| 2023 | abab 5.5 | 多轮对话能力 |
| 2024 | abab 6.0 | MoE架构大语言模型 |
| 2024 | MiniMax-Text-01 | 长文本处理 |
| 2025年4月 | Speech-02 | 语音生成（全球#1） |
| 2025年6月 | MiniMax M1 | 开源MoE大模型 |
| 2025 | MiniMax M2 | 代码+Agent专精 |
| 2025 | Hailuo-02 | 视频生成（全球#2） |
| 2025 | Music-01/02 | 音乐生成 |

## 与GLM系列对比

| 维度 | MiniMax M系列 | [[GLM系列模型]] |
|------|--------------|----------------|
| 架构 | MoE + Lightning Attention | GLM自研框架 + MoE |
| 开源 | M1开源 | GLM-130B、GLM-4.5开源 |
| 上下文 | 100万token | 未公开具体数值 |
| 代码能力 | M2专攻，全球前5 | GLM-4.6全球#1 |
| 语音 | Speech-02全球#1 | GLM-4-Voice端到端 |
| 视频 | Hailuo-02全球#2 | CogVideoX中国领先 |
| 参数量 | 未公开 | 1.5B-355B |
