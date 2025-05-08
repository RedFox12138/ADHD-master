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
    baselineDisplay: "--",
    attentionDisplay: "--",

    // 实验控制
    experimentStarted: false,
    currentPhase: '',      // '基准阶段'/'治疗阶段'
    remainingTime: 0,
    baselineValue: null,
    baselineSamples: [],
    currentAttention: null,

    // 游戏状态
    gameStarted: false,
    spaceshipX: 50,        // 飞船位置(百分比)
    spaceshipY: 80,
    spaceshipSize: 30,
    spaceshipColor: '#4CAF50',
    meteors: [],           // 陨石数组
    score: 0,
    gameSpeed: 1,
    explosions: [],        // 爆炸效果
    gameOver: false,
    lastMeteorTime: 0,
    shield: 100,           // 护盾值
    boost: 0,              // 推进能量
    gameMessage: "",
    messageTimer: null,
    gameOverTimestamp: 0   // 新增：游戏结束时间戳
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
  
  // 启动治疗阶段
  startTreatmentPhase: function() {
    this.setData({
      currentPhase: '治疗阶段',
      remainingTime: 60,
      gameStarted: true,
      gameOver: false,
      shield: 100,
      score: 0,
      gameMessage: "保持专注！陨石即将来袭！"
    });
    
    // 消息自动消失
    this.data.messageTimer = setTimeout(() => {
      this.setData({ gameMessage: "" });
    }, 3000);
    
     // 启动游戏循环
     this.startPhaseTimer();
     this.data.timer = setInterval(this.updateGameState.bind(this), 50);
   },
  
  
   updateGameState: function() {
    if (!this.data.gameStarted || this.data.currentAttention === null) return;

    // 注意力计算
    const attentionDiff = this.data.currentAttention - this.data.baselineValue;
    const gameSpeed = Math.max(0.5, Math.min(2, 1 + attentionDiff * 0.02));

    // 飞船状态
    let spaceshipColor = '#4CAF50';
    if (attentionDiff < -5) spaceshipColor = '#FF5722';
    if (attentionDiff > 5) spaceshipColor = '#2196F3';

    // 飞船移动
    let [x, y] = [this.data.spaceshipX, this.data.spaceshipY];
    if (attentionDiff > 0) {
      x += (50 - x) * 0.02 * gameSpeed;
      y += (80 - y) * 0.02 * gameSpeed;
    } else {
      x += (Math.random() - 0.5) * 3 * (2 - gameSpeed);
      y += (Math.random() - 0.3) * 2 * (2 - gameSpeed);
    }
    x = Math.max(10, Math.min(90, x));
    y = Math.max(20, Math.min(90, y));

    // 陨石生成（仅在游戏进行时）
    let meteors = this.data.meteors;
    if (!this.data.gameOver) {
      const now = Date.now();
      const spawnRate = Math.max(0.5, 2 - attentionDiff * 0.03);
      
      if (now - this.data.lastMeteorTime > 1000 / spawnRate) {
        meteors.push(this.createMeteor());
        this.setData({ lastMeteorTime: now });
      }

      // 碰撞检测
      meteors = meteors.map(meteor => {
        meteor.y += 2 * gameSpeed;
        
        if (!meteor.hit && this.checkCollision(x, y, meteor)) {
          meteor.hit = true;
          this.setData({ shield: this.data.shield - (10 + meteor.size * 2) });
          
          if (attentionDiff > 5 && Math.random() > 0.7) {
            this.createExplosion(meteor.x, meteor.y, meteor.size);
            return null;
          }
        }
        return meteor;
      }).filter(m => m && m.y < 100 + m.size);
    }

    // 护盾恢复
    const shield = Math.max(0, Math.min(100, 
      this.data.shield + attentionDiff * 0.3));

    // 游戏结束检测
    if (shield <= 0 && !this.data.gameOver) {
      this.handleGameOver();
      meteors = []; // 清空陨石
    }

    // 更新视图
    this.setData({
      spaceshipX: x,
      spaceshipY: y,
      spaceshipColor,
      meteors,
      shield,
      gameSpeed,
      boost: Math.max(0, Math.min(100, this.data.boost + attentionDiff * 0.5)),
      score: Math.floor(this.data.score + Math.max(0, gameSpeed * 0.1))
    });
  },
  handleGameOver: function() {
    this.setData({
      gameOver: true,
      gameOverTimestamp: Date.now()
    });
    this.showGameMessage("护盾耗尽！3秒后复活");

    setTimeout(() => {
      this.setData({
        gameOver: false,
        shield: 100,
        score: Math.max(0, this.data.score - 30)
      });
    }, 3000);
  },

  createMeteor: function() {
    const size = 5 + Math.random() * 15;
    return {
      x: Math.random() * 80 + 10,
      y: -size,
      size,
      speed: 1 + Math.random() * 2,
      hit: false
    };
  },

   checkCollision: function(shipX, shipY, meteor) {
    const dist = Math.sqrt(
      Math.pow(shipX - meteor.x, 2) + 
      Math.pow(shipY - meteor.y, 2)
    );
    return dist < (this.data.spaceshipSize + meteor.size) / 2;
  },
    
  createExplosion: function(x, y, size) {
    this.setData({
      explosions: [...this.data.explosions, {
        x, y, 
        size: size * 0.5, 
        opacity: 1
      }]
    });
  },

  showGameMessage: function(msg) {
    clearTimeout(this.data.messageTimer);
    this.setData({ gameMessage: msg });
    this.data.messageTimer = setTimeout(() => {
      this.setData({ gameMessage: "" });
    }, 3000);
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
              url: 'http://4nbsf9900182.vicp.fun/getOpenId',
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
        url: 'http://4nbsf9900182.vicp.fun/process', 
        method: 'POST',
        data: {
          points: dataToSend,
          userId: user_id
        },
        success: (res) => {
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
          
          const averageTBR = validTBRs.reduce((sum, tbr) => sum + tbr, 0) / validTBRs.length;
          const attentionValues = validTBRs.map(tbr => 
            Math.max(0, Math.min(100, 100 - (tbr * 10)))
          );
          
          // 强制更新UI显示平均值
          this.setData({
            powerRatio: averageTBR.toFixed(2),
            currentAttention: (100 - (averageTBR * 10)).toFixed(2)
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