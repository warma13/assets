# 章节设计规范 v1.0

> 《挂机英雄·术士》章节关卡设计标准文档

---

## 一、章节结构规范

### 1.1 基本结构

每章由以下要素组成：

| 要素 | 说明 |
|------|------|
| id | 章节编号（从1开始，递增） |
| name | 章节名称（4字，如"灰烬荒原"） |
| desc | 一句话描述（10字以内） |
| lore | 剧情背景（100-200字，衔接上一章结局） |
| stages[] | 10个关卡 |

### 1.2 关卡布局（10关制）

| 关卡 | 定位 | Boss | 波数 | 设计目标 |
|------|------|------|------|---------|
| 1 | 入门 | 否 | 2 | 纯蜂群，引入章节主力小怪 |
| 2 | 引入 | 否 | 2 | 引入第2类怪物（如肉盾/穿防） |
| 3 | 变奏 | 否 | 2 | 引入第3类怪物（速度/特殊机制） |
| 4 | 墙 | 否 | 2 | 引入精英怪组合，装备检定 |
| **5** | **中Boss** | **是** | **2** | Boss + 小怪群，DPS检定 |
| 6 | 过渡 | 否 | 2 | 引入后半程新怪物 |
| 7 | 墙 | 否 | 2-3 | 高难组合，装备检定 |
| 8 | 综合 | 否 | 3 | 全种类混合大混战 |
| 9 | 终极墙 | 否 | 3 | 最高难度非Boss关，全精英 |
| **10** | **终Boss** | **是** | **2** | 终极Boss + 大量小怪 |

### 1.3 Boss关固定模式

**中Boss（关卡5）**：
- wave 1：精英怪预热（2类混合）
- wave 2：Boss ×1 + 大量填充小怪

**终Boss（关卡10）**：
- wave 1：高难混合怪群（3类以上）
- wave 2：Boss ×1 + 大量填充小怪 + 中型怪

---

## 二、怪物设计规范

### 2.1 每章怪物配额

| 类型 | 数量 | 说明 |
|------|------|------|
| 普通怪 | 8 | 包含多种定位（见2.2） |
| 中Boss | 1 | 关卡5的Boss |
| 终Boss | 1 | 关卡10的Boss |
| **合计** | **10** | — |

### 2.2 怪物定位矩阵（8个普通怪的标准配置）

每章的8个普通怪应覆盖以下定位：

| 编号 | 定位 | HP | 速度 | 特征 | 示例能力 |
|------|------|-----|------|------|---------|
| M1 | 蜂群填充 | 低 | 中高 | 低血量、大数量 | packBonus |
| M2 | 精锐打手 | 中 | 中高 | 高攻、中血 | defPierce, firstStrikeMul |
| M3 | 坦克肉盾 | 极高 | 极低 | 高DEF高HP | hpRegen, slowOnHit |
| M4 | 远程法师 | 中 | 中低 | 远程、控制 | isRanged, healAura |
| M5 | 自爆型 | 低中 | 中高 | 死亡爆炸 | deathExplode, packBonus |
| M6 | 控制型 | 中 | 中 | 减速/毒素 | slowOnHit, venomStack |
| M7 | 超级坦克 | 极高 | 极低 | 最厚肉盾 | hpRegen, sporeCloud |
| M8 | 精英祭司 | 高 | 中低 | 远程+治疗 | isRanged, healAura, antiHeal |

> 不要求严格一一对应，可根据主题灵活调整，但应覆盖"蜂群/打手/坦克/远程/自爆/控制"这些核心定位。

### 2.3 怪物模板字段

