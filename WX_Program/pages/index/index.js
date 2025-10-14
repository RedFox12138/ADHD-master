const app = getApp();
var receivedData = []; // 全局数据接收缓冲区
var batch_len = 500;   // 每批发送数据量
var wxCharts = require('../../utils/wxcharts.js');
let lineChart = null;

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

    // 脑电参数（仅保留 TBR）
    powerRatio: null, // TBR 数值（基准阶段为累计均值，治疗阶段为最新值）

    // 实验控制
    experimentStarted: false,
    currentPhase: '',      // '基准阶段'/'治疗阶段'
    remainingTime: 0,
    baselineValue: null,
    currentAttention: null,
    baselineSum: 0,       // 基准阶段累计求和
    baselineCount: 0,     // 基准阶段累计个数

    // 游戏相关
    birdY: 50,          // 小鸟垂直位置（百分比）
    currentScene: 'forest', // 当前场景
    scenes: {
      hell: { level: -2, image: '/images/hell.jpg' },
      ground: { level: -1, image: '/images/ground.jpg' },
      forest: { level: 0, image: '/images/forest.jpg' },
      sky: { level: 1, image: '/images/sky.jpg' },
      space: { level: 2, image: '/images/space.jpg' },
      heaven: { level: 3, image: '/images/heaven.jpg' }
    },
    sceneTransitionProgress: 0,
    nextScene: null,
    isTransitioning: false,
    sceneCooldown: false,
    boundaryLock: false,
    gameStarted: false,
    gameOver: false,

    inputData: '', // 输入框数据
    chartInited: false
  },

  onLoad: function() {
    this.initEmptyChart();
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
    if (!this.data.connected) {
      wx.showToast({ title: '请先连接设备', icon: 'none' });
      return;
    }
    
    this.resetChart();
    this.setData({
      experimentStarted: true,
      currentPhase: '准备阶段',
      remainingTime: 10,
      baselineValue: null,
      baselineSum: 0,
      baselineCount: 0,
      gameOver: false,
      gameStarted: false
    });
    this.startPhaseTimer();
  },
  
  stopExperiment: function() {
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

    this.setData({
      experimentStarted: false,
      currentPhase: '',
      gameOver: true,
      gameStarted: false,
      timer: null,
      phaseTimer: null,
      gameTimer: null,
      baselineSum: 0,
      baselineCount: 0
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
          // 基准阶段结束：使用整段基准期内TBR的累计均值作为 baselineValue
          const { baselineSum, baselineCount } = that.data;
          const baselineValue = baselineCount > 0 ? Math.round((baselineSum / baselineCount) * 100) / 100 : null;
          that.setData({
            baselineValue,
            currentPhase: '治疗阶段',
            remainingTime: 180,
            // 清空基准阶段的累加值，避免影响下次实验
            baselineSum: 0,
            baselineCount: 0
          });
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
      birdY: 50,
      currentScene: 'forest'
    });

    // 游戏倒计时
    this.data.gameTimer = setInterval(() => {
      if(this.data.remainingTime <= 0){
        clearInterval(this.data.gameTimer);
        this.setData({ gameOver: true });
        return;
      }
      this.setData({ remainingTime: this.data.remainingTime - 1 });
    }, 1000);

    // 游戏循环
    this.data.timer = setInterval(this.updateGameState.bind(this), 50);
  },

  restartExperiment: function() {
    this.stopExperiment();
    this.resetChart();
    this.setData({
      baselineValue: null,
      currentAttention: null,
      baselineSum: 0,
      baselineCount: 0,
      currentPhase:'',
      gameOver: false,
      experimentStarted: false,
      birdY: 50,
      currentScene: 'forest'
    });
    setTimeout(() => {
      this.startExperiment();
    }, 500);
  },
  
  updateGameState: function() {
    if (!this.data.gameStarted || this.data.gameOver || 
        this.data.sceneCooldown || this.data.boundaryLock) return;
    if (this.data.currentPhase === '基准阶段') return;

    // 空值保护：没有基线或当前注意力值则不更新
    if (this.data.baselineValue == null || this.data.currentAttention == null) return;

    const attentionDiff = this.data.currentAttention - this.data.baselineValue;
    let newBirdY = this.data.birdY;

    const speed = 0.1 + Math.abs(attentionDiff) * 0.02;

    if (attentionDiff < 0) {
      newBirdY = Math.max(5, newBirdY - speed);
    } else {
      newBirdY = Math.min(95, newBirdY + speed);
    }

    this.setData({ birdY: newBirdY });

    if (newBirdY === 5 || newBirdY === 95) {
      this.checkSceneChange(newBirdY, attentionDiff);
    }
  },

  checkSceneChange: function(newBirdY, attentionDiff) {
    if (this.data.sceneCooldown || this.data.isTransitioning) return;
    
    const currentScene = this.data.currentScene;
    const currentLevel = this.data.scenes[currentScene].level;
    
    let targetLevel = currentLevel;
    let resetPosition = newBirdY;

    if (newBirdY === 5 && attentionDiff < 0) { // 注意力低，向上飞，触发向上切换场景
      targetLevel = Math.min(currentLevel + 1, 3);
      resetPosition = 95;
    } else if (newBirdY === 95 && attentionDiff > 0) { // 注意力高，向下飞，触发向下切换场景
      targetLevel = Math.max(currentLevel - 1, -2);
      resetPosition = 5;
    } else {
      return;
    }
    
    const targetScene = Object.entries(this.data.scenes).find(
      ([_, s]) => s.level === targetLevel
    );
    
    if (targetScene) {
      const [newSceneKey] = targetScene;
      
      this.setData({
        nextScene: newSceneKey,
        isTransitioning: true,
        sceneCooldown: true,
        boundaryLock: true
      });
      
      const duration = 800;
      const steps = 20;
      const interval = duration / steps;
      let progress = 0;
      
      const transitionTimer = setInterval(() => {
        progress += (1 / steps);
        if (progress >= 1) {
          clearInterval(transitionTimer);
          this.setData({
            currentScene: newSceneKey,
            nextScene: null,
            isTransitioning: false,
            sceneTransitionProgress: 0,
            birdY: resetPosition,
            boundaryLock: false
          });
          
          setTimeout(() => {
            this.setData({ sceneCooldown: false });
          }, 500);
        } else {
          this.setData({ sceneTransitionProgress: progress });
        }
      }, interval);
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
              url: 'http://xxyeeg.zicp.fun/getOpenId',
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
    this.getUserId().then((user_id) => {
      const dataToSend = receivedData.slice(0, batch_len);
      receivedData = receivedData.slice(batch_len);

      wx.request({
        url: 'http://xxyeeg.zicp.fun/process', 
        method: 'POST',
        data: {
          points: dataToSend,
          userId: user_id,
          Step: this.data.currentPhase
        },
        success: (res) => {
          if (!res.data || res.data.TBR === undefined || res.data.TBR === null) {
            return;
          }

          // 兼容 TBR 为单值或数组
          const tbrRaw = res.data.TBR;
          const tbrArr = Array.isArray(tbrRaw) ? tbrRaw : [tbrRaw];

          // 显式数值化并过滤无效 TBR
          const tbrNums = tbrArr
            .map(v => Number(v))
            .filter(v => Number.isFinite(v) && v >= 0);
          if (tbrNums.length === 0) {
            return;
          }

          const phase = this.data.currentPhase;

          if (phase === '基准阶段') {
            // 基准阶段：
            // 1. 图表和当前值(powerRatio)显示最新的TBR值
            const lastTbr = tbrNums[tbrNums.length - 1];
            const lastTbrSnap = Math.round(lastTbr * 100) / 100;
            this.setData({
              powerRatio: lastTbrSnap
            });
            this.updateChartData(lastTbrSnap);

            // 2. 暂存完整的TBR数组，用于在阶段结束时计算总均值
            const batchSum = tbrNums.reduce((s, v) => s + v, 0);
            this.setData({
              baselineSum: batchSum,
              baselineCount: tbrNums.length
            });

          } else if (phase === '治疗阶段') {
            // 治疗阶段：使用最新的一个TBR作为当前值
            const last = tbrNums[tbrNums.length - 1];
            const lastSnap = Math.round(last * 100) / 100;
            this.setData({
              powerRatio: lastSnap,
              currentAttention: lastSnap
            });
            this.updateChartData(lastSnap);

          } else {
            // 准备阶段或其他：可忽略或仅做预热，不入库
            // 这里选择忽略
          }

          if (receivedData.length >= batch_len) {
            this.sendDataToServer();
          }
        },
        fail: (err) => {
          console.error('Request failed:', err);
        }
      });
    }).catch((err) => {
      console.error('获取 user_id 失败:', err);
    });
  },

  onShow() {
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
    wx.navigateTo({ url: '/pages/history/history' });
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
        console.log("指令发送成功");
      },
      fail: function (res) {
        console.log("指令发送失败", res.errMsg);
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

        that.enableBLEData("1919");
        let buf = '';

        wx.notifyBLECharacteristicValueChange({
          deviceId: deviceId,
          serviceId: serviceId,
          characteristicId: targetChar.uuid,
          state: true,
          success: function (res) {
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

  buf2hex: function (buffer) {
    return Array.prototype.map.call(new Uint8Array(buffer), x => ('00' + x.toString(16)).slice(-2)).join('');
  },

  // 发送数据函数
  sendData() {
    if (!this.data.connected) {
      wx.showToast({ title: '未连接设备', icon: 'none' });
      return;
    }

    if (!this.data.inputData) {
      wx.showToast({ title: '请输入数据', icon: 'none' });
      return;
    }

    // 调用蓝牙数据发送函数
    this.enableBLEData(this.data.inputData);
    wx.showToast({ title: '数据发送成功', icon: 'success' });
  },

  // 处理输入框数据
  handleInput(e) {
    this.setData({ inputData: e.detail.value });
  },

  // 十六进制字符串转ArrayBuffer
  hexStringToArrayBuffer(hexString) {
    var hex = hexString;
    var typedArray = new Uint8Array(hex.match(/[\da-f]{2}/gi).map(function (h) {
      return parseInt(h, 16);
    }));
    return typedArray.buffer;
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
        name: '样本熵',
        data: [],
        color: '#ff0000'
      }],
      xAxis: {
        disableGrid: true,
        axisLineColor: '#cccccc',
        fontColor: '#ffffff',
        titleFontColor: '#ffffff'
      },
      yAxis: {
        title: '样本熵',
        format: val => (typeof val === 'number' ? val.toFixed(2) : val),
        min: 0,
        max: 10,
        gridColor: '#D8D8D8',
        fontColor: '#ffffff',
        titleFontColor: '#ffffff'
      },
      width: windowWidth * 0.95,
      height: 200,
      dataLabel: false,
      dataPointShape: false,
      extra: {
        lineStyle: 'curve'
      },
      legend: {
        show: true,
        position: 'topRight',
        color: '#ffffff'
      },
      background: '#00000000',
      padding: [40, 10, 20, 20]
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

    lineChart.updateData({
      categories: this.data.chartData.timePoints,
      series: [{
        name: '样本熵',
        data: this.data.chartData.tbrData
      }]
    });
  }
});
