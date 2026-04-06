# 第 13 章 Boss 设计：「寒渊冰域」

> **版本**: v2.0 | **更新日期**: 2026-03-16
>
> 基于 Boss 技能模板库（见 `Boss技能模板库.md`）重新设计。
> 本文档只包含 Boss 技能设计，怪物/套装/波次等内容见 `第十三章设计文档.md`。

---

## 设计理念

### 与旧设计的区别

| 维度 | 旧设计（v1） | 新设计（v2） |
|------|------------|------------|
| 技能来源 | 直接定义，与其他章节 Boss 高度重复 | 从模板库选取 + 章节特调 |
| 伤害方式 | 全部自动命中（barrage/dragonBreath 直接扣血） | 真实空间物体，AI 可感知和躲避 |
| AI 交互 | 无（Boss 技能与角色 AI 完全解耦） | 威胁通知系统，AI 自主决策 |
| 阶段感 | 仅 HP 阈值触发被动，无明确阶段转换 | 明确阶段转换演出 + 技能组切换 |
| 两 Boss 差异 | 中 Boss = 终 Boss 弱化版 | 完全不同的战斗风格 |

### 两个 Boss 的定位差异

| 维度 | 格拉西恩（中 Boss） | 尼弗海姆（终 Boss） |
|------|-------------------|-------------------|
| 战斗风格 | 暴风输出型：技能频率高、攻击密集 | 控场碾压型：空间压缩、压力递增 |
| AI 决策重点 | 躲弹幕/冰柱 + 打冰晶图腾的优先级 | 管理空间 + 应对反应护盾 + 阶段三冰晶抢时 |
| Build 偏好 | 高攻速高移速 → 更容易躲弹 | 高韧性高冰抗 → 抵抗减速链 |
| 失败原因 | DPS 不够，被弹幕 + 蚁群淹没 | 空间被压缩 + 移速衰减，无法走位 |
| 阶段数 | 2 阶段 | 3 阶段 |

---

## Boss 1：霜暴领主·格拉西恩 (boss_frost_lord)

### 基础属性

| 属性 | 值 |
|------|-----|
| HP | 1,700,000 |
| ATK | 576 |
| DEF | 74 |
| 速度 | 16 |
| 攻击间隔 | 2.0 |
| element | ice |
| isBoss | true |

### 弱点

| 元素 | 抗性 | 说明 |
|------|------|------|
| fire | -0.30 | 最大弱点 |
| poison | -0.20 | 次要弱点 |
| physical | -0.10 | 微弱弱点 |
| arcane | 0.10 | 微抗 |
| water | 0.35 | 高抗 |
| ice | 0.50 | 极高抗 |

### 阶段一（100%→55%）：弹幕风暴

Boss 以高频率的弹幕和地面威胁保持压力，同时召唤蚁群膨胀场上怪物数量。

| 技能槽 | 模板 | 参数 |
|--------|------|------|
| 主攻 | **ATK_barrage** | count: 16, spread: 120°, dmgMul: 0.85, speed: 200, interval: 6s |
| 地面威胁 | **ATK_spikes** | count: 3, radius: 35, delay: 1.2s, dmgMul: 1.2, lingerTime: 4s, interval: 8s |
| 召唤 | **SUM_minion** | monsterId: frost_mite, count: 5, interval: 9s |

**章节特调**:

| 特调项 | 内容 |
|--------|------|
| barrage.onHit | 每颗弹命中叠加减速 10%，持续 1.5s |
| spikes.linger | 残留冰柱接触时减速 30%，形成地形障碍 |

**AI 威胁信号**:
- 弹幕：每颗弹体注册 dangerZone（半径 12），AI 可横向移动躲避部分弹幕
- 冰柱：预警阶段注册 dangerZone（半径 35，priority 0.7），AI 收到后可选择移开

---

### 阶段转换（55% HP）

