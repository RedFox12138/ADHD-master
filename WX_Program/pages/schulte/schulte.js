// 获取应用实例
const app = getApp()
var wxCharts = require('../../utils/wxcharts.js');
let historyChart = null;

// API地址配置
const HTTP_URL = 'https://xxyeeg.zicp.fun';

Page({
  data: {
    // 游戏配置
    selectedDifficulty: '5x5',  // 默认选择5x5
    gridSize: 5,                // 方格大小
    
    // 游戏状态
    gameStarted: false,
    currentNumber: 1,           // 当前要找的数字
    startTime: 0,               // 开始时间
    elapsedTime: 0,             // 已用时间
    timer: null,                // 计时器
    
    // 方格数据
    grid: [],
    
    // 历史记录
    records: [],
    bestTime: 0,
    avgTime: 0,
    totalGames: 0,
    
    // 完成弹窗
    showCompleteModal: false,
    isNewRecord: false
  },

  onLoad: function() {
    // 加载历史记录
    this.loadRecords();
  },

  onUnload: function() {
    // 页面卸载时清除计时器
    if (this.data.timer) {
      clearInterval(this.data.timer);
    }
  },

  // 选择难度
  selectDifficulty: function(e) {
    const difficulty = e.currentTarget.dataset.difficulty;
    let gridSize = 5;
    
    if (difficulty === '6x6') {
      gridSize = 6;
    } else if (difficulty === '7x7') {
      gridSize = 7;
    }
    
    this.setData({
      selectedDifficulty: difficulty,
      gridSize: gridSize
    });
    
    // 加载对应难度的历史记录
    this.loadRecords();
  },

  // 加载历史记录
  loadRecords: function() {
    const userId = app.globalData.userId || 'user001';
    const difficulty = this.data.selectedDifficulty;
    
    wx.request({
      url: `${HTTP_URL}/getSchulteRecords`,
      method: 'GET',
      data: {
        userId: userId,
        difficulty: difficulty
      },
      success: (res) => {
        if (res.data.success) {
          const records = res.data.records || [];
          const stats = res.data.stats || {};
          
          this.setData({
            records: records.slice(0, 20), // 显示最近20条用于绘图
            bestTime: stats.bestTime || 0,
            avgTime: Math.round(stats.avgTime * 10) / 10 || 0, // 保留一位小数并转为数字
            totalGames: stats.totalGames || 0
          }, () => {
            // 数据加载后渲染图表
            if (records.length > 0) {
              this.renderChart();
            }
          });
        }
      },
      fail: (err) => {
        console.error('[加载记录失败]', err);
      }
    });
  },

  // 渲染历史趋势图
  renderChart: function() {
    const records = this.data.records;
    if (records.length === 0) return;

    // 反转数组，让最早的记录在左边
    const reversedRecords = [...records].reverse();
    
    // 提取时间数据和日期标签
    const timeData = reversedRecords.map(r => r.time);
    const labels = reversedRecords.map((r, index) => `第${index + 1}次`);

    const windowWidth = wx.getSystemInfoSync().windowWidth;

    // 计算Y轴范围
    const minTime = Math.min(...timeData);
    const maxTime = Math.max(...timeData);
    const range = maxTime - minTime;
    const yMin = Math.max(0, minTime - range * 0.2);
    const yMax = maxTime + range * 0.2;

    historyChart = new wxCharts({
      canvasId: 'schulteChart',
      type: 'line',
      categories: labels,
      animation: true,
      series: [{
        name: '用时',
        data: timeData,
        color: '#667eea'
      }],
      xAxis: {
        disableGrid: false,
        axisLineColor: '#cccccc',
        fontColor: '#666666'
      },
      yAxis: {
        title: '用时(秒)',
        format: val => val.toFixed(1),
        min: yMin,
        max: yMax,
        gridColor: '#eeeeee',
        fontColor: '#666666'
      },
      width: windowWidth * 0.85,
      height: 300,
      dataLabel: false,
      dataPointShape: true,
      extra: {
        lineStyle: 'curve'
      },
      legend: {
        show: false
      },
      background: '#ffffff',
      padding: [20, 15, 20, 40]
    });
  },

  // 开始游戏
  startGame: function() {
    // 生成随机方格
    const gridSize = this.data.gridSize;
    const totalCells = gridSize * gridSize;
    const numbers = [];
    
    // 生成1到totalCells的数字数组
    for (let i = 1; i <= totalCells; i++) {
      numbers.push(i);
    }
    
    // 随机打乱
    for (let i = numbers.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [numbers[i], numbers[j]] = [numbers[j], numbers[i]];
    }
    
    // 创建方格数据
    const grid = numbers.map(num => ({
      number: num,
      found: false
    }));
    
    // 开始计时
    const startTime = Date.now();
    const timer = setInterval(() => {
      const elapsed = Math.floor((Date.now() - startTime) / 1000);
      this.setData({
        elapsedTime: elapsed
      });
    }, 1000);
    
    this.setData({
      grid: grid,
      gameStarted: true,
      currentNumber: 1,
      startTime: startTime,
      elapsedTime: 0,
      timer: timer
    });
  },

  // 点击方格
  onCellTap: function(e) {
    const number = e.currentTarget.dataset.number;
    const currentNumber = this.data.currentNumber;
    
    if (number === currentNumber) {
      // 找对了
      const grid = this.data.grid;
      const index = grid.findIndex(item => item.number === number);
      grid[index].found = true;
      
      const nextNumber = currentNumber + 1;
      const totalCells = this.data.gridSize * this.data.gridSize;
      
      if (nextNumber > totalCells) {
        // 游戏完成
        this.completeGame();
      } else {
        this.setData({
          grid: grid,
          currentNumber: nextNumber
        });
      }
    } else {
      // 找错了，震动提示
      wx.vibrateShort();
    }
  },

  // 完成游戏
  completeGame: function() {
    // 停止计时
    if (this.data.timer) {
      clearInterval(this.data.timer);
    }
    
    const elapsedTime = this.data.elapsedTime;
    const userId = app.globalData.userId || 'user001';
    const difficulty = this.data.selectedDifficulty;
    
    // 检查是否是新记录
    const isNewRecord = this.data.bestTime === 0 || elapsedTime < this.data.bestTime;
    
    // 保存记录到后端
    wx.request({
      url: `${HTTP_URL}/saveSchulteRecord`,
      method: 'POST',
      data: {
        userId: userId,
        difficulty: difficulty,
        time: elapsedTime
      },
      success: (res) => {
        if (res.data.success) {
          console.log('[保存记录成功]');
          // 重新加载记录
          this.loadRecords();
        }
      },
      fail: (err) => {
        console.error('[保存记录失败]', err);
      }
    });
    
    // 显示完成弹窗
    this.setData({
      showCompleteModal: true,
      isNewRecord: isNewRecord
    });
  },

  // 放弃游戏
  quitGame: function() {
    wx.showModal({
      title: '确认放弃',
      content: '放弃当前游戏不会记录成绩，确定要放弃吗？',
      confirmText: '确定',
      cancelText: '取消',
      success: (res) => {
        if (res.confirm) {
          // 停止计时
          if (this.data.timer) {
            clearInterval(this.data.timer);
          }
          
          this.setData({
            gameStarted: false,
            grid: [],
            currentNumber: 1,
            elapsedTime: 0,
            timer: null
          });
        }
      }
    });
  },

  // 关闭完成弹窗
  closeModal: function() {
    this.setData({
      showCompleteModal: false,
      gameStarted: false,
      grid: [],
      currentNumber: 1,
      elapsedTime: 0
    });
  }
});
