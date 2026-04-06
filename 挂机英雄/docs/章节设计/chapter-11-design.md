# 第十一章：焚天炼狱 — 设计文档

---

## 一、章节概要

| 字段 | 值 |
|------|-----|
| id | 11 |
| name | 焚天炼狱 |
| desc | 焚尽万物的炼狱烈焰 |
| 主元素 | fire |
| 弱点元素 | ice, water |
| 环境 | 永恒之火铸就的灼热领域，熔金岩浆流淌，灼烟遮天 |

---

## 二、Lore

> 永夜深渊的最底层并非终点——当黑暗被斩断后，一道炽热的光芒从深渊裂缝中喷涌而出。那是比深渊更古老的存在——焚天炼狱，一片由永恒之火铸就的灼热领域。熔金般的岩浆在脚下流淌，灼热的烟尘遮蔽天穹。炼狱将军·焚骨者守护着通往核心的通道，而焚天帝主·灭世之焰则是这片烈焰领域的至高主宰，其力量足以焚尽天地万物。这是你迄今为止最危险的征途。

**衔接上章**：第10章击败永夜深渊君王后，深渊裂缝中喷出炽热光芒，引向更古老的火焰领域。

---

## 三、怪物设计

### 3.1 怪物总览

| 编号 | ID | 名称 | 定位 | 元素 | HP | ATK | Speed | DEF |
|------|-----|------|------|------|-----|-----|-------|-----|
| M1 | pyre_imp | 焚炎小鬼 | 蜂群填充 | fire | 75 | 50 | 70 | 4 |
| M2 | inferno_blade | 炼狱刀客 | 精锐打手 | fire | 110 | 68 | 66 | 8 |
| M3 | molten_golem | 熔金傀儡 | 坦克肉盾 | physical | 350 | 48 | 22 | 35 |
| M4 | hellfire_caster | 狱火法师 | 远程法师 | fire | 200 | 62 | 40 | 16 |
| M5 | cinder_wraith | 余烬亡魂 | 自爆型 | fire | 90 | 55 | 76 | 2 |
| M6 | scorch_knight | 灼焰骑士 | 控制型 | fire | 160 | 65 | 50 | 11 |
| M7 | purgatory_giant | 炼狱巨兽 | 超级坦克 | physical | 900 | 40 | 6 | 70 |
| M8 | flame_hierophant | 烈焰祭司 | 精英祭司 | fire | 320 | 68 | 36 | 22 |
| B1 | boss_inferno_general | 炼狱将军·焚骨者 | 中Boss | fire | 1,100,000 | 400 | 18 | 52 |
| B2 | boss_pyre_sovereign | 焚天帝主·灭世之焰 | 终Boss | fire | 2,500,000 | 520 | 10 | 75 |

### 3.2 怪物详细设计

---

#### M1 — 焚炎小鬼 (pyre_imp)

**定位**：蜂群填充

| 属性 | 值 |
|------|-----|
| HP | 75 |
| ATK | 50 |
| Speed | 70 |
| DEF | 4 |
| atkInterval | 1.0s |
| element | fire |

**特殊能力**：
- `packBonus = 0.40`：≥4只同屏时 ATK+40%
- `packThreshold = 4`

**抗性**：

| fire | ice | poison | water | arcane | physical |
|------|-----|--------|-------|--------|----------|
| 0.40 | -0.25 | 0 | -0.15 | 0 | -0.10 |

**设计意图**：大量涌出的火焰小鬼，群体增伤机制迫使玩家尽快清场，否则 ATK 滚雪球。高火抗、弱冰/水。

**掉落**：exp=1100, gold={10, 16}

---

#### M2 — 炼狱刀客 (inferno_blade)

**定位**：精锐打手

| 属性 | 值 |
|------|-----|
| HP | 110 |
| ATK | 68 |
| Speed | 66 |
| DEF | 8 |
| atkInterval | 0.9s |
| element | fire |

**特殊能力**：
- `defPierce = 0.45`：无视 45% 防御
- `firstStrikeMul = 2.5`：首击伤害 ×2.5

**抗性**：

| fire | ice | poison | water | arcane | physical |
|------|-----|--------|-------|--------|----------|
| 0.35 | -0.20 | 0 | -0.15 | 0 | 0 |

