const app = getApp();
var receivedData = []; // 全局数据接收缓冲区
var batch_len = 500;   // 每批发送数据量

Page({
  data: {
    // 设备连接状态
    connected: false,
    deviceName: '',
    inputData: '',

    // 数据可视化
    x_data: [],
    y_data: [],
    x_value: [],
    EEGdata: [],

    // 脑电参数
    powerRatio: null,
    DeltaPower: null,
    baselineDisplay: "--",
    attentionDisplay: "--",

    // 实验控制
    experimentStarted: false,
    currentPhase: '',      // '基准阶段'/'治疗阶段'
    remainingTime: 0,
    baselineValue: null,
    baselineSamples: [],
    currentAttention: null,

    birdY: 50,          // 小鸟垂直位置（百分比）
    currentScene: 'forest', // 当前场景
    scenes: {
      hell: { level: -2, image: '/images/hell.jpg', threshold: -20 },
      ground: { level: -1, image: '/images/ground.jpg', threshold: -10 },
      forest: { level: 0, image: '/images/forest.jpg', threshold: 0 },
      sky: { level: 1, image: '/images/sky.jpg', threshold: 60 },
      space: { level: 2, image: '/images/space.jpg', threshold: 120 },
      heaven: { level: 3, image: '/images/heaven.jpg', threshold: 180 }
    },
    sceneTimer: 0,      // 场景计时器（秒）
    sceneChanged: false, // 场景是否刚变化
    sceneCooldown: false // 场景切换冷却状态
  },

  onLoad: function() {
    // 初始化图表数据
    var arr1 = Array(20).fill().map((_,i) => i+1);
    var arr2 = Array(20).fill(0);
    this.setData({ x_value: arr1, EEGdata: arr2 });

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

  // 开始实验
  startExperiment: function() {
    if (!this.data.connected) {
      wx.showToast({ title: '请先连接设备', icon: 'none' });
      return;
    }

    this.setData({
      experimentStarted: true,
      currentPhase: '基准阶段',
      remainingTime: 20,
      baselineValue: null,
      baselineSamples: []
    });
    this.startPhaseTimer();
  },
  
  // 停止实验
  stopExperiment: function() {
    if (this.data.timer) {
      clearInterval(this.data.timer);
    }
    if (this.data.phaseTimer) {
      clearInterval(this.data.phaseTimer);
    }
    
    this.setData({
      experimentStarted: false,
      timer: null,
      phaseTimer: null
    });
  },
  
  // 启动阶段计时器
  startPhaseTimer: function() {
    const that = this;
    
    // 更新剩余时间
    that.data.phaseTimer = setInterval(() => {
      let remainingTime = that.data.remainingTime - 1;
      that.setData({ remainingTime });
      
      if (remainingTime <= 0) {
        clearInterval(that.data.phaseTimer);
        
        if (that.data.currentPhase === '基准阶段') {
          // 计算基准值
          const baselineValue = that.calculateBaseline();
          that.setData({
            baselineValue,
            currentPhase: '治疗阶段',
            remainingTime: 60
          });
          
          // 启动治疗阶段
          that.startTreatmentPhase();
        } else {
          // 实验结束
          that.stopExperiment();
          wx.showToast({ title: '实验完成', icon: 'success' });
        }
      }
    }, 1000);
  },
  
  // 计算基准值
// 计算基准值
calculateBaseline: function() {
  const samples = this.data.baselineSamples;
  if (samples.length === 0) return 0;

  const avg = samples.reduce((a,b) => a + parseFloat(b), 0) / samples.length;
  this.setData({ baselineValue: parseFloat(avg.toFixed(2)) });
  return this.data.baselineValue;
},
  

startTreatmentPhase: function() {
  this.setData({
    currentPhase: '治疗阶段',
    remainingTime: 180, // 延长到3分钟
    gameStarted: true,
    gameOver: false,
    birdY: 50,
    currentScene: 'forest',
    sceneTimer: 0,
    sceneChanged: false
  });

  // 游戏倒计时
  const gameTimer = setInterval(() => {
    if(this.data.remainingTime <= 0){
      clearInterval(gameTimer);
      this.setData({ gameOver: true });
      return;
    }
    this.setData({ remainingTime: this.data.remainingTime - 1 });
  }, 1000);

  // 游戏循环
  this.data.timer = setInterval(this.updateGameState.bind(this), 50);
},
  
  // 重新开始实验
restartExperiment: function() {
    this.stopExperiment();
    this.setData({
        gameOver: false,
        experimentStarted: false
    });
    // 可以添加一些延迟让用户看到状态变化
    setTimeout(() => {
        this.startExperiment();
    }, 500);
},
  
updateGameState: function() {
  if (!this.data.gameStarted || this.data.gameOver || this.data.sceneCooldown) return;
  
  // 计算注意力差值
  const attentionDiff = this.data.currentAttention - this.data.baselineValue;
  
  // 更新小鸟位置（带速度限制）
  let newBirdY = this.data.birdY;
  const speed = 0.15; // 降低速度防止过冲
  
  if (attentionDiff > 0) {
    newBirdY = Math.max(5, newBirdY - speed);
  } else {
    newBirdY = Math.min(95, newBirdY + speed);
  }
  
  // 强制边界锁定
  if (newBirdY <= 5) newBirdY = 5;
  if (newBirdY >= 95) newBirdY = 95;
  
  this.setData({ birdY: newBirdY });
  
  // 场景检查（带冷却检测）
  if (newBirdY === 5 || newBirdY === 95) {
    this.checkSceneChange(newBirdY, attentionDiff);
  }
},

checkSceneChange: function(newBirdY, attentionDiff) {
  if (this.data.sceneCooldown) return;
  
  const currentScene = this.data.currentScene;
  const currentLevel = this.data.scenes[currentScene].level;
  
  // 精确逐级切换逻辑
  let targetLevel = currentLevel;
  if (newBirdY === 5 && attentionDiff > 0) {
    targetLevel = Math.min(currentLevel + 1, 3); // 最大层级3
  } else if (newBirdY === 95 && attentionDiff < 0) {
    targetLevel = Math.max(currentLevel - 1, -2); // 最小层级-2
  } else {
    return;
  }
  
  // 查找目标场景
  const targetScene = Object.entries(this.data.scenes).find(
    ([_, s]) => s.level === targetLevel
  );
  
  if (targetScene) {
    // 开启冷却
    this.setData({ sceneCooldown: true });
    
    // 执行切换
    const [newSceneKey] = targetScene;
    this.setData({
      currentScene: newSceneKey,
      birdY: targetLevel > currentLevel ? 95 : 5,
      sceneChanged: true
    });
    
    // 调试日志
    console.log(`[切换] ${currentScene}(${currentLevel}) → ${newSceneKey}(${targetLevel})`);
    
    // 冷却计时器（500ms内禁止再次切换）
    setTimeout(() => {
      this.setData({ sceneCooldown: false });
    }, 500);
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
              url: 'http://4nbsf9900182.vicp.fun:18595/getOpenId',
              method: 'POST',
              data: { code: res.code },
              success: (res) => {
                console.log(res);
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
    this.getUserId().then((user_id) => {
      const dataToSend = receivedData.slice(0, batch_len);
      receivedData = receivedData.slice(batch_len);
      wx.request({
        url: 'http://4nbsf9900182.vicp.fun:18595/process', 
        method: 'POST',
        data: {
          points: dataToSend,
          userId: user_id
        },
        success: (res) => {
          console.log(res);
          // 检查返回数据是否有效
          if (!res.data || !Array.isArray(res.data.TBR) || res.data.TBR.length === 0) {
            console.log('无效的TBR数据，已忽略');
            return;
          }
          
          // 计算TBR数组的平均值
          const validTBRs = res.data.TBR.filter(tbr => tbr !== undefined && tbr !== null && tbr >= 0);
          if (validTBRs.length === 0) {
            console.log('没有有效的TBR值');
            return;
          }
          
          // const DeltaPowerCurrent = res.data.DeltaCumAvg[-1];
          const averageTBR = validTBRs.reduce((sum, tbr) => sum + tbr, 0) / validTBRs.length;
          const attentionValues = validTBRs.map(tbr => 
            Math.max(0, Math.min(100, tbr * 10))
          );
          
          // 强制更新UI显示平均值
          this.setData({
            // DeltaPower: DeltaPowerCurrent.toFixed(2),
            powerRatio: averageTBR.toFixed(2),
            currentAttention: (averageTBR * 10).toFixed(2)
          });
          
          // 如果在基准阶段，收集所有样本
          if (this.data.experimentStarted && this.data.currentPhase === '基准阶段') {
            this.setData({
              baselineSamples: [...this.data.baselineSamples, ...attentionValues]
            });
          }
          
          if (receivedData.length >= batch_len) {
            this.sendDataToServer();
          }
        },
        fail: (err) => {
          console.error('Request failed:', err);
        },
      });
    }).catch((err) => {
      console.error('获取 user_id 失败:', err);
    });
  },

  onShow() {
    var that = this;
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
        console.log("success  指令发送成功");
      },
      fail: function (res) {
        console.log("success  指令发送失败", res.errMsg);
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

        if (!deviceId || !serviceId || !targetCharacteristicId) {
          console.error('缺失必要参数，请检查设备连接状态');
          return;
        }

        that.enableBLEData("1919"); 

        let buf = '';

        wx.notifyBLECharacteristicValueChange({
          deviceId: deviceId,
          serviceId: serviceId,
          characteristicId: targetChar.uuid,
          state: true,
          success: function (res) {
            console.log('Notify功能启用成功', res);
            wx.onBLECharacteristicValueChange(function (characteristic) {
              let hex = that.buf2hex(characteristic.value);
              buf += hex;
              const packetLength = 10;
              let processedIndex = 0;
              let bufLen = buf.length;
        
              while (bufLen - processedIndex >= packetLength) {
                if (buf[processedIndex] === '1' &&
                    buf[processedIndex + 1] === '1' &&
                    buf[processedIndex + 8] === '0' &&
                    buf[processedIndex + 9] === '1') {
                  let str1 = buf.substring(processedIndex + 2, processedIndex + 8);
                  let value1 = parseInt(str1, 16);
                  if (value1 >= 8388608) {
                    value1 -= 16777216;
                  }
                  value1 = value1 * 2.24 * 1000 / 8388608;
                  receivedData.push(value1);
                  processedIndex += packetLength;
                } else {
                  processedIndex++;
                }
              }
              buf = buf.substring(processedIndex);
              
              if(receivedData.length >= batch_len) {
                that.sendDataToServer();
              }
            });
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

  handleInput(e) {
    this.setData({ inputData: e.detail.value });
  },
  
  buf2hex: function (buffer) {
    return Array.prototype.map.call(new Uint8Array(buffer), x => ('00' + x.toString(16)).slice(-2)).join('');
  },
  
  hexStringToArrayBuffer(hexString) {
    var hex = hexString
    var typedArray = new Uint8Array(hex.match(/[\da-f]{2}/gi).map(function (h) {
      return parseInt(h, 16)
    }))
    return typedArray.buffer
  },

  sendData() {
    if (!this.data.connected) {
      wx.showToast({ title: '未连接设备', icon: 'none' });
      return;
    }

    if (!this.data.inputData) {
      wx.showToast({ title: '请输入数据', icon: 'none' });
      return;
    }
    this.enableBLEData(this.data.inputData)
  }
});