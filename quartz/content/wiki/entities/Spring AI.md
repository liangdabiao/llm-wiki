---
type: entity
name: Spring AI
category: 开发框架
tags: [Java, Spring, AI框架, 大模型集成]
sources: 
  - 2026-04-29-yupi-ai-guide-programming-tech
created: 2026-04-29
updated: 2026-04-29
---

# Spring AI

> Spring 官方推出的 AI 应用开发框架，专为 Java 生态设计

## 简介

Spring AI 是 Pivotal 官方推出的 AI 应用开发框架，无缝集成 Spring 生态系统。它为 Java 程序员提供了一套标准化的大模型对接方案，降低了 AI 应用开发的入门门槛。

## 核心能力

### 1. 大模型快速对接
- 统一的 API 接口层
- 支持主流大模型提供商
- 可插拔的模型切换机制
- 自动处理认证和计费

### 2. 会话上下文管理
- 内置会话状态持久化
- 支持多轮对话
- 上下文窗口自动管理
- Token 消耗统计

### 3. RAG 知识库支持
- 对接向量数据库
- 内置 Embedding 向量化
- 文档加载和解析管道
- 相似度检索算法

### 4. Spring 生态集成
- 与 Spring Boot 自动配置
- Spring Data 数据访问
- Spring Security 安全控制
- Spring Cloud 微服务支持

## 不同素材中的观点

来自 [[2026-04-29-yupi-ai-guide-programming-tech]]：
- Java 程序员首选框架
- 和主流 Spring 无缝集成
- 上手难度低，学习曲线平缓
- 企业级应用开发的标准选择
- 建议先从 Spring AI 学起，再学 LangChain4j 会更简单

## 实用信息

### 官方资源
- 官方文档：https://docs.spring.io/spring-ai/reference/getting-started.html
- GitHub 仓库：Spring AI 官方仓库

### 快速开始
1. 添加 Spring AI Maven/Gradle 依赖
2. 配置 application.yml 中的 API Key
3. 使用 ChatClient 接口调用大模型
4. 对接向量数据库实现 RAG

### 适用场景
- 企业级 AI 应用开发
- 需要与现有 Spring 系统集成
- Java 技术栈团队
- 对稳定性和可维护性要求高的项目

## 相关页面
- [[LangChain4j]]
- [[LangGraph]]
- [[RAG 知识库]]
- [[AI编程开发]]