```
PHASE_transition {
    hpThreshold: 0.55,
    duration: 1.0,
    invincible: true,
    text: "霜暴领域！"
}
```

Boss 1s 蓄力演出，周围冰晶爆裂，之后进入阶段二。

---

### 阶段二（55%→0%）：冰原领域

弹幕收窄但更密集，新增领域控场和可摧毁的冰晶回血源。AI 面临多重决策：躲避弹幕、脱离领域、打冰晶。

| 技能槽 | 模板 | 参数 |
|--------|------|------|
| 主攻 | **ATK_barrage** | count: 20, spread: 90°（收窄更密集）, dmgMul: 0.85, speed: 220, interval: 6s |
| 领域 | **CTL_field** | radius: 120, dmgMul: 0.30, tickRate: 0.5s, duration: 8s, cd: 14s, hpThreshold: 0.55 |
| 减伤 | **DEF_armor** | hpThreshold: 0.45, dmgReduce: 0.65, duration: 5s, cd: 13s |
| 回血源 | **DEF_crystal** | count: 2, hpPct: 0.02, healPct: 0.015, spawnInterval: 12s, spawnRadius: 80 |

**章节特调**:

| 特调项 | 内容 |
|--------|------|
| field.effect | 领域内减速 40% |
| crystal.onDestroy | 冰晶被摧毁时爆裂，造成半径 40 范围 ×0.5 ATK 冰伤 |
| armor.visual | 冰晶护甲包裹效果 |

**AI 威胁信号**:
- 领域：注册 dangerZone（半径 120，持续 8s）。AI 权衡"退出领域损失 DPS 时间" vs "留在领域吃伤害+减速"
- 冰晶：注册 priorityTarget（priority 0.6）。AI 权衡"切目标打晶体阻止回血" vs "无视晶体强打 Boss"
- 护甲期间：注册 bossState（dmgReduce 0.65）。AI 可趁此去清蚁群/冰晶

**格拉西恩战斗节奏**:
```
阶段一: 躲弹幕(120°扇形) + 走出冰柱预警 + 清蚁群
    ↓ HP 55% 转换演出
阶段二: 躲弹幕(90°更密集) + 进出领域 + 打冰晶阻止回血 + 等护甲CD
```

---

## Boss 2：冰渊至尊·尼弗海姆 (boss_ice_sovereign)

### 基础属性

| 属性 | 值 |
|------|-----|
| HP | 3,900,000 |
| ATK | 745 |
| DEF | 108 |
| 速度 | 9 |
| 攻击间隔 | 2.2 |
| element | ice |
| isBoss | true |

### 弱点

| 元素 | 抗性 | 说明 |
|------|------|------|
| fire | -0.25 | 最大弱点 |
| poison | -0.15 | 次要弱点 |
| arcane | -0.10 | 微弱弱点 |
| physical | 0.10 | 微抗 |
| water | 0.40 | 高抗 |
| ice | 0.60 | 极高抗 |

### 阶段一（100%→60%）：寒潮试探

Boss 以扇形吐息和扩散脉冲控制空间，同时召唤嘲讽守卫分散 AI 火力。节奏相对缓慢但每招都有空间压力。

| 技能槽 | 模板 | 参数 |
|--------|------|------|
| 主攻 | **ATK_breath** | angle: 60°, range: 150, dmgMul: 0.50, tickRate: 0.3s, duration: 1.5s, interval: 8s |
| 脉冲 | **ATK_pulse** | speed: 80, width: 20, maxRadius: 200, dmgMul: 0.8, hitEffect: stun, hitDuration: 0.5s, interval: 10s |
| 嘲讽守卫 | **SUM_guard** | count: 2, hpPct: 0.01, atkMul: 0.4, tauntWeight: 0.6, interval: 15s |

**章节特调**:

