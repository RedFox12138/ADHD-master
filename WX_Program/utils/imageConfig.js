/**
 * 游戏图片资源配置
 * 
 * 如果你想增加更多图片，只需修改下面的数量，并确保图片文件存在
 */

module.exports = {
  // 图片数量配置
  imageCount: {
    monsters: 10,   // 普通怪物图片数量 (monster1.png ~ monster10.png)
    bosses: 5,      // Boss怪物图片数量 (boss1.png ~ boss5.png)
    turrets: 10,    // 炮塔图片数量 (turret1.png ~ turret10.png)
    bullets: 10     // 炮弹图片数量 (bullet1.png ~ bullet10.png)
  },
  
  // 图片路径配置
  paths: {
    monsters: '/images/game/monsters/',
    turrets: '/images/game/turrets/',
    bullets: '/images/game/bullets/',
    backgrounds: '/images/game/backgrounds/'
  },
  
  // 图片命名规则
  naming: {
    monster: 'monster',    // 普通怪物前缀
    boss: 'boss',          // Boss怪物前缀
    turret: 'turret',      // 炮塔前缀
    bullet: 'bullet',      // 炮弹前缀
    background: 'background' // 背景文件名
  },
  
  // 图片格式
  formats: ['.png', '.jpg'],
  
  // 是否启用随机选择
  randomSelection: true,
  
  // 回退设置（当图片不存在时使用emoji）
  fallback: {
    monster: '👾',
    boss: '👹',
    turret: '🔫',
    bullet: '💥'
  }
};