```lua
monster_id = {
    name = "显示名称",
    hp = 数值,          -- 基础生命值
    atk = 数值,         -- 基础攻击力
    speed = 数值,       -- 移动速度 (0=固定, 6~80)
    def = 数值,         -- 防御值
    atkInterval = 数值, -- 攻击间隔(秒)
    element = "元素",   -- fire/ice/poison/water/arcane/physical/holy

    -- 可选能力（按需添加）
    packBonus = 倍率,          -- 群体增伤（达到packThreshold时）
    packThreshold = 数量,      -- 群体增伤触发阈值
    defPierce = 比例,          -- 无视DEF百分比
    firstStrikeMul = 倍率,     -- 首击伤害倍率
    slowOnHit = 比例,          -- 命中减速比例
    slowDuration = 秒数,       -- 减速持续时间
    deathExplode = { element, dmgMul, radius },  -- 死亡爆炸
    isRanged = true/false,     -- 远程攻击
    lifesteal = 比例,          -- 生命偷取
    antiHeal = true/false,     -- 减疗标记
    hpRegen = 比例,            -- HP回复百分比
    hpRegenInterval = 秒数,    -- 回复间隔
    healAura = { pct, interval, radius }, -- 治疗光环
    venomStack = { dmgPctPerStack, stackMax, duration }, -- 毒素叠加
    sporeCloud = { atkSpeedReducePct, duration }, -- 孢子云减攻速
    summon = { interval, monsterId, count }, -- 召唤（仅Boss）
    barrage = { interval, count, dmgMul, element }, -- 弹幕（仅Boss）
    dragonBreath = { interval, dmgMul, element }, -- 龙息（仅Boss）
    frozenField = { hpThreshold, slowRate, duration, cd }, -- 减速场（仅Boss）
    iceArmor = { hpThreshold, dmgReduce, duration, cd }, -- 护盾（仅Boss）
    iceRegen = { hpThreshold, regenPct }, -- Boss回血

    -- 掉落与外观
    expDrop = 数值,
    goldDrop = { min, max },
    image = "贴图路径",
    radius = 数值,             -- 碰撞半径(像素)
    color = { r, g, b },       -- 显示颜色
    isBoss = true/false,

    -- 抗性表（第4章起必须添加）
    resist = {
        fire = 0,    -- 范围 -0.30 ~ 0.50
        ice = 0,
        poison = 0,
        water = 0,
        arcane = 0,
        physical = 0,
        -- holy = 0, -- 第9章起可选
    },
}
```

### 2.4 Boss能力模板

**中Boss（关卡5）** — 固定3技能组合：

| 技能 | 说明 | 参数参考 |
|------|------|---------|
| barrage | 弹幕攻击 | interval=7-8s, count=6-12, dmgMul=0.5-0.75 |
| iceArmor | 低血量护盾 | hpThreshold=0.50, dmgReduce=0.50-0.60, duration=3-5s, cd=13-15s |
| summon | 召唤小怪 | interval=10s, count=3, monsterId=本章蜂群怪 |

**终Boss（关卡10）** — 固定4技能组合：

| 技能 | 说明 | 参数参考 |
|------|------|---------|
| dragonBreath | 锥形AOE | interval=9-10s, dmgMul=1.3-2.0 |
| frozenField | 减速场 | hpThreshold=0.55-0.60, slowRate=0.55-0.60, duration=8s, cd=15-20s |
| iceArmor | 低血量护盾 | hpThreshold=0.35, dmgReduce=0.60-0.65, duration=5-6s, cd=12s |
| iceRegen | 低血量回复 | hpThreshold=0.18-0.30, regenPct=0.003-0.03 |

### 2.5 抗性设计规则

**从第4章起所有怪物必须有 resist 表**。

设计原则：
1. **本章主元素抗性高**（0.20 ~ 0.50）— 鼓励玩家使用克制元素
2. **弱点元素抗性为负**（-0.15 ~ -0.30）— 提供可利用的弱点
3. **无关元素为 0** — 不影响中性伤害
4. **Boss抗性略高于普通怪** — 但弱点更明显

**元素克制参考**：

| 章节元素 | 高抗 | 弱点 |
|---------|------|------|
| fire | fire 0.30-0.50 | ice -0.15~-0.30, water -0.15~-0.25 |
| ice | ice 0.20-0.40 | fire -0.20~-0.30 |
| poison | poison 0.30-0.50 | fire -0.15~-0.30 |
| water | water 0.30-0.50 | ice -0.15~-0.25 |
| arcane | arcane 0.20-0.50 | water -0.15~-0.20, poison -0.15~-0.20 |
| physical | physical 0.20-0.30 | arcane -0.10~-0.20 |
| holy | holy 0.35-0.55 | poison -0.15~-0.25 |

---