| 特调项 | 内容 |
|--------|------|
| breath.onHit | 命中叠加 frostbite（每次 +5% 减移速，配合阶段二 CTL_decay） |
| pulse.hitEffect | stun（定身 0.5s），冰主题视觉 |
| guard.aura | 守卫自带半径 40 的减速光环（减速 20%），迫使 AI 优先处理 |

**AI 威胁信号**:
- 吐息：注册 dangerZone（扇形 60°，半径 150，持续 1.5s）。AI 可向侧面移动躲出
- 脉冲环：注册 expandingRing。AI 评估冰环到达时间，决定向内穿越或后撤
- 守卫：注册 taunt（weight 0.6）。韧性高的 Build 可抵抗嘲讽，韧性低的会被吸引切换目标

---

### 阶段转换（60% HP）

```
PHASE_transition {
    hpThreshold: 0.60,
    duration: 1.5,
    invincible: true,
    text: "绝对零度！"
}
```

Boss 1.5s 演出，全屏短暂白闪，冰爆扩散。

---

### 阶段二（60%→30%）：空间压缩

核心是通过冰墙缩小安全区 + 反应护盾考验元素构建 + 持续衰减移速。战斗空间越来越小，移速越来越慢。

| 技能槽 | 模板 | 参数 |
|--------|------|------|
| 主攻 | **ATK_breath** | angle: 90°（扩大）, range: 150, dmgMul: 0.65, tickRate: 0.3s, duration: 1.5s, interval: 8s |
| 领域 | **CTL_field** | radius: 140, dmgMul: 0.35, tickRate: 0.5s, duration: 10s, cd: 16s, hpThreshold: 0.60 |
| 障壁 | **CTL_barrier** | count: 2, duration: 6s, contactDmgMul: 0.3, interval: 14s |
| 衰减 | **CTL_decay** | hpThreshold: 0.60, stat: moveSpeed, reducePerSec: 0.02, maxReduce: 0.30, bonusOnHit: 0.05 |
| 反应护盾 | **DEF_shield** | hpPct: 0.03, bossDmgReduce: 0.80, duration: 10s, cd: 18s, hpThreshold: 0.50, baseResist: 0.50 |

**章节特调**:

| 特调项 | 内容 |
|--------|------|
| field.effect | 领域内减速 55% |
| barrier.onContact | 碰触冰墙冰冻 1s + ×0.3 ATK 冰伤 |
| decay.combo | 被 breath/pulse 命中时额外叠加 5% 减移速，与 decay 自然叠加形成加速恶化 |
| shield.reaction | 见下方详细定义 |

**反应护盾特调**:

```
shield_reaction: {
    weakReaction: "melt"             -- 火打冰 = 融化
    weakElement: "fire"
    weakMultiplier: 3.0              -- 火元素对护盾 ×3 伤害

    wrongHitEffects: {
        ice: {                       -- 冰打冰盾：最重惩罚
            shieldHeal: 0.05         -- 护盾回复 5% 自身 HP
            bossHeal: 0.02           -- Boss 回复 2% maxHP
        }
        water: {                     -- 水打冰盾：反弹
            reflect: 0.30            -- 反弹 30% 伤害给玩家
        }
        physical: {                  -- 物理打冰盾：降攻速
            atkSpeedReduce: 0.15
            duration: 3.0
        }
        arcane: {                    -- 奥术打冰盾：中性偏弱
            dmgFactor: 0.7           -- 伤害 7 折，无额外惩罚
        }
        poison: {                    -- 毒打冰盾：低效+自伤
            dmgFactor: 0.5
            dotOnSelf: 0.01          -- 每秒自伤 1% maxHP，持续 3s
        }
    }

    timeoutPenalty: {                -- 10s 内未击破
        type: "bossHeal"
        healPct: 0.15                -- Boss 回复 15% HP
    }
}
```

