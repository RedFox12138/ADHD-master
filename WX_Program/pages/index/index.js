const app = getApp();
const audioManager = require('../../utils/audioManager');

// ========== URL 配置（自动切换开发工具/真机调试）==========
// 开发工具使用内网穿透
const DEV_WS_URL = 'wss://xxyeeg.zicp.fun/ws';
const DEV_HTTP_URL = 'https://xxyeeg.zicp.fun';

// 真机调试使用局域网IP（⚠️ 请修改为你电脑的IP地址）
// 获取IP方法：PowerShell执行 ipconfig | Select-String "IPv4"
const DEBUG_WS_URL = 'wss://xxyeeg.zicp.fun/ws';  // ⚠️ 修改这里的IP
const DEBUG_HTTP_URL = 'https://xxyeeg.zicp.fun';  // ⚠️ 修改这里的IP

// 自动检测运行环境
const isDevTools = wx.getSystemInfoSync().platform === 'devtools';
const WS_URL = isDevTools ? DEV_WS_URL : DEBUG_WS_URL;
const HTTP_URL = isDevTools ? DEV_HTTP_URL : DEBUG_HTTP_URL;
// =========================================================

// 批量累积策略：累积500个数据包（5000字符）再发送
var buf = ''; // 16进制字符串累积缓冲区
var batch_len = 5000; // 批量发送阈值：500个数据包 * 10字符/包 = 5000字符
var wxCharts = require('../../utils/wxcharts.js');
const GAME_CONFIG = require('../../utils/gameConfig.js');
let lineChart = null;
let socketTask = null; // WebSocket连接对象
let heartbeatTimer = null; // 心跳定时器

