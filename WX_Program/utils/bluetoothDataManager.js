// 蓝牙数据管理模块
// 用于calibration页面的数据收集

let dataBuffer = []; // 数据缓冲区
let isCollecting = false; // 是否正在收集数据
let collectionCallback = null; // 数据收集回调函数

const bluetoothDataManager = {
  // 开始数据收集
  startCollection: function(callback) {
    console.log('开始数据收集');
    dataBuffer = [];
    isCollecting = true;
    collectionCallback = callback;
  },

  // 停止数据收集
  stopCollection: function() {
    console.log('停止数据收集，共收集', dataBuffer.length, '个数据点');
    isCollecting = false;
    const data = [...dataBuffer]; // 复制数据
    dataBuffer = []; // 清空缓冲区
    return data;
  },

  // 添加数据点
  addDataPoint: function(dataPoint) {
    if (isCollecting) {
      dataBuffer.push(dataPoint);
      
      // 如果设置了回调，每收集一定量数据后调用
      if (collectionCallback && dataBuffer.length % 10 === 0) {
        collectionCallback(dataBuffer.length);
      }
    }
  },

  // 获取当前收集的数据数量
  getDataCount: function() {
    return dataBuffer.length;
  },

  // 是否正在收集
  isCollecting: function() {
    return isCollecting;
  },

  // 清空缓冲区
  clear: function() {
    dataBuffer = [];
    isCollecting = false;
    collectionCallback = null;
  }
};

module.exports = bluetoothDataManager;