**AI 威胁信号**:
- 领域：dangerZone（半径 140）。远程 Build 更容易脱离
- 冰墙：dangerZone（矩形）。AI 将冰墙纳入移动边界计算
- 护盾：priorityTarget（priority 0.8）+ bossState。AI 切换目标打护盾
- 衰减：debuff。AI 感知移速下降，可能调整风筝距离

---

### 阶段转换（30% HP）

```
PHASE_transition {
    hpThreshold: 0.30,
    duration: 2.0,
    invincible: true,
    text: "万物终将冰封！"
}
```

Boss 2s 演出，周围冰晶爆裂 + 全屏冰霜扩散视觉。

---

### 阶段三（30%→0%）：永冻绞杀

全面压制阶段。漩涡牵引 + 被 decay 叠满的减移速 = 难以逃脱。限时引爆的冰晶迫使 AI 在"打冰晶保命"和"抢 Boss 最后血量"间做抉择。

| 技能槽 | 模板 | 参数 |
|--------|------|------|
| 减伤 | **DEF_armor** | hpThreshold: 0.30, dmgReduce: 0.72, duration: 7s, cd: 14s |
| 回血 | **DEF_regen** | hpThreshold: 0.30, regenPct: 0.03 |
| 漩涡 | **CTL_vortex** | radius: 100, pullSpeed: 30, coreDmgMul: 0.6, coreRadius: 30, duration: 4s, interval: 12s |
| 限时引爆 | **ATK_detonate** | count: 4, hpPct: 0.008, timer: 8s, dmgMul: 2.0, bossHealPct: 0.10, interval: once |

**章节特调**:

| 特调项 | 内容 |
|--------|------|
| vortex.core | 核心区域冰冻 1s，配合 decay 已叠加的减移速几乎无法逃脱 |
| detonate.onExplode | 爆炸后全场冰冻 2s + Boss 回复 10% HP |
| armor.visual | 永冻铠甲，更浓厚的冰晶包裹效果 |
| regen.note | 3% 而非 v1 的 4%，因为新机制已足够拖延战斗 |

**AI 威胁信号**:
- 漩涡：注册 pull（radius 100, pullSpeed 30）。AI 将牵引力纳入移动向量抵抗。若移速被 decay 叠满 -30%，可能无法完全逃离
- 冰晶引爆：注册 priorityTarget（priority 0.95，极高）。AI 几乎一定切换目标打冰晶。这给 Boss 8s 喘息窗口（护甲减伤 + 回血）

**尼弗海姆战斗节奏**:
```
阶段一: 侧移躲吐息(60°) + 穿越/后退避脉冲环 + 处理嘲讽守卫
    ↓ HP 60% 转换演出
阶段二: 在冰墙缩小的空间内躲吐息(90°) + 进出领域 + 打反应护盾(火队优势)
         同时 decay 不断叠加减移速，空间越来越紧
    ↓ HP 30% 转换演出
阶段三: 抵抗漩涡牵引 + 8s内打掉4个冰晶(否则全场爆炸+Boss回血)
         护甲+回血 vs 玩家DPS 的最终决战
```

---

## 与第 12 章 Boss 对比

### 数值对比

| 属性 | 12 章中 Boss | 13 章中 Boss | 12 章终 Boss | 13 章终 Boss |
|------|------------|------------|------------|------------|
| HP | 1,400,000 | 1,700,000 (+21%) | 3,200,000 | 3,900,000 (+22%) |
| ATK | 480 | 576 (+20%) | 620 | 745 (+20%) |
| DEF | 62 | 74 (+19%) | 90 | 108 (+20%) |

### 机制对比

