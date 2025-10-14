// logs.js
const util = require('../../utils/util.js')

Page({
  data: {
    logs: [],
    todayLogs: 0
  },

  onLoad() {
    this.loadLogs();
  },

  // 加载日志数据
  loadLogs: function() {
    const logs = (wx.getStorageSync('logs') || []).map(log => {
      return {
        date: util.formatTime(new Date(log)),
        timeStamp: log,
        time: this.formatTime(new Date(log)),
        type: '系统日志'
      }
    });

    // 计算今日日志数量
    const today = new Date().toDateString();
    const todayLogs = logs.filter(log =>
      new Date(log.timeStamp).toDateString() === today
    ).length;

    this.setData({
      logs: logs.reverse(), // 最新的在前面
      todayLogs
    });
  },

  // 格式化时间
  formatTime: function(date) {
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    const seconds = date.getSeconds().toString().padStart(2, '0');
    return `${hours}:${minutes}:${seconds}`;
  },

  // 清空日志
  clearLogs: function() {
    wx.showModal({
      title: '确认清空',
      content: '确定要清空所有日志记录吗？此操作不可恢复。',
      success: (res) => {
        if (res.confirm) {
          wx.removeStorageSync('logs');
          this.setData({
            logs: [],
            todayLogs: 0
          });
          wx.showToast({
            title: '日志已清空',
            icon: 'success'
          });
        }
      }
    });
  },

  // 导出日志
  exportLogs: function() {
    if (this.data.logs.length === 0) {
      wx.showToast({
        title: '暂无日志可导出',
        icon: 'none'
      });
      return;
    }

    // 生成导出内容
    const exportContent = this.data.logs.map((log, index) => {
      return `${index + 1}. ${log.date} - ${log.type}`;
    }).join('\n');

    // 复制到剪贴板
    wx.setClipboardData({
      data: exportContent,
      success: () => {
        wx.showToast({
          title: '日志已复制到剪贴板',
          icon: 'success'
        });
      },
      fail: () => {
        wx.showToast({
          title: '导出失败',
          icon: 'error'
        });
      }
    });
  },

  // 刷新日志
  refreshLogs: function() {
    wx.showLoading({
      title: '刷新中...'
    });

    // 模拟刷新延迟
    setTimeout(() => {
      this.loadLogs();
      wx.hideLoading();
      wx.showToast({
        title: '刷新完成',
        icon: 'success'
      });
    }, 1000);
  },

  // 下拉刷新
  onPullDownRefresh: function() {
    this.refreshLogs();
    setTimeout(() => {
      wx.stopPullDownRefresh();
    }, 1000);
  }
});
