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
    
    // 游戏记录相关
    gameRecords: [],
    totalGames: 0,
    avgTime: 0,
    maxTime: 0,
    trend: '', // 'improving', 'stable', 'declining'
    suggestion: '', // 训练建议
    analysis: null // 完整的分析数据
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
                  size: '未知大小',
                  difficulty: res.data.difficulties ? res.data.difficulties[file] : 'normal' // 添加难度信息
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
      // 文件名格式为 HHMMSS_xxx.txt，提取前6个字符作为时间
      const timePart = filename.split('_')[0];
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
                baseline: res.data.baseline !== undefined ? res.data.baseline : null,
                totalPoints: res.data.totalPoints,
                difficulty: res.data.difficulty || 'normal' // 添加难度信息，默认普通
              },
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

  // 渲染图表 - 使用Canvas直接绘制(显示全部数据)
  renderChart: function() {
    const { values, baseline, totalPoints } = this.data.chartData;
    
    if (!values || values.length === 0) {
      console.warn('[特征图表] 没有数据');
      return;
    }

    // 计算Y轴范围 - 使用全部数据
    let allValues = [...values];
    if (baseline !== null) {
      allValues.push(baseline);
    }
    
    const minVal = Math.min(...allValues);
    const maxVal = Math.max(...allValues);
    const range = maxVal - minVal;
    
    let yMin, yMax;
    if (range === 0) {
      yMin = minVal - 1;
      yMax = maxVal + 1;
    } else {
      // 使用50%边距确保所有点可见
      const padding = range * 0.5;
      yMin = minVal - padding;
      yMax = maxVal + padding;
    }
    
    console.log('[特征图表] Y轴范围:', { minVal, maxVal, yMin, yMax });

    try {
      const systemInfo = wx.getSystemInfoSync();
      const windowWidth = systemInfo.windowWidth;

      // 使用Canvas 2D直接绘制
      const query = wx.createSelectorQuery();
      query.select('#historyChart').fields({ node: true, size: true }).exec((res) => {
        if (!res || !res[0]) {
          console.error('[特征图表] Canvas节点未找到');
          return;
        }

        const canvas = res[0].node;
        const ctx = canvas.getContext('2d');
        const dpr = wx.getSystemInfoSync().pixelRatio;

        // 设置canvas尺寸
        canvas.width = res[0].width * dpr;
        canvas.height = res[0].height * dpr;
        ctx.scale(dpr, dpr);

        const width = res[0].width;
        const height = res[0].height;
        const padding = { top: 40, right: 50, bottom: 50, left: 60 };
        const chartWidth = width - padding.left - padding.right;
        const chartHeight = height - padding.top - padding.bottom;

        // 清空画布
        ctx.clearRect(0, 0, width, height);

        // 绘制背景
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(0, 0, width, height);

        // 绘制标题
        ctx.fillStyle = '#333333';
        ctx.font = 'bold 16px sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText('样本熵趋势图', width / 2, 25);

        // 绘制网格和Y轴刻度
        ctx.strokeStyle = '#e0e0e0';
        ctx.fillStyle = '#666666';
        ctx.font = '11px sans-serif';
        ctx.lineWidth = 1;

        const ySteps = 6;
        for (let i = 0; i <= ySteps; i++) {
          const y = padding.top + (chartHeight / ySteps) * i;
          const value = yMax - (yMax - yMin) / ySteps * i;

          // 网格线
          ctx.beginPath();
          ctx.moveTo(padding.left, y);
          ctx.lineTo(padding.left + chartWidth, y);
          ctx.stroke();

          // Y轴标签
          ctx.textAlign = 'right';
          ctx.textBaseline = 'middle';
          ctx.fillText(value.toFixed(2), padding.left - 10, y);
        }

        // 绘制X轴刻度
        const xLabelCount = Math.min(10, values.length);
        const xLabelStep = Math.floor(values.length / xLabelCount) || 1;
        ctx.textAlign = 'center';
        for (let i = 0; i < values.length; i += xLabelStep) {
          const x = padding.left + (i / (values.length - 1 || 1)) * chartWidth;
          const label = `${(i * 2).toFixed(0)}s`;
          ctx.fillText(label, x, height - 20);
        }

        // 根据难度设置颜色
        const difficulty = this.data.chartData.difficulty || 'normal';
        const difficultyColors = {
          'easy': '#4caf50',    // 绿色
          'normal': '#2196f3',  // 蓝色
          'hard': '#f44336'     // 红色
        };
        const lineColor = difficultyColors[difficulty] || difficultyColors['normal'];
        
        // 绘制数据折线
        ctx.strokeStyle = lineColor;
        ctx.lineWidth = 2;
        ctx.beginPath();

        values.forEach((val, idx) => {
          const x = padding.left + (idx / (values.length - 1 || 1)) * chartWidth;
          const y = padding.top + chartHeight - ((val - yMin) / (yMax - yMin)) * chartHeight;

          if (idx === 0) {
            ctx.moveTo(x, y);
          } else {
            ctx.lineTo(x, y);
          }
        });
        ctx.stroke();

        // 绘制数据点
        ctx.fillStyle = lineColor;
        values.forEach((val, idx) => {
          const x = padding.left + (idx / (values.length - 1 || 1)) * chartWidth;
          const y = padding.top + chartHeight - ((val - yMin) / (yMax - yMin)) * chartHeight;

          ctx.beginPath();
          ctx.arc(x, y, 3, 0, 2 * Math.PI);
          ctx.fill();
        });

        // 绘制基线
        if (baseline !== null) {
          const baselineY = padding.top + chartHeight - ((baseline - yMin) / (yMax - yMin)) * chartHeight;
          
          ctx.strokeStyle = '#ff0000';
          ctx.lineWidth = 2;
          ctx.setLineDash([5, 5]);
          ctx.beginPath();
          ctx.moveTo(padding.left, baselineY);
          ctx.lineTo(padding.left + chartWidth, baselineY);
          ctx.stroke();
          ctx.setLineDash([]);

          // 基线标签
          ctx.fillStyle = '#ff0000';
          ctx.font = '11px sans-serif';
          ctx.textAlign = 'left';
          ctx.fillText(`基线: ${baseline.toFixed(2)}`, padding.left + chartWidth + 5, baselineY);
        }

        console.log('[特征图表] 绘制完成');
      });
    } catch (e) {
      console.error('图表渲染失败:', e);
      wx.showToast({ title: '图表渲染失败', icon: 'none' });
    }
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

  // 渲染游戏记录图表 - 使用Canvas直接绘制（按难度分类）
  renderGameChart: function(records) {
    try {
      // 准备数据（最多显示最近30次）
      const displayRecords = records.length > 30 ? records.slice(-30) : records;
      
      // 按难度分组
      const easyData = displayRecords.filter(r => (r.difficulty || 'normal') === 'easy').map(r => ({ time: r.gameTime, difficulty: 'easy' }));
      const normalData = displayRecords.filter(r => (r.difficulty || 'normal') === 'normal').map(r => ({ time: r.gameTime, difficulty: 'normal' }));
      const hardData = displayRecords.filter(r => (r.difficulty || 'normal') === 'hard').map(r => ({ time: r.gameTime, difficulty: 'hard' }));
      
      const data = displayRecords.map(r => r.gameTime);

      if (data.length === 0) {
        console.warn('[游戏记录] 没有数据');
        return;
      }

      // 计算Y轴范围
      const minVal = Math.min(...data);
      const maxVal = Math.max(...data);
      const range = maxVal - minVal;

      let yMin, yMax;
      if (range === 0) {
        yMin = Math.max(0, minVal - 20);
        yMax = minVal + 20;
      } else {
        // 使用50%边距确保所有点可见
        const padding = range * 0.5;
        yMin = Math.max(0, minVal - padding);
        yMax = maxVal + padding;
      }

      console.log('[游戏记录] Y轴范围:', { minVal, maxVal, yMin, yMax, 数据: data });

      // 使用Canvas 2D直接绘制
      const query = wx.createSelectorQuery();
      query.select('#historyChart').fields({ node: true, size: true }).exec((res) => {
        if (!res || !res[0]) {
          console.error('[游戏记录] Canvas节点未找到');
          return;
        }

        const canvas = res[0].node;
        const ctx = canvas.getContext('2d');
        const dpr = wx.getSystemInfoSync().pixelRatio;

        // 设置canvas尺寸
        canvas.width = res[0].width * dpr;
        canvas.height = res[0].height * dpr;
        ctx.scale(dpr, dpr);

        const width = res[0].width;
        const height = res[0].height;
        const padding = { top: 40, right: 40, bottom: 50, left: 60 };
        const chartWidth = width - padding.left - padding.right;
        const chartHeight = height - padding.top - padding.bottom;

        // 清空画布
        ctx.clearRect(0, 0, width, height);

        // 绘制背景
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(0, 0, width, height);

        // 绘制标题
        ctx.fillStyle = '#333333';
        ctx.font = 'bold 16px sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText('训练时长趋势图（按难度分类）', width / 2, 25);
        
        // 绘制图例
        const legendY = 50;
        const legendX = padding.left;
        ctx.font = '12px sans-serif';
        ctx.textAlign = 'left';
        
        // 简单难度
        ctx.fillStyle = '#4caf50';
        ctx.fillRect(legendX, legendY, 30, 10);
        ctx.fillStyle = '#333333';
        ctx.fillText('简单', legendX + 35, legendY + 9);
        
        // 普通难度
        ctx.fillStyle = '#2196f3';
        ctx.fillRect(legendX + 90, legendY, 30, 10);
        ctx.fillStyle = '#333333';
        ctx.fillText('普通', legendX + 125, legendY + 9);
        
        // 困难难度
        ctx.fillStyle = '#f44336';
        ctx.fillRect(legendX + 180, legendY, 30, 10);
        ctx.fillStyle = '#333333';
        ctx.fillText('困难', legendX + 215, legendY + 9);

        // 绘制网格和Y轴刻度
        ctx.strokeStyle = '#e0e0e0';
        ctx.fillStyle = '#666666';
        ctx.font = '11px sans-serif';
        ctx.lineWidth = 1;

        const ySteps = 6;
        for (let i = 0; i <= ySteps; i++) {
          const y = padding.top + (chartHeight / ySteps) * i;
          const value = yMax - (yMax - yMin) / ySteps * i;

          // 网格线
          ctx.beginPath();
          ctx.moveTo(padding.left, y);
          ctx.lineTo(padding.left + chartWidth, y);
          ctx.stroke();

          // Y轴标签
          ctx.textAlign = 'right';
          ctx.textBaseline = 'middle';
          ctx.fillText(Math.round(value) + 's', padding.left - 10, y);
        }

        // 绘制X轴刻度
        const xLabelCount = Math.min(10, data.length);
        const xLabelStep = Math.floor(data.length / xLabelCount) || 1;
        ctx.textAlign = 'center';
        for (let i = 0; i < data.length; i += xLabelStep) {
          const x = padding.left + (i / (data.length - 1 || 1)) * chartWidth;
          const actualIndex = records.length > 30 ? records.length - 30 + i + 1 : i + 1;
          ctx.fillText(`第${actualIndex}次`, x, height - 20);
        }

        // 绘制数据折线和数据点（按难度分类使用不同颜色）
        const difficultyColors = {
          'easy': '#4caf50',    // 绿色
          'normal': '#2196f3',  // 蓝色
          'hard': '#f44336'     // 红色
        };
        
        // 先绘制连线
        ctx.lineWidth = 2;
        ctx.beginPath();
        let lastX = null, lastY = null;
        
        displayRecords.forEach((record, idx) => {
          const val = record.gameTime;
          const difficulty = record.difficulty || 'normal';
          const x = padding.left + (idx / (data.length - 1 || 1)) * chartWidth;
          const y = padding.top + chartHeight - ((val - yMin) / (yMax - yMin)) * chartHeight;
          
          if (idx === 0) {
            ctx.moveTo(x, y);
          } else {
            // 如果相邻两点难度不同，分段绘制
            if (displayRecords[idx - 1] && (displayRecords[idx - 1].difficulty || 'normal') === difficulty) {
              ctx.strokeStyle = difficultyColors[difficulty];
              ctx.beginPath();
              ctx.moveTo(lastX, lastY);
              ctx.lineTo(x, y);
              ctx.stroke();
            } else {
              // 难度改变时，用灰色虚线连接
              ctx.save();
              ctx.strokeStyle = '#cccccc';
              ctx.setLineDash([5, 5]);
              ctx.beginPath();
              ctx.moveTo(lastX, lastY);
              ctx.lineTo(x, y);
              ctx.stroke();
              ctx.restore();
            }
          }
          
          lastX = x;
          lastY = y;
        });

        // 再绘制数据点
        displayRecords.forEach((record, idx) => {
          const val = record.gameTime;
          const difficulty = record.difficulty || 'normal';
          const x = padding.left + (idx / (data.length - 1 || 1)) * chartWidth;
          const y = padding.top + chartHeight - ((val - yMin) / (yMax - yMin)) * chartHeight;

          ctx.fillStyle = difficultyColors[difficulty];
          ctx.beginPath();
          ctx.arc(x, y, 5, 0, 2 * Math.PI);
          ctx.fill();
          
          // 添加白色边框让点更明显
          ctx.strokeStyle = '#ffffff';
          ctx.lineWidth = 2;
          ctx.stroke();
        });

        console.log('[游戏记录] 绘制完成');
      });
    } catch (e) {
      console.error('[游戏记录] 图表渲染失败:', e);
    }
  }
});