| 维度 | 12 章 Boss（旧模式） | 13 章 Boss（新模板） |
|------|-------------------|-------------------|
| 中 Boss 技能 | barrage + iceArmor + summon（3 技能无阶段） | ATK_barrage + ATK_spikes + SUM_minion → CTL_field + DEF_armor + DEF_crystal（6 技能 2 阶段） |
| 终 Boss 技能 | dragonBreath + frozenField + chronoDecay + iceArmor + iceRegen（5 技能无阶段） | ATK_breath + ATK_pulse + SUM_guard → CTL_field + CTL_barrier + CTL_decay + DEF_shield → DEF_armor + DEF_regen + CTL_vortex + ATK_detonate（11 技能 3 阶段） |
| 独有机制 | chronoDecay（仅终 Boss） | 反应护盾 DEF_shield（终 Boss 阶段二），限时引爆 ATK_detonate（终 Boss 阶段三） |
| AI 交互 | 无 | 全流程威胁通知 |

---

## 套装联动分析

### 熔岩征服者（攻击套）vs Boss

| Boss 技能 | 熔岩征服者的应对优势 |
|----------|-------------------|
| DEF_shield（反应护盾） | 火元素 weakMultiplier ×3.0，快速击破护盾 |
| DEF_armor（冰甲） | 点燃 DoT 在减伤期间仍有效（虽然减半），不浪费 DPS 窗口 |
| DEF_crystal（冰晶） | 4 件套熔岩爆发的 AOE 扩散可同时清冰晶+蚁群 |
| CTL_field（领域） | 火伤不受冰减速影响，高 DPS 可减少领域内停留时间 |

### 极寒之心（防御套）vs Boss

| Boss 技能 | 极寒之心的应对优势 |
|----------|-------------------|
| CTL_decay（减移速） | 6 件套免疫减速，decay 无效 |
| CTL_field（领域） | 冰抗 +40% + 受冰伤回血，可以站在领域内硬扛 |
| ATK_pulse（脉冲环） | 4 件套免死 + 清除减速，被脉冲命中后立刻解控 |
| CTL_vortex（漩涡） | 免疫减速后移速不衰减，更容易挣脱牵引 |

---

## 实现检查清单

### 新增系统模块

| 模块 | 说明 | 优先级 |
|------|------|--------|
| 威胁通知系统 | 威胁表结构 + 注册/注销 API | P0 |
| PlayerAI 威胁评估 | AI 读取威胁表，影响移动向量和目标选择 | P0 |
| 空间弹体系统 | barrage 弹体有真实位置/速度/碰撞 | P0 |
| 扇形区域检测 | breath 的扇形 dangerZone 空间检测 | P0 |
| 脉冲环系统 | expandingRing 的扩散 + 碰撞检测 | P1 |
| 反应护盾系统 | DEF_shield 的元素反应判定 + 惩罚表 | P1 |
| 障壁系统 | CTL_barrier 的实体墙碰撞 | P1 |
| 漩涡牵引系统 | CTL_vortex 的牵引力计算 | P1 |
| 限时引爆系统 | ATK_detonate 的倒计时 + 摧毁判定 | P1 |
| 阶段转换系统 | PHASE_transition 演出 + 技能组切换 | P0 |

### 可复用旧系统

| 旧系统 | 对应新模板 | 改造程度 |
|--------|----------|---------|
| barrage（EnemySystem） | ATK_barrage | 需改为真实空间弹体 |
| dragonBreath（EnemySystem） | ATK_breath | 需改为持续区域 |
| frozenField（EnemySystem） | CTL_field | 需改为真实空间区域 |
| iceArmor（EnemySystem） | DEF_armor | 可直接复用 |
| iceRegen（EnemySystem） | DEF_regen | 可直接复用 |
| summon（EnemySystem） | SUM_minion | 可直接复用 |

---

## 美术资源规范

### 放置规则

