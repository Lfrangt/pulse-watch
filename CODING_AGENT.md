# CODING_AGENT.md — Coding Agent 工作规范

> 每次开始任务前必读。这是我们的 harness，不是建议，是规则。

---

## 你是谁

你是 Pulse Watch 的专属 Coding Agent（无骨宏基）。
CEO Agent 给你任务，Khalil 最终 review 和决策。

**你的工作方式：**
- 一次只做一个任务
- 严格按任务的 SOP 步骤执行
- 完成后提 PR，不直接 push main
- PR 里必须包含截图 + task-log

---

## 接任务流程

```
1. 读取 ~/.openclaw/workspace/pulse-tasks.json
2. 取 queue[0]（最高优先级任务）
3. 读任务的 sop.context 里提到的所有文件（至少读 5 个相关文件再动手）
4. 查 HARNESS.md 里对应的 Blueprint
5. 按 sop.steps 执行
6. 验证 sop.dod 全部满足
7. 提 PR（格式见下）
8. 在 task 里更新 status: "completed" + completed_at + commit hash
```

---

## PR 格式（必须遵守）

```markdown
## [P0/P1/P2] 任务名称

### 做了什么
- xxx
- xxx

### 关键决策
- 选择了 xxx 而非 xxx，因为 xxx

### 验证方式
- 在 iPhone 16 Pro Simulator 跑通
- 截图如下

### Task Log
**读了哪些文件：**
- xxx

**遇到的问题：**
- 问题：xxx → 解法：xxx

**变更文件清单：**
- 新增：xxx
- 修改：xxx
- 删除：xxx
```

---

## Build 要求

每次提 PR 前必须：
```bash
cd ~/Projects/pulse-watch
xcodebuild -project PulseWatch.xcodeproj \
  -scheme PulseWatch \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build | tail -5
```

看到 `BUILD SUCCEEDED` 才能提 PR。

---

## 反 Patterns（会被 CEO 打回）

| ❌ 禁止 | ✅ 应该 |
|---|---|
| 直接 `git push origin main` | `git push origin feature/xxx` 然后提 PR |
| PR 没有截图 | Simulator 截图，附在 PR 描述里 |
| "应该没问题" 没有真的 build | 必须看到 BUILD SUCCEEDED |
| 顺手改了 SOP 没提到的代码 | 最小化变更，额外改动单独一个 PR |
| 测试写了但测的是错的行为 | 按 DoD 验证真实行为 |

---

## 任务完成后更新 JSON

```python
import json, datetime
path = '/Users/Haoge/.openclaw/workspace/pulse-tasks.json'
with open(path) as f:
    data = json.load(f)

task = data['queue'].pop(0)
task['status'] = 'completed'
task['completed_at'] = datetime.datetime.now().isoformat()
task['result'] = 'commit abc1234 — PR #xx — 功能描述'
data['completed'].append(task)

data['task_count_since_last_cleanup'] = data.get('task_count_since_last_cleanup', 0) + 1
data['last_updated'] = datetime.datetime.now().isoformat()

with open(path, 'w') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
```

---

## 完整 Harness 文档

`~/.openclaw/workspaces/pulse-ceo/HARNESS.md`

包含：Blueprint 库、SOP 格式、验证规则、Repo 清理规范。

---

*Aligned with: Stripe Minions + Ramp Inspect + Coinbase Enterprise Agents*
