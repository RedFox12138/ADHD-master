const app = getApp();
var receivedData = [];//全局用来接收数据的点
var batch_len = 500;
Page({
  data: {
    connected: false,
    deviceName: '',
    inputData: '', // 用户输入的十六进制数据
    x_data:[],
    y_data:[],
    x_value: [],
    EEGdata: [],
    powerRatio: null,
    baselineDisplay: "--",
    attentionDisplay: "--",
    
    // 实验相关状态
    experimentStarted: false,
    currentPhase: '', // '基准阶段' 或 '治疗阶段'
    remainingTime: 0,
    baselineValue: null,
    baselineSamples: [],
    currentAttention: null,
    
    // 游戏相关状态
    houseHeight: 50,
    houseWidth: 80,
    roofHeight: 30,
    roofWidth: 100,
    gameProgress: 0, // 0-100
    timer: null,
    phaseTimer: null
  },

  onLoad: function () {
    var that = this;
    var arr1 = new Array(20);
    var arr2 = new Array(20);
    for (var i = 0; i < 20; i++) {
      arr1[i] = i + 1;
      arr2[i] = 0;
    }
    that.setData({
      x_value: arr1,
      EEGdata: arr2,
    });

    
    wx.onBLEConnectionStateChange(res => {
      console.log('连接状态变化:', res);
      if (!res.connected) {
        this.setData({ connected: false });
        wx.showToast({ title: '连接已断开', icon: 'none' });
        // 如果实验正在进行中，停止实验
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
      baselineSamples: [],
      currentAttention: null,
      houseHeight: 50,
      houseWidth: 80,
      roofHeight: 30,
      roofWidth: 100,
      gameProgress: 0
    });
    
    // 启动基准阶段计时器
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
  if (this.data.baselineSamples.length === 0) {
    console.warn('没有可用的基准样本');
    return 0;
  }
  
  const sum = this.data.baselineSamples.reduce((a, b) => a + parseFloat(b), 0);
  const avg = sum / this.data.baselineSamples.length;
  // 强制更新UI
  this.setData({
    baselineValue: parseFloat(avg.toFixed(2))
  });
  
  return parseFloat(avg.toFixed(2));
},
  
  // 启动治疗阶段
  startTreatmentPhase: function() {
    const that = this;
    
    // 启动计时器
    this.startPhaseTimer();
    
    // 启动游戏更新循环
    that.data.timer = setInterval(() => {
      // 更新游戏状态
      that.updateGameState();
    }, 100); // 每100毫秒更新一次游戏状态
  },
  
  // 更新游戏状态
  updateGameState: function() {
    if (this.data.currentAttention === null) return;
    
    const baseline = this.data.baselineValue;
    const current = this.data.currentAttention;
    
    // 计算注意力变化
    const attentionDiff = current - baseline;
    
    // 更新游戏进度 (0-100)
    let progress = this.data.gameProgress;
    progress += attentionDiff * 0.5; // 调整系数控制灵敏度
    
    // 限制在0-100范围内
    progress = Math.max(0, Math.min(100, progress));
    
    // 更新房子大小
    const houseHeight = 50 + progress * 1.5;
    const houseWidth = 80 + progress * 0.8;
    const roofHeight = 30 + progress * 0.5;
    const roofWidth = 100 + progress;
    
    this.setData({
      gameProgress: progress,
      houseHeight,
      houseWidth,
      roofHeight,
      roofWidth
    });
    
    // 实时更新UI
    this.setData({
      currentAttention: current,
      baselineValue: baseline
    });
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
              url: 'http://7809sk6421.zicp.fun:47409/getOpenId',
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
        url: 'http://7809sk6421.zicp.fun:47409/process', 
        method: 'POST',
        data: {
          points: dataToSend,
          userId: user_id
        },
        success: (res) => {
          // 检查返回数据是否有效
          if (!res.data || res.data.TBR === undefined || res.data.TBR === null || res.data.TBR < 0) {
            console.log('无效的TBR值，已忽略');
            return;
          }
          
          const powerRatio = parseFloat(res.data.TBR);
          const attentionValue = Math.max(0, Math.min(100, 100 - (powerRatio * 10))); // 确保在0-100范围内
          // 强制更新UI
          this.setData({
            powerRatio: powerRatio.toFixed(2),
            currentAttention: attentionValue.toFixed(2)
          });
          
          // 如果在基准阶段，收集样本
          if (this.data.experimentStarted && this.data.currentPhase === '基准阶段') {
            this.setData({
              baselineSamples: [...this.data.baselineSamples, attentionValue]
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