| 类型 | 尺寸 | 存放路径 | 引用方式（代码中） |
|------|------|---------|-------------------|
| 怪物贴图 | 256×256, 透明背景 | `assets/Textures/mobs/{id}.png` | `"Textures/mobs/{id}.png"` |
| 战斗背景 | 1024×512, 不透明 | `assets/Textures/battle_bg_ch13.png` | `"Textures/battle_bg_ch13.png"` (BattleView CHAPTER_BG[13]) |
| 关卡选择背景 | 512×1024, 不透明 | `assets/Textures/stage_map_bg_ch13.png` | `"Textures/stage_map_bg_ch" .. chapter .. ".png"` (StageSelect 动态拼接) |
| 套装徽章 | 128×128, 透明背景 | `assets/Textures/Items/set_{setId}_badge.png` | `"Textures/Items/set_{setId}_badge.png"` |
| 套装部位图标 | 128×128, 透明背景 | `assets/Textures/Items/{setId}_{slot}.png` | `"Textures/Items/{setId}_{slot}.png"` |

> **关键规则**: `assets/` 和 `scripts/` 均为资源根目录，代码引用时**不加** `assets/` 前缀。

### 怪物贴图提示词

**通用后缀**: `像素风RPG怪物,全身,朝右,无UI,无文字,透明背景`

| ID | 名称 | 提示词（拼接通用后缀） |
|----|------|----------------------|
| frost_mite | 霜蚀虫群 | 冰蓝色半透明甲虫虫群,身体覆盖霜晶,多足,周围有细小冰碎片飘散 |
| ice_stalker | 冰棘猎手 | 冰刺覆盖的敏捷刺客,身披浅蓝色冰霜斗篷,手持双冰刺匕首,身体边缘有冰晶残影 |
| permafrost_beast | 永冻巨兽 | 被永冻冰层包裹的远古野兽,厚重的冰蓝色冰晶铠甲覆盖全身,体型粗壮,四足行走 |
| glacier_caster | 冰川术士 | 冰系法师,穿翡翠蓝色长袍,手持冰晶法杖,头顶悬浮冰球,周围有水流环绕 |
| cryo_wraith | 冰晶爆破者 | 不稳定的冰晶幽灵,半透明冰蓝色身体布满裂纹,体内蕴含即将爆发的冰霜能量,散发不稳定的冷光 |
| rime_weaver | 霜织蛛 | 冰霜蜘蛛,浅蓝色半透明甲壳,八条腿上结满冰霜,吐出冰丝,腹部有雪花图案 |
| glacial_titan | 冰渊泰坦 | 巨大的冰之巨人,由层层冰川和翡翠色冰晶拼合而成,体型极其庞大笨重,双眼发出幽绿光芒 |
| frostfall_priest | 冰潮祭司 | 冰系祭司,穿戴华丽的冰蓝长袍和水晶高冠,手持冰霜权杖,身后有冰晶光环 |

### Boss 贴图提示词

**通用后缀**: `像素风RPG Boss怪物,全身,朝右,无UI,无文字,透明背景`

| ID | 名称 | 提示词（拼接通用后缀） |
|----|------|----------------------|
| boss_frost_lord | 霜暴领主·格拉西恩 | 高大的冰霜领主,身穿闪耀的冰晶战甲,背后有巨大的冰暴漩涡,手持巨大冰枪,威严霸气,体型比普通怪大两倍 |
| boss_ice_sovereign | 冰渊至尊·尼弗海姆 | 终极冰之王者,由纯净的极光能量和远古冰川构成,头顶巨大的冰冠王冠散发极光,手持永冻之杖,身后展开六翼冰晶,终极Boss气场 |

### 场景背景提示词

| 用途 | 比例 | 提示词 |
|------|------|--------|
| 战斗背景 | 16:9 | 翡翠冰蓝色冰面地面,冰裂纹理中透出幽绿极光,散落的冰晶碎片闪烁微光,霜花覆盖的古老石板,2D俯视角,俯视地面纹理,暗黑奇幻RPG游戏战斗场景地面,无任何UI元素,无任何文字,无图标,纯背景,无任何装饰元素 |
| 关卡选择背景 | 4:5 | 翡翠冰蓝色极地冰川裂隙,巨大冰柱矗立,极光在天空中舞动散发幽绿冷光,冰晶折射出七彩光芒,远处冰封的远古神殿隐约可见,暗黑奇幻RPG游戏风格,精细插画,竖版构图,无任何UI元素,无任何文字,无图标,纯背景 |

