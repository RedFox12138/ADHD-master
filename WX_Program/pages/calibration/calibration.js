const app = getApp();
// 不再需要bluetoothDataManager，数据直接通过全局buf发送

// ========== URL 配置 ==========
const isDevTools = wx.getSystemInfoSync().platform === 'devtools';
const DEV_WS_URL = 'wss://xxyeeg.zicp.fun/ws';
const DEBUG_WS_URL = 'wss://xxyeeg.zicp.fun/ws';
const WS_URL = isDevTools ? DEV_WS_URL : DEBUG_WS_URL;

const DEV_HTTP_URL = 'https://xxyeeg.zicp.fun';
const DEBUG_HTTP_URL = 'https://xxyeeg.zicp.fun';
const HTTP_URL = isDevTools ? DEV_HTTP_URL : DEBUG_HTTP_URL;

// 批量累积策略
var buf = '';
var batch_len = 5000;
let socketTask = null;
let heartbeatTimer = null;

Page({
  data: {
    // 蓝牙连接状态
    connected: false,
    deviceName: '',
    socketConnected: false,
    isDataSending: false,
    lastDataTime: 0,  // 最后收到蓝牙数据的时间戳
    
    // 实验状态
    experimentStarted: false,
    currentPhase: '', // 'prepare', 'rest', 'break', 'attention', 'complete'
    phaseText: '',
    remainingTime: 0,
    
    // 实验次数记录
    completedTrials: 0,
    requiredTrials: 2,
    currentTrialNumber: 0,
    
    // 数据收集
    isCollectingData: false,
    currentCollectionPhase: '', // 当前收集的阶段类型
    restingData: [],     // 静息阶段数据
    attentionData: [],   // 注意力阶段数据
    currentPhaseData: [], // 当前阶段收集的数据
    
    // 躲避游戏相关
    gameActive: false,
    playerX: 375,         // 玩家位置（rpx）
    playerLives: 3,       // 玩家生命值
    obstacles: [],        // 障碍物数组
    gameScore: 0,         // 游戏分数
    
    // UI显示
    showGreenCross: false,  // 是否显示绿色十字
    showInstructions: false, // 是否显示说明
    instructionText: '',
    statusBarHeight: 0,
    
    // WebSocket重连
    reconnectAttempts: 0,
    maxReconnectAttempts: 10,
    reconnectTimer: null,
    isReconnecting: false,
    
    // 定时器
    phaseTimer: null,
    gameTimer: null,
    obstacleSpawnTimer: null
  },

  onLoad: function(options) {
    // 获取系统信息
    const systemInfo = wx.getSystemInfoSync();
    this.setData({
      statusBarHeight: systemInfo.statusBarHeight || 20
    });
    
    // 从app全局获取蓝牙连接状态
    if (app.globalData && app.globalData.connectedDevice) {
      this.setData({
        connected: true,
        deviceName: app.globalData.connectedDevice.name || '已连接'
      });
      console.log('蓝牙设备已连接:', app.globalData.connectedDevice.name);
    } else {
      console.log('蓝牙设备未连接');
    }
    
    // 检查是否已完成标定
    this.checkCalibrationStatus();
    
    // 连接WebSocket
    this.connectWebSocket();
    
    // 设置蓝牙数据监听
    this.setupBluetoothDataListener();
    
    // 监听蓝牙连接状态
    wx.onBLEConnectionStateChange(res => {
      if (!res.connected) {
        this.setData({ connected: false });
        wx.showToast({ title: '蓝牙连接已断开', icon: 'none' });
        this.stopCurrentPhase();
      } else {
        // 重新获取设备信息
        if (app.globalData && app.globalData.connectedDevice) {
          this.setData({ 
            connected: true,
            deviceName: app.globalData.connectedDevice.name || '已连接'
          });
        }
      }
    });
  },

  onShow: function() {
    // 每次显示页面时重新检查蓝牙连接状态
    if (app.globalData && app.globalData.connectedDevice) {
      this.setData({
        connected: true,
        deviceName: app.globalData.connectedDevice.name || '已连接'
      });
      console.log('页面显示，蓝牙已连接:', app.globalData.connectedDevice.name);
    } else {
      this.setData({
        connected: false,
        deviceName: ''
      });
      console.log('页面显示，蓝牙未连接');
    }
    
    // 重新检查标定状态，以获取最新的实验次数
    this.checkCalibrationStatus();
  },

  onUnload: function() {
    // 清理定时器
    this.stopCurrentPhase();
    
    // 关闭WebSocket
    if (socketTask) {
      socketTask.close();
      socketTask = null;
    }
    
    if (heartbeatTimer) {
      clearInterval(heartbeatTimer);
      heartbeatTimer = null;
    }
  },

  // ========== WebSocket相关 ==========
  connectWebSocket: function() {
    if (socketTask) {
      console.log('WebSocket已连接，跳过重连');
      return;
    }

    const userID = wx.getStorageSync('userID') || this.generateUserID();
    
    socketTask = wx.connectSocket({
      url: `${WS_URL}?user_id=${userID}`,
      success: () => {
        console.log('WebSocket连接请求已发送');
      },
      fail: (err) => {
        console.error('WebSocket连接失败:', err);
        this.scheduleReconnect();
      }
    });

    socketTask.onOpen(() => {
      console.log('WebSocket连接已建立');
      this.setData({ 
        socketConnected: true,
        reconnectAttempts: 0,
        isReconnecting: false
      });
      
      // 注册用户
      this.registerUser(userID);
      
      // 启动心跳
      this.startHeartbeat();
    });

    socketTask.onMessage((res) => {
      console.log('收到服务器消息:', res.data);
      try {
        const msg = JSON.parse(res.data);
        this.handleServerMessage(msg);
      } catch (e) {
        console.error('解析服务器消息失败:', e);
      }
    });

    socketTask.onClose(() => {
      console.log('WebSocket连接已关闭');
      this.setData({ socketConnected: false });
      socketTask = null;
      
      if (heartbeatTimer) {
        clearInterval(heartbeatTimer);
        heartbeatTimer = null;
      }
      
      this.scheduleReconnect();
    });

    socketTask.onError((err) => {
      console.error('WebSocket错误:', err);
      this.setData({ socketConnected: false });
    });
  },

  // 注册用户
  registerUser: function(userID) {
    if (socketTask && this.data.socketConnected) {
      const registerMsg = {
        type: 'register',
        user_id: userID
      };
      socketTask.send({
        data: JSON.stringify(registerMsg),
        success: () => {
          console.log('用户注册成功:', userID);
        },
        fail: (err) => {
          console.error('用户注册失败:', err);
        }
      });
    }
  },

  // 心跳机制
  startHeartbeat: function() {
    if (heartbeatTimer) {
      clearInterval(heartbeatTimer);
    }
    
    heartbeatTimer = setInterval(() => {
      if (socketTask && this.data.socketConnected) {
        socketTask.send({
          data: JSON.stringify({ type: 'ping' }),
          fail: (err) => {
            console.error('心跳发送失败:', err);
          }
        });
      }
    }, 30000); // 30秒心跳
  },

  // 重连调度
  scheduleReconnect: function() {
    if (this.data.isReconnecting || this.data.reconnectAttempts >= this.data.maxReconnectAttempts) {
      return;
    }

    this.setData({
      isReconnecting: true,
      reconnectAttempts: this.data.reconnectAttempts + 1
    });

    const delay = Math.min(1000 * Math.pow(2, this.data.reconnectAttempts), 30000);
    
    if (this.data.reconnectTimer) {
      clearTimeout(this.data.reconnectTimer);
    }

    const timer = setTimeout(() => {
      console.log(`第${this.data.reconnectAttempts}次重连WebSocket...`);
      this.connectWebSocket();
    }, delay);

    this.setData({ reconnectTimer: timer });
  },

  // 生成用户ID
  generateUserID: function() {
    const userID = 'user_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
    wx.setStorageSync('userID', userID);
    return userID;
  },

  // 处理服务器消息
  handleServerMessage: function(msg) {
    switch(msg.type) {
      case 'pong':
        // 心跳响应
        break;
      case 'calibration_result':
        // 标定结果
        this.handleCalibrationResult(msg.data);
        break;
      case 'error':
        wx.showToast({ title: msg.message || '服务器错误', icon: 'none' });
        break;
    }
  },

  // ========== 标定状态检查 ==========
  checkCalibrationStatus: function() {
    // 先从本地加载，然后从后端更新
    const calibrationData = wx.getStorageSync('calibrationData');
    if (calibrationData && calibrationData.userType) {
      this.setData({
        completedTrials: calibrationData.completedTrials || 3
      });
    }
    
    // 从后端获取最新状态
    this.fetchCalibrationStatusFromServer();
  },
  
  /**
   * 从后端获取用户标定状态
   */
  fetchCalibrationStatusFromServer: function() {
    // 使用与index.js相同的getUserId方法
    this.getUserId().then(userID => {
      console.log('[标定状态] 从后端获取用户标定状态, userID:', userID);
      
      wx.request({
        url: 'https://xxyeeg.zicp.fun/get_calibration_status',
        method: 'GET',
        data: { user_id: userID },
        success: (res) => {
          console.log('[标定状态] 后端返回:', res.data);
          
          if (res.data.success) {
            const completedCount = res.data.completed_trials || 0;
            this.setData({
              completedTrials: completedCount
            });
            
            // 如果已完成所有实验，保存标定结果到本地
            if (res.data.calibration_result) {
              const calibrationData = {
                userType: res.data.calibration_result.user_type,
                user_type: res.data.calibration_result.user_type,
                completedTrials: completedCount,
                restingMean: res.data.calibration_result.resting_mean,
                attentionMean: res.data.calibration_result.attention_mean,
                description: res.data.calibration_result.description
              };
              wx.setStorageSync('calibrationData', calibrationData);
              console.log('[标定状态] 已保存标定结果到本地');
            }
            
            console.log(`[标定状态] 已完成 ${completedCount}/${this.data.requiredTrials} 次实验`);
          } else {
            console.log('[标定状态] 用户还未进行过标定');
          }
        },
        fail: (err) => {
          console.error('[标定状态] 获取失败:', err);
          // 网络错误时使用本地数据
        }
      });
    }).catch(err => {
      console.error('[标定状态] 获取userID失败:', err);
    });
  },

  // ========== 实验控制 ==========
  sendDataToServer: function() {
    // 批量发送策略：每次发送5000字符（500个数据包）
    if (buf.length < batch_len) {
      return; // 数据不足，不发送
    }
    
    const that = this;
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
          Step: that.data.experimentStarted ? 'calibration_' + that.data.currentPhase : 'calibration',
          difficulty: 'normal'
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



  startCalibration: function() {
    // 检查蓝牙连接
    if (!this.data.connected) {
      wx.showModal({
        title: '提示',
        content: '请先连接脑电设备',
        showCancel: false,
        success: (res) => {
          if (res.confirm) {
            wx.navigateTo({ url: '/pages/scan/scan' });
          }
        }
      });
      return;
    }

    // 检查蓝牙数据是否正在传输
    if (!this.data.isDataSending) {
      wx.showModal({
        title: '数据未传输',
        content: '请先佩戴好设备，确保蓝牙数据正在传输。\n\n提示：返回主页查看实时波形，确认数据正常后再开始实验。',
        showCancel: false,
        confirmText: '知道了'
      });
      return;
    }

    // 检查WebSocket连接
    if (!this.data.socketConnected) {
      wx.showToast({ title: '服务器未连接', icon: 'none' });
      return;
    }

    // 显示实验说明
    wx.showModal({
      title: '离线实验说明',
      content: '实验流程：\n1. 10秒准备时间\n2. 1分钟静息阶段（显示绿色十字）\n3. 10秒休息时间\n4. 1分钟注意力阶段（躲避游戏）\n\n需要完成至少3次实验',
      confirmText: '开始',
      cancelText: '取消',
      success: (res) => {
        if (res.confirm) {
          this.runExperimentTrial();
        }
      }
    });
  },

  // 运行一次完整实验
  runExperimentTrial: function() {
    console.log('[离线实验] 开始第', this.data.completedTrials + 1, '次实验');
    
    // 重置数据收集
    this.setData({
      currentPhaseData: [],
      restingData: [],
      attentionData: [],
      experimentStarted: true,
      currentTrialNumber: this.data.completedTrials + 1
    });

    console.log('[离线实验] 发送开始记录指令到后端');
    
    // 发送开始记录指令给后端（学习塔防游戏）
    this.getUserId().then(user_id => {
      if (socketTask && this.data.socketConnected) {
        socketTask.send({
          data: JSON.stringify({
            event: 'start_calibration_recording',
            userId: user_id,
            trialNumber: this.data.completedTrials + 1
          }),
          success: () => {
            console.log('✅ 已发送开始记录指令（离线实验）');
          },
          fail: (err) => {
            console.error('❌ 发送开始记录指令失败', err);
          }
        });
      }
    });

    // 开始准备阶段
    this.startPreparePhase();
  },

  // ========== 准备阶段 (10秒) ==========
  startPreparePhase: function() {
    console.log('开始准备阶段');
    this.setData({
      currentPhase: 'prepare',
      remainingTime: 10,
      showGreenCross: false
    });

    // 倒计时
    const timer = setInterval(() => {
      const newTime = this.data.remainingTime - 1;
      this.setData({ remainingTime: newTime });

      if (newTime <= 0) {
        clearInterval(timer);
        this.setData({ phaseTimer: null });
        // 准备阶段结束，进入静息阶段
        this.startRestPhase();
      }
    }, 1000);

    this.setData({ phaseTimer: timer });
  },

  // ========== 静息阶段 (60秒) ==========
  startRestPhase: function() {
    console.log('开始静息阶段');
    this.setData({
      currentPhase: 'rest',
      remainingTime: 30,
      showGreenCross: true
    });

    // 倒计时
    const timer = setInterval(() => {
      const newTime = this.data.remainingTime - 1;
      this.setData({ remainingTime: newTime });

      if (newTime <= 0) {
        clearInterval(timer);
        this.setData({ phaseTimer: null });
        // 静息阶段结束，进入休息阶段
        this.startBreakPhase();
      }
    }, 1000);

    this.setData({ phaseTimer: timer });
  },

  // ========== 休息阶段 (10秒) ==========
  startBreakPhase: function() {
    console.log('开始休息阶段');
    this.setData({
      currentPhase: 'break',
      remainingTime: 10,
      showGreenCross: false
    });

    // 倒计时
    const timer = setInterval(() => {
      const newTime = this.data.remainingTime - 1;
      this.setData({ remainingTime: newTime });

      if (newTime <= 0) {
        clearInterval(timer);
        this.setData({ phaseTimer: null });
        // 休息阶段结束，进入注意力阶段
        this.startAttentionPhase();
      }
    }, 1000);

    this.setData({ phaseTimer: timer });
  },

  // ========== 注意力阶段 (60秒躲避游戏) ==========
  startAttentionPhase: function() {
    console.log('开始注意力阶段');
    this.setData({
      currentPhase: 'attention',
      remainingTime: 30,
      gameActive: true,
      gameScore: 0,
      playerX: 375,
      playerLives: 3,
      obstacles: []
    });

    // 开始游戏
    this.startDodgeGame();

    // 倒计时
    const timer = setInterval(() => {
      const newTime = this.data.remainingTime - 1;
      this.setData({ remainingTime: newTime });

      if (newTime <= 0) {
        clearInterval(timer);
        this.setData({ phaseTimer: null });
        // 停止游戏
        this.stopDodgeGame();
        // 注意力阶段结束，直接完成实验
        this.completeExperimentTrial();
      }
    }, 1000);

    this.setData({ phaseTimer: timer });
  },

  // ========== 躲避游戏逻辑 ==========
  startDodgeGame: function() {
    // 游戏循环 - 更新障碍物位置
    const gameLoop = setInterval(() => {
      if (!this.data.gameActive) {
        clearInterval(gameLoop);
        return;
      }
      this.updateGame();
    }, 50); // 20fps

    // 障碍物生成
    const obstacleSpawn = setInterval(() => {
      if (!this.data.gameActive) {
        clearInterval(obstacleSpawn);
        return;
      }
      this.spawnObstacle();
    }, 1000); // 每1秒生成一个障碍物

    this.setData({ 
      gameTimer: gameLoop,
      obstacleSpawnTimer: obstacleSpawn
    });
  },

  stopDodgeGame: function() {
    this.setData({ gameActive: false });
    if (this.data.gameTimer) {
      clearInterval(this.data.gameTimer);
    }
    if (this.data.obstacleSpawnTimer) {
      clearInterval(this.data.obstacleSpawnTimer);
    }
  },

  spawnObstacle: function() {
    const obstacle = {
      id: Date.now() + Math.random(),
      x: Math.random() * 550 + 100, // 随机x位置 100-650rpx
      y: 0,
      speed: Math.random() * 8 + 18,  // 速度18-26，更快的下落速度
      width: 50,  // 障碍物宽度（与CSS一致）
      height: 50  // 障碍物高度（与CSS一致）
    };
    
    const obstacles = this.data.obstacles;
    obstacles.push(obstacle);
    this.setData({ obstacles });
  },

  updateGame: function() {
    // 更新障碍物位置
    let obstacles = this.data.obstacles;
    let score = this.data.gameScore;
    let lives = this.data.playerLives;
    const playerX = this.data.playerX;
    const playerY = 1150;  // 玩家固定在底部的y坐标
    const playerWidth = 60;  // 玩家宽度（与CSS一致）
    const playerHeight = 60; // 玩家高度（与CSS一致）

    obstacles = obstacles.filter(obs => {
      obs.y += obs.speed;
      
      // 矩形碰撞检测（AABB碰撞）
      const obsLeft = obs.x - obs.width / 2;
      const obsRight = obs.x + obs.width / 2;
      const obsTop = obs.y;
      const obsBottom = obs.y + obs.height;
      
      const playerLeft = playerX - playerWidth / 2;
      const playerRight = playerX + playerWidth / 2;
      const playerTop = playerY - playerHeight / 2;
      const playerBottom = playerY + playerHeight / 2;
      
      // 检测碰撞：两个矩形是否重叠
      const isColliding = (
        obsLeft < playerRight &&
        obsRight > playerLeft &&
        obsTop < playerBottom &&
        obsBottom > playerTop
      );
      
      if (isColliding) {
        // 碰撞！仅移除子弹，不影响游戏继续（只采集脑电数据）
        console.log(`[躲避游戏] 检测到碰撞`);
        return false; // 移除这个子弹
      }
      
      // 障碍物超出屏幕底部
      if (obs.y > 1300) {
        return false; // 移除障碍物
      }
      
      return true;  // 保留这个障碍物
    });

    this.setData({ 
      obstacles,
      gameScore: score,
      playerLives: lives
    });
  },

  // 游戏控制
  onLeftDown: function() {
    this.moveInterval = setInterval(() => {
      let x = this.data.playerX - 10;
      if (x < 50) x = 50;
      this.setData({ playerX: x });
    }, 50);
  },

  onLeftUp: function() {
    if (this.moveInterval) {
      clearInterval(this.moveInterval);
    }
  },

  onRightDown: function() {
    this.moveInterval = setInterval(() => {
      let x = this.data.playerX + 10;
      if (x > 700) x = 700;
      this.setData({ playerX: x });
    }, 50);
  },

  onRightUp: function() {
    if (this.moveInterval) {
      clearInterval(this.moveInterval);
    }
  },

  // 开始离线实验数据记录
  startCalibrationRecording: function() {
    if (!this.data.socketConnected) {
      console.log('WebSocket未连接，无法开始记录');
      return;
    }

    const userID = wx.getStorageSync('userID');
    const trialNumber = this.data.currentTrialNumber;

    const msg = {
      type: 'start_calibration_recording',
      user_id: userID,
      trial_number: trialNumber
    };

    socketTask.send({
      data: JSON.stringify(msg),
      success: () => {
        console.log(`开始记录离线实验${trialNumber}数据`);
      },
      fail: (err) => {
        console.error('开始记录失败:', err);
      }
    });
  },

  // 停止离线实验数据记录并处理
  stopCalibrationRecording: function() {
    if (!this.data.socketConnected) {
      console.log('WebSocket未连接，无法停止记录');
      return;
    }

    const userID = wx.getStorageSync('userID');
    const trialNumber = this.data.currentTrialNumber;

    const msg = {
      type: 'stop_calibration_recording',
      user_id: userID,
      trial_number: trialNumber
    };

    socketTask.send({
      data: JSON.stringify(msg),
      success: () => {
        console.log(`停止记录离线实验${trialNumber}数据，开始处理`);
      },
      fail: (err) => {
        console.error('停止记录失败:', err);
      }
    });
  },

  // ========== 实验完成 ==========
  completeExperimentTrial: function() {
    console.log('[离线实验] 第', this.data.currentTrialNumber, '次实验完成');

    // 发送停止记录指令给后端（学习塔防游戏）
    this.getUserId().then(user_id => {
      if (socketTask && this.data.socketConnected) {
        socketTask.send({
          data: JSON.stringify({
            event: 'stop_calibration_recording',
            userId: user_id,
            trialNumber: this.data.currentTrialNumber
          }),
          success: () => {
            console.log('✅ 已发送停止记录指令（离线实验）');
          },
          fail: (err) => {
            console.error('❌ 发送停止记录指令失败', err);
          }
        });
      }
    });

    const completedCount = this.data.completedTrials + 1;
    this.setData({
      completedTrials: completedCount,
      currentPhase: 'complete',
      experimentStarted: false
    });

    console.log(`[离线实验] 已完成 ${completedCount}/${this.data.requiredTrials} 次实验`);

    // 检查是否完成所有实验
    if (completedCount >= this.data.requiredTrials) {
      // 所有实验完成
      this.setData({
        allTrialsComplete: true
      });
      
      // 查询最终结果（后端会自动分析）
      this.checkCalibrationResult();
    } else {
      // 还需要继续实验
      wx.showModal({
        title: '提示',
        content: `第 ${completedCount} 次实验已完成，请准备进行下一次实验`,
        showCancel: false
      });
    }
  },

  /**
   * 上传实验数据到后端
   */
  uploadTrialData: function() {
    this.getUserId().then(userID => {
      const trialNumber = this.data.currentTrialNumber;
      const eegData = this.data.allTrialData;
    
      console.log(`[离线实验] 上传第 ${trialNumber} 次实验数据，共 ${eegData.length} 个点`);
    
      if (eegData.length === 0) {
        wx.showModal({
          title: '错误',
          content: '没有收集到数据，请确保蓝牙已连接',
          showCancel: false
        });
        return;
      }
    
      wx.showLoading({ title: '正在上传数据...' });
    
      wx.request({
        url: 'https://xxyeeg.zicp.fun/upload_calibration_data',
        method: 'POST',
        data: {
          user_id: userID,
          trial_number: trialNumber,
          eeg_data: eegData
        },
        success: (res) => {
          wx.hideLoading();
          console.log('[离线实验] 数据上传成功:', res.data);
        
          if (res.data.success) {
            wx.showToast({ 
              title: `第${trialNumber}次数据已上传`, 
              icon: 'success' 
            });
          } else {
            wx.showToast({ 
              title: '数据上传失败', 
              icon: 'error' 
            });
          }
        },
        fail: (err) => {
          wx.hideLoading();
          console.error('[离线实验] 数据上传失败:', err);
          wx.showToast({ title: '网络错误', icon: 'error' });
        }
      });
    }).catch(err => {
      console.error('[离线实验] 获取 userId 失败:', err);
      wx.showToast({ title: '获取用户ID失败', icon: 'error' });
    });
  },

  /**
   * 查询标定结果
   */
  checkCalibrationResult: function() {
    console.log('[离线实验] 查询标定结果...');
    wx.showLoading({ title: '正在分析数据...' });
    
    // 使用统一的getUserId方法
    this.getUserId().then(userID => {
      // 延迟查询，给后端处理时间
      setTimeout(() => {
        wx.request({
          url: 'https://xxyeeg.zicp.fun/get_calibration_result',
          method: 'GET',
          data: { user_id: userID },
          success: (res) => {
            wx.hideLoading();
            console.log('[离线实验] 标定结果:', res.data);
            
            if (res.data.success) {
              // 保存结果到本地
              wx.setStorageSync('calibrationData', res.data);
              
              // 显示结果
              this.setData({
                calibrationResult: res.data
              });
              
              const typeDesc = res.data.user_type === 'type_A' ? '高活跃型' : '低活跃型';
              wx.showModal({
                title: '标定完成',
                content: `您的类型是: ${typeDesc}\n${res.data.description}`,
                showCancel: false,
                success: () => {
                  // 返回首页
                  wx.navigateBack();
                }
              });
            } else {
              // 还在处理中，继续查询
              console.log('[离线实验] 数据还在处理中，3秒后重试...');
              wx.showLoading({ title: '数据处理中...' });
              this.checkCalibrationResult();
            }
          },
          fail: (err) => {
            wx.hideLoading();
            console.error('[离线实验] 查询结果失败:', err);
            wx.showToast({ title: '查询失败', icon: 'error' });
          }
        });
      }, 3000);  // 延迟3秒查询
    }).catch(err => {
      wx.hideLoading();
      console.error('[离线实验] 获取userId失败:', err);
      wx.showToast({ title: '获取用户ID失败', icon: 'error' });
    });
  },

  continueExperiment: function() {
    this.runExperimentTrial();
  },

  viewResults: function() {
    const calibrationData = wx.getStorageSync('calibrationData');
    if (calibrationData) {
      wx.showModal({
        title: '标定结果',
        content: `用户类型: ${calibrationData.userType}\n静息均值: ${calibrationData.restingMean}\n注意力均值: ${calibrationData.attentionMean}`,
        showCancel: false
      });
    }
  },

  backToHome: function() {
    wx.navigateBack();
  },

  // 停止当前阶段
  stopCurrentPhase: function() {
    if (this.data.phaseTimer) {
      clearInterval(this.data.phaseTimer);
      this.setData({ phaseTimer: null });
    }
    
    if (this.data.gameTimer) {
      clearInterval(this.data.gameTimer);
      this.setData({ gameTimer: null });
    }
    
    if (this.data.obstacleSpawnTimer) {
      clearInterval(this.data.obstacleSpawnTimer);
      this.setData({ obstacleSpawnTimer: null });
    }
  },

  // ========== 导航 ==========
  navigateToScan: function() {
    wx.navigateTo({ url: '/pages/scan/scan' });
  },

  navigateBack: function() {
    wx.navigateBack();
  },

  // ========== 蓝牙数据监听 ==========
  /**
   * 设置蓝牙数据监听（在页面加载时调用一次）
   */
  setupBluetoothDataListener: function() {
    const that = this;
    
    // 监听所有蓝牙特征值变化
    wx.onBLECharacteristicValueChange(function (characteristic) {
      // 接收到的数据转换为16进制字符串
      const hex = that.buf2hex(characteristic.value);
      
      // 更新数据接收时间和状态
      const now = Date.now();
      that.setData({ 
        lastDataTime: now,
        isDataSending: true 
      });
      
      // 累积到全局缓冲区（用于实时波形显示）
      buf += hex;
      
      // 当累积到5000字符时，批量发送到服务器
      if (buf.length >= batch_len) {
        that.sendDataToServer();
      }
    });
    
    // 定期检查数据传输状态（2秒内没有数据则认为停止传输）
    setInterval(() => {
      const timeSinceLastData = Date.now() - that.data.lastDataTime;
      if (timeSinceLastData > 2000 && that.data.isDataSending) {
        that.setData({ isDataSending: false });
      }
    }, 1000);
    
    console.log('[离线实验] 蓝牙数据监听已设置');
  },

  /**
   * 将ArrayBuffer转换为16进制字符串
   */
  buf2hex: function (buffer) {
    return Array.prototype.map.call(
      new Uint8Array(buffer), 
      x => ('00' + x.toString(16)).slice(-2)
    ).join('');
  },

  /**
   * 解析16进制字符串为EEG整数值
   */
  parseHexToEEG: function(hexString) {
    const eegValues = [];
    
    // 每10个字符是一个数据包
    for (let i = 0; i < hexString.length; i += 10) {
      const packet = hexString.substr(i, 10);
      
      if (packet.length === 10) {
        // 前6个字符是EEG值（24位）
        const eegHex = packet.substr(0, 6);
        let value = parseInt(eegHex, 16);
        
        // 转换为有符号数
        if (value > 0x7FFFFF) {
          value -= 0x1000000;
        }
        
        eegValues.push(value);
      }
    }
    
    return eegValues;
  },

  // 与index.js完全一致的getUserId方法
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
              url: `${HTTP_URL}/getOpenId`,
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
            reject('登录失败');
          }
        },
        fail: () => {
          reject('wx.login 调用失败');
        }
      });
    });
  }
});
