// pages/history/history.js
const wxCharts = require('../../utils/wxcharts.js');

Page({
  data: {
    // 数据类型选择
    dataType: 'feature', // 'feature' 或 'gameRecords'
    
    // 历史数据
    historyDates: [],
    selectedDate: null,
    historyFiles: [],
    showChart: false,
    loading: false,
    currentUserId: null,
    
    // 图表相关
    chartData: {
      values: [],
      baseline: null,
      totalPoints: 0
    },
    
    // 缩放和拖动
    zoomLevel: 1, // 缩放级别 (0.5-5)
    viewStart: 0, // 当前视图起始位置（数据点索引）
    viewRange: 100, // 当前视图显示的数据点数量
    
    // 游戏记录相关
    gameRecords: [],
    totalGames: 0,
    avgTime: 0,
    maxTime: 0,
    trend: '', // 'improving', 'stable', 'declining'
    suggestion: '', // 训练建议
    analysis: null, // 完整的分析数据
    
    // 触摸手势相关
    touchStartX: 0,
    touchStartY: 0,
    lastTouchDistance: 0,
    lastViewStart: 0,
    lastViewRange: 100,
    isTouching: false
  },

  onLoad: function() {
    this.loadHistoryDates();
  },

  // 切换数据类型
  switchDataType: function(e) {
    const type = e.currentTarget.dataset.type;
    this.setData({ 
      dataType: type,
      selectedDate: null,
      historyFiles: [],
      showChart: false
    });
    
    if (type === 'feature') {
      this.loadHistoryDates();
    } else if (type === 'gameRecords') {
      this.loadGameRecords();
    }
  },

  // 加载历史日期列表
  loadHistoryDates: function() {
    this.getUserId().then(user_id => {
      wx.request({
        url: 'https://xxyeeg.zicp.fun/getHistoryDates',
        method: 'POST',
        data: { userId: user_id },
        success: (res) => {
          if (res.data.success) {
            this.setData({
              historyDates: res.data.dates
                .map(date => ({
                  text: this.formatDate(date),
                  value: date,
                  count: res.data.counts ? res.data.counts[date] : 0
                }))
                .sort((a, b) => b.value.localeCompare(a.value))
            });
          }
        },
        fail: (err) => {
          wx.showToast({ title: '加载失败', icon: 'none' });
        }
      });
    });
  },

  // 日期格式化
  formatDate: function(dateStr) {
    const year = dateStr.substr(0,4);
    const month = dateStr.substr(4,2);
    const day = dateStr.substr(6,2);
    return `${year}-${month}-${day}`;
  },

  // 选择日期
  selectDate: function(e) {
    const date = e.currentTarget.dataset.date;
    this.setData({ selectedDate: date }, () => {
      this.loadDateFiles();
    });
  },

  // 获取用户ID
  getUserId: function() {
    return new Promise((resolve, reject) => {
      if (this.data.currentUserId) {
        resolve(this.data.currentUserId);
        return;
      }
      
      wx.getStorage({
        key: 'user_id',
        success: (res) => {
          this.setData({ currentUserId: res.data });
          resolve(res.data);
        },
        fail: () => {
          wx.login({
            success: (res) => {
              if (res.code) {
                wx.request({
                  url: 'http://xxyeeg.zicp.fun/getOpenId',
                  method: 'POST',
                  data: { code: res.code },
                  success: (res) => {
                    if (res.data && res.data.openid) {
                      const user_id = res.data.openid;
                      this.setData({ currentUserId: user_id });
                      wx.setStorage({ key: 'user_id', data: user_id });
                      resolve(user_id);
                    } else {
                      reject(new Error('获取openid失败'));
                    }
                  },
                  fail: (err) => {
                    reject(new Error('请求失败'));
                  }
                });
              } else {
                reject(new Error('wx.login失败'));
              }
            },
            fail: (err) => {
              reject(new Error('wx.login调用失败'));
            }
          });
        }
      });
    });
  },

  // 加载指定日期的文件列表
  loadDateFiles: function() {
    this.setData({ loading: true });
    
    const url = this.data.dataType === 'feature' 
      ? 'https://xxyeeg.zicp.fun/getHistoryFiles'
      : 'https://xxyeeg.zicp.fun/getRawHistoryFiles';
    
    this.getUserId().then(user_id => {
      wx.request({
        url: url,
        method: 'POST',
        data: { 
          userId: user_id,
          date: this.data.selectedDate 
        },
        success: (res) => {
          if (res.data.success) {
            this.setData({
              historyFiles: res.data.files
                .map(file => ({
                  name: this.formatTime(file),
                  fullName: file,
                  time: this.formatTime(file),
                  size: '未知大小'
                }))
                .sort((a, b) => b.name.localeCompare(a.name))
            });
          }
          this.setData({ loading: false });
        },
        fail: (err) => {
          this.setData({ loading: false });
          wx.showToast({ title: '加载失败', icon: 'none' });
        }
      });
    });
  },

  // 从文件名解析时间
  formatTime: function(filename) {
    try {
      const timePart = filename.split('_')[1];
      const hh = timePart.substr(0,2);
      const mm = timePart.substr(2,2);
      const ss = timePart.substr(4,2);
      return `${hh}:${mm}:${ss}`;
    } catch (e) {
      return '时间未知';
    }
  },

  // 查看文件内容
  viewFile: function(e) {
    const file = e.currentTarget.dataset.file;
    this.setData({ loading: true });
    
    // 只加载特征文件
    this.loadFeatureFile(file);
  },

  // 加载特征文件
  loadFeatureFile: function(file) {
    this.getUserId().then(user_id => {
      wx.request({
        url: 'https://xxyeeg.zicp.fun/getHistoryFile',
        method: 'POST',
        data: { 
          userId: user_id,
          date: this.data.selectedDate,
          fileName: file 
        },
        success: (res) => {
          if (res.data.success) {
            this.setData({
              chartData: {
                values: res.data.data,
                baseline: res.data.baseline,
                totalPoints: res.data.totalPoints
              },
              viewRange: Math.min(100, res.data.totalPoints),
              viewStart: 0,
              zoomLevel: 1,
              showChart: true,
              loading: false
            }, () => {
              this.renderChart();
            });
          } else {
            this.setData({ loading: false });
            wx.showToast({ title: '文件加载失败', icon: 'none' });
          }
        },
        fail: (err) => {
          this.setData({ loading: false });
          wx.showToast({ title: '网络错误', icon: 'none' });
        }
      });
    });
  },

  // 渲染图表
  renderChart: function() {
    const { values, baseline, totalPoints } = this.data.chartData;
    const { viewStart, viewRange } = this.data;
    
    // 截取当前视图范围的数据
    const endIndex = Math.min(viewStart + viewRange, totalPoints);
    const viewValues = values.slice(viewStart, endIndex);
    
    // 生成时间标签（特征图每2秒一个点）
    const times = viewValues.map((_, i) => {
      const timeIndex = viewStart + i;
      return `${(timeIndex * 2).toFixed(0)}s`;
    });

    // 构建系列数据
    const series = [{
      name: '样本熵',
      data: viewValues,
      color: '#1aad19',
      width: 2
    }];

    // 添加基线
    if (baseline !== null) {
      series.push({
        name: '基线',
        data: viewValues.map(() => baseline),
        color: '#ff0000',
        width: 2
      });
    }

    // 计算Y轴范围（自适应）
    let allValues = [...viewValues];
    if (baseline !== null) {
      allValues.push(baseline); // 包含基线值
    }
    const minVal = Math.min(...allValues);
    const maxVal = Math.max(...allValues);
    const range = maxVal - minVal;
    const yMin = minVal - range * 0.1; // 下方留10%空间
    const yMax = maxVal + range * 0.1; // 上方留10%空间

    try {
      const systemInfo = wx.getSystemInfoSync();
      const windowWidth = systemInfo.windowWidth;

      new wxCharts({
        width: windowWidth * 0.95,
        height: 350,
        canvasId: 'historyChart',
        type: 'line',
        categories: times,
        series: series,
        xAxis: {
          disableGrid: false,
          axisLineColor: '#999',
          fontColor: '#333',
          labelCount: 10
        },
        yAxis: {
          title: '数值',
          min: yMin,
          max: yMax,
          format: val => val.toFixed(2)
        },
        dataLabel: false,
        dataPointShape: false,
        extra: {
          lineStyle: 'curve'
        },
        legend: {
          show: true,
          position: 'top',
          color: '#333'
        },
        background: '#ffffff',
        padding: [15, 10, 15, 20],
        animation: false
      });
    } catch (e) {
      console.error('图表渲染失败:', e);
      wx.showToast({ title: '图表渲染失败', icon: 'none' });
    }
  },

  // 缩放控制
  zoomIn: function() {
    let newZoom = this.data.zoomLevel * 1.5;
    if (newZoom > 5) newZoom = 5;
    
    const newRange = Math.floor(this.data.viewRange / 1.5);
    this.setData({
      zoomLevel: newZoom,
      viewRange: Math.max(10, newRange)
    }, () => {
      this.renderChart();
    });
  },

  zoomOut: function() {
    let newZoom = this.data.zoomLevel / 1.5;
    if (newZoom < 0.5) newZoom = 0.5;
    
    const newRange = Math.floor(this.data.viewRange * 1.5);
    const maxRange = this.data.chartData.totalPoints;
    
    this.setData({
      zoomLevel: newZoom,
      viewRange: Math.min(maxRange, newRange),
      viewStart: Math.max(0, Math.min(this.data.viewStart, maxRange - newRange))
    }, () => {
      this.renderChart();
    });
  },

  // 时间轴滑动
  onTimeSliderChange: function(e) {
    const value = e.detail.value;
    const maxStart = Math.max(0, this.data.chartData.totalPoints - this.data.viewRange);
    const newStart = Math.floor((value / 100) * maxStart);
    
    this.setData({
      viewStart: newStart
    }, () => {
      this.renderChart();
    });
  },

  // 左移视图
  moveLeft: function() {
    const step = Math.floor(this.data.viewRange * 0.2);
    const newStart = Math.max(0, this.data.viewStart - step);
    
    this.setData({
      viewStart: newStart
    }, () => {
      this.renderChart();
    });
  },

  // 右移视图
  moveRight: function() {
    const step = Math.floor(this.data.viewRange * 0.2);
    const maxStart = Math.max(0, this.data.chartData.totalPoints - this.data.viewRange);
    const newStart = Math.min(maxStart, this.data.viewStart + step);
    
    this.setData({
      viewStart: newStart
    }, () => {
      this.renderChart();
    });
  },

  // 返回文件列表
  backToList: function() {
    this.setData({ 
      showChart: false,
      chartData: {
        values: [],
        baseline: null,
        totalPoints: 0
      },
      rawDataCache: [],
      viewStart: 0,
      viewRange: 100,
      zoomLevel: 1
    });
  },

  // 导出数据 (新增功能)
  exportData: function() {
    wx.showToast({ title: '导出功能开发中', icon: 'none' });
  },

  // 分享图表 (新增功能)
  shareChart: function() {
    wx.showToast({ title: '分享功能开发中', icon: 'none' });
  },

  // ============= 游戏记录相关 =============
  
  // 加载游戏记录
  loadGameRecords: function() {
    this.setData({ loading: true, showChart: false });

    this.getUserId().then(user_id => {
      wx.request({
        url: 'https://xxyeeg.zicp.fun/getGameRecords',
        method: 'POST',
        data: { userId: user_id },
        success: (res) => {
          if (res.data.success && res.data.records.length > 0) {
            const records = res.data.records;
            const analysis = res.data.analysis || {};
            
            // 从后端获取统计数据和分析
            const stats = analysis.stats || {};
            const totalGames = stats.totalGames || records.length;
            const avgTime = Math.round(stats.avgTime || 0);
            const maxTime = stats.maxTime || 0;
            const trend = analysis.trend || 'stable';
            const suggestion = analysis.suggestion || '继续加油！';

            this.setData({
              gameRecords: records,
              totalGames: totalGames,
              avgTime: avgTime,
              maxTime: maxTime,
              trend: trend,
              suggestion: suggestion,
              analysis: analysis,
              loading: false,
              showChart: true
            }, () => {
              this.renderGameChart(records);
            });
          } else {
            this.setData({
              gameRecords: [],
              totalGames: 0,
              loading: false,
              showChart: false
            });
            wx.showToast({ title: '暂无游戏记录', icon: 'none' });
          }
        },
        fail: (err) => {
          console.error('[游戏记录] 加载失败:', err);
          this.setData({ loading: false });
          wx.showToast({ title: '加载失败', icon: 'none' });
        }
      });
    }).catch(err => {
      console.error('[游戏记录] 获取用户ID失败:', err);
      this.setData({ loading: false });
    });
  },

  // 渲染游戏记录图表
  renderGameChart: function(records) {
    try {
      const systemInfo = wx.getSystemInfoSync();
      const windowWidth = systemInfo.windowWidth;

      // 准备数据（最多显示最近20次）
      const displayRecords = records.slice(-20);
      const categories = displayRecords.map((_, index) => `第${index + 1}次`);
      const data = displayRecords.map(r => r.gameTime);

      // 计算Y轴范围（改进算法，更好地处理离群点）
      const minVal = Math.min(...data);
      const maxVal = Math.max(...data);
      const range = maxVal - minVal;
      
      // 如果range很小（数据集中），扩大范围以便看清楚
      let yMin, yMax;
      if (range < 10) {
        // 数据很集中，使用固定范围
        const center = (maxVal + minVal) / 2;
        yMin = Math.max(0, center - 10);
        yMax = center + 10;
      } else {
        // 数据分散，使用20%的padding确保离群点可见
        yMin = Math.max(0, minVal - range * 0.2);
        yMax = maxVal + range * 0.2;
      }
      
      // 确保Y轴范围至少为20（避免过于压缩）
      if (yMax - yMin < 20) {
        const center = (yMax + yMin) / 2;
        yMin = Math.max(0, center - 10);
        yMax = center + 10;
      }

      new wxCharts({
        canvasId: 'historyChart',
        type: 'line',
        categories: categories,
        animation: true,
        series: [{
          name: '游戏时长(秒)',
          data: data,
          color: '#1aad19',
          width: 3
        }],
        xAxis: {
          disableGrid: false,
          axisLineColor: '#999',
          fontColor: '#666',
          labelCount: 10
        },
        yAxis: {
          title: '时长(秒)',
          min: yMin,
          max: yMax,
          format: val => Math.round(val)
        },
        width: windowWidth * 0.9,
        height: 350,
        dataLabel: false,
        dataPointShape: true,
        extra: {
          lineStyle: 'curve'
        },
        legend: {
          show: false
        },
        background: '#ffffff',
        padding: [15, 15, 15, 25]
      });
    } catch (e) {
      console.error('[游戏记录] 图表渲染失败:', e);
    }
  },

  // ============= 触摸手势控制 =============
  
  // 触摸开始
  onChartTouchStart: function(e) {
    if (this.data.dataType === 'gameRecords') return; // 游戏记录不支持手势
    
    this.setData({ isTouching: true });
    
    if (e.touches.length === 1) {
      // 单指触摸 - 准备拖动
      this.setData({
        touchStartX: e.touches[0].pageX,
        lastViewStart: this.data.viewStart
      });
    } else if (e.touches.length === 2) {
      // 双指触摸 - 准备缩放
      const touch1 = e.touches[0];
      const touch2 = e.touches[1];
      const distance = Math.sqrt(
        Math.pow(touch2.pageX - touch1.pageX, 2) + 
        Math.pow(touch2.pageY - touch1.pageY, 2)
      );
      this.setData({
        lastTouchDistance: distance,
        lastViewRange: this.data.viewRange
      });
    }
  },

  // 触摸移动
  onChartTouchMove: function(e) {
    if (!this.data.isTouching || this.data.dataType === 'gameRecords') return;
    
    if (e.touches.length === 1) {
      // 单指拖动 - 平移视图
      const deltaX = e.touches[0].pageX - this.data.touchStartX;
      const systemInfo = wx.getSystemInfoSync();
      const windowWidth = systemInfo.windowWidth;
      
      // 将像素移动转换为数据点移动
      const dataPointsPerPixel = this.data.viewRange / (windowWidth * 0.95);
      const dataPointsDelta = -Math.round(deltaX * dataPointsPerPixel);
      
      let newStart = this.data.lastViewStart + dataPointsDelta;
      const maxStart = Math.max(0, this.data.chartData.totalPoints - this.data.viewRange);
      newStart = Math.max(0, Math.min(newStart, maxStart));
      
      if (newStart !== this.data.viewStart) {
        this.setData({ viewStart: newStart }, () => {
          this.renderChart();
        });
      }
    } else if (e.touches.length === 2) {
      // 双指缩放
      const touch1 = e.touches[0];
      const touch2 = e.touches[1];
      const distance = Math.sqrt(
        Math.pow(touch2.pageX - touch1.pageX, 2) + 
        Math.pow(touch2.pageY - touch1.pageY, 2)
      );
      
      const scale = distance / this.data.lastTouchDistance;
      let newRange = Math.round(this.data.lastViewRange / scale);
      
      // 限制缩放范围
      const minRange = 10;
      const maxRange = this.data.chartData.totalPoints;
      newRange = Math.max(minRange, Math.min(newRange, maxRange));
      
      // 计算新的缩放级别
      const newZoomLevel = 100 / newRange;
      
      if (newRange !== this.data.viewRange) {
        // 保持中心点不变
        const centerRatio = 0.5;
        let newStart = this.data.viewStart + Math.round((this.data.viewRange - newRange) * centerRatio);
        const maxStart = Math.max(0, this.data.chartData.totalPoints - newRange);
        newStart = Math.max(0, Math.min(newStart, maxStart));
        
        this.setData({
          viewRange: newRange,
          viewStart: newStart,
          zoomLevel: newZoomLevel
        }, () => {
          this.renderChart();
        });
      }
    }
  },

  // 触摸结束
  onChartTouchEnd: function(e) {
    this.setData({ isTouching: false });
  }
});