**设计意图**：高攻速+穿防+首击倍增的刺客型怪物，对低防高血构建威胁极大。必须在首击后迅速击杀。

**掉落**：exp=1300, gold={12, 18}

---

#### M3 — 熔金傀儡 (molten_golem)

**定位**：坦克肉盾

| 属性 | 值 |
|------|-----|
| HP | 350 |
| ATK | 48 |
| Speed | 22 |
| DEF | 35 |
| atkInterval | 1.5s |
| element | physical |

**特殊能力**：
- `slowOnHit = 0.40`：命中减速 40%
- `slowDuration = 2.0s`
- `hpRegen = 0.025`：每 5s 回复 2.5% HP
- `hpRegenInterval = 5.0s`

**抗性**：

| fire | ice | poison | water | arcane | physical |
|------|-----|--------|-------|--------|----------|
| 0.30 | -0.15 | 0 | -0.25 | 0 | 0.25 |

**设计意图**：高防高血的肉盾，减速命中防止玩家走位规避，HP 回复增加持久战压力。物理元素不走火系高抗，但物理抗性本身较高，水系为最佳弱点。

**掉落**：exp=1600, gold={14, 22}

---

#### M4 — 狱火法师 (hellfire_caster)

**定位**：远程法师

| 属性 | 值 |
|------|-----|
| HP | 200 |
| ATK | 62 |
| Speed | 40 |
| DEF | 16 |
| atkInterval | 1.2s |
| element | fire |

**特殊能力**：
- `isRanged = true`：远程攻击
- `lifesteal = 0.18`：生命偷取 18%
- `healAura = { pct=0.05, interval=6.0, radius=100 }`：每 6s 治疗范围内友军 5% HP

**抗性**：

| fire | ice | poison | water | arcane | physical |
|------|-----|--------|-------|--------|----------|
| 0.45 | -0.25 | -0.10 | 0 | 0 | -0.10 |

**设计意图**：后排输出+治疗双重威胁。lifesteal 保证自身续航，healAura 加强周围怪物生存力。火抗最高（0.45），冰系是最佳克制元素。优先击杀目标。

**掉落**：exp=1400, gold={12, 18}

---

#### M5 — 余烬亡魂 (cinder_wraith)

**定位**：自爆型

| 属性 | 值 |
|------|-----|
| HP | 90 |
| ATK | 55 |
| Speed | 76 |
| DEF | 2 |
| atkInterval | 0.9s |
| element | fire |

**特殊能力**：
- `deathExplode = { element="fire", dmgMul=1.3, radius=55 }`：死亡爆炸，火伤 ×1.3，55像素范围
- `packBonus = 0.30`：≥5只同屏 ATK+30%
- `packThreshold = 5`

**抗性**：

| fire | ice | poison | water | arcane | physical |
|------|-----|--------|-------|--------|----------|
| 0.30 | -0.30 | 0 | -0.15 | 0 | 0 |

**设计意图**：高速冲向玩家，死亡后大范围火焰爆炸。群体出现时 packBonus 叠加攻击力，连锁爆炸可造成毁灭性伤害。冰系为最大弱点（-0.30）。

**掉落**：exp=1200, gold={10, 16}

---

#### M6 — 灼焰骑士 (scorch_knight)

**定位**：控制型

| 属性 | 值 |
|------|-----|
| HP | 160 |
| ATK | 65 |
| Speed | 50 |
| DEF | 11 |
| atkInterval | 1.1s |
| element | fire |

**特殊能力**：
- `venomStack = { dmgPctPerStack=0.03, stackMax=5, duration=5.0 }`：每次命中叠加灼伤，每层 +3% 持续伤害，最多 5 层，持续 5s

**抗性**：

| fire | ice | poison | water | arcane | physical |
|------|-----|--------|-------|--------|----------|
| 0.30 | -0.15 | -0.15 | 0 | 0 | 0 |

**设计意图**：灼伤叠加机制（venomStack），持续输出玩家。5层叠满 =15% 每秒持续伤害，对血量较低的构建威胁很大。冰和毒均为弱点。

**掉落**：exp=1300, gold={12, 18}

---

#### M7 — 炼狱巨兽 (purgatory_giant)

**定位**：超级坦克