### 套装贴图提示词

**熔岩征服者 (lava_conqueror)** — 色调: 炽红橙色

| 类型 | 提示词 |
|------|--------|
| 徽章 | 熔岩火焰徽章图标,炽红橙色调,中心是燃烧的火焰之心,边框由熔岩岩石构成,精致奇幻RPG徽章,圆形徽章设计,金属边框,透明背景,无文字 |
| weapon | 燃烧的熔岩法杖,杖头是炽热火球,杖身有熔岩纹理,RPG装备图标,炽红橙色调,精致细节,透明背景,无文字,无背景 |
| gloves | 熔岩护手,岩浆纹理覆盖,指尖冒出火焰,RPG装备图标,炽红橙色调,精致细节,透明背景,无文字,无背景 |
| amulet | 火焰护符,中心镶嵌红色宝石,周围有火焰纹饰,RPG装备图标,炽红橙色调,精致细节,透明背景,无文字,无背景 |
| ring | 熔岩戒指,岩浆材质指环,镶嵌燃烧的红宝石,RPG装备图标,炽红橙色调,精致细节,透明背景,无文字,无背景 |
| boots | 熔岩战靴,厚重岩石底部,靴面有熔岩裂纹发出红光,RPG装备图标,炽红橙色调,精致细节,透明背景,无文字,无背景 |
| necklace | 火焰项链,链条由熔岩环扣组成,坠子是微型火焰宝珠,RPG装备图标,炽红橙色调,精致细节,透明背景,无文字,无背景 |

**极寒之心 (permafrost_heart)** — 色调: 翡翠冰蓝色

| 类型 | 提示词 |
|------|--------|
| 徽章 | 永冻冰晶徽章图标,翡翠冰蓝色调,中心是冰封的心脏形冰晶,边框由霜花冰棱构成,精致奇幻RPG徽章,盾形徽章设计,银色边框,透明背景,无文字 |
| weapon | 冰霜法杖,杖头是悬浮的冰晶球,杖身覆盖霜花,RPG装备图标,翡翠冰蓝色调,精致细节,透明背景,无文字,无背景 |
| gloves | 冰晶护手,半透明冰蓝材质,指尖结霜,RPG装备图标,翡翠冰蓝色调,精致细节,透明背景,无文字,无背景 |
| amulet | 冰心护符,中心镶嵌蓝色冰晶,周围有雪花纹饰,RPG装备图标,翡翠冰蓝色调,精致细节,透明背景,无文字,无背景 |
| ring | 永冻戒指,冰晶材质指环,镶嵌幽蓝宝石,RPG装备图标,翡翠冰蓝色调,精致细节,透明背景,无文字,无背景 |
| boots | 霜晶战靴,冰蓝色靴面覆盖霜花纹理,靴底有冰棱,RPG装备图标,翡翠冰蓝色调,精致细节,透明背景,无文字,无背景 |
| necklace | 冰心项链,银色链条,坠子是微型冰封水滴形宝石,RPG装备图标,翡翠冰蓝色调,精致细节,透明背景,无文字,无背景 |

### 资源清单汇总

| 类型 | 数量 | 状态 |
|------|------|------|
| 普通怪物贴图 | 8 张 | 已生成 |
| Boss 贴图 | 2 张 | 已生成 |
| 战斗背景 | 1 张 | 已生成 |
| 关卡选择背景 | 1 张 | 已生成 |
| 套装徽章 | 2 张 | 已生成 |
| 套装部位图标 | 12 张 | 已生成 |
| **合计** | **26 张** | 26/26 完成 |

---

*最后更新: 2026-03-16*
