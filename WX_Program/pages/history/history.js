// pages/history/history.js
const wxCharts = require('../../utils/wxcharts.js');

Page({
  data: {
    historyDates: [],
    selectedDate: null,
    historyFiles: [],
    showChart: false,
    loading: false,
    currentUserId: null
  },

  onLoad: function() {
    this.loadHistoryDates();
  },

  // 加载历史日期列表
  loadHistoryDates: function() {
    this.getUserId().then(user_id => {
      wx.request({
        url: 'http://xxyeeg.zicp.fun/getHistoryDates',
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
    this.getUserId().then(user_id => {
      wx.request({
        url: 'http://xxyeeg.zicp.fun/getHistoryFiles',
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

    this.getUserId().then(user_id => {
      wx.request({
        url: 'http://xxyeeg.zicp.fun/getHistoryFile',
        method: 'POST',
        data: { 
          userId: user_id,
          date: this.data.selectedDate,
          fileName: file 
        },
        success: (res) => {
          if (res.data.success) {
            this.processFileData(res.data.data);
          } else {
            wx.showToast({ title: '文件加载失败', icon: 'none' });
          }
          this.setData({ loading: false });
        },
        fail: (err) => {
          this.setData({ loading: false });
          wx.showToast({ title: '网络错误', icon: 'none' });
        }
      });
    });
  },

  // 处理文件数据
  processFileData: function(rawData) {
    const values = rawData.map(Number);
    const times = values.map((_, i) => `${(i * 0.5).toFixed(1)}s`);

    this.setData({
      showChart: true
    }, () => {
      this.initChart(values, times);
    });
  },

  // 初始化图表
  initChart: function(values, times) {
    const baselineValue = values.length > 0 ? values[0] : 0;
    
    const series = [{
      name: 'Delta功率',
      data: values,
      color: '#1aad19',
      width: 3
    }, {
      name: '基线',
      data: values.map(() => baselineValue),
      color: '#ff0000',
      width: 2
    }];

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
          min: Math.min(...values) * 0.9,
          max: Math.max(...values) * 1.1,
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
      console.error('图表初始化失败:', e);
      wx.showToast({ title: '图表加载失败', icon: 'none' });
    }
  },

  // 返回文件列表
  backToList: function() {
    this.setData({ showChart: false });
  },

  // 导出数据 (新增功能)
  exportData: function() {
    wx.showToast({ title: '导出功能开发中', icon: 'none' });
  },

  // 分享图表 (新增功能)
  shareChart: function() {
    wx.showToast({ title: '分享功能开发中', icon: 'none' });
  }
});