| 属性 | 值 |
|------|-----|
| HP | 900 |
| ATK | 40 |
| Speed | 6 |
| DEF | 70 |
| atkInterval | 2.0s |
| element | physical |

**特殊能力**：
- `sporeCloud = { atkSpeedReducePct=0.30, duration=5.0 }`：孢子云减少玩家攻速 30%，持续 5s
- `hpRegen = 0.025`：每 5s 回复 2.5% HP
- `hpRegenInterval = 5.0s`

**抗性**：

| fire | ice | poison | water | arcane | physical |
|------|-----|--------|-------|--------|----------|
| 0.20 | 0 | -0.25 | -0.15 | 0 | 0.30 |

**设计意图**：全章最厚的肉盾（HP 900 + DEF 70），减攻速光环降低玩家 DPS，HP 回复拉长战斗。毒系为最大弱点（-0.25）。极慢移速（6）是唯一缺陷，远程构建可风筝。

**掉落**：exp=2400, gold={18, 28}

---

#### M8 — 烈焰祭司 (flame_hierophant)

**定位**：精英祭司

| 属性 | 值 |
|------|-----|
| HP | 320 |
| ATK | 68 |
| Speed | 36 |
| DEF | 22 |
| atkInterval | 1.3s |
| element | fire |

**特殊能力**：
- `isRanged = true`：远程攻击
- `antiHeal = true`：减疗
- `healAura = { pct=0.07, interval=7.0, radius=120 }`：每 7s 治疗范围内友军 7% HP，半径 120

**抗性**：

| fire | ice | poison | water | arcane | physical |
|------|-----|--------|-------|--------|----------|
| 0.40 | -0.20 | 0 | -0.20 | 0 | 0 |

**设计意图**：比狱火法师更强的祭司级远程。healAura 治疗量更高（7% vs 5%），范围更大（120 vs 100），同时自带 antiHeal 减疗压制玩家回复。是"持久战"策略的核心压力源，必须优先集火。冰/水均为弱点。

**掉落**：exp=1800, gold={14, 22}

---

### 3.3 中Boss — 炼狱将军·焚骨者 (boss_inferno_general)

| 属性 | 值 |
|------|-----|
| HP | 1,100,000 |
| ATK | 400 |
| Speed | 18 |
| DEF | 52 |
| atkInterval | 2.0s |
| element | fire |
| antiHeal | true |

**Boss 技能（标准三技能组合）**：

| 技能 | 参数 | 效果 |
|------|------|------|
| barrage | interval=7s, count=12, dmgMul=0.75, element=fire | 每 7s 向周围发射 12 枚火焰弹，每枚 0.75×ATK 伤害 |
| iceArmor | hpThreshold=0.50, dmgReduce=0.60, duration=5s, cd=13s | HP<50% 时触发，受伤减少 60%，持续 5s，CD 13s |
| summon | interval=10s, monsterId=pyre_imp, count=3 | 每 10s 召唤 3 只焚炎小鬼 |

**附加效果**：slowOnHit=0.35, slowDuration=2.0s

**抗性**：

| fire | ice | poison | water | arcane | physical |
|------|-----|--------|-------|--------|----------|
| 0.50 | -0.25 | 0.10 | -0.20 | 0 | 0.10 |

**掉落**：exp=65000, gold={1500, 2200}

**radius**=42, **color**={255, 100, 20}

**战术分析**：
- 火抗高达 0.50，冰系(-0.25)和水系(-0.20)为最佳输出元素
- 弹幕频率高（7s 12枚），需要移动规避或足够防御
- 50% 血量触发护盾，需要在 5s 窗口内保持输出
- 持续召唤焚炎小鬼，场上怪物数量持续增长，不能无限拉锯

---

### 3.4 终Boss — 焚天帝主·灭世之焰 (boss_pyre_sovereign)

| 属性 | 值 |
|------|-----|
| HP | 2,500,000 |
| ATK | 520 |
| Speed | 10 |
| DEF | 75 |
| atkInterval | 2.0s |
| element | fire |
| antiHeal | true |

**Boss 技能（标准四技能组合）**：

