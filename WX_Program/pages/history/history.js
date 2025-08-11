// pages/history/history.js
const wxCharts = require('../../utils/wxcharts.js');

Page({
  data: {
    historyDates: [],    // 日期列表
    selectedDate: null,  // 选中的日期
    historyFiles: [],    // 指定日期的文件列表
    chartData: {
      values: [],
      times: []
    },
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
        url: 'http://4nbsf9900182.vicp.fun:18595/getHistoryDates',
        method: 'POST',
        data: { userId: user_id },
        success: (res) => {
          if (res.data.success) {
            this.setData({
              historyDates: res.data.dates
                .map(date => ({
                  text: this.formatDate(date),
                  value: date
                }))
                .sort((a, b) => b.value.localeCompare(a.value)) // 日期降序
            });
          }
        }
      });
    });
  },

  // 日期格式化
  formatDate: function(dateStr) {
    const year = dateStr.substr(0,4)
    const month = dateStr.substr(4,2)
    const day = dateStr.substr(6,2)
    return `${year}-${month}-${day}`
  },

  // 选择日期
  selectDate: function(e) {
    const date = e.currentTarget.dataset.date
    this.setData({ selectedDate: date }, () => {
      this.loadDateFiles()
    })
  },

  // 获取用户ID（不使用globalData）
  getUserId: function() {
    return new Promise((resolve, reject) => {
      // 优先从页面data中获取
      if (this.data.currentUserId) {
        resolve(this.data.currentUserId);
        return;
      }
      
      // 其次从缓存获取
      wx.getStorage({
        key: 'user_id',
        success: (res) => {
          this.setData({ currentUserId: res.data });
          resolve(res.data);
        },
        fail: () => {
          // 最后从微信登录获取
          wx.login({
            success: (res) => {
              if (res.code) {
                wx.request({
                  url: 'http://4nbsf9900182.vicp.fun:18595/getOpenId',
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
                    reject(new Error('请求失败: ' + err.errMsg));
                  }
                });
              } else {
                reject(new Error('wx.login失败: ' + res.errMsg));
              }
            },
            fail: (err) => {
              reject(new Error('wx.login调用失败: ' + err.errMsg));
            }
          });
        }
      });
    });
  },

  // 加载指定日期的文件列表
  loadDateFiles: function() {
    this.getUserId().then(user_id => {
      wx.request({
        url: 'http://4nbsf9900182.vicp.fun:18595/getHistoryFiles',
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
                  name: this.formatTime(file), // 根据文件名生成时间
                  fullName: file
                }))
                .sort((a, b) => b.name.localeCompare(a.name)) // 时间降序
            })
          }
        }
      });
    })
  },

  // 从文件名解析时间（示例文件名：processed_120304_123.txt）
  formatTime: function(filename) {
    const timePart = filename.split('_')[1]
    const hh = timePart.substr(0,2)
    const mm = timePart.substr(2,2)
    const ss = timePart.substr(4,2)
    return `${hh}:${mm}:${ss}`
  },

  // 从文件名提取日期
  extractDateFromFilename: function(filename) {
    try {
      // 假设文件名格式为: experiment-20240101_120000.txt
      const dateStr = filename.match(/\d{8}_\d{6}/)[0];
      const year = dateStr.substr(0, 4);
      const month = dateStr.substr(4, 2);
      const day = dateStr.substr(6, 2);
      return new Date(`${year}-${month}-${day}`).getTime();
    } catch (e) {
      return 0; // 如果解析失败，返回0
    }
  },

  // 查看文件内容
  viewFile: function(e) {
    const file = e.currentTarget.dataset.file
    this.getUserId().then(user_id => {
      wx.request({
        url: 'http://4nbsf9900182.vicp.fun:18595/getHistoryFile',
        method: 'POST',
        data: { 
          userId: user_id,
          date: this.data.selectedDate,
          fileName: file 
        },
        success: (res) => {
          if (res.data.success) {
            this.processFileData(res.data.data)
          }
        }
      });
    })
  },

  // 处理文件数据
  processFileData: function(rawData) {
    // 假设每个数据点间隔0.5秒
    const values = rawData.map(Number)
    const times = values.map((_,i) => `${(i * 0.5).toFixed(1)}s`)
    
    this.setData({
      chartData: { values, times },
      showChart: true
    }, () => this.initChart())
  },


  initChart: function() {
    const { values, times } = this.data.chartData;
    
    // 1. 生成时间轴（每0.5秒一个点）
    const categories = times;
    
    // 2. 计算基线值（第一个数据点）
    const baselineValue = values.length > 0 ? values[0] : 0;
    
    // 3. 准备图表数据
    const series = [
      {
        name: 'TBR',
        data: values,
        color: '#1aad19',
        width: 3,
        format: val => val.toFixed(2)
      },
      // 基线系列（虚线）
      {
        name: '基线',
        data: values.map(() => baselineValue), // 所有点都是基线值
        color: '#ff0000',
        type: 'dash', // 虚线样式
        width: 2
      }
    ];
  
    try {

      const systemInfo = wx.getSystemInfoSync();
      const windowWidth = systemInfo.windowWidth;
      const windowHeight = systemInfo.windowHeight;
      
      new wxCharts({
        width: windowWidth * 0.95,
        height: windowHeight * 0.7,  // 使用窗口高度的70%
        canvasId: 'historyChart',
        type: 'line',
        categories: categories,
        series: series,
        xAxis: {
          disableGrid: false,
          axisLineColor: '#999',
          fontColor: '#333',
          labelCount: 10, // 增加标签数量
          format: val => val
        },
        yAxis: {
          title: '数值',
          min: Math.min(...values) * 0.9,
          max: Math.max(...values) * 1.1,
          format: val => val.toFixed(2),
          // 添加基线标记（红色参考线）
          plotLines: [{
            value: baselineValue,
            color: '#ff0000',
            width: 2,
            dashLength: 8
          }]
        },
        width: windowWidth * 0.95,
        height: 350,
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
      wx.showToast({ 
        title: '图表错误: ' + e.message, 
        icon: 'none' 
      });
    }
  },

  // 返回文件列表
  backToList: function() {
    this.setData({ showChart: false })
  }
});