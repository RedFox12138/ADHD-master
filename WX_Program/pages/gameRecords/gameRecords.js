// pages/gameRecords/gameRecords.js
const wxCharts = require('../../utils/wxcharts.js');

Page({
  data: {
    loading: false,
    records: [],
    chartData: [],
    hasRecords: false,
    totalGames: 0,
    avgTime: 0,
    maxTime: 0,
    trend: '' // 'up', 'down', 'stable'
  },

  onLoad: function() {
    this.loadGameRecords();
  },

  onShow: function() {
    // 每次显示页面时刷新数据
    this.loadGameRecords();
  },

  // 获取用户ID
  getUserId: function() {
    return new Promise((resolve, reject) => {
      wx.login({
        success: (res) => {
          if (res.code) {
            wx.request({
              url: 'https://xxyeeg.zicp.fun/login',
              method: 'POST',
              data: { code: res.code },
              success: (result) => {
                if (result.data.openid) {
                  resolve(result.data.openid);
                } else {
                  reject('获取openid失败');
                }
              },
              fail: reject
            });
          } else {
            reject('登录失败');
          }
        },
        fail: reject
      });
    });
  },

  // 加载游戏记录
  loadGameRecords: function() {
    this.setData({ loading: true });

    this.getUserId().then(user_id => {
      wx.request({
        url: 'https://xxyeeg.zicp.fun/getGameRecords',
        method: 'POST',
        data: { userId: user_id },
        success: (res) => {
          if (res.data.success && res.data.records.length > 0) {
            const records = res.data.records;
            
            // 计算统计数据
            const totalGames = records.length;
            const gameTimes = records.map(r => r.gameTime);
            const avgTime = Math.round(gameTimes.reduce((a, b) => a + b, 0) / totalGames);
            const maxTime = Math.max(...gameTimes);

            // 计算趋势（最近5局与之前的对比）
            let trend = 'stable';
            if (totalGames >= 10) {
              const recent5 = gameTimes.slice(-5);
              const previous5 = gameTimes.slice(-10, -5);
              const recentAvg = recent5.reduce((a, b) => a + b, 0) / 5;
              const previousAvg = previous5.reduce((a, b) => a + b, 0) / 5;
              
              if (recentAvg > previousAvg * 1.1) {
                trend = 'up';
              } else if (recentAvg < previousAvg * 0.9) {
                trend = 'down';
              }
            }

            this.setData({
              records: records,
              hasRecords: true,
              totalGames: totalGames,
              avgTime: avgTime,
              maxTime: maxTime,
              trend: trend,
              loading: false
            }, () => {
              this.renderChart(records);
            });
          } else {
            this.setData({
              hasRecords: false,
              loading: false
            });
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

  // 渲染图表
  renderChart: function(records) {
    try {
      const systemInfo = wx.getSystemInfoSync();
      const windowWidth = systemInfo.windowWidth;

      // 准备数据（最多显示最近20次）
      const displayRecords = records.slice(-20);
      const categories = displayRecords.map((_, index) => `第${index + 1}次`);
      const data = displayRecords.map(r => r.gameTime);

      new wxCharts({
        canvasId: 'gameRecordsChart',
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
          min: 0,
          format: val => Math.round(val)
        },
        width: windowWidth * 0.9,
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
        padding: [15, 15, 15, 25]
      });
    } catch (e) {
      console.error('[游戏记录] 图表渲染失败:', e);
    }
  },

  // 刷新数据
  onRefresh: function() {
    this.loadGameRecords();
  },

  // 查看详细记录
  viewDetail: function(e) {
    const index = e.currentTarget.dataset.index;
    const record = this.data.records[index];
    
    wx.showModal({
      title: '记录详情',
      content: `时间: ${record.timestamp}\n游戏时长: ${record.gameTime}秒`,
      showCancel: false
    });
  },

  // 跳转到游戏页面
  goToGame: function() {
    wx.switchTab({
      url: '/pages/index/index'
    });
  }
});