## 三、数值递进规范

### 3.1 ScaleMul 递进

ScaleMul 是该关卡怪物模板数值的全局乘数，决定了整体难度。

**历史数据**：

| 章节 | Stage 1 | Stage 10 | 章内倍率 | 章间跳跃(上章末→本章初) |
|------|---------|----------|----------|----------------------|
| 1 | 1.4 | 7.8 | ×5.6 | — |
| 2 | 12.0 | 60.0 | ×5.0 | 7.8→12.0 (×1.54) |
| 3 | 88.0 | 422.0 | ×4.8 | 60→88 (×1.47) |
| 4 | 600.0 | 3,460.0 | ×5.8 | 422→600 (×1.42) |
| 5 | 4,600.0 | 24,600.0 | ×5.3 | 3,460→4,600 (×1.33) |
| 6 | 33,000.0 | 175,000.0 | ×5.3 | 24,600→33,000 (×1.34) |
| 7 | 240,000.0 | 1,300,000.0 | ×5.4 | 175,000→240,000 (×1.37) |
| 8 | 1,800,000.0 | 10,000,000.0 | ×5.6 | 1,300,000→1,800,000 (×1.38) |
| 9 | 14,000,000.0 | 55,000,000.0 | ×3.9 | 10,000,000→14,000,000 (×1.40) |
| 10 | 77,000,000.0 | 400,000,000.0 | ×5.2 | 55,000,000→77,000,000 (×1.40) |
| 11 | 560,000,000.0 | 2,800,000,000.0 | ×5.0 | 400,000,000→560,000,000 (×1.40) |

**设计公式**：
- **章内倍率**: Stage 10 ≈ Stage 1 × 5.0（范围 4.0~6.0）
- **章间跳跃**: 本章 Stage 1 ≈ 上章 Stage 10 × 1.4（范围 1.33~1.54，后期稳定在 1.40）
- **章内10关递进**: 大致等比递增，前半平缓后半陡峭

**章内 scaleMul 分配参考（以倍率曲线为例）**：

| 关卡 | 占比系数（相对 Stage 1） |
|------|----------------------|
| 1 | ×1.00 |
| 2 | ×1.20 |
| 3 | ×1.45 |
| 4 | ×1.75 |
| 5 (中Boss) | ×2.10 |
| 6 | ×2.50 |
| 7 | ×3.00 |
| 8 | ×3.60 |
| 9 | ×4.30 |
| 10 (终Boss) | ×5.00 |

### 3.2 金币奖励递进

**历史数据**：

| 章节 | 最小金币(Stage 1) | 最大金币(Stage 10 Boss) | Boss5金币 |
|------|------------------|----------------------|----------|
| 1 | 30 | 350 | 150 |
| 2 | 60 | 800 | 300 |
| 3 | 140 | 1,500 | 600 |
| 4 | 200 | 2,500 | 1,000 |
| 5 | 300 | 4,000 | 1,500 |
| 6 | 500 | 6,000 | 2,500 |
| 7 | 700 | 8,000 | 3,500 |
| 8 | 900 | 10,000 | 4,500 |
| 9 | 1,200 | 12,000 | 5,500 |
| 10 | 1,500 | 15,000 | 6,500 |
| 11 | 1,800 | 18,000 | 8,000 |

**递进规律**：
- Stage 1 金币 ≈ 上一章 × 1.2~1.5
- Boss10 金币 ≈ Stage 1 × 10
- Boss5 金币 ≈ Boss10 × 0.45

### 3.3 装备品质奖励

| 关卡类型 | guaranteeEquipQuality |
|---------|---------------------|
| 普通关（前期） | 无 或 1 |
| 普通关（后期） | 2 |
| 装备墙关 | 2~3 |
| 中Boss (关5) | 3 |
| 终Boss (关10) | 4 |

### 3.4 怪物基础数值参考（第11章为基准）

第11章怪物基础数值范围：

