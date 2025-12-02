// 保卫小镇游戏数值配置
module.exports = {
  // 小镇属性
  town: {
    maxHp: 100,           // 小镇初始血量
    x: 375,               // 小镇X坐标（地图中心：750/2=375，rpx单位）
    y: 500                // 小镇Y坐标（地图中心：1000/2=500，rpx单位）
  },

  // 炮台属性  
  turret: {
    initialCount: 1,      // 初始炮台数量
    maxCount: 6,          // 最大炮台数量
    attackInterval: 2000, // 攻击间隔(ms)
    range: 200,           // 攻击范围(rpx)
    initialDamage: 1,     // 初始攻击力
    bulletSpeed: 10       // 子弹移动速度(rpx/frame)
  },

  // 怪物属性
  monster: {
    baseSpawnInterval: 3000,  // 基础怪物生成间隔(ms) - 从4500降低到3000，加快生成
    initialHp: 1,         // 前期怪物血量
    moveSpeed: 2.5,       // 怪物移动速度(rpx/frame) - 提升到2.5，增加难度
    attackDamage: 1,      // 怪物攻击力 - 保持为1
    attackInterval: 6000, // 怪物攻击间隔(ms) - 保持6000
    attackRange: 60,      // 怪物攻击范围(rpx)
    // Boss属性
    bossHpMultiplier: 3,  // Boss血量倍数
    bossAtkMultiplier: 2, // Boss攻击力倍数
    bossSpeedMultiplier: 0.6, // Boss移动速度倍数
    // 怪物群属性
    groupSize: 2          // 每个怪物群的数量
  },

  // 经验值和升级系统
  experience: {
    gainRate: 1,          // 每次注意力超过基线获得的经验值
    checkInterval: 500,   // 经验值检查间隔(ms)
    levelThresholds: [    // 各等级所需经验值（降低升级所需经验）
      8,    // 1级->2级: 8经验，获得第2个炮台
      18,   // 2级->3级: 10经验，获得第3个炮台  
      30,   // 3级->4级: 12经验，获得第4个炮台
      45,   // 4级->5级: 15经验，获得第5个炮台
      63,   // 5级->6级: 18经验，获得第6个炮台
      85,   // 6级->7级: 22经验，升级单个炮台
      110,  // 7级->8级: 25经验，升级单个炮台
      140,  // 8级->9级: 30经验，升级单个炮台
      175,  // 9级->10级: 35经验，升级单个炮台
      215,  // 10级->11级: 40经验，升级单个炮台
      260,  // 11级->12级: 45经验
      310,  // 12级->13级: 50经验
      365   // 13级->14级: 55经验
    ]
  },

  // 难度递增系统
  difficulty: {
    // 每30秒增加难度
    escalationInterval: 30000,
    // 怪物血量递增: 每波+0.3
    monsterHpProgression: (wave) => Math.max(1, 1 + Math.floor(wave * 0.3)),
    // 怪物攻击力递增: 每8波+1
    monsterAtkProgression: (wave) => 1 + Math.floor(wave / 8),
    // 怪物生成速度递增（间隔减少，最低1500）
    spawnSpeedProgression: (wave) => Math.max(1500, 3000 - wave * 60),
    // 怪物移动速度递增
    moveSpeedProgression: (wave) => 2.5 + wave * 0.08,
    // 每波生成的怪物数量基数（起始1只，上限3只）
    monstersPerWave: (wave) => Math.min(1 + Math.floor(wave / 5), 3)
  },

  // 地图配置
  map: {
    width: 750,          // 地图宽度(rpx) - 全屏宽度
    height: 1000,        // 地图高度(rpx) - 增加高度
    spawnZones: [        // 怪物生成区域(地图边缘, rpx单位)
      { x: 0, y: 0, width: 750, height: 50 },      // 上边
      { x: 0, y: 950, width: 750, height: 50 },    // 下边  
      { x: 0, y: 0, width: 50, height: 1000 },     // 左边
      { x: 700, y: 0, width: 50, height: 1000 }    // 右边
    ]
  }
};