| 技能 | 参数 | 效果 |
|------|------|------|
| dragonBreath | interval=9s, dmgMul=1.3, element=fire | 每 9s 释放锥形火焰龙息，1.3×ATK 伤害 |
| frozenField | hpThreshold=0.55, slowRate=0.55, duration=8s, cd=15s | HP<55% 时释放灼热领域，减速 55%，持续 8s，CD 15s |
| iceArmor | hpThreshold=0.35, dmgReduce=0.65, duration=6s, cd=12s | HP<35% 时触发护盾，减伤 65%，持续 6s，CD 12s |
| iceRegen | hpThreshold=0.18, regenPct=0.03 | HP<18% 时每秒回复 3% HP |

**附加效果**：slowOnHit=0.45, slowDuration=2.5s

**抗性**：

| fire | ice | poison | water | arcane | physical |
|------|-----|--------|-------|--------|----------|
| 0.50 | -0.20 | 0.10 | -0.15 | 0 | 0.20 |

**掉落**：exp=85000, gold={1800, 2800}

**radius**=48, **color**={255, 160, 30}

**战术分析**：
- 全章最高火抗（0.50），冰系(-0.20)为最佳、水系(-0.15)次佳
- 三阶段战斗：
  - **Phase 1 (100%~55%)**：龙息 + 普攻减速，考验走位
  - **Phase 2 (55%~35%)**：灼热领域叠加减速（0.55 + 0.45），几乎无法移动，考验防御
  - **Phase 3 (<35%)**：护盾 + 回血双重防线，需要爆发窗口突破
- 18% 血量触发 3%/s 回血 = 75000 HP/s，DPS 必须压过此阈值
- 物理抗性 0.20 + DEF 75，物理构建在此Boss面前受阻

---

## 四、ScaleMul 与奖励

### 4.1 数值定位

| 参考点 | 值 |
|--------|-----|
| 上一章（10章）终点 | 400,000,000 |
| 章间跳跃倍率 | ×1.40 |
| 本章起点 | 560,000,000 |
| 章内倍率 | ×5.0 |
| 本章终点 | 2,800,000,000 |

### 4.2 关卡数值表

| 关卡 | 名称 | scaleMul | 相对倍率 | 波数 | 金币 | 品质保底 |
|------|------|----------|---------|------|------|---------|
| 11-1 | 焚天之路 | 560,000,000 | ×1.00 | 2 | 1,800 | 无 |
| 11-2 | 熔金走廊 | 610,000,000 | ×1.09 | 2 | 2,000 | 无 |
| 11-3 | 灰烬祭坛 | 720,000,000 | ×1.29 | 2 | 2,400 | 1 |
| 11-4 | 烈焰试炼场 | 950,000,000 | ×1.70 | 2 | 2,800 | 1 |
| 11-5 | **炼狱将军·焚骨者** | 1,200,000,000 | ×2.14 | 2 | 7,000 | **3** |
| 11-6 | 永焰殿堂 | 1,500,000,000 | ×2.68 | 2 | 3,200 | 2 |
| 11-7 | 毁灭熔炉 | 1,850,000,000 | ×3.30 | 3 | 4,000 | 2 |
| 11-8 | 炼狱深层 | 2,200,000,000 | ×3.93 | 3 | 4,500 | 2 |
| 11-9 | 焚天王座 | 2,500,000,000 | ×4.46 | 3 | 5,500 | 3 |
| 11-10 | **焚天帝主·灭世之焰** | 2,800,000,000 | ×5.00 | 2 | 18,000 | **4** |

---

## 五、波次详细设计

### 11-1 焚天之路（入门：纯蜂群）

| 波次 | 怪物组成 | 总数 |
|------|---------|------|
| wave 1 | pyre_imp ×48 | 48 |
| wave 2 | pyre_imp ×55 | 55 |

**设计意图**：纯焚炎小鬼蜂群，让玩家适应第11章节奏。48+55 的高数量测试 AOE 清场效率。packBonus 机制在数量堆积时触发，制造时间压力。

---

### 11-2 熔金走廊（引入刀客+傀儡）

| 波次 | 怪物组成 | 总数 |
|------|---------|------|
| wave 1 | pyre_imp ×30 + inferno_blade ×12 | 42 |
| wave 2 | inferno_blade ×14 + molten_golem ×4 | 18 |

**设计意图**：引入两大核心怪物。wave 1 蜂群中混入穿防刀客，测试玩家是否扛得住首击伤害。wave 2 引入坦克傀儡，减速 + 高防要求玩家有足够 DPS。