| 属性 | 蜂群 | 打手 | 坦克 | 远程 | 自爆 | Boss(中) | Boss(终) |
|------|------|------|------|------|------|---------|---------|
| HP | 75-90 | 110-160 | 200-350 | 200-320 | 90 | ~1,100,000 | ~2,500,000 |
| ATK | 50-55 | 65-68 | 40-48 | 62-68 | 55 | 400 | 520 |
| Speed | 66-76 | 50-66 | 6-22 | 36-40 | 76 | 18 | 10 |
| DEF | 2-4 | 8-11 | 35-70 | 16-22 | 2 | 52 | 75 |
| atkInterval | 0.9-1.0 | 0.9-1.1 | 1.5-2.0 | 1.2-1.3 | 0.9 | 2.0 | 2.0 |

**新章节数值应比上一章提升约 20-30%**。

### 3.5 Boss HP 递进

Boss HP 不受 scaleMul 影响（Boss有独立HP），历史数据：

| 章节 | 中Boss HP | 终Boss HP | 倍率(中) | 倍率(终) |
|------|----------|----------|---------|---------|
| 1 | 800 | 2,500 | — | — |
| 2 | 3,500 | 8,000 | ×4.4 | ×3.2 |
| 11 | 1,100,000 | 2,500,000 | — | — |

> Boss HP 后期通过 scaleMul 缩放实现，基础 HP 保持在百万级。

---

## 四、波次设计规范

### 4.1 每关波次数量

| 关卡 | 波数 | 说明 |
|------|------|------|
| 1-6 | 2 | 节奏明快 |
| 7-9 | 2-3 | 增加压力和持久战 |
| 5, 10 (Boss) | 2 | 预热波 + Boss波 |

### 4.2 每波怪物数量

| 怪物类型 | 每波数量范围 |
|---------|------------|
| 蜂群小怪 | 15~35 |
| 中型怪 | 6~12 |
| 精英/坦克 | 3~8 |
| Boss | 1 |

### 4.3 波次组合原则

1. **前半程（关1-4）**：逐步引入新怪物，从单种到2-3种混合
2. **中Boss（关5）**：预热波考验DPS，Boss波测试综合能力
3. **后半程（关6-9）**：引入剩余怪物，组合越来越复杂
4. **终Boss（关10）**：全怪种大混战预热 + Boss决战

---

## 五、主题与剧情规范

### 5.1 已使用主题

| 章节 | 主题 | 主元素 | 环境 |
|------|------|--------|------|
| 1 | 灰烬荒原 | fire/混合 | 焰息城外废墟 |
| 2 | 冰封深渊 | ice | 冰霜巨人领地 |
| 3 | 熔岩炼狱 | fire/poison | 地下熔岩世界 |
| 4 | 幽暗墓域 | arcane/physical | 亡灵墓地 |
| 5 | 深海渊域 | water | 深海遗迹 |
| 6 | 雷鸣荒漠 | arcane(雷) | 雷暴沙漠 |
| 7 | 瘴毒密林 | poison | 远古密林 |
| 8 | 虚空裂隙 | arcane(虚空) | 虚空维度 |
| 9 | 天穹圣域 | holy | 神界圣域 |
| 10 | 永夜深渊 | arcane(暗) | 黑暗深渊 |
| 11 | 焚天炼狱 | fire | 终极火焰领域 |

### 5.2 剧情衔接规则

- 每章 lore 首句应衔接上一章的结局
- 格式：「[上一章结局的简述]后，术士[来到新章节的原因]」
- lore 应包含：环境描写 + Boss/敌人背景 + 冒险动机

### 5.3 命名规范

- **章节名**：4字（偶尔5字），意境化
- **关卡名**：2-4字地点名（如"冰封隘口""枯骨田野"），Boss关用Boss名
- **怪物名**：2-4字（蜂群怪可2字，Boss用"·"分隔称号）
- **Boss命名格式**：
  - 中Boss：`[称号]·[名字]`（如"骨冠领主·厄亡"）
  - 终Boss：`[称号]·[名字]`（如"焚天帝主·灭世之焰"）

---

## 六、设计检查清单

新章节交付前，逐项检查：

