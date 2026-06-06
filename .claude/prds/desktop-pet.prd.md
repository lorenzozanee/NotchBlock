# Desktop Pet — 桌面宠物功能

## Problem
NotchBlock 的时间块管理界面是纯功能性的——设置计时器、勾选任务、看进度条。这导致用户在使用几周后进入"工具疲劳"：App 变成后台进程，专注会话变成例行公事而非有意义的行为。Dockling 的 beta 测试数据和 Murchi/Paw-Paw 的社区反馈表明：一个可见的、有状态反馈的桌面宠物能让用户对专注会话产生情感投入——用户不愿意"吵醒"睡眠中的宠物，想看到庆祝动画，从而更认真地对待每个专注会话。

## Evidence
- Dockling beta 反馈："当你的小熊猫在睡觉时，你会有一种不理性的抗拒，不想提前结束休息"（Research Section 1.3）
- Paw-Paw 社区：用户每天打开 App 的理由从"需要打字"变成"想看到宠物戴着新帽子"
- Red/Blue 论证 Blue Team："time-block adherence 是核心 KPI。宠物不是装饰——它是行为合规机制。"
- **Assumption — needs validation via analytics**: 宠物启用用户 vs 未启用用户的 7 天/30 天日活跃留存率差异（需上线后 A/B 对比）

## Users
- **Primary**: NotchBlock 专注用户——使用时间块管理日常工作的 macOS 用户（开发者、创意工作者、学生）
- **Not for**: 纯企业/团队用户（NotchBlock 无团队功能）；追求极简无干扰界面的用户（可选择 opt-out）

## Hypothesis
We believe **一个 9 状态动画桌面宠物，其行为由 NotchBlock 时间块调度状态机驱动** will **提高专注会话完成率和日活跃留存率** for **NotchBlock 专注用户**.
We'll know we're right when **宠物启用用户在 30 天后的日活跃率比未启用用户高 15%+，且专注会话完成率提升 10%+**.

## Success Metrics
| Metric | Target | How measured |
|---|---|---|
| 宠物启用率（新用户） | ≥ 60% onboarding opt-in | UserDefaults `pet.enabled` 计数 |
| 宠物 7 天留存率 | ≥ 50% 用户在第 7 天仍保持 `pet.enabled = true` | UserDefaults 每周快照 |
| 专注会话完成率 | 启用用户比未启用高 10%+ | BlockScheduler completed vs missed 对比 |
| 日活跃会话数 | 启用用户日均专注会话数 > 未启用用户 | TimeBlockStore 日志 |
| 性能 | 宠物窗口增量内存 < 15MB，增量 CPU < 1% | Activity Monitor 实测 |
| 用户满意度 | "宠物让我更想专注"认可率 ≥ 70% | In-app 问卷（上线后 2 周） |

## Scope

**MVP** — P0 Must-Have:
- F1: 浮动宠物窗口（NSPanel，跨 Spaces，全屏可见）
- F2: 9 状态动画状态机（GIF 驱动，CGImageSource + CVDisplayLink）
- F3: 交互系统（单击→NotchPanel，拖拽→移动+方向动画，悬停→1.1x scale+alpha，右键→菜单）
- F4: 可扩展协议架构（Pet protocol + PetManifest.json）
- F5: 引导页宠物选择（elysia only）
- F6: UserDefaults 偏好持久化

**Out of scope — v1 明确不做**
- F9: CAEmitterLayer 粒子系统 — delayed（用预合成 GIF 替代，若 jumping.gif 已含粒子效果则零代码）
- F8: 空闲睡眠状态 (P2) — delayed（需先验证基础状态机稳定性）
- P1-5 idle-micro 微动作 (P1) — delayed（需额外 GIF 素材 blink.gif/stretch.gif，当前素材库缺少）
- P2-2 多宠物选择 — delayed（仅 elysia 存在）
- P2-3 全屏隐藏选项 — delayed
- 音效系统 — 永久排除
- 联网下载宠物 — 永久排除
- 多宠物同时显示 — 永久排除

## Delivery Milestones
| # | Milestone | Outcome | Status | Plan |
|---|---|---|---|---|
| 1 | Pet Window + Animation | 宠物出现在桌面，根据 TimeBlockStore 状态切换动画 | pending | — |
| 2 | Interaction | 单击弹出面板，拖拽移动，悬停高亮，右键菜单 | pending | — |
| 3 | Onboarding + Persistence | 新用户引导选择宠物，偏好持久化，重启恢复 | pending | — |
| 4 | Polish + Ship | Bug 修复，性能调优，多显示器测试，DMG 发布 | pending | — |

## Open Questions
- [ ] `idle-micro` 的 blink.gif / stretch.gif 素材谁来做？若缺失则 P1 降级为仅 idle/waiting 切换
- [ ] 引导页 GIF 预览是否需要独立于宠物窗口的渲染路径？OnboardingWindowController 是 AppKit — 需要确认是否支持 NSImageView GIF
- [ ] 老用户升级是否默认启用宠物？当前决策：`pet.enabled = false`（需手动开启），但需确认产品意图
- [ ] 专注完成后的 celebration jumping 动画持续 60 秒是否过长？可能调整为 15 秒

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| 宠物窗口在 macOS 版本更新后行为异常 | Medium | High | .fullScreenAuxiliary + .nonactivatingPanel 已有已知 Radar bug；每个 macOS beta 测试 |
| 用户觉得宠物分散注意力 | Medium | Low | Opt-out 一键关闭；默认关闭于升级用户；键盘快捷键 Cmd+Shift+P |
| GIF 动画性能影响电池续航 | Low | Medium | 电池模式降帧至 10fps，空闲 30s 降至 5fps；NFR 已在 v2 定义 |
| 多显示器坐标 bug | Medium | Medium | 钳制策略 + NSScreen.screens 动态校验；P0 仅主屏测试 |
| 状态机复杂度导致 bug 密度高 | Medium | Medium | 状态机独立单元测试覆盖所有 20+ 转换；Red Team 已警示此风险 |

---
*Status: DRAFT — requirements only. Implementation planning via architecture doc + task breakdown below.*