---

### 11-3 灰烬祭坛（自爆+骑士）

| 波次 | 怪物组成 | 总数 |
|------|---------|------|
| wave 1 | cinder_wraith ×18 + scorch_knight ×12 | 30 |
| wave 2 | scorch_knight ×14 + inferno_blade ×10 | 24 |

**设计意图**：自爆亡魂 + 灼伤骑士的组合。wave 1 的亡魂死亡爆炸连锁可在密集区域造成大量伤害。wave 2 灼伤叠加持续消耗血量。开始给出 quality=1 装备奖励。

---

### 11-4 烈焰试炼场（⚠️ 装备墙1）

| 波次 | 怪物组成 | 总数 |
|------|---------|------|
| wave 1 | molten_golem ×6 + hellfire_caster ×6 + pyre_imp ×25 | 37 |
| wave 2 | purgatory_giant ×3 + flame_hierophant ×4 + scorch_knight ×12 | 19 |

**设计意图**：第一道装备墙。wave 1 傀儡减速 + 法师后排输出 + 蜂群压力。wave 2 首次登场炼狱巨兽（DEF 70 + 减攻速）和烈焰祭司（远程 + healAura），考验玩家综合装备水平。

---

### 11-5 炼狱将军·焚骨者（中Boss）

| 波次 | 怪物组成 | 总数 |
|------|---------|------|
| wave 1 | pyre_imp ×32 + cinder_wraith ×18 + inferno_blade ×12 | 62 |
| wave 2 | **boss_inferno_general** ×1 + scorch_knight ×20 | 21 |

**设计意图**：wave 1 是高密度三类混合预热，蜂群+自爆+穿防的组合考验 AOE 和生存。wave 2 Boss 登场带 20 灼焰骑士护卫，骑士的 venomStack 叠加 + Boss 弹幕形成双重压力。

---

### 11-6 永焰殿堂（过渡：引入后半程组合）

| 波次 | 怪物组成 | 总数 |
|------|---------|------|
| wave 1 | flame_hierophant ×5 + hellfire_caster ×6 + molten_golem ×5 | 16 |
| wave 2 | purgatory_giant ×3 + flame_hierophant ×4 + cinder_wraith ×20 | 27 |

**设计意图**：后半程过渡关。wave 1 双祭司/法师远程组 + 傀儡前排。wave 2 巨兽 + 祭司 + 大量亡魂，healAura 治疗巨兽使其更难击杀。

---

### 11-7 毁灭熔炉（⚠️ 装备墙2，3波）

| 波次 | 怪物组成 | 总数 |
|------|---------|------|
| wave 1 | purgatory_giant ×5 + flame_hierophant ×5 + hellfire_caster ×5 | 15 |
| wave 2 | molten_golem ×6 + scorch_knight ×14 + inferno_blade ×12 | 32 |
| wave 3 | purgatory_giant ×4 + flame_hierophant ×4 + cinder_wraith ×22 + pyre_imp ×30 | 60 |

**设计意图**：三波地狱关。wave 1 巨兽墙+双祭司治疗，纯前排压力。wave 2 中型精英混合。wave 3 大混战，巨兽+祭司+亡魂+蜂群全上，亡魂自爆 + 巨兽减攻速 + 祭司 healAura 三重压力。

---

### 11-8 炼狱深层（全怪混合3波）

| 波次 | 怪物组成 | 总数 |
|------|---------|------|
| wave 1 | pyre_imp ×42 + inferno_blade ×14 + cinder_wraith ×14 | 70 |
| wave 2 | molten_golem ×5 + scorch_knight ×12 + hellfire_caster ×6 | 23 |
| wave 3 | purgatory_giant ×4 + flame_hierophant ×5 + scorch_knight ×12 + pyre_imp ×25 | 46 |

**设计意图**：全8种怪物登场的综合考验。wave 1 高密度快速怪群冲击。wave 2 中坚力量。wave 3 重型 + 祭司 + 中型 + 蜂群的全面混战。

---

### 11-9 焚天王座（⚠️ 装备墙3，终极难度墙）

