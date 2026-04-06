# Boss 技能模板库

> **版本**: v1.0 | **更新日期**: 2026-03-16
>
> 本文档定义 Boss 技能的可复用模板。设计新 Boss 时从模板库选取 → 填数值参数 → 添加章节特调 → 组合成完整 Boss。
>
> **核心原则**: 模板只定义行为框架，不包含元素/主题。元素和附加效果由"特调层"在每个 Boss 定义中单独配置。

---

## 一、设计架构

### 1.1 三层分离

```
┌─────────────────────────────────────────┐
│  特调层（每Boss独有）                     │
│  元素、onHit效果、视觉主题、反应规则       │
├─────────────────────────────────────────┤
│  参数层（数值调整）                       │
│  伤害倍率、CD、持续时间、范围、数量等      │
├─────────────────────────────────────────┤
│  模板层（行为框架，全Boss共享）            │
│  弹幕、吐息、地刺、护甲、护盾、漩涡...    │
└─────────────────────────────────────────┘
```

- **模板层**: 定义技能"做什么"（发射弹体/创建区域/召唤物体），所有章节共用
- **参数层**: 定义技能"多强"（伤害、CD、范围等数值），每个 Boss 各不同
- **特调层**: 定义技能"什么感觉"（冰/火/毒/奥术的独特附加效果），每章主题决定

### 1.2 AI 威胁通知系统

Boss 技能不再直接扣血/加 debuff，而是在战场上创建**威胁对象**，注册到共享的威胁表。角色 AI 每帧读取威胁表，根据自身属性（攻击力、血量、抗性、韧性）自主决策。

**威胁对象结构**:

| 字段 | 类型 | 说明 |
|------|------|------|
| type | string | 威胁类型（见 §1.3） |
| x, y | number | 空间位置 |
| radius | number | 影响范围 |
| damage | number | 预期伤害（AI 用来权衡风险） |
| duration | number | 剩余持续时间 |
| priority | number | 威胁优先级权重（0~1） |

### 1.3 威胁类型

| 类型 | 含义 | AI 决策方式 |
|------|------|-----------|
| **dangerZone** | 区域持续伤害（圆形/扇形/矩形/环形） | 移动向量加入"远离区域中心"分量，权重由 damage/自身HP 决定。高防角色可能忽略低伤害区域 |
| **priorityTarget** | 高价值可摧毁目标（冰晶/图腾/护盾） | 纳入目标选择评分，与当前目标比较权重后决定是否切换。priority 越高越倾向切换 |
| **taunt** | 嘲讽/吸引效果 | 影响目标选择权重，玩家韧性属性可削弱嘲讽权重 |
| **pull** | 牵引力 | 作为移动向量的外力分量，AI 自然地试图抵抗。移速越低越难挣脱 |
| **expandingRing** | 向外扩散的环形伤害 | AI 评估冰环到达时间和自身位置，决定向内穿越或向外撤退 |

**关键**: 这些不是硬编码的 if-else 响应，而是 AI 已有的移动向量计算和目标选择评分中新增的权重因素。同一个 dangerZone，高防角色权重低（可能无视），低防角色权重高（立刻跑）。

---

## 二、攻击类模板（Offensive）

### ATK_barrage — 弹幕

**行为**: 向玩家方向发射多枚弹体。弹体是真实空间物体（有位置、速度、碰撞半径），AI 可尝试横向移动躲避。

**威胁通知**: 每颗弹体注册为小型 dangerZone

| 参数 | 类型 | 说明 | 参考范围 |
|------|------|------|---------|
| count | int | 弹体数量 | 8~24 |
| spread | float | 扇形角度（°），360=全向 | 60~360 |
| dmgMul | float | 每颗伤害 = ATK × dmgMul | 0.5~1.2 |
| speed | float | 弹体飞行速度（像素/s） | 120~300 |
| interval | float | 施放间隔（s） | 5~10 |