- [ ] 10个关卡，Boss在关5和关10
- [ ] 8个普通怪 + 2个Boss，覆盖6种定位
- [ ] scaleMul 递进符合 ×5.0 章内倍率、×1.40 章间跳跃
- [ ] 金币奖励递进合理
- [ ] Boss5 品质=3，Boss10 品质=4
- [ ] 怪物数值比上一章提升 20-30%
- [ ] 第4章起所有怪物有 resist 表
- [ ] 中Boss 有 barrage + iceArmor + summon
- [ ] 终Boss 有 dragonBreath + frozenField + iceArmor + iceRegen
- [ ] lore 衔接上一章结局
- [ ] 怪物命名风格统一
- [ ] 主题元素未与前11章重复（或有足够差异化）

---

## 七、第12章设计

### 7.1 主题选择

**已用元素**：fire×3, ice×1, poison×1, water×1, arcane×3, physical×1, holy×1

**推荐**：**时空/时间** — 一个全新的概念维度，引入"时间扭曲"机制。

### 7.2 章节概要

| 字段 | 值 |
|------|-----|
| id | 12 |
| name | 时渊回廊 |
| desc | 时间尽头的回廊 |
| 主元素 | arcane (时空亚型) |
| 弱点元素 | fire, physical |
| 环境 | 时空扭曲的回廊，过去未来交错 |

### 7.3 Lore

> 焚天帝主的灭世之焰被扑灭后，术士发现炼狱深处隐藏着一道扭曲的时空裂缝。裂缝的另一端是「时渊回廊」——一片时间法则崩塌的混沌维度。这里的生物拥有操纵时间的能力：它们可以加速自身、减缓敌人、甚至在临死前回溯时间。回廊的尽头是「永恒钟主·克洛诺斯」，一个妄图吞噬所有时间线的远古存在。若不将其击败，过去和未来都将被吞噬为虚无。

### 7.4 怪物设计

#### 普通怪（8个）

**M1 — 时隙蜉蝣 (chrono_mite)**
- 定位：蜂群填充
- 属性：hp=95, atk=62, speed=72, def=5, atkInterval=1.0
- 元素：arcane
- 能力：packBonus=0.45, packThreshold=4
- 特色：时空裂隙中涌出的微型虫群
- 抗性：{ fire=-0.25, ice=0, poison=0, water=0, arcane=0.40, physical=-0.15 }

**M2 — 回溯刺客 (rewind_assassin)**
- 定位：精锐打手
- 属性：hp=130, atk=82, speed=70, def=10, atkInterval=0.9
- 元素：arcane
- 能力：defPierce=0.50, firstStrikeMul=2.8
- 特色：能回溯到攻击前一刻的刺客，首击致命
- 抗性：{ fire=-0.20, ice=0, poison=0, water=-0.10, arcane=0.35, physical=-0.20 }

**M3 — 永恒哨卫 (eternal_sentinel)**
- 定位：坦克肉盾
- 属性：hp=450, atk=55, speed=20, def=42, atkInterval=1.5
- 元素：physical
- 能力：hpRegen=0.03, hpRegenInterval=5.0, slowOnHit=0.40, slowDuration=2.0
- 特色：被时间凝固的远古守卫，近乎不朽
- 抗性：{ fire=-0.15, ice=0, poison=-0.20, water=0, arcane=0.30, physical=0.30 }

**M4 — 时序术士 (chrono_mage)**
- 定位：远程法师
- 属性：hp=250, atk=75, speed=38, def=18, atkInterval=1.2
- 元素：arcane
- 能力：isRanged=true, lifesteal=0.20
- 特色：操纵时间流速的法师，偷取生命延续自身
- 抗性：{ fire=-0.20, ice=0.10, poison=-0.15, water=0, arcane=0.45, physical=-0.10 }

**M5 — 时裂游魂 (rift_phantom)**
- 定位：自爆型
- 属性：hp=110, atk=65, speed=78, def=3, atkInterval=0.9
- 元素：arcane
- 能力：deathExplode={ element="arcane", dmgMul=1.5, radius=58 }, packBonus=0.35, packThreshold=5
- 特色：时空裂隙中逸散的幽灵，死亡时引发时空崩塌
- 抗性：{ fire=-0.25, ice=0, poison=0, water=0, arcane=0.35, physical=0 }