| 波次 | 怪物组成 | 总数 |
|------|---------|------|
| wave 1 | purgatory_giant ×6 + flame_hierophant ×6 + hellfire_caster ×5 | 17 |
| wave 2 | molten_golem ×6 + scorch_knight ×14 + inferno_blade ×14 | 34 |
| wave 3 | purgatory_giant ×5 + flame_hierophant ×5 + molten_golem ×5 + cinder_wraith ×20 | 35 |

**设计意图**：Boss 前最后一关，难度极高。wave 1 全重型单位（6巨兽+6祭司+5法师），healAura 交叉治疗。wave 2 精英部队。wave 3 双坦克（巨兽+傀儡）+ 祭司 + 自爆亡魂，考验装备是否达到终Boss水准。quality=3 奖励帮助玩家最后补强。

---

### 11-10 焚天帝主·灭世之焰（终Boss）

| 波次 | 怪物组成 | 总数 |
|------|---------|------|
| wave 1 | purgatory_giant ×4 + flame_hierophant ×5 + molten_golem ×5 + hellfire_caster ×5 | 19 |
| wave 2 | **boss_pyre_sovereign** ×1 + pyre_imp ×50 + inferno_blade ×14 | 65 |

**设计意图**：wave 1 全精英预热，4巨兽+5祭司+5傀儡+5法师，纯重型单位混战。wave 2 Boss 登场，带 50 蜂群和 14 穿防刀客。Boss 龙息 + 减速场 + 蜂群 packBonus + 刀客穿防首击，四重压力同时施加。

---

## 六、抗性体系总览

| 怪物 | fire | ice | poison | water | arcane | physical |
|------|------|-----|--------|-------|--------|----------|
| pyre_imp | **0.40** | -0.25 | 0 | -0.15 | 0 | -0.10 |
| inferno_blade | **0.35** | -0.20 | 0 | -0.15 | 0 | 0 |
| molten_golem | 0.30 | -0.15 | 0 | **-0.25** | 0 | **0.25** |
| hellfire_caster | **0.45** | **-0.25** | -0.10 | 0 | 0 | -0.10 |
| cinder_wraith | 0.30 | **-0.30** | 0 | -0.15 | 0 | 0 |
| scorch_knight | 0.30 | -0.15 | -0.15 | 0 | 0 | 0 |
| purgatory_giant | 0.20 | 0 | **-0.25** | -0.15 | 0 | **0.30** |
| flame_hierophant | **0.40** | -0.20 | 0 | -0.20 | 0 | 0 |
| boss_inferno_general | **0.50** | **-0.25** | 0.10 | -0.20 | 0 | 0.10 |
| boss_pyre_sovereign | **0.50** | -0.20 | 0.10 | -0.15 | 0 | 0.20 |

**克制策略**：
- **冰系构建**：对 6/10 怪物有效（含两个Boss），是本章最通用的克制元素
- **水系构建**：对傀儡(-0.25)和祭司(-0.20)效果最佳，对Boss中等有效
- **毒系构建**：仅对巨兽(-0.25)和骑士/法师(-0.10~-0.15)有效，非主流选择
- **火系构建**：本章几乎完全无效（全员火抗 0.20~0.50）

---

## 七、设计检查清单

- [x] 10 个关卡，Boss 在关 5 和关 10
- [x] 8 个普通怪 + 2 个 Boss，覆盖蜂群/打手/坦克/远程/自爆/控制/超坦/祭司
- [x] scaleMul：560M → 2.8B，章内 ×5.0，章间 ×1.40（上章 400M × 1.40 = 560M）
- [x] 金币奖励：1,800 → 18,000，Boss5=7,000，Boss10=18,000
- [x] Boss5 品质=3，Boss10 品质=4
- [x] 所有怪物有 resist 表（fire 主系高抗，ice/water 为主弱点）
- [x] 中Boss 有 barrage(12枚) + iceArmor(0.60减伤) + summon(pyre_imp×3)
- [x] 终Boss 有 dragonBreath(1.3×) + frozenField(0.55减速) + iceArmor(0.65减伤) + iceRegen(3%)
- [x] lore 衔接第10章（永夜深渊）结局
- [x] 怪物命名风格统一（火焰/炼狱主题）
- [x] 数值比第10章怪物提升 ~25%

---

*文档版本: v1.0*
*基于 StageConfig.lua 实际数据整理*
*最后更新: 2026-03-11*