**特调示例**:
- 冰章: onHit 叠加减速
- 火章: onHit 施加灼烧 DoT
- 毒章: onHit 叠加毒素层

---

### ATK_breath — 吐息

**行为**: 向玩家方向释放扇形持续伤害区域，区域存在一段时间。AI 可向侧面移动躲出扇形范围。

**威胁通知**: dangerZone（扇形）

| 参数 | 类型 | 说明 | 参考范围 |
|------|------|------|---------|
| angle | float | 扇形角度（°） | 45~120 |
| range | float | 射程（像素） | 100~200 |
| dmgMul | float | 每 tick 伤害 = ATK × dmgMul | 0.3~0.8 |
| tickRate | float | 伤害间隔（s） | 0.2~0.5 |
| duration | float | 区域持续时间（s） | 1.0~3.0 |
| interval | float | 施放间隔（s） | 6~12 |

**特调示例**:
- 冰章: 区域内额外减速
- 火章: 离开后持续灼烧 3s
- 毒章: 区域内降低防御

---

### ATK_spikes — 地刺

**行为**: 在目标位置生成预警标记（可视），延迟后触发范围伤害。残留物可作为地形障碍持续一段时间。

**威胁通知**: dangerZone（圆形预警，延迟触发）

| 参数 | 类型 | 说明 | 参考范围 |
|------|------|------|---------|
| count | int | 同时生成的地刺数 | 2~5 |
| radius | float | 每根的伤害半径 | 25~45 |
| delay | float | 预警→触发延迟（s） | 0.8~1.5 |
| dmgMul | float | 触发伤害 = ATK × dmgMul | 0.8~1.5 |
| lingerTime | float | 残留障碍持续时间（s），0=不残留 | 0~6 |
| interval | float | 施放间隔（s） | 6~12 |

**特调示例**:
- 冰章: 残留冰柱接触额外减速
- 火章: 残留火柱持续灼烧接触者
- 奥术章: 残留扭曲区降低攻速

---

### ATK_pulse — 脉冲环

**行为**: 从 Boss 位置向外扩散的环形冲击波。冲击波有宽度，AI 可选择向 Boss 方向冲刺穿越（冲击波已过），或后撤等待消散。

**威胁通知**: expandingRing

| 参数 | 类型 | 说明 | 参考范围 |
|------|------|------|---------|
| speed | float | 扩散速度（像素/s） | 60~120 |
| width | float | 环宽度（像素） | 15~30 |
| maxRadius | float | 最大扩散半径 | 150~250 |
| dmgMul | float | 命中伤害 = ATK × dmgMul | 0.5~1.2 |
| hitEffect | string | 命中效果类型（stun/knockback/slow） | — |
| hitDuration | float | 命中效果持续时间（s） | 0.3~1.5 |
| interval | float | 施放间隔（s） | 8~15 |

**特调示例**:
- 冰章: hitEffect=stun（定身）
- 火章: hitEffect=knockback（击退）+ 落地灼烧
- 物理章: hitEffect=slow + 破甲

---

### ATK_detonate — 限时引爆

**行为**: 生成 N 个可摧毁物体，倒计时结束未摧毁则全场爆炸 + Boss 获益。AI 收到极高优先级 priorityTarget，几乎一定切换目标。

**威胁通知**: priorityTarget（极高优先级）

| 参数 | 类型 | 说明 | 参考范围 |
|------|------|------|---------|
| count | int | 生成数量 | 2~5 |
| hpPct | float | 每个 HP = Boss maxHP × hpPct | 0.005~0.02 |
| timer | float | 引爆倒计时（s） | 6~12 |
| dmgMul | float | 爆炸伤害 = ATK × dmgMul | 1.5~3.0 |
| bossHealPct | float | 爆炸后 Boss 回复 HP 百分比 | 0.05~0.15 |
| interval | float | 施放间隔（s），`once`=仅触发一次 | once 或 20~30 |