Page({
  data: {
    chartData: {
      tbrData: [],
      timePoints: []
    },
    dataCount: 0,
    maxDataPoints: 60,

    // 设备连接状态
    connected: false,
    deviceName: '',
    socketConnected: false, // WebSocket连接状态
    isDataSending: false, // 数据发送状态
    lastDataTime: 0, // 最后一次收到数据的时间戳
    dataCheckTimer: null, // 数据状态检查定时器
    
    // WebSocket重连相关
    reconnectAttempts: 0, // 当前重连次数
    maxReconnectAttempts: 10, // 最大重连次数
    reconnectTimer: null, // 重连定时器
    isReconnecting: false, // 是否正在重连中
    registerTimeout: null, // 注册超时检查定时器

    // 脑电参数（仅保留 TBR）
    powerRatio: null, // TBR 数值（基准阶段为实时值，治疗阶段为最新值）

    // 实验控制
    experimentStarted: false,
    currentPhase: '',      // '基准阶段'/'治疗阶段'
    remainingTime: 0,
    baselineValue: null,   // 基准值（游戏开始时计算）
    currentAttention: null,
    baselineTbrList: [],   // 基准阶段收集的样本熵列表

    // 保卫小镇游戏相关
    gameStarted: false,
    gameOver: false,
    gamePaused: false,
    showGamePrompt: false,
    
    // 地图拖动相关
    mapOffsetX: 0,        // 地图X偏移量
    mapOffsetY: 0,        // 地图Y偏移量
    touchStartX: 0,       // 触摸开始X坐标
    touchStartY: 0,       // 触摸开始Y坐标
    lastOffsetX: 0,       // 上次的X偏移量
    lastOffsetY: 0,       // 上次的Y偏移量
    
    // 游戏对象
    town: {
      x: GAME_CONFIG.town.x,
      y: GAME_CONFIG.town.y,
      hp: GAME_CONFIG.town.maxHp,
      maxHp: GAME_CONFIG.town.maxHp
    },
    turrets: [],
    monsters: [],
    bullets: [],
    explosions: [],
    
    // 游戏状态
    playerLevel: 1,
    experience: 0,
    nextLevelExp: GAME_CONFIG.experience.levelThresholds[0],
    defeatedMonsters: 0,
    currentWave: 0,
    survivedTime: 0,
    turretDamage: GAME_CONFIG.turret.initialDamage,
    turretTargets: 1, // 每个炮台可以同时攻击的目标数量

    // 游戏定时器
    gameTimer: null,
    monsterSpawnTimer: null,
    turretAttackTimer: null,
    difficultyTimer: null,

    chartInited: false,
    
    // UI控制
    showDataPanel: false,  // 侧边数据面板显示状态
    showStartCover: true,  // 启动封面显示状态
    gameBackground: '',    // 游戏背景图片路径
    showGameStats: true,   // 游戏顶部信息栏显示状态
    showTurretPanel: true, // 炮台信息面板显示状态
    
    // 音效控制
    soundEnabled: true,    // 音效开关
    bgmEnabled: true,      // BGM开关
    
    // 游戏图片资源
    gameImages: {
      monsters: [],      // 普通怪物图片列表
      bosses: [],        // Boss怪物图片列表
      turrets: [],       // 炮塔图片列表
      bullets: [],       // 炮弹图片列表
      background: ''     // 游戏背景图片
    },
    
    // 屏幕适配相关
    statusBarHeight: 0,    // 状态栏高度
    screenHeight: 0,       // 屏幕高度
    safeAreaInsets: {      // 安全区域
      top: 0,
      bottom: 0
    },
    toolbarHeight: 88,     // 工具栏高度（rpx）
    gameContainerHeight: 0, // 游戏容器实际高度
    
    // 游戏难度
    gameDifficulty: 'normal',  // 游戏难度：'easy'=简单, 'normal'=普通, 'hard'=困难
    showDifficultySelector: false,  // 是否显示难度选择界面
    
    // 注意力监测
    attentionLowStartTime: null,  // 注意力低下开始时间
    showAttentionAlert: false,    // 是否显示注意力提醒
    lastAlertTime: 0,             // 上次显示提醒的时间（秒数）
    lastDamageTime: 0             // 上次损坏炮台的时间（秒数）
  },

  onLoad: function() {
    // 获取系统信息进行屏幕适配
    this.initSystemInfo();
    
    this.initEmptyChart();
    this.connectWebSocket(); // 初始化WebSocket连接
    this.loadGameImages();    // 加载游戏图片资源
    
    // ========== 播放主界面BGM（预留） ==========
    // 请添加 /audio/main_bgm.mp3 文件后取消注释
    // audioManager.playBGM('main_bgm', 'ADHD训练 - 主界面');
    // ==========================================
    
    // 蓝牙连接监听
    wx.onBLEConnectionStateChange(res => {
      if (!res.connected) {
        this.setData({ connected: false });
        wx.showToast({ title: '连接已断开', icon: 'none' });
        if (this.data.experimentStarted) {
          this.stopExperiment();
        }
      }
    });
  },
  
  // 初始化系统信息，获取屏幕尺寸和安全区域
  initSystemInfo: function() {
    const systemInfo = wx.getSystemInfoSync();
    const statusBarHeight = systemInfo.statusBarHeight || 0;
    const screenHeight = systemInfo.screenHeight;
    const safeArea = systemInfo.safeArea || {};
    
    // 计算安全区域的上下边距
    const safeAreaInsets = {
      top: safeArea.top || statusBarHeight,
      bottom: screenHeight - (safeArea.bottom || screenHeight)
    };
    
    // 将px转换为rpx (1px = 2rpx on iPhone 6/7/8)
    const pixelRatio = 750 / systemInfo.windowWidth;
    const statusBarHeightRpx = statusBarHeight * pixelRatio;
    const toolbarHeight = 88; // 工具栏固定高度
    const screenHeightRpx = screenHeight * pixelRatio;
    const safeAreaBottomRpx = safeAreaInsets.bottom * pixelRatio;
    
    // 计算游戏容器实际可用高度（屏幕高度 - 状态栏 - 工具栏 - 底部安全区域）
    const gameContainerHeight = screenHeightRpx - statusBarHeightRpx - toolbarHeight - safeAreaBottomRpx;
    
    this.setData({
      statusBarHeight: statusBarHeightRpx,
      screenHeight: screenHeightRpx,
      safeAreaInsets: {
        top: safeAreaInsets.top * pixelRatio,
        bottom: safeAreaBottomRpx
      },
      gameContainerHeight: gameContainerHeight
    });
    
    console.log('屏幕适配信息:', {
      statusBarHeight: statusBarHeightRpx,
      screenHeight: screenHeightRpx,
      safeAreaInsets: this.data.safeAreaInsets,
      gameContainerHeight: gameContainerHeight
    });
  },

  onUnload: function() {
    // 页面卸载时关闭WebSocket
    this.closeWebSocket();
    
    // 停止所有音频
    audioManager.stopBGM();
    
    // 清除数据状态检查定时器
    if (this.data.dataCheckTimer) {
      clearInterval(this.data.dataCheckTimer);
    }
    
    // 清除重连定时器
    if (this.data.reconnectTimer) {
      clearTimeout(this.data.reconnectTimer);
    }
    
    // 清除注册超时定时器
    if (this.data.registerTimeout) {
      clearTimeout(this.data.registerTimeout);
    }
  },

  // ========== WebSocket 连接管理 ==========
  
  connectWebSocket: function() {
    const that = this;
    
    // 如果正在重连中且已有连接对象，不要重复发起
    if (that.data.isReconnecting && socketTask) {
      return;
    }
    
    // 如果已经有连接，先彻底清理
    if (socketTask) {
      try {
        socketTask.close({
          code: 1000,
          reason: '主动关闭以重新连接'
        });
      } catch (e) {
        console.error('关闭旧连接失败:', e);
      }
      socketTask = null;
    }
    
    // 停止旧的心跳
    that.stopHeartbeat();
    
    // 标记正在连接
    that.setData({ isReconnecting: true });
    
    // 创建WebSocket连接
    console.log(`🔌 连接服务器 (${that.data.reconnectAttempts + 1}/${that.data.maxReconnectAttempts})`);
    
    // ⚠️ 关键修改：先创建局部变量，绑定事件后再赋值给全局变量
    const newSocket = wx.connectSocket({
      url: WS_URL,
      header: {
        'content-type': 'application/json'
      }
    });
    
    // ✅ 立即绑定事件监听器到新的连接对象
    
    // 监听WebSocket打开
    newSocket.onOpen(() => {
      console.log('✅ 服务器已连接');
      
      // 先不更新连接状态，等注册成功后再更新
      that.setData({ 
        isReconnecting: false,
        reconnectAttempts: 0
      });
      
      // 清除重连定时器
      if (that.data.reconnectTimer) {
        clearTimeout(that.data.reconnectTimer);
        that.setData({ reconnectTimer: null });
      }
      
      // 连接成功后立即注册用户
      that.getUserId().then((user_id) => {
        
        // 使用newSocket发送消息
        newSocket.send({
          data: JSON.stringify({
            event: 'register_user',
            userId: user_id
          }),
          success: () => {
            
            // 设置注册超时检查（5秒内未收到确认则重连）
            const registerTimeout = setTimeout(() => {
              if (!that.data.socketConnected) {
                console.error('❌ 注册超时，未收到服务器确认');
                wx.showToast({
                  title: '注册超时，正在重连...',
                  icon: 'none'
                });
                that.scheduleReconnect();
              }
            }, 5000);
            
            // 存储超时定时器ID，以便在收到确认后清除
            that.setData({ registerTimeout: registerTimeout });
          },
          fail: (err) => {
            console.error('❌ 发送注册消息失败:', err);
            // 注册失败，触发重连
            that.scheduleReconnect();
          }
        });
      }).catch((err) => {
        console.error('❌ 获取用户ID失败:', err);
        // 无法获取用户ID，触发重连
        that.scheduleReconnect();
      });
      
      // 启动心跳（即使未注册也保持心跳）
      that.startHeartbeat();
    });
    
    // 监听WebSocket消息
    newSocket.onMessage((res) => {
      try {
        const data = JSON.parse(res.data);
        that.handleSocketMessage(data);
      } catch (e) {
        console.error('解析WebSocket消息失败', e);
      }
    });
    
    // 监听WebSocket错误
    newSocket.onError((err) => {
      console.error('❌ WebSocket错误:', err);
      
      // 清除注册超时定时器
      if (that.data.registerTimeout) {
        clearTimeout(that.data.registerTimeout);
        that.setData({ registerTimeout: null });
      }
      
      that.setData({ 
        socketConnected: false,
        isReconnecting: false
      });
      
      // 清空全局变量（只清空与newSocket匹配的）
      if (socketTask === newSocket) {
        socketTask = null;
      }
      
      // 错误时也触发重连
      that.scheduleReconnect();
    });
    
    // 监听WebSocket关闭
    newSocket.onClose((res) => {
      
      // 清除注册超时定时器
      if (that.data.registerTimeout) {
        clearTimeout(that.data.registerTimeout);
        that.setData({ registerTimeout: null });
      }
      
      that.setData({ 
        socketConnected: false,
        isReconnecting: false
      });
      that.stopHeartbeat();
      
      // 清空全局变量（只清空与newSocket匹配的）
      if (socketTask === newSocket) {
        socketTask = null;
      }
      
      // 自动触发重连（除非是正常关闭）
      if (res.code !== 1000) {
        that.scheduleReconnect();
      }
    });
    
    // ✅ 所有事件监听器绑定完成后，赋值给全局变量
    socketTask = newSocket;
  },
  
  // 调度重连（使用指数退避策略）
  scheduleReconnect: function() {
    const that = this;
    
    // 如果已经有重连定时器在运行，不要重复创建
    if (that.data.reconnectTimer) {
      return;
    }
    
    // 如果已经连接成功，不需要重连
    if (that.data.socketConnected) {
      return;
    }
    
    // 检查是否超过最大重连次数
    if (that.data.reconnectAttempts >= that.data.maxReconnectAttempts) {
      wx.showModal({
        title: '连接失败',
        content: '无法连接到服务器，请检查网络后重启小程序',
        showCancel: false
      });
      return;
    }
    
    // 计算退避时间：1秒、2秒、4秒、8秒...最大30秒
    const backoffTime = Math.min(1000 * Math.pow(2, that.data.reconnectAttempts), 30000);
    
    const timer = setTimeout(() => {
      that.setData({ 
        reconnectTimer: null,
        reconnectAttempts: that.data.reconnectAttempts + 1
      });
      
      that.connectWebSocket();
    }, backoffTime);
    
    that.setData({ reconnectTimer: timer });
  },
  
  closeWebSocket: function() {
    // 清除重连定时器
    if (this.data.reconnectTimer) {
      clearTimeout(this.data.reconnectTimer);
      this.setData({ reconnectTimer: null });
    }
    
    // 清除注册超时定时器
    if (this.data.registerTimeout) {
      clearTimeout(this.data.registerTimeout);
      this.setData({ registerTimeout: null });
    }
    
    if (socketTask) {
      try {
        socketTask.close({
          code: 1000,
          reason: '主动关闭'
        });
      } catch (e) {
        console.error('关闭WebSocket失败:', e);
      }
      socketTask = null;
    }
    this.stopHeartbeat();
    
    this.setData({
      socketConnected: false,
      isReconnecting: false,
      reconnectAttempts: 0
    });
  },
  
  startHeartbeat: function() {
    const that = this;
    that.stopHeartbeat();
    
    heartbeatTimer = setInterval(() => {
      if (socketTask && that.data.socketConnected) {
        socketTask.send({
          data: JSON.stringify({ event: 'ping' }),
          fail: (err) => {
            console.error('❌ 心跳发送失败，可能连接已断开');
            // 心跳失败，标记连接断开并触发重连
            that.setData({ 
              socketConnected: false,
              isReconnecting: false
            });
            that.stopHeartbeat();
            that.scheduleReconnect();
          }
        });
      }
    }, 30000); // 每30秒发送一次心跳
  },
  
  stopHeartbeat: function() {
    if (heartbeatTimer) {
      clearInterval(heartbeatTimer);
      heartbeatTimer = null;
    }
  },
  
  handleSocketMessage: function(data) {
    // 只打印重要消息，不打印频繁的数据推送
    
    // 处理注册确认
    if (data.event === 'registered') {
      console.log('✅ 用户注册成功');
      
      // 清除注册超时定时器
      if (this.data.registerTimeout) {
        clearTimeout(this.data.registerTimeout);
        this.setData({ registerTimeout: null });
      }
      
      // 注册成功后才标记为已连接
      this.setData({ socketConnected: true });
      
      // 显示连接成功提示
      wx.showToast({
        title: 'WebSocket已连接',
        icon: 'success',
        duration: 2000
      });
    }
    // 处理EEG特征值推送（不打印日志，直接处理）
    else if (data.event === 'eeg_feature' || data.TBR !== undefined) {
      this.handleEEGFeature(data);
    }
    // 处理连接确认
    else if (data.event === 'connected') {
      // 静默处理
    }
    // 处理心跳响应（不打印，避免刷屏）
    else if (data.event === 'pong') {
      // 静默处理心跳
    }
  },
  
  handleEEGFeature: function(data) {
    const tbrValue = data.TBR;
    const phase = data.Step || this.data.currentPhase;
    
    // 移除实验开始检查，允许任何阶段接收数据
    if (tbrValue === undefined || tbrValue === null) {
      return;
    }
    
    const tbrSnap = Math.round(tbrValue * 100) / 100;
    
    // 所有阶段都显示TBR和更新图表
    this.setData({
      powerRatio: tbrSnap
    });
    this.updateChartData(tbrSnap);
    
    // 基准阶段：额外收集数据到列表
    if (phase === '基准阶段') {
      this.data.baselineTbrList.push(tbrValue);
      
    } else if (phase === '治疗阶段' || this.data.currentPhase === '治疗阶段') {
      // 治疗阶段：额外更新当前注意力并判断经验值
      // 修复：使用本地 currentPhase 作为备用判断，防止服务器 Step 字段缺失
      this.setData({
        currentAttention: tbrSnap
      });
      
      // 注意力监测：检测样本熵持续高于基准值的时间
      if (this.data.baselineValue != null && !this.data.gameOver) {
        if (tbrSnap > this.data.baselineValue) {
          // 样本熵高于基准值（注意力不集中）
          if (this.data.attentionLowStartTime === null) {
            // 开始计时
            this.data.attentionLowStartTime = Date.now();
            this.data.lastAlertTime = 0;
            this.data.lastDamageTime = 0;
          } else {
            // 计算已持续的秒数
            const duration = Math.floor((Date.now() - this.data.attentionLowStartTime) / 1000);
            
            // 每6秒显示一次提醒（6秒、12秒、18秒...）
            const currentAlertCycle = Math.floor(duration / 6);
            if (currentAlertCycle > this.data.lastAlertTime && duration >= 6) {
              this.data.lastAlertTime = currentAlertCycle;
              this.setData({ showAttentionAlert: true });
              audioManager.playSound('button_click');
              // 3秒后自动隐藏
              setTimeout(() => {
                this.setData({ showAttentionAlert: false });
              }, 3000);
            }
            
            // 每12秒损坏一个炮台（12秒、24秒、36秒...）
            const currentDamageCycle = Math.floor(duration / 12);
            if (currentDamageCycle > this.data.lastDamageTime && duration >= 12) {
              this.data.lastDamageTime = currentDamageCycle;
              this.damageTurret();
            }
          }
        } else {
          // 样本熵低于或等于基准值，重置计时并恢复炮台
          if (this.data.attentionLowStartTime !== null) {
            this.repairAllTurrets();
          }
          this.data.attentionLowStartTime = null;
          this.data.lastAlertTime = 0;
          this.data.lastDamageTime = 0;
        }
      }
      
      // 每次收到推送时，立即判断是否增加经验值
      // 游戏结束后不再增加经验值
      // 逻辑：当样本熵低于基准值时增加经验（样本熵越低表示注意力越集中）
      if (!this.data.gameOver && this.data.baselineValue != null) {
        if (tbrSnap < this.data.baselineValue) {
          this.gainExperience(GAME_CONFIG.experience.gainRate);
        }
      }
    }
    // 其他阶段（准备阶段、未开始等）：只显示TBR和更新图表
  },
  
  // 损坏一个炮台（注意力不集中12秒）
  damageTurret: function() {
    const turrets = this.data.turrets;
    // 找到所有未损坏的炮台
    const activeTurrets = turrets.filter(t => !t.disabled);
    
    if (activeTurrets.length === 0) {
      return; // 所有炮台已经损坏
    }
    
    // 随机选择一个炮台
    const randomIndex = Math.floor(Math.random() * activeTurrets.length);
    const targetTurret = activeTurrets[randomIndex];
    
    // 找到该炮台在数组中的位置
    const turretIndex = turrets.findIndex(t => t.id === targetTurret.id);
    if (turretIndex !== -1) {
      turrets[turretIndex].disabled = true;
      this.setData({ turrets });
      
      // 显示损坏提示
      wx.showToast({
        title: '⚠️ 注意力不集中，炮台损坏！',
        icon: 'none',
        duration: 2000
      });
      
      // 播放音效
      audioManager.playSound('button_click');
    }
  },
  
  // 恢复所有炮台（注意力恢复）
  repairAllTurrets: function() {
    const turrets = this.data.turrets;
    let hasDisabled = false;
    
    turrets.forEach(turret => {
      if (turret.disabled) {
        turret.disabled = false;
        hasDisabled = true;
      }
    });
    
    if (hasDisabled) {
      this.setData({ turrets });
      wx.showToast({
        title: '✅ 注意力恢复，炮台修复！',
        icon: 'success',
        duration: 1500
      });
      audioManager.playSound('button_click');
    }
  },
  
  // ========================================

  resetChart: function() {
    this.setData({
      chartData: {
        tbrData: [],
        timePoints: []
      },
      dataCount: 0,
      baselineSum: 0,
      baselineCount: 0
    });
    this.initEmptyChart();
  },

  // 开始实验
  startExperiment: function() {
    audioManager.playSound('button_click');
    
    if (!this.data.connected) {
      wx.showToast({ title: '请先连接设备', icon: 'none' });
      return;
    }
    
    // 检查WebSocket连接状态
    if (!this.data.socketConnected) {
      wx.showModal({
        title: '无法开始',
        content: 'WebSocket未连接，无法开始游戏\n请等待连接成功或检查网络',
        showCancel: false
      });
      return;
    }
    
    // 显示难度选择界面
    this.setData({ 
      showDifficultySelector: true,
      showStartCover: false
    });
  },
  
  // 选择游戏难度
  selectDifficulty: function(e) {
    audioManager.playSound('button_click');
    const difficulty = e.currentTarget.dataset.difficulty;
    console.log(`[难度选择] 用户选择了难度: ${difficulty}`);
    
    this.setData({ 
      gameDifficulty: difficulty,
      showDifficultySelector: false
    }, () => {
      // 在setData回调中确认难度已设置
      console.log(`[难度选择] 难度设置确认: ${this.data.gameDifficulty}`);
    });
    
    // 发送开始记录指令给后端（从难度选择后就开始记录）
    this.getUserId().then(user_id => {
      if (socketTask && this.data.socketConnected) {
        socketTask.send({
          data: JSON.stringify({
            event: 'start_recording',
            userId: user_id
          }),
          success: () => {
            console.log('✅ 已发送开始记录指令（难度选择后）');
          },
          fail: (err) => {
            console.error('❌ 发送开始记录指令失败', err);
          }
        });
      }
    });
    
    // 隐藏启动封面，开始游戏
    
    this.resetChart();
    this.setData({
      experimentStarted: true,
      currentPhase: '准备阶段',
      remainingTime: 10,
      baselineValue: null,
      baselineTbrList: [],  // 清空基准阶段样本熵列表
      gameOver: false,
      gameStarted: false,
      attentionLowStartTime: null,
      showAttentionAlert: false,
      lastAlertTime: 0,
      lastDamageTime: 0
    });
    
    this.startPhaseTimer();
  },
  
  stopExperiment: function() {
    audioManager.playSound('button_click');  // 添加按钮音效
    
    // 发送停止记录指令给后端
    this.getUserId().then(user_id => {
      if (socketTask && this.data.socketConnected) {
        socketTask.send({
          data: JSON.stringify({
            event: 'stop_recording',
            userId: user_id
          }),
          success: () => {
            console.log('✅ 已发送停止记录指令');
          },
          fail: (err) => {
            console.error('❌ 发送停止记录指令失败', err);
          }
        });
      }
    });
    
    // 停止游戏BGM（确保BGM完全停止）
    audioManager.stopBGM();
    
    // 如果游戏已开始，保存游戏时长记录（包含难度信息）
    if (this.data.gameStarted && this.data.survivedTime > 0) {
      this.saveGameRecord(this.data.survivedTime, this.data.gameDifficulty);
    }

    // 清除所有定时器
    if (this.data.phaseTimer) {
      clearInterval(this.data.phaseTimer);
    }
    if (this.data.timer) {
      clearInterval(this.data.timer);
    }
    if (this.data.gameTimer) {
      clearInterval(this.data.gameTimer);
    }
    if (this.data.monsterSpawnTimer) {
      clearInterval(this.data.monsterSpawnTimer);
    }
    if (this.data.turretAttackTimer) {
      clearInterval(this.data.turretAttackTimer);
    }
    // experienceTimer 已移除，现在通过 WebSocket 推送触发
    if (this.data.difficultyTimer) {
      clearInterval(this.data.difficultyTimer);
    }

    this.setData({
      experimentStarted: false,
      currentPhase: '',
      gameOver: true,
      gameStarted: false,
      timer: null,
      phaseTimer: null,
      gameTimer: null,
      monsterSpawnTimer: null,
      turretAttackTimer: null,
      difficultyTimer: null,
      baselineSum: 0,
      baselineCount: 0,
      showStartCover: true,  // 恢复启动封面显示
      showDifficultySelector: false,  // 重置难度选择界面
      attentionLowStartTime: null,
      showAttentionAlert: false,
      lastAlertTime: 0,
      lastDamageTime: 0
    });
  },

  // 保存游戏时长记录
  saveGameRecord: function(gameTime, difficulty) {
    this.getUserId().then(user_id => {
      wx.request({
        url: `${HTTP_URL}/saveGameRecord`,
        method: 'POST',
        data: {
          userId: user_id,
          gameTime: gameTime,
          difficulty: difficulty || 'normal'  // 添加难度信息，默认为普通
        },
        success: (res) => {
          if (!res.data.success) {
            console.error('[游戏记录] 保存失败:', res.data.error);
          }
        },
        fail: (err) => {
          console.error('[游戏记录] 网络错误:', err);
        }
      });
    }).catch(err => {
      console.error('[游戏记录] 获取用户ID失败:', err);
    });
  },
  
  // 启动阶段计时器
  startPhaseTimer: function() {
    const that = this;

    that.data.phaseTimer = setInterval(() => {
      let remainingTime = that.data.remainingTime - 1;
      that.setData({ remainingTime });

      if (remainingTime <= 0) {
        clearInterval(that.data.phaseTimer);

        if (that.data.currentPhase === '准备阶段') {
          that.setData({
            currentPhase: '基准阶段',
            remainingTime: 30
          });
          that.startPhaseTimer();
        }
        else if (that.data.currentPhase === '基准阶段') {
          // 基准阶段结束：计算收集到的样本熵列表的平均值作为基准值
          const tbrList = that.data.baselineTbrList;
          
          if (tbrList.length > 0) {
            const sum = tbrList.reduce((acc, val) => acc + val, 0);
            const baselineValue = Math.round((sum / tbrList.length) * 100) / 100;
            
            that.setData({
              baselineValue,
              currentPhase: '治疗阶段'
            });
          } else {
            wx.showToast({ title: '基准数据不足', icon: 'none' });
            that.stopExperiment();
            return;
          }
          
          that.startTreatmentPhase();
        } else {
          that.stopExperiment();
          wx.showToast({ title: '实验完成', icon: 'success' });
        }
      }
    }, 1000);
  },

  startTreatmentPhase: function() {
    this.setData({
      currentPhase: '治疗阶段',
      gameStarted: true,
      gameOver: false,
      showGamePrompt: true,
      survivedTime: 0
    });

    // ========== 切换到游戏BGM（正式启用） - 启用随机播放列表 ==========
    audioManager.playBGM('game_bgm', 'ADHD训练 - 游戏中', true);
    // ==========================================

    // 初始化游戏
    this.initGame();

    // 显示游戏开始提示3秒
    setTimeout(() => {
      this.setData({ showGamePrompt: false });
    }, 3000);

    // 存活时间计时器（无尽模式）
    this.data.gameTimer = setInterval(() => {
      this.setData({ 
        survivedTime: this.data.survivedTime + 1 
      });
    }, 1000);

    // 游戏主循环
    this.data.timer = setInterval(this.updateGameState.bind(this), 50);
    
    // 怪物生成定时器
    this.startMonsterSpawn();
    
    // 炮台攻击定时器
    this.startTurretAttack();
    
    // 注意：经验值现在通过 WebSocket 推送触发，不再需要定时检查
    
    // 难度递增定时器
    this.startDifficultyEscalation();
  },

  restartExperiment: function() {
    audioManager.playSound('button_click');  // 添加按钮音效
    
    // 停止游戏BGM
    audioManager.stopBGM();
    
    this.stopExperiment();
    this.resetChart();
    this.setData({
      baselineValue: null,
      currentAttention: null,
      baselineTbrList: [],  // 清空基准阶段样本熵列表
      currentPhase:'',
      gameOver: false,
      experimentStarted: false,
      showGamePrompt: false,
      survivedTime: 0,
      // 重置游戏状态
      town: {
        x: GAME_CONFIG.town.x,
        y: GAME_CONFIG.town.y,
        hp: GAME_CONFIG.town.maxHp,
        maxHp: GAME_CONFIG.town.maxHp
      },
      turrets: [],
      monsters: [],
      bullets: [],
      explosions: [],
      playerLevel: 1,
      experience: 0,
      nextLevelExp: GAME_CONFIG.experience.levelThresholds[0],
      defeatedMonsters: 0,
      currentWave: 0,
      turretDamage: GAME_CONFIG.turret.initialDamage,
      turretTargets: 1
    });
    setTimeout(() => {
      this.startExperiment();
    }, 500);
  },
  
  // 初始化游戏
  initGame: function() {
    // 设置游戏背景图片
    const backgroundImage = this.getBackgroundImage();
    
    // 重置游戏状态
    this.setData({
      gameBackground: backgroundImage,  // 设置背景图片
      town: {
        x: GAME_CONFIG.town.x,
        y: GAME_CONFIG.town.y,
        hp: GAME_CONFIG.town.maxHp,
        maxHp: GAME_CONFIG.town.maxHp
      },
      turrets: [],
      monsters: [],
      bullets: [],
      explosions: [],
      playerLevel: 1,
      experience: 0,
      nextLevelExp: GAME_CONFIG.experience.levelThresholds[0],
      defeatedMonsters: 0,
      currentWave: 0,
      turretDamage: GAME_CONFIG.turret.initialDamage,
      turretTargets: 1,
      survivedTime: 0 // 存活时间（秒）
    });

    // 创建初始炮台
    this.createInitialTurret();
  },

  // 创建初始炮台
  createInitialTurret: function() {
    // 初始化炮台（只有1个）- 六边形分布的第一个位置（正上方）
    const turretImage = this.getRandomTurretImage();
    const bulletImage = this.getRandomBulletImage();
    
    const radius = 100; // 炮台距离小镇中心的半径
    const angle = -90 * Math.PI / 180; // 第一个炮台在正上方（-90度）
    
    const turret = {
      id: Date.now(),
      x: GAME_CONFIG.town.x + Math.cos(angle) * radius,
      y: GAME_CONFIG.town.y + Math.sin(angle) * radius,
      rotation: 0,
      lastAttackTime: 0,
      damage: GAME_CONFIG.turret.initialDamage,
      attackInterval: GAME_CONFIG.turret.attackInterval,
      targets: 1, // 可攻击目标数
      image: turretImage,  // 炮台图片
      bulletImage: bulletImage,  // 为这个炮台固定分配子弹图片
      positionIndex: 0  // 标记这是第几个位置（用于六边形分布）
    };
    this.setData({
      turrets: [turret]
    });
  },

  // 开始怪物生成
  startMonsterSpawn: function() {
    this.spawnMonstersForWave(); // 立即生成第一波
    const spawnInterval = GAME_CONFIG.difficulty.spawnSpeedProgression(this.data.currentWave);
    this.data.monsterSpawnTimer = setInterval(() => {
      if (!this.data.gameOver) {
        this.spawnMonster();
      }
    }, spawnInterval);
  },

  // 为当前波次生成怪物
  spawnMonstersForWave: function() {
    const wave = this.data.currentWave;
    const monstersCount = GAME_CONFIG.difficulty.monstersPerWave(wave);
    
    // 检查是否生成Boss（每10波）
    if (wave > 0 && wave % 10 === 0) {
      this.spawnBoss();
    }
    
    // 检查是否生成怪物群（每5波）
    if (wave > 0 && wave % 5 === 0) {
      this.spawnMonsterGroup();
    }
    
    // 生成普通怪物
    for (let i = 0; i < monstersCount; i++) {
      setTimeout(() => {
        if (!this.data.gameOver) {
          this.spawnMonster();
        }
      }, i * 300); // 间隔300ms生成
    }
  },

  // 生成普通怪物
  spawnMonster: function(isBoss = false, hpMultiplier = 1, atkMultiplier = 1, speedMultiplier = 1) {
    const spawnZones = GAME_CONFIG.map.spawnZones;
    const zone = spawnZones[Math.floor(Math.random() * spawnZones.length)];
    
    const baseHp = GAME_CONFIG.difficulty.monsterHpProgression(this.data.currentWave);
    const baseAtk = GAME_CONFIG.difficulty.monsterAtkProgression(this.data.currentWave);
    const baseSpeed = GAME_CONFIG.difficulty.moveSpeedProgression(this.data.currentWave);
    
    // 随机选择怪物图片
    const monsterImage = isBoss ? this.getRandomBossImage() : this.getRandomMonsterImage();
    
    const monster = {
      id: Date.now() + Math.random(),
      x: zone.x + Math.random() * zone.width,
      y: zone.y + Math.random() * zone.height,
      hp: Math.floor(baseHp * hpMultiplier),
      maxHp: Math.floor(baseHp * hpMultiplier),
      atk: Math.floor(baseAtk * atkMultiplier),
      speed: baseSpeed * speedMultiplier,
      lastAttackTime: 0,
      targetX: this.data.town.x,
      targetY: this.data.town.y,
      isBoss: isBoss,
      image: monsterImage  // 添加图片路径
    };

    const monsters = [...this.data.monsters, monster];
    this.setData({ monsters });
  },

  // 生成Boss
  spawnBoss: function() {
    this.spawnMonster(
      true,
      GAME_CONFIG.monster.bossHpMultiplier,
      GAME_CONFIG.monster.bossAtkMultiplier,
      GAME_CONFIG.monster.bossSpeedMultiplier
    );
    
    wx.showToast({
      title: '⚠️ Boss来袭！',
      icon: 'none',
      duration: 2000
    });
  },

  // 生成怪物群
  spawnMonsterGroup: function() {
    const groupSize = GAME_CONFIG.monster.groupSize;
    
    for (let i = 0; i < groupSize; i++) {
      setTimeout(() => {
        if (!this.data.gameOver) {
          this.spawnMonster(false, 1, 1, 1.2); // 怪物群速度稍快
        }
      }, i * 200);
    }
    
    wx.showToast({
      title: '🔥 怪物群入侵！',
      icon: 'none',
      duration: 1500
    });
  },

  // 开始炮台攻击
  startTurretAttack: function() {
    this.data.turretAttackTimer = setInterval(() => {
      if (!this.data.gameOver) {
        this.turretsAttack();
      }
    }, GAME_CONFIG.turret.attackInterval);
  },

  // 炮台攻击逻辑
  turretsAttack: function() {
    const turrets = this.data.turrets;
    const monsters = this.data.monsters;
    const bullets = [...this.data.bullets];
    const targetedMonsters = new Set(); // 记录已被锁定的怪物，避免重复攻击

    turrets.forEach(turret => {
      // 跳过被禁用的炮台
      if (turret.disabled) {
        return;
      }
      
      // 寻找攻击范围内的怪物
      const targetsInRange = monsters
        .filter(monster => {
          const dx = monster.x - turret.x;
          const dy = monster.y - turret.y;
          const distance = Math.sqrt(dx * dx + dy * dy);
          return distance <= GAME_CONFIG.turret.range;
        })
        .map(monster => {
          // 计算每个怪物距离该炮台的距离
          const dx = monster.x - turret.x;
          const dy = monster.y - turret.y;
          const distanceToTurret = Math.sqrt(dx * dx + dy * dy);
          return { monster, distanceToTurret };
        })
        .sort((a, b) => {
          // 优先攻击距离该炮台最近的怪物
          return a.distanceToTurret - b.distanceToTurret;
        });

      // 攻击目标（根据炮台自己的目标数决定攻击数量）
      const targetCount = Math.min(turret.targets || 1, targetsInRange.length);
      for (let i = 0; i < targetCount; i++) {
        const targetData = targetsInRange[i];
        if (!targetData) break;
        
        const target = targetData.monster;
        
        // 如果该怪物已被其他炮台锁定，尝试找下一个目标（除非没有其他选择）
        if (targetedMonsters.has(target.id) && i < targetsInRange.length - 1) {
          // 寻找未被锁定的下一个目标
          let foundAlternative = false;
          for (let j = i + 1; j < targetsInRange.length; j++) {
            const altTarget = targetsInRange[j].monster;
            if (!targetedMonsters.has(altTarget.id)) {
              this.fireBullet(turret, altTarget, bullets);
              targetedMonsters.add(altTarget.id);
              foundAlternative = true;
              break;
            }
          }
          if (!foundAlternative) {
            // 没有其他选择，还是攻击这个已被锁定的目标
            this.fireBullet(turret, target, bullets);
          }
        } else {
          // 攻击该目标
          this.fireBullet(turret, target, bullets);
          targetedMonsters.add(target.id);
        }
      }
    });

    this.setData({ bullets });
  },

  // 发射子弹
  fireBullet: function(turret, target, bullets) {
    // 播放射击音效
    audioManager.playSound('turret_shoot');
    
    const bullet = {
      id: Date.now() + Math.random(),
      x: turret.x,
      y: turret.y,
      targetId: target.id,
      targetX: target.x,
      targetY: target.y,
      damage: turret.damage || GAME_CONFIG.turret.initialDamage,
      image: turret.bulletImage  // 使用炮台绑定的子弹图片（不再随机）
    };
    bullets.push(bullet);
  },

  // 获得经验值（由 WebSocket 推送触发）
  gainExperience: function(amount) {
    // 根据难度调整经验值获取速率
    const difficultyMultiplier = {
      'easy': 1.5,    // 简单模式：经验值获取速度提升50%
      'normal': 1.0,  // 普通模式：正常速度
      'hard': 0.7     // 困难模式：经验值获取速度降低30%
    };
    const multiplier = difficultyMultiplier[this.data.gameDifficulty] || 1.0;
    const adjustedAmount = amount * multiplier;  // 保留小数，累积精确经验值
    
    // 调试日志：输出难度和经验倍率
    console.log(`[经验获取] 难度: ${this.data.gameDifficulty}, 原始经验: ${amount}, 倍率: ${multiplier}, 调整后: ${adjustedAmount.toFixed(2)}`);
    
    let newExp = this.data.experience + adjustedAmount;  // 内部累积小数
    let level = this.data.playerLevel;
    let nextLevelExp = this.data.nextLevelExp;

    // 检查是否升级
    while (newExp >= nextLevelExp && level < GAME_CONFIG.experience.levelThresholds.length + 1) {
      level++;
      this.levelUp(level);
      if (level <= GAME_CONFIG.experience.levelThresholds.length) {
        nextLevelExp = GAME_CONFIG.experience.levelThresholds[level - 1];
      } else {
        nextLevelExp = newExp + 100; // 最高级后的经验值
      }
    }

    this.setData({
      experience: newExp,
      playerLevel: level,
      nextLevelExp: nextLevelExp
    });
  },

  // 升级处理
  levelUp: function(newLevel) {
    // 升级音效已移除（精简版）
    
    if (newLevel <= 6) {
      // 1-6级：增加炮台数量
      this.addTurret();
    } else {
      // 7级以上：随机升级单个炮台
      this.randomUpgradeTurret();
    }
    
    wx.showToast({
      title: `升级到${newLevel}级！`,
      icon: 'success',
      duration: 1000
    });
  },

  // 随机升级一个炮台
  randomUpgradeTurret: function() {
    const turrets = this.data.turrets;
    if (turrets.length === 0) return;
    
    // 随机选择一个炮台
    const randomIndex = Math.floor(Math.random() * turrets.length);
    
    // 随机选择升级类型：0=攻击力，1=攻击目标数量，2=攻击速度
    const upgradeType = Math.floor(Math.random() * 3);
    
    const upgradedTurrets = turrets.map((turret, index) => {
      if (index === randomIndex) {
        if (upgradeType === 0) {
          // 升级攻击力
          turret.damage = (turret.damage || GAME_CONFIG.turret.initialDamage) + 1;
          wx.showToast({
            title: `炮台${index + 1}攻击力+1！`,
            icon: 'success',
            duration: 1500
          });
        } else if (upgradeType === 1) {
          // 升级攻击目标数量（最多同时攻击3个目标）
          const currentTargets = turret.targets || 1;
          if (currentTargets < 3) {
            turret.targets = currentTargets + 1;
            wx.showToast({
              title: `炮台${index + 1}可攻击${turret.targets}个目标！`,
              icon: 'success',
              duration: 1500
            });
          } else {
            // 如果已经达到最大目标数，改为提升攻击力
            turret.damage = (turret.damage || GAME_CONFIG.turret.initialDamage) + 1;
            wx.showToast({
              title: `炮台${index + 1}攻击力+1！`,
              icon: 'success',
              duration: 1500
            });
          }
        } else {
          // 升级攻击速度（减少攻击间隔，最低500ms）
          const currentInterval = turret.attackInterval || GAME_CONFIG.turret.attackInterval;
          turret.attackInterval = Math.max(500, currentInterval - 200);
          wx.showToast({
            title: `炮台${index + 1}攻击速度提升！`,
            icon: 'success',
            duration: 1500
          });
        }
      }
      return turret;
    });
    
    this.setData({ turrets: upgradedTurrets });
  },

  // 添加炮台
  addTurret: function() {
    const turrets = [...this.data.turrets];
    const turretCount = turrets.length;
    
    if (turretCount < GAME_CONFIG.turret.maxCount) {
      // 六边形均匀分布：从正上方开始，每60度一个炮台
      // 位置索引：0=上(-90°), 1=右上(30°), 2=右下(90°), 3=下(150°), 4=左下(210°), 5=左上(270°)
      const angle = (-90 + turretCount * 60) * Math.PI / 180; // 从-90度开始，顺时针每60度
      const radius = 100; // 炮台距离小镇中心的半径
      const turretImage = this.getRandomTurretImage();
      const bulletImage = this.getRandomBulletImage();
      
      const turret = {
        id: Date.now() + turretCount,
        x: this.data.town.x + Math.cos(angle) * radius,
        y: this.data.town.y + Math.sin(angle) * radius,
        rotation: 0,
        lastAttackTime: 0,
        damage: GAME_CONFIG.turret.initialDamage,
        attackInterval: GAME_CONFIG.turret.attackInterval,
        targets: 1,
        image: turretImage,  // 添加炮台图片
        bulletImage: bulletImage,  // 为新炮台分配子弹图片
        positionIndex: turretCount  // 记录位置索引
      };
      turrets.push(turret);
      this.setData({ turrets });
    }
  },

  // 开始难度递增
  startDifficultyEscalation: function() {
    this.data.difficultyTimer = setInterval(() => {
      if (!this.data.gameOver) {
        const newWave = this.data.currentWave + 1;
        this.setData({
          currentWave: newWave
        });
        
        // 为新波次生成怪物
        this.spawnMonstersForWave();
        
        // 重新设置怪物生成间隔
        clearInterval(this.data.monsterSpawnTimer);
        this.startMonsterSpawn();
        
        // 显示波次提示
        wx.showToast({
          title: `第 ${newWave} 波来袭！`,
          icon: 'none',
          duration: 1500
        });
      }
    }, GAME_CONFIG.difficulty.escalationInterval);
  },

  // 游戏主循环
  updateGameState: function() {
    if (!this.data.gameStarted || this.data.gameOver) return;
    
    // 更新子弹
    this.updateBullets();
    
    // 更新怪物
    this.updateMonsters();
    
    // 更新爆炸效果
    this.updateExplosions();
    
    // 检查游戏结束条件
    this.checkGameOver();
  },

  // 更新子弹
  updateBullets: function() {
    const bullets = this.data.bullets.filter(bullet => {
      // 移动子弹
      const dx = bullet.targetX - bullet.x;
      const dy = bullet.targetY - bullet.y;
      const distance = Math.sqrt(dx * dx + dy * dy);
      
      if (distance < GAME_CONFIG.turret.bulletSpeed) {
        // 子弹命中目标
        this.hitMonster(bullet.targetId, bullet.damage, bullet.x, bullet.y);
        return false; // 移除子弹
      } else {
        // 移动子弹
        const moveX = (dx / distance) * GAME_CONFIG.turret.bulletSpeed;
        const moveY = (dy / distance) * GAME_CONFIG.turret.bulletSpeed;
        bullet.x += moveX;
        bullet.y += moveY;
        return true;
      }
    });

    this.setData({ bullets });
  },

  // 更新怪物
  updateMonsters: function() {
    const monsters = this.data.monsters.map(monster => {
      // 怪物向小镇移动
      const dx = monster.targetX - monster.x;
      const dy = monster.targetY - monster.y;
      const distance = Math.sqrt(dx * dx + dy * dy);
      
      if (distance > GAME_CONFIG.monster.attackRange) {
        // 移动向小镇
        const moveX = (dx / distance) * monster.speed;
        const moveY = (dy / distance) * monster.speed;
        monster.x += moveX;
        monster.y += moveY;
      } else {
        // 攻击小镇
        const now = Date.now();
        if (now - monster.lastAttackTime > GAME_CONFIG.monster.attackInterval) {
          this.monsterAttackTown(monster);
          monster.lastAttackTime = now;
        }
      }
      
      return monster;
    }).filter(monster => monster.hp > 0); // 移除死亡怪物

    this.setData({ monsters });
  },

  // 怪物攻击小镇
  monsterAttackTown: function(monster) {
    // 小镇受伤音效已移除（精简版）
    
    const town = { ...this.data.town };
    const damage = monster.atk || GAME_CONFIG.monster.attackDamage;
    town.hp = Math.max(0, town.hp - damage);
    this.setData({ town });
    
    // 创建攻击特效
    this.createExplosion(town.x, town.y);
  },

  // 子弹击中怪物
  hitMonster: function(monsterId, damage, x, y) {
    // 子弹击中和怪物死亡音效已移除（精简版）
    
    const monsters = this.data.monsters.map(monster => {
      if (monster.id === monsterId) {
        monster.hp -= damage;
        if (monster.hp <= 0) {
          // 怪物死亡
          this.setData({
            defeatedMonsters: this.data.defeatedMonsters + 1
          });
        }
      }
      return monster;
    });
    
    // 创建击中特效
    this.createExplosion(x, y);
    this.setData({ monsters });
  },

  // 创建爆炸特效
  createExplosion: function(x, y) {
    // 播放爆炸音效
    audioManager.playSound('explosion');
    
    const explosion = {
      id: Date.now() + Math.random(),
      x: x,
      y: y,
      life: 10 // 显示10帧
    };
    
    const explosions = [...this.data.explosions, explosion];
    this.setData({ explosions });
  },

  // 更新爆炸特效
  updateExplosions: function() {
    const explosions = this.data.explosions.filter(explosion => {
      explosion.life--;
      return explosion.life > 0;
    });
    this.setData({ explosions });
  },

  // 检查游戏结束
  checkGameOver: function() {
    if (this.data.town.hp <= 0) {
      this.endGame();
    }
  },

  // 结束游戏
  endGame: function() {
    // 发送停止记录指令给后端
    this.getUserId().then(user_id => {
      if (socketTask && this.data.socketConnected) {
        socketTask.send({
          data: JSON.stringify({
            event: 'stop_recording',
            userId: user_id
          }),
          success: () => {
            console.log('✅ 已发送停止记录指令');
          },
          fail: (err) => {
            console.error('❌ 发送停止记录指令失败', err);
          }
        });
      }
    });

    // 停止游戏BGM
    audioManager.stopBGM();
    
    // 播放游戏结束音效
    audioManager.playSound('game_over');
    
    // 清除所有定时器
    if (this.data.gameTimer) clearInterval(this.data.gameTimer);
    if (this.data.monsterSpawnTimer) clearInterval(this.data.monsterSpawnTimer);
    if (this.data.turretAttackTimer) clearInterval(this.data.turretAttackTimer);
    if (this.data.experienceTimer) clearInterval(this.data.experienceTimer);
    if (this.data.difficultyTimer) clearInterval(this.data.difficultyTimer);
    if (this.data.timer) clearInterval(this.data.timer);
    
    this.setData({
      gameOver: true,
      gameStarted: false
    });
    
    // 保存游戏记录（生存时间和难度）
    if (this.data.survivedTime > 0) {
      this.saveGameRecord(this.data.survivedTime, this.data.gameDifficulty);
    }
  },



  getUserId() {
    return new Promise((resolve, reject) => {
      const user_id = wx.getStorageSync('user_id');
      if (user_id) {
        resolve(user_id);
        return;
      }
  
      wx.login({
        success: (res) => {
          if (res.code) {
            wx.request({
              url: `${HTTP_URL}/getOpenId`,  // 使用动态URL
              method: 'POST',
              data: { code: res.code },
              success: (res) => {
                const user_id = res.data.openid;
                wx.setStorageSync('user_id', user_id);  
                resolve(user_id);
              },
              fail: (err) => {
                reject('获取 user_id 失败');
              }
            });
          } else {
            reject('wx.login 失败');
          }
        },
        fail: (err) => {
          reject('wx.login 调用失败');
        }
      });
    });
  },

  sendDataToServer: function() {
    // 批量发送策略：每次发送5000字符（500个数据包）
    
    if (buf.length < batch_len) {
      return; // 数据不足，不发送
    }
    
    this.getUserId().then((user_id) => {
      // 取出batch_len长度的数据发送
      const hexToSend = buf.slice(0, batch_len);
      buf = buf.slice(batch_len); // 删除已发送的部分
      
      wx.request({
        url: `${HTTP_URL}/process`,
        method: 'POST',
        data: {
          hexData: hexToSend,
          userId: user_id,
          Step: this.data.currentPhase,
          difficulty: this.data.gameDifficulty || 'normal'  // 发送难度信息
        },
        success: (res) => {
          // 静默成功，不打印
        },
        fail: (err) => {
          console.error('❌ 数据发送失败:', err);
          // 发送失败，放回缓冲区
          buf = hexToSend + buf;
        }
      });
    }).catch((err) => {
      console.error('❌ 获取 user_id 失败:', err);
    });
  },

  onShow() {
    // 每次显示页面时，如果没有正在进行的实验，显示启动封面
    if (!this.data.experimentStarted) {
      this.setData({ showStartCover: true });
    }
    
    if (app.globalData.connectedDevice) {
      this.setData({
        connected: true,
        deviceName: app.globalData.connectedDevice.name
      });
      this.startListenData();
    }
  },
  
  navigateToScan() {
    wx.navigateTo({ url: '/pages/scan/scan' });
  },
  
  navigateToHistory: function() {
    audioManager.playSound('button_click');
    wx.navigateTo({ url: '/pages/history/history' });
  },

  navigateToGameRecords: function() {
    audioManager.playSound('button_click');
    wx.navigateTo({ url: '/pages/gameRecords/gameRecords' });
  },

  navigateToSchulte: function() {
    audioManager.playSound('button_click');
    wx.navigateTo({ url: '/pages/schulte/schulte' });
  },

  toggleDataPanel: function() {
    audioManager.playSound('button_click');
    this.setData({
      showDataPanel: !this.data.showDataPanel
    });
  },

  // 切换游戏顶部信息栏显示
  toggleGameStats: function() {
    audioManager.playSound('button_click');
    this.setData({
      showGameStats: !this.data.showGameStats
    });
  },

  // 切换炮台信息面板显示
  toggleTurretPanel: function() {
    audioManager.playSound('button_click');
    this.setData({
      showTurretPanel: !this.data.showTurretPanel
    });
  },
  
  enableBLEData: function (data) {
    var hex = data
    var typedArray = new Uint8Array(hex.match(/[\da-f]{2}/gi).map(function (h) {
      return parseInt(h, 16)
    }))
    var buffer1 = typedArray.buffer
    
    wx.writeBLECharacteristicValue({
      deviceId: app.globalData.connectedDevice.deviceId,
      serviceId: app.globalData.connectedDevice.advertisServiceUUIDs[0],
      characteristicId: app.globalData.SendCharacteristicId,
      value: buffer1,
      success: function (res) {
      },
      fail: function (res) {
      }
    });
  },

  startListenData() {
    const that = this;
    const deviceId = app.globalData.connectedDevice.deviceId;
    const serviceId = app.globalData.connectedDevice.advertisServiceUUIDs[0];
    const targetCharacteristicId = app.globalData.RecvCharacteristicId;
  
    wx.getBLEDeviceCharacteristics({
      deviceId: deviceId,
      serviceId: serviceId,
      success: function (res) {
        const targetChar = res.characteristics.find(c => 
          c.uuid.toUpperCase() === targetCharacteristicId.toUpperCase()
        );

        if (!targetChar) {
          console.error('未找到匹配的特征ID');
          return;
        }
  
        if (!(targetChar.properties.notify || targetChar.properties.indicate)) {
          console.error('特征不支持NOTIFY/INDICATE属性');
          return;
        }

        // 不再自动开启数据发送，等待用户点击按钮
        // that.enableBLEData("1919");

        wx.notifyBLECharacteristicValueChange({
          deviceId: deviceId,
          serviceId: serviceId,
          characteristicId: targetChar.uuid,
          state: true,
          success: function (res) {
            wx.onBLECharacteristicValueChange(function (characteristic) {
              // 接收到的数据转换为16进制字符串
              let hex = that.buf2hex(characteristic.value);
              
              // 更新最后收到数据的时间
              that.setData({
                lastDataTime: Date.now(),
                isDataSending: true
              });
              
              // 累积到全局缓冲区
              buf += hex;
              
              // 当累积到5000字符（500个数据包）时，批量发送
              if (buf.length >= batch_len) {
                that.sendDataToServer();
              }
            });
            
            // 启动数据状态检查定时器（每秒检查一次）
            that.startDataStatusCheck();
          },
          fail: function (err) {
            console.error('启用Notify功能失败', err);
          }
        });        
      },
      fail: function (err) {
        console.error('获取特征列表失败', err);
      }
    });
  },

  buf2hex: function (buffer) {
    return Array.prototype.map.call(new Uint8Array(buffer), x => ('00' + x.toString(16)).slice(-2)).join('');
  },

  // 启动数据状态检查定时器
  startDataStatusCheck: function() {
    const that = this;
    
    // 清除旧的定时器
    if (that.data.dataCheckTimer) {
      clearInterval(that.data.dataCheckTimer);
    }
    
    // 每1秒检查一次数据状态
    const timer = setInterval(() => {
      const now = Date.now();
      const timeSinceLastData = now - that.data.lastDataTime;
      
      // 如果超过2秒没有收到数据，认为数据发送已停止
      if (timeSinceLastData > 2000 && that.data.isDataSending) {
        that.setData({
          isDataSending: false
        });
      }
    }, 1000);
    
    that.setData({
      dataCheckTimer: timer
    });
  },

  // 切换数据发送状态
  toggleDataSending: function() {
    audioManager.playSound('button_click');  // 添加按钮音效
    
    if (!this.data.connected) {
      wx.showToast({ 
        title: '请先连接设备', 
        icon: 'none' 
      });
      return;
    }

    if (this.data.isDataSending) {
      // 当前正在发送，点击后停止
      this.enableBLEData("1919"); // 停止发送命令
      this.setData({
        isDataSending: false
      });
      wx.showToast({ 
        title: '数据发送已停止', 
        icon: 'success' 
      });
    } else {
      // 当前未发送，点击后开始
      this.enableBLEData("1919"); // 开始发送命令
      wx.showToast({ 
        title: '数据发送已开启', 
        icon: 'success' 
      });
      // 注意：isDataSending 会在收到第一个数据包时自动设置为 true
    }
  },

  // 发送数据函数（已废弃，保留以防兼容性问题）
  sendData() {
    // 该函数已被 toggleDataSending 替代
    wx.showToast({ 
      title: '请使用"发送数据"按钮', 
      icon: 'none' 
    });
  },

  // 切换音效开关
  toggleSound: function() {
    const enabled = audioManager.toggleSound();
    this.setData({ soundEnabled: enabled });
    
    // 播放音效测试（只在开启时）
    if (enabled) {
      audioManager.playSound('button_click');
    }
    
    wx.showToast({
      title: enabled ? '音效已开启' : '音效已关闭',
      icon: 'success',
      duration: 1000
    });
  },

  // 切换BGM开关
  toggleBGM: function() {
    const enabled = audioManager.toggleBGM();
    this.setData({ bgmEnabled: enabled });
    
    wx.showToast({
      title: enabled ? 'BGM已开启' : 'BGM已关闭',
      icon: 'success',
      duration: 1000
    });
  },

  // 处理输入框数据（已废弃）
  handleInput(e) {
    // 该函数已废弃，输入框已移除
  },

  // 十六进制字符串转ArrayBuffer
  hexStringToArrayBuffer(hexString) {
    var hex = hexString;
    var typedArray = new Uint8Array(hex.match(/[\da-f]{2}/gi).map(function (h) {
      return parseInt(h, 16);
    }));
    return typedArray.buffer;
  },

  // ========== 游戏图片资源加载 ==========
  
  // 加载游戏图片资源
  loadGameImages: function() {
    const fs = wx.getFileSystemManager();
    const basePath = `${wx.env.USER_DATA_PATH}/../../../images/game`;
    
    // 注意：小程序无法直接枚举文件，需要预定义图片文件名
    // 这里使用一个简单的方法：尝试加载固定命名的图片
    const gameImages = {
      monsters: [],
      bosses: [],
      turrets: [],
      bullets: [],
      background: ''
    };
    
    // 根据你的实际图片数量加载
    // 怪物图片: monster1.png ~ monster4.png
    for (let i = 1; i <= 4; i++) {
      const path = `/images/game/monsters/monster${i}.png`;
      gameImages.monsters.push(path);
    }
    
    // Boss图片: boss1.png ~ boss4.png
    for (let i = 1; i <= 4; i++) {
      const path = `/images/game/monsters/boss${i}.png`;
      gameImages.bosses.push(path);
    }
    
    // 炮塔图片: turret1.png ~ turret5.png
    for (let i = 1; i <= 5; i++) {
      const path = `/images/game/turrets/turret${i}.png`;
      gameImages.turrets.push(path);
    }
    
    // 炮弹图片: bullet1.png ~ bullet6.png
    for (let i = 1; i <= 6; i++) {
      const path = `/images/game/bullets/bullet${i}.png`;
      gameImages.bullets.push(path);
    }
    
    // 加载背景图片（只加载第一张）
    gameImages.background = '/images/game/backgrounds/background.png';
    
    this.setData({ gameImages });
  },
  
  // 从列表中随机选择一张图片
  getRandomImage: function(imageList) {
    if (!imageList || imageList.length === 0) {
      return null;
    }
    const randomIndex = Math.floor(Math.random() * imageList.length);
    const selectedImage = imageList[randomIndex];
    return selectedImage;
  },
  
  // 获取随机怪物图片（如果没有图片则返回null，使用emoji）
  getRandomMonsterImage: function() {
    return this.getRandomImage(this.data.gameImages.monsters);
  },
  
  // 获取随机Boss图片
  getRandomBossImage: function() {
    return this.getRandomImage(this.data.gameImages.bosses);
  },
  
  // 获取随机炮塔图片
  getRandomTurretImage: function() {
    return this.getRandomImage(this.data.gameImages.turrets);
  },
  
  // 获取随机炮弹图片
  getRandomBulletImage: function() {
    return this.getRandomImage(this.data.gameImages.bullets);
  },
  
  // 获取游戏背景图片
  getBackgroundImage: function() {
    return this.data.gameImages.background || '';
  },

  // 初始化空白图表
  initEmptyChart: function() {
    const windowWidth = wx.getSystemInfoSync().windowWidth;

    lineChart = new wxCharts({
      canvasId: 'eegChart',
      type: 'line',
      categories: [],
      animation: false,
      series: [{
        name: '注意力分数',
        data: [],
        color: '#4facfe'
      }],
      xAxis: {
        disableGrid: true,
        axisLineColor: '#cccccc',
        fontColor: '#ffffff',
        titleFontColor: '#ffffff'
      },
      yAxis: {
        title: '注意力分数',
        format: val => (typeof val === 'number' ? val.toFixed(2) : val),
        min: 0,
        max: 2,  // 初始范围，会动态调整
        gridColor: '#D8D8D8',
        fontColor: '#ffffff',
        titleFontColor: '#ffffff'
      },
      width: windowWidth * 0.95,
      height: 120,  // 迷你图表高度
      dataLabel: false,
      dataPointShape: false,
      extra: {
        lineStyle: 'curve'
      },
      legend: {
        show: false  // 隐藏图例节省空间
      },
      background: 'transparent',
      padding: [30, 10, 15, 30]
    });

    this.setData({ chartInited: true });
  },

  // 更新图表数据
  updateChartData: function(tbrValue) {
    if (!this.data.chartInited) return;

    const chartData = this.data.chartData;
    const dataCount = this.data.dataCount + 1;

    chartData.tbrData.push(tbrValue);
    chartData.timePoints.push(dataCount.toString());

    if (chartData.tbrData.length > this.data.maxDataPoints) {
      chartData.tbrData.shift();
      chartData.timePoints.shift();
    }

    this.setData({
      chartData,
      dataCount
    }, () => {
      this.refreshChart();
    });
  },

  // 刷新图表显示
  refreshChart: function() {
    if (!lineChart || !this.data.chartInited) return;

    const data = this.data.chartData.tbrData;
    
    // 动态计算Y轴范围
    let yMin = 0;
    let yMax = 2;
    
    if (data.length > 0) {
      const minVal = Math.min(...data);
      const maxVal = Math.max(...data);
      const range = maxVal - minVal;
      
      // 如果数据范围太小，设置最小范围
      if (range < 0.5) {
        const center = (maxVal + minVal) / 2;
        yMin = Math.max(0, center - 0.5);
        yMax = center + 0.5;
      } else {
        // 添加20%的余量
        yMin = Math.max(0, minVal - range * 0.2);
        yMax = maxVal + range * 0.2;
      }
    }

    lineChart.updateData({
      categories: this.data.chartData.timePoints,
      series: [{
        name: '注意力分数',
        data: data,
        color: '#4facfe'
      }],
      yAxis: {
        min: yMin,
        max: yMax,
        format: val => (typeof val === 'number' ? val.toFixed(2) : val)
      }
    });
  },

  // 地图拖动开始
  onMapTouchStart: function(e) {
    if (!this.data.gameStarted || this.data.gameOver) return;
    
    const touch = e.touches[0];
    this.setData({
      touchStartX: touch.pageX,
      touchStartY: touch.pageY,
      lastOffsetX: this.data.mapOffsetX,
      lastOffsetY: this.data.mapOffsetY
    });
  },

  // 地图拖动中
  onMapTouchMove: function(e) {
    if (!this.data.gameStarted || this.data.gameOver) return;
    
    const touch = e.touches[0];
    const deltaX = touch.pageX - this.data.touchStartX;
    const deltaY = touch.pageY - this.data.touchStartY;
    
    // 计算新的偏移量，限制拖动范围
    const maxOffsetX = 200; // 最大X偏移
    const maxOffsetY = 300; // 最大Y偏移
    
    let newOffsetX = this.data.lastOffsetX + deltaX;
    let newOffsetY = this.data.lastOffsetY + deltaY;
    
    // 限制偏移范围
    newOffsetX = Math.max(-maxOffsetX, Math.min(maxOffsetX, newOffsetX));
    newOffsetY = Math.max(-maxOffsetY, Math.min(maxOffsetY, newOffsetY));
    
    this.setData({
      mapOffsetX: newOffsetX,
      mapOffsetY: newOffsetY
    });
  },

  // 地图拖动结束
  onMapTouchEnd: function(e) {
    // 保存最终偏移量
    this.setData({
      lastOffsetX: this.data.mapOffsetX,
      lastOffsetY: this.data.mapOffsetY
    });
  },

  // 阻止页面滚动（游戏进行时锁定页面）
  preventPageScroll: function(e) {
    // 阻止默认的滚动行为
    return false;
  },

  // 手动结束游戏
  endGameManually: function() {
    audioManager.playSound('button_click');  // 添加按钮音效
    
    if (!this.data.gameStarted || this.data.gameOver) return;
    
    wx.showModal({
      title: '确认结束',
      content: '确定要结束本次游戏吗？',
      confirmText: '确定',
      cancelText: '取消',
      success: (res) => {
        if (res.confirm) {
          // 停止游戏BGM
          audioManager.stopBGM();
          
          // 调用stopExperiment完全重置到初始状态（内部会自动保存游戏记录）
          this.stopExperiment();

          wx.showToast({
            title: '游戏已结束',
            icon: 'success',
            duration: 2000
          });
        }
      }
    });
  }
});


