---
type: entity
name: MCP 模型上下文协议
category: 核心技术
tags: [MCP, Model Context Protocol, 工具调用, 标准化协议]
sources: 
  - 2026-04-29-yupi-ai-guide-core-concepts
  - 2026-04-29-yupi-ai-guide-programming-tech
created: 2026-04-29
updated: 2026-04-29
---

# MCP 模型上下文协议

> Model Context Protocol，AI 与外部工具/数据的标准化交互协议

## 简介

MCP（Model Context Protocol）是模型上下文协议，为 AI 与外部工具和数据的交互提供了标准化方式。它使得不同系统之间的工具调用和数据交换变得统一和可互操作。

## 核心价值

### 1. 标准化服务接口
- 统一的工具调用格式
- 统一的数据交换协议
- 统一的错误处理机制
- 统一的认证方式

### 2. 增强 AI 功能
- 让 AI 调用外部工具
- 让 AI 访问外部数据
- 扩展 AI 能力边界
- 实现复杂功能组合

### 3. 生态互操作性
- 不同系统之间可互操作
- 工具可复用可共享
- 降低集成成本
- 促进生态发展

## 两大核心技能

### 1. 接入别人的 MCP 服务
- 发现可用的 MCP 服务
- 理解服务接口定义
- 集成到自己的项目中
- 调用服务增强功能

### 2. 开发自己的 MCP 服务
- 设计服务接口
- 实现服务逻辑
- 发布服务供他人使用
- 维护和更新服务

## 不同素材中的观点

来自 [[2026-04-29-yupi-ai-guide-core-concepts]]：
- Model Context Protocol，模型上下文协议
- AI 与外部工具/数据的标准化交互，增强 AI 功能
- 16 个核心概念之一

来自 [[2026-04-29-yupi-ai-guide-programming-tech]]：
- 是 AI 编程开发的四大核心业务领域之一
- 提供给 AI 的标准化服务
- 让 AI 调用外部工具和数据，增强功能
- Spring AI 框架原生支持 MCP

## 快速开发工具

### MCPify
- 官网：http://mcpify.ai/
- 一句话创建自己的 MCP 服务
- 快速开发和部署
- 自动生成接口文档

### Spring AI 原生支持
- Spring AI 框架已原生支持 MCP
- 简化 MCP 服务开发
- 与 Spring 生态无缝集成

## 实用信息

### MCP vs Function Call

| 维度 | Function Call | MCP |
|------|--------------|-----|
| 范围 | 单模型内 | 跨系统跨模型 |
| 标准化 | 各厂商自定义 | 统一标准协议 |
| 可复用性 | 特定场景 | 通用可复用 |
| 生态支持 | 大模型厂商 | 社区生态 |

### 应用场景
- 企业内部工具标准化
- AI 应用之间功能共享
- 多智能体协作系统
- 插件生态系统建设

## 相关页面
- [[AI Agent 智能体]]
- [[ReAct]]
- [[Spring AI]]
- [[AI编程开发]]
