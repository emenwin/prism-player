# README

## 文档分类

### 文档目录 [./docs](./docs/)

推荐使用树形结构展示，清晰标注用途和关键文件：

```text
docs/
├── requirements/                 # 需求文档
│   ├── prd_v0.2.md               # 当前 PRD（最新）
│   ├── prd_v0.1.md               # PRD 历史版本
│   ├── prd_review-claude4.5.md   # PRD 评审报告（Claude 4.5）
│   ├── prd_review_gemini2.5.md   # PRD 评审报告（Gemini 2.5）
│   └── short.md                  # PRD 摘要/提要
└── tdd/                          # 技术设计文档（TDD/HLD，待补充）
```

最新 PRD：
- v0.2（当前）：[docs/requirements/prd_v0.2.md](./docs/requirements/prd_v0.2.md)
- v0.1（存档）：[docs/requirements/prd_v0.1.md](./docs/requirements/prd_v0.1.md)

### PRD vs TDD 

PRD 文档应该聚焦于"做什么"（What）和"为什么"（Why），而不是"怎么做"（How）。架构图、线程模型、DI 策略等属于**技术设计文档（Technical Design Document, TDD）**的范畴，不应该出现在 PRD 中。

### PRD vs TDD 的职责分离

| 文档类型 | 核心职责 | 典型内容 | 负责人 |
|---------|---------|---------|--------|
| **PRD** | 定义产品需求 | 用户故事、功能列项、验收标准、成功指标 | PM/产品经理 |
| **TDD** | 定义技术方案 | 架构设计、API 设计、数据模型、技术选型细节 | 技术负责人/架构师 |

 