**特调示例**:
- 冰章: 爆炸后全场冰冻 2s
- 毒章: 爆炸后全场毒雾持续 5s
- 奥术章: 爆炸后 Boss 获得增伤 buff

---

## 三、防御类模板（Defensive）

### DEF_armor — 护甲

**行为**: HP 低于阈值后获得减伤，持续一段时间后消失，进入冷却。

**威胁通知**: bossState（通知 AI Boss 当前减伤中，可选择去做其他事）

| 参数 | 类型 | 说明 | 参考范围 |
|------|------|------|---------|
| hpThreshold | float | 触发 HP 百分比 | 0.30~0.55 |
| dmgReduce | float | 减伤比例 | 0.45~0.75 |
| duration | float | 持续时间（s） | 4~8 |
| cd | float | 冷却时间（s） | 10~16 |

---

### DEF_regen — 回血

**行为**: HP 低于阈值后每秒回复百分比 HP，永久生效直至 Boss 死亡。

**威胁通知**: 无（纯 DPS 检定）

| 参数 | 类型 | 说明 | 参考范围 |
|------|------|------|---------|
| hpThreshold | float | 触发 HP 百分比 | 0.15~0.30 |
| regenPct | float | 每秒回复 maxHP 的百分比 | 0.02~0.05 |

---

### DEF_crystal — 回血源

**行为**: 定时在 Boss 附近生成可摧毁的晶体。晶体存活期间 Boss 持续回血。AI 权衡：切换目标打晶体（中断对 Boss 的输出但阻止回血）vs 无视晶体强打 Boss（需要 DPS 压过回血速度）。

**威胁通知**: priorityTarget

| 参数 | 类型 | 说明 | 参考范围 |
|------|------|------|---------|
| count | int | 每次生成数量 | 1~3 |
| hpPct | float | 每个晶体 HP = Boss maxHP × hpPct | 0.01~0.03 |
| healPct | float | 每个晶体每秒回复 Boss maxHP 的百分比 | 0.01~0.02 |
| spawnInterval | float | 生成间隔（s） | 10~18 |
| spawnRadius | float | 生成距离 Boss 的半径（像素） | 50~120 |

**特调示例**:
- 冰章: 晶体被摧毁时爆裂造成小范围冰伤
- 火章: 晶体存活时额外给 Boss 加攻
- 毒章: 晶体周围释放毒雾减速区域

---

### DEF_shield — 反应护盾 🆕

**行为**: Boss 召唤一面护盾，护盾有独立 HP。存活期间 Boss 免疫/大幅减伤。护盾对所有伤害有高基础减免，但存在**弱点反应**——用特定元素打护盾触发反应时，获得倍率加成。用其他元素打，不仅效率低，还会受到不同惩罚。

**威胁通知**: priorityTarget + bossState

| 参数 | 类型 | 说明 | 参考范围 |
|------|------|------|---------|
| hpPct | float | 护盾 HP = Boss maxHP × hpPct | 0.02~0.05 |
| bossDmgReduce | float | 护盾存活时 Boss 受到的减伤 | 0.70~0.90 |
| duration | float | 护盾最大持续时间（s） | 8~15 |
| cd | float | 冷却时间（s） | 16~25 |
| hpThreshold | float | 触发 HP 百分比 | 0.30~0.60 |
| baseResist | float | 护盾对所有伤害的基础减免 | 0.40~0.60 |

**特调部分**（每个 Boss 单独定义，不属于模板）:

#### 弱点反应

| 特调字段 | 类型 | 说明 |
|---------|------|------|
| weakReaction | string | 弱点反应名称（如 melt/corrode/vaporize） |
| weakElement | string | 触发弱点反应的元素 |
| weakMultiplier | float | 弱点反应伤害倍率（通常 2.0~4.0） |

#### 非弱点命中惩罚表 wrongHitEffects

每种元素命中护盾时的独立惩罚，由特调层定义：

| 命中类型 | 典型效果 | 设计意图 |
|---------|---------|---------|
| **同系元素** | 0 伤害 + 护盾/Boss 回血 | 惩罚最重，用冰打冰盾帮 Boss 回血 |
| **克制反转元素** | 微量伤害 + 反弹伤害给玩家 | 比如水打冰盾，盾把攻击冻住弹回 |
| **物理元素** | 减半伤害 + 降低玩家攻速 | 物理可以莽但有代价 |
| **中性元素** | 正常伤害但有高 baseResist 减免 | 不惩罚但效率极低 |

#### 超时惩罚 timeoutPenalty

护盾持续到 duration 结束仍未击破时触发：

| 惩罚选项 | 效果 | 适用场景 |
|---------|------|---------|
| explode | 护盾碎裂对玩家造成大范围伤害 | 高压 Boss |
| bossHeal | Boss 回复大量 HP | 持久战 Boss |
| bossBuff | Boss 获得临时增伤 buff | 逐步升级型 Boss |
| respawn | 立刻刷新护盾（更厚） | 极限压力 Boss |

**特调完整示例（第 13 章冰 Boss）**:
```
shield_reaction: {
    weakReaction: "melt",
    weakElement: "fire",
    weakMultiplier: 3.0,
    wrongHitEffects: {
        ice:      { shieldHeal: 0.05, bossHeal: 0.02 },
        water:    { reflect: 0.30 },
        physical: { atkSpeedReduce: 0.15, duration: 3.0 },
        arcane:   { dmgFactor: 0.7 },
        poison:   { dmgFactor: 0.5, dotOnSelf: 0.01 },
    },
    timeoutPenalty: { type: "bossHeal", healPct: 0.15 },
}
```

**特调完整示例（假设第 14 章毒 Boss）**:
```
shield_reaction: {
    weakReaction: "purify",
    weakElement: "fire",
    weakMultiplier: 2.5,
    wrongHitEffects: {
        poison:   { shieldHeal: 0.08 },
        water:    { spreadPoison: true, aoeRadius: 60 },
        fire:     { explode: true, selfDmgPct: 0.10 },
        physical: { corrosion: 0.05, maxStack: 5 },
        ice:      { dmgFactor: 0.6, slowSelf: 0.20 },
    },
    timeoutPenalty: { type: "bossBuff", atkBonus: 0.30, duration: 8.0 },
}
```

---

## 四、控场类模板（Control）

### CTL_field — 领域

**行为**: 以 Boss 为圆心的持续效果区域。是真实空间区域——角色在范围外不受影响，AI 可选择后撤脱离。

**威胁通知**: dangerZone（圆形）

| 参数 | 类型 | 说明 | 参考范围 |
|------|------|------|---------|
| radius | float | 区域半径（像素） | 80~160 |
| dmgMul | float | 每 tick 伤害 = ATK × dmgMul | 0.15~0.40 |
| tickRate | float | 伤害间隔（s） | 0.3~0.8 |
| duration | float | 区域持续时间（s） | 6~12 |
| cd | float | 冷却时间（s） | 12~20 |
| hpThreshold | float | 触发 HP 百分比（1.0=随时可用） | 0.40~1.0 |

**特调示例**:
- 冰章: 区域内减速 40~60%
- 火章: 区域内灼烧 DoT + 降低回血效果
- 毒章: 区域内叠加腐蚀降防

---

### CTL_barrier — 障壁

**行为**: 在战场边缘/指定位置生成实体墙壁，缩小有效活动区域。墙壁是实体，角色碰触会被弹开并受伤。

**威胁通知**: dangerZone（矩形）

| 参数 | 类型 | 说明 | 参考范围 |
|------|------|------|---------|
| count | int | 每次生成的墙壁数量 | 1~4 |
| duration | float | 墙壁持续时间（s） | 4~8 |
| contactDmgMul | float | 碰触伤害 = ATK × contactDmgMul | 0.2~0.5 |
| interval | float | 施放间隔（s） | 10~18 |

**特调示例**:
- 冰章: 冰墙，碰触冰冻 1s
- 火章: 火墙，碰触灼烧
- 奥术章: 扭曲屏障，碰触致混乱（随机移动 1s）

---

### CTL_vortex — 漩涡

**行为**: 在指定位置生成牵引区域，将角色持续拉向中心。核心区域伤害更高。

**威胁通知**: pull

| 参数 | 类型 | 说明 | 参考范围 |
|------|------|------|---------|
| radius | float | 牵引范围半径 | 60~120 |
| pullSpeed | float | 牵引速度（像素/s） | 20~50 |
| coreDmgMul | float | 核心区每 tick 伤害 = ATK × coreDmgMul | 0.3~0.8 |
| coreRadius | float | 核心高伤区域半径 | 20~40 |
| duration | float | 持续时间（s） | 3~6 |
| interval | float | 施放间隔（s） | 10~18 |

**特调示例**:
- 冰章: 核心区域冰冻
- 火章: 核心区域爆炸（到达中心触发一次大伤害）
- 水章: 持续时间更长，牵引速度递增

---

### CTL_decay — 持续衰减

**行为**: HP 低于阈值后，每秒持续削弱玩家某项属性。被 Boss 技能命中时额外叠加。

**威胁通知**: debuff（AI 感知到属性下降后可能调整策略）

| 参数 | 类型 | 说明 | 参考范围 |
|------|------|------|---------|
| hpThreshold | float | 触发 HP 百分比 | 0.40~0.60 |
| stat | string | 目标属性 | moveSpeed / atkSpeed / atk / def |
| reducePerSec | float | 每秒削减百分比 | 0.01~0.05 |
| maxReduce | float | 最大累计削减 | 0.20~0.50 |
| bonusOnHit | float | 被 Boss 技能命中时额外叠加量 | 0.03~0.08 |

**特调示例**:
- 冰章: stat=moveSpeed（减移速，配合减速场形成双重压制）
- 奥术章: stat=atkSpeed（减攻速，拉长战斗时间）
- 毒章: stat=def（腐蚀防御，受伤越来越痛）

---

## 五、召唤类模板（Summon）

### SUM_minion — 召唤小怪

**行为**: 定时召唤本章已有怪物。走正常敌人 AI 逻辑。

**威胁通知**: 无（普通敌人目标选择）

| 参数 | 类型 | 说明 | 参考范围 |
|------|------|------|---------|
| monsterId | string | 召唤的怪物 ID | 本章怪物 |
| count | int | 每次召唤数量 | 2~6 |
| interval | float | 召唤间隔（s） | 8~15 |

---

### SUM_guard — 嘲讽守卫

**行为**: 召唤带嘲讽效果的守卫。守卫存活时以 tauntWeight 权重吸引角色 AI 的目标选择。韧性高的 Build 可以抵抗嘲讽继续打 Boss，韧性低的会被吸引切换目标。

**威胁通知**: taunt

| 参数 | 类型 | 说明 | 参考范围 |
|------|------|------|---------|
| count | int | 每次召唤数量 | 1~3 |
| hpPct | float | 守卫 HP = Boss maxHP × hpPct | 0.005~0.02 |
| atkMul | float | 守卫 ATK = Boss ATK × atkMul | 0.2~0.5 |
| tauntWeight | float | 嘲讽权重（0~1），越高越难抵抗 | 0.3~0.8 |
| interval | float | 召唤间隔（s） | 12~20 |

**特调示例**:
- 冰章: 守卫自带减速光环
- 火章: 守卫死亡时自爆
- 毒章: 守卫存活时降低玩家回血效果

---

## 六、阶段控制模板（Phase）

### PHASE_transition — 阶段转换

**行为**: HP 达到阈值时触发阶段转换演出，切换到新的技能组。演出期间可设置无敌。

| 参数 | 类型 | 说明 | 参考范围 |
|------|------|------|---------|
| hpThreshold | float | 触发 HP 百分比 | 0.25~0.65 |
| duration | float | 演出时长（s） | 0.8~2.5 |
| invincible | bool | 演出期间是否无敌 | true/false |
| text | string | 演出文字 | "Boss名 进入XX状态！" |

---

## 七、Boss 组装格式

### 7.1 完整定义结构

```
BossName = {
    -- 基础属性
    base: { HP, ATK, DEF, speed, atkInterval },
    element: "章节主元素",
    weaknesses: { 元素: 减伤比例, ... },
    
    -- 阶段列表
    phases: [
        {
            name: "阶段名",
            trigger: { type: "hpBelow", value: 1.0 },
            transition: PHASE_transition { ... },     -- 可选
            skills: [
                模板ID { 参数... },
                模板ID { 参数... },
            ],
            -- 章节特调
            特调字段: { ... },
        },
        ...
    ]
}
```

### 7.2 组合约束（推荐遵守）

| 规则 | 说明 | 理由 |
|------|------|------|
| 每阶段至少 1 个攻击类 | 否则 Boss 无输出 | 保证战斗节奏 |
| 防御类每阶段不超过 2 个 | 过多防御→纯消耗战 | 保证战斗趣味 |
| 控场类按阶段递进 | 前期 0~1 个，后期 2~3 个 | 制造压迫感 |
| 召唤类每阶段最多 1 个 | 场上实体过多影响性能 | 保证帧率 |
| 后期技能要与前期形成 combo | 如 CTL_decay + CTL_vortex | 创造叠加压力 |
| 中 Boss 最多 2 阶段 | 中 Boss 不应太复杂 | 控制战斗时长 |
| 终 Boss 推荐 3 阶段 | 创造史诗感 | 阶段感体验 |

### 7.3 阶段技能数量参考

| Boss 类型 | 阶段一 | 阶段二 | 阶段三 |
|----------|--------|--------|--------|
| 中章 Boss | 2~3 技能 | 3~4 技能 | — |
| 终章 Boss | 2~3 技能 | 3~4 技能 | 3~4 技能 |

### 7.4 复用示例

同一个 `ATK_breath` 模板在不同章节的完全不同表现：

| 章节 | 参数调整 | 特调 | 战斗体验 |
|------|---------|------|---------|
| 第 11 章（火） | angle:45, dmgMul:0.7 | onHit: 灼烧 5s, 离开后持续掉血 | 被吐息扫到持续掉血 |
| 第 12 章（奥术） | angle:60, dmgMul:0.5 | onHit: 攻速降低 20% 3s | 被扫到攻速变慢 |
| 第 13 章（冰） | angle:60→90, dmgMul:0.5→0.65 | onHit: 减速 + bonusOnHit 叠加 CTL_decay | 被扫到越来越慢 |
| 假设 14 章（毒） | angle:90, dmgMul:0.4 | onHit: 叠毒 + 降防 | 被扫到越来越脆 |

---

## 八、新增模板流程

当现有模板无法满足需求时，按以下流程新增：

1. **确认现有模板无法通过特调实现需求**
2. **定义行为框架**（不含元素，不含特定效果）
3. **定义参数列表**（只放通用参数，特定效果放特调层）
4. **确定威胁通知类型**（从 §1.3 已有类型中选择，或提出新类型）
5. **编写 2~3 个不同章节的特调示例**（证明模板通用性）
6. **更新本文档**

---

## 九、技能释放贴图资源规范

### 9.1 命名规则

```
boss_{模板ID}_{元素}.png
```

**模板 ID 映射**:

| 模板 | 文件中的模板ID |
|------|--------------|
| ATK_barrage | barrage |
| ATK_breath | breath |
| ATK_spikes | spikes |
| ATK_pulse | pulse |
| ATK_detonate | detonate |
| DEF_armor | armor |
| DEF_crystal | crystal |
| DEF_shield | shield |
| CTL_field | field |
| CTL_barrier | barrier |
| CTL_vortex | vortex |

**元素 ID**: ice / fire / poison / arcane / water / physical

**示例**: `boss_barrage_ice.png`, `boss_shield_fire.png`, `boss_vortex_arcane.png`

### 9.2 存放路径

```
assets/Textures/skills/boss_{模板ID}_{元素}.png
```

代码引用: `"Textures/skills/boss_barrage_ice.png"`（不加 `assets/` 前缀）

### 9.3 尺寸规范

| 模板类型 | 尺寸 | 比例 | 说明 |
|---------|------|------|------|
| barrage | 64×64 | 1:1 | 小型弹体 |
| detonate | 64×64 | 1:1 | 小型爆炸物 |
| breath | 128×86 | 3:2 | 横向扇形/锥形 |
| barrier | 128×86 | 3:2 | 横向墙壁 |
| spikes | 86×128 | 2:3 | 纵向地刺 |
| crystal | 64×96 | 2:3 | 纵向晶体 |
| pulse, armor, shield, field, vortex | 128×128 | 1:1 | 环形/圆形效果 |

### 9.4 元素配色

| 元素 | 主色调 | 辅助色 |
|------|--------|--------|
| ice | 冰蓝/白 | 浅蓝/霜白 |
| fire | 红/橙 | 金黄/暗红 |
| poison | 绿/紫 | 暗绿/黄绿 |
| arcane | 紫/蓝紫 | 亮紫/白 |
| water | 深蓝/青 | 浅蓝/白 |
| physical | 灰/银 | 金属光泽/暗金 |

### 9.5 不需要贴图的模板

以下 4 个模板使用程序化渲染或复用其他资源，不需要专用贴图:

| 模板 | 原因 |
|------|------|
| DEF_regen | 粒子/数字特效，程序化绘制 |
| CTL_decay | Debuff 图标/滤镜效果 |
| SUM_minion | 复用本章已有怪物贴图 |
| SUM_guard | 复用本章已有怪物贴图 |
| PHASE_transition | 程序化屏幕特效（闪白/缩放） |

### 9.6 资源清单

**总计**: 11 模板 × 6 元素 = **66 张贴图**

| 元素 | 数量 | 状态 |
|------|------|------|
| ice | 11 | 已生成 |
| fire | 11 | 已生成 |
| poison | 11 | 已生成 |
| arcane | 11 | 已生成 |
| water | 11 | 已生成 |
| physical | 11 | 已生成 |
| **合计** | **66** | **66/66 完成** |

### 9.7 提示词参考

所有贴图生成时使用透明背景，弹体类（barrage/breath）朝右方向。各模板提示词要点:

| 模板 | 提示词要点 |
|------|-----------|
| barrage | {元素}能量弹丸，朝右飞行，拖尾特效，透明背景 |
| breath | {元素}吐息/喷射，扇形朝右扩散，透明背景 |
| spikes | {元素}地刺，从地面向上刺出，锐利，透明背景 |
| pulse | {元素}脉冲波/冲击环，圆形向外扩散，透明背景 |
| detonate | {元素}定时炸弹/能量球，发光倒计时，透明背景 |
| armor | {元素}护甲光环，环绕角色的防护层，透明背景 |
| crystal | {元素}水晶/晶体，发光漂浮，透明背景 |
| shield | {元素}魔法护盾，半球形防护罩，透明背景 |
| field | {元素}领域/法阵，俯视圆形区域，透明背景 |
| barrier | {元素}屏障/能量墙，横向排列，透明背景 |
| vortex | {元素}漩涡，螺旋吸引效果，透明背景 |

---

*最后更新: 2026-03-16*
