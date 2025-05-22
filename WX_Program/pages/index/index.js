const app = getApp();
var receivedData = []; // 全局数据接收缓冲区
var batch_len = 500;   // 每批发送数据量
var wxCharts = require('../../utils/wxcharts.js');
let lineChart = null;
Page({
  resetChart: function() {
    this.setData({
      chartData: {
        tbrData: [],
        deltaData: [],
        timePoints: []
      },
      dataCount: 0
    });
    
    // 重新初始化图表
    this.initEmptyChart();
  },
  data: {
    chartData: {
      tbrData: [],
      deltaData: [],
      timePoints: []
    },

    mathProblem: '',       // 当前显示的数学题
    mathAnswer: 0,         // 正确答案
    mathTimer: null,       // 数学题定时器
    showMathProblem: false, // 是否显示数学题

    dataCount: 0,
    maxDataPoints: 60,

    // 设备连接状态
    connected: false,
    deviceName: '',
    inputData: '',

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

  // 开始实验
  startExperiment: function() {
    if (!this.data.connected) {
      wx.showToast({ title: '请先连接设备', icon: 'none' });
      return;
    }
    
 // 重置图表
    this.resetChart();
    this.setData({
      experimentStarted: true,
      currentPhase: '准备阶段',  // 先进入准备阶段
      remainingTime: 10,        // 10秒纯倒计时
      baselineValue: null,
      baselineSamples: [],
      gameOver: false
    });
    this.startPhaseTimer();

    // 重置图表
    this.resetChart();
  },
  
  stopExperiment: function() {
    // 清除所有可能的定时器
    if (this.data.mathTimer) {
      clearInterval(this.data.mathTimer);
    }

    if (this.data.timer) {
      clearInterval(this.data.timer);
    }
    if (this.data.phaseTimer) {
      clearInterval(this.data.phaseTimer);
    }
    if (this.data.gameTimer) {
      clearInterval(this.data.gameTimer);
    }
    if (this.data.sceneTimer) {
      clearInterval(this.data.sceneTimer);
    }
    
    this.setData({
      baselineValue: null,
      baselineSamples: [],
      currentAttention: null,
      currentPhase: '',
      experimentStarted: false,
      timer: null,
      phaseTimer: null,
      gameTimer: null,
      sceneTimer: null,
      gameOver: true,  // 显示游戏结束界面
      gameStarted: false,
      showMathProblem: false
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
        
        if (that.data.currentPhase === '准备阶段') {
          // 准备阶段结束，自动进入基准阶段
          that.setData({
            currentPhase: '基准阶段',
            remainingTime: 30
          });
          that.startPhaseTimer(); // 继续计时
        } 
        else if (that.data.currentPhase === '基准阶段') {
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
  // const samples = this.data.baselineSamples;
  // if (samples.length === 0) return 0;

  // const avg = samples.reduce((a,b) => a + parseFloat(b), 0) / samples.length;
  // this.setData({ baselineValue: parseFloat(avg.toFixed(2)) });
  const baseDelta = this.data.DeltaPower;
  this.setData({ baselineValue: baseDelta });
  return this.data.baselineValue;
},
  

startTreatmentPhase: function() {
  this.setData({
    showMathProblem: true,
    currentPhase: '治疗阶段',
    remainingTime: 180, // 延长到3分钟
    gameStarted: true,
    gameOver: false,
    birdY: 50,
    currentScene: 'forest',
    sceneTimer: 0,
    sceneChanged: false
  });
 // 启动数学题定时器
 this.startMathProblemTimer();
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
    // 重置图表
    this.resetChart();
    this.setData({
      baselineValue: null,
      baselineSamples: [],
      currentAttention: null,
      currentPhase:'',
      gameOver: false,
      experimentStarted: false,
      birdY: 50,
      currentScene: 'forest'
    });
    // 延迟开始避免状态冲突
    setTimeout(() => {
      this.startExperiment();
    }, 500);
  },
  
  updateGameState: function() {
    if (!this.data.gameStarted || this.data.gameOver || this.data.sceneCooldown) return;
    
    // 基准阶段不移动小鸟
    if (this.data.currentPhase === '基准阶段') return;
    
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

// 添加新的方法：开始数学题定时器
startMathProblemTimer: function() {
  // 先立即生成一道题
  this.generateMathProblem();
  
  // 然后每3秒切换一次
  this.data.mathTimer = setInterval(() => {
    this.generateMathProblem();
  }, 3000);
},

// 添加新的方法：生成随机数学题
generateMathProblem: function() {
  // 生成两个10-99的随机数
  const num1 = Math.floor(Math.random() * 90) + 10;
  const num2 = Math.floor(Math.random() * 90) + 10;
  const answer = num1 + num2;
  
  this.setData({
    mathProblem: `${num1} + ${num2} = ?`,
    mathAnswer: answer
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
              url: 'http://4nbsf9900182.vicp.fun:18595/getOpenId',
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
      // console.log(this.data.currentPhase);
      wx.request({
        url: 'http://4nbsf9900182.vicp.fun:18595/process', 
        method: 'POST',
        data: {
          points: dataToSend,
          userId: user_id,
          Step: this.data.currentPhase
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
          
          // const DeltaPowerCurrent = res.data.DeltaCumAvg*100000;
          // const averageTBR = validTBRs.reduce((sum, tbr) => sum + tbr, 0) / validTBRs.length;

          const DeltaPowerCurrent = res.data.DeltaCumAvg;
          const averageTBR = validTBRs.reduce((sum, tbr) => sum + tbr, 0) / validTBRs.length;
          
          this.setData({
            DeltaPower: DeltaPowerCurrent.toFixed(2),
            powerRatio: averageTBR.toFixed(2),
            currentAttention:DeltaPowerCurrent.toFixed(2)
            // currentAttention: (averageTBR * 10).toFixed(2)
          });
          
          // 处理图表数据
          this.updateChartData(
            parseFloat(averageTBR.toFixed(2)), 
            parseFloat(DeltaPowerCurrent.toFixed(2))
          );

          const attentionValues = validTBRs.map(tbr => 
            Math.max(0, Math.min(100, tbr * 10))
          );
          
          // 强制更新UI显示平均值
          this.setData({
            DeltaPower: DeltaPowerCurrent.toFixed(2),
            powerRatio: averageTBR.toFixed(2),
            // currentAttention: (averageTBR * 10).toFixed(2)
            currentAttention: DeltaPowerCurrent.toFixed(2)
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
  
  navigateToHistory: function() {
    wx.navigateTo({
      url: '/pages/history/history'
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
  },


  // 初始化空白图表
  initEmptyChart: function() {
    const windowWidth = wx.getSystemInfoSync().windowWidth;
    
    lineChart = new wxCharts({
      canvasId: 'eegChart',
      type: 'line',
      categories: [],
      animation: false,
      series: [
        // {
        //   name: 'TBR',
        //   data: [],
        //   color: '#1aad19',
        //   labelColor: '#ffffff'  // 数据标签颜色
        // },
        {
          name: 'DeltaPower',
          data: [],
          color: '#ff0000'
        }
      ],
      xAxis: {
        disableGrid: true,
        axisLineColor: '#cccccc',
        fontColor: '#ffffff',  // X轴文字颜色
        titleFontColor: '#ffffff'  // X轴标题颜色
      },
      yAxis: {
        title: '数值',
        format: val => val.toFixed(2),
        min: 0,
        max: 20,
        gridColor: '#D8D8D8',
        fontColor: '#ffffff',  // Y轴文字颜色
        titleFontColor: '#ffffff'  // Y轴标题颜色
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
        color: '#ffffff'  // 图例文字颜色
      },
      background: '#00000000',  // 透明背景
      padding: [40, 10, 20, 20],  // 调整内边距确保文字显示完整
      title: {
        content: '',
        fontColor: '#ffffff'  // 标题颜色
      }
    });
    
    this.setData({ chartInited: true });
  },

 // 更新图表数据
 updateChartData: function(tbr, deltaPower) {
  if (!this.data.chartInited) return;
  
  const chartData = this.data.chartData;
  const dataCount = this.data.dataCount + 1;
  
  // 添加新数据
  chartData.tbrData.push(tbr);
  chartData.deltaData.push(deltaPower);
  chartData.timePoints.push(dataCount.toString());
  
  // 限制数据点数量
  if (chartData.tbrData.length > this.data.maxDataPoints) {
    chartData.tbrData.shift();
    chartData.deltaData.shift();
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
    series: [
      // { name: 'TBR', data: this.data.chartData.tbrData },
      { name: 'DeltaPower', data: this.data.chartData.deltaData }
    ]
  });
}

});