**M6 — 迟滞蛛母 (stasis_spider)**
- 定位：控制型
- 属性：hp=190, atk=72, speed=45, def=14, atkInterval=1.1
- 元素：arcane
- 能力：venomStack={ dmgPctPerStack=0.04, stackMax=6, duration=5.0 }, slowOnHit=0.35, slowDuration=2.5
- 特色：编织时间之网的蛛母，被缠住的目标行动越来越慢
- 抗性：{ fire=-0.20, ice=0, poison=-0.15, water=0, arcane=0.35, physical=0 }

**M7 — 时渊巨像 (epoch_colossus)**
- 定位：超级坦克
- 属性：hp=1100, atk=48, speed=6, def=85, atkInterval=2.0
- 元素：physical
- 能力：sporeCloud={ atkSpeedReducePct=0.35, duration=5.0 }, hpRegen=0.03, hpRegenInterval=5.0
- 特色：由无数时间碎片凝聚而成的巨像，极度坚固
- 抗性：{ fire=-0.15, ice=0, poison=-0.25, water=0, arcane=0.25, physical=0.35 }

**M8 — 永劫祭司 (aeon_hierophant)**
- 定位：精英祭司
- 属性：hp=400, atk=80, speed=34, def=26, atkInterval=1.3
- 元素：arcane
- 能力：isRanged=true, antiHeal=true, healAura={ pct=0.08, interval=7.0, radius=120 }
- 特色：侍奉克洛诺斯的祭司，能加速同伴恢复
- 抗性：{ fire=-0.20, ice=0, poison=0, water=-0.15, arcane=0.45, physical=0 }

#### 中Boss — 时空裂主·弗拉克图斯 (boss_rift_lord)
- hp=1,400,000, atk=480, speed=18, def=62
- atkInterval=2.0, element="arcane", antiHeal=true
- slowOnHit=0.40, slowDuration=2.0
- barrage={ interval=7.0, count=14, dmgMul=0.80, element="arcane" }
- iceArmor={ hpThreshold=0.50, dmgReduce=0.62, duration=5.0, cd=13.0 }
- summon={ interval=10.0, monsterId="chrono_mite", count=4 }
- expDrop=78000, goldDrop={ 1800, 2600 }
- radius=44, color={ 160, 120, 255 }, isBoss=true
- resist={ fire=-0.25, ice=0.10, poison=0.10, water=-0.15, arcane=0.50, physical=-0.15 }

#### 终Boss — 永恒钟主·克洛诺斯 (boss_chrono_sovereign)
- hp=3,200,000, atk=620, speed=10, def=90
- atkInterval=2.0, element="arcane", antiHeal=true
- slowOnHit=0.50, slowDuration=2.5
- dragonBreath={ interval=9.0, dmgMul=1.5, element="arcane" }
- frozenField={ hpThreshold=0.55, slowRate=0.58, duration=8.0, cd=15.0 }
- iceArmor={ hpThreshold=0.35, dmgReduce=0.68, duration=6.0, cd=12.0 }
- iceRegen={ hpThreshold=0.18, regenPct=0.035 }
- expDrop=100000, goldDrop={ 2200, 3400 }
- radius=50, color={ 180, 140, 255 }, isBoss=true
- resist={ fire=-0.20, ice=0.10, poison=0.10, water=-0.10, arcane=0.55, physical=-0.10 }

### 7.5 ScaleMul 设计

上一章（11章）终点：2,800,000,000
章间跳跃 ×1.40 → 第12章起点：3,920,000,000
章内倍率 ×5.0 → 第12章终点：19,600,000,000

| 关卡 | 名称 | scaleMul | 波数 | 金币 | 品质保底 |
|------|------|----------|------|------|---------|
| 12-1 | 时裂入口 | 3,920,000,000 | 2 | 2,200 | 无 |
| 12-2 | 回忆长廊 | 4,700,000,000 | 2 | 2,800 | 无 |
| 12-3 | 停滞之间 | 5,700,000,000 | 2 | 3,400 | 1 |
| 12-4 | 悖论花园 | 6,860,000,000 | 2 | 4,200 | 1 |
| 12-5 | 时空裂主·弗拉克图斯 | 8,230,000,000 | 2 | 9,500 | 3 |
| 12-6 | 碎片回廊 | 9,800,000,000 | 2 | 5,000 | 2 |
| 12-7 | 永劫祭坛 | 11,760,000,000 | 2-3 | 6,200 | 2 |
| 12-8 | 时序熔炉 | 14,110,000,000 | 3 | 7,800 | 2 |
| 12-9 | 因果终端 | 16,860,000,000 | 3 | 10,000 | 3 |
| 12-10 | 永恒钟主·克洛诺斯 | 19,600,000,000 | 2 | 22,000 | 4 |

### 7.6 波次详细设计

**12-1 时裂入口**（纯蜂群）
- wave 1: chrono_mite ×30
- wave 2: chrono_mite ×35

**12-2 回忆长廊**（引入刺客）
- wave 1: chrono_mite ×22, rewind_assassin ×8
- wave 2: chrono_mite ×18, rewind_assassin ×10

**12-3 停滞之间**（引入坦克）
- wave 1: eternal_sentinel ×5, chrono_mite ×22
- wave 2: eternal_sentinel ×6, rewind_assassin ×8

**12-4 悖论花园**（装备墙：控制+远程）
- wave 1: stasis_spider ×8, chrono_mage ×6, chrono_mite ×12
- wave 2: stasis_spider ×6, chrono_mage ×8, rewind_assassin ×8

**12-5 时空裂主·弗拉克图斯**（中Boss）
- wave 1: chrono_mage ×8, stasis_spider ×8, chrono_mite ×15
- wave 2: boss_rift_lord ×1, chrono_mite ×30

**12-6 碎片回廊**（引入自爆+祭司）
- wave 1: rift_phantom ×12, aeon_hierophant ×4, chrono_mite ×15
- wave 2: rift_phantom ×10, aeon_hierophant ×5, eternal_sentinel ×4

**12-7 永劫祭坛**（装备墙：超级坦克登场）
- wave 1: epoch_colossus ×3, chrono_mage ×6, chrono_mite ×15
- wave 2: epoch_colossus ×4, aeon_hierophant ×5, stasis_spider ×6
- wave 3: epoch_colossus ×3, rewind_assassin ×10, rift_phantom ×8

**12-8 时序熔炉**（全种类3波混战）
- wave 1: chrono_mite ×20, rewind_assassin ×10, rift_phantom ×8
- wave 2: stasis_spider ×8, chrono_mage ×6, eternal_sentinel ×5
- wave 3: epoch_colossus ×3, aeon_hierophant ×5, rewind_assassin ×8

**12-9 因果终端**（终极墙：全精英）
- wave 1: epoch_colossus ×4, chrono_mage ×8, stasis_spider ×6
- wave 2: aeon_hierophant ×6, rift_phantom ×12, rewind_assassin ×10
- wave 3: epoch_colossus ×3, aeon_hierophant ×4, eternal_sentinel ×6, chrono_mage ×6

**12-10 永恒钟主·克洛诺斯**（终Boss）
- wave 1: aeon_hierophant ×6, stasis_spider ×8, rewind_assassin ×10, epoch_colossus ×3
- wave 2: boss_chrono_sovereign ×1, chrono_mite ×35, rift_phantom ×8

---

## 附录A：怪物ID命名规范

格式：`[形容词]_[生物类型]`（全小写，下划线分隔）

| 类型 | 命名示例 |
|------|---------|
| 蜂群 | ash_rat, frost_imp, chrono_mite |
| 打手 | inferno_blade, rewind_assassin |
| 坦克 | glacier_beetle, eternal_sentinel |
| 远程 | cryo_mage, chrono_mage |
| 自爆 | molten_sprite, rift_phantom |
| 控制 | spore_shroom, stasis_spider |
| 超坦 | purgatory_giant, epoch_colossus |
| 祭司 | flame_hierophant, aeon_hierophant |
| 中Boss | boss_[称号]（如 boss_rift_lord） |
| 终Boss | boss_[称号]（如 boss_chrono_sovereign） |

## 附录B：图片资源命名规范

格式：`Textures/mobs/mob_[monster_id]_[时间戳].png`

Boss: `Textures/mobs/mob_boss_[id]_[时间戳].png`

---

*文档版本: v1.0*
*最后更新: 2026-03-11*
*适用范围: 第12章及后续章节设计*
