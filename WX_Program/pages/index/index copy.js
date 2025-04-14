const app = getApp();
const util = require('../../utils/render.js');
var wxCharts = require('../../utils/wxcharts.js');
var lineChart = null;

Page({
  data: {
    connected: false,
    deviceName: '',
    dataPoints: new Array(1000).fill(0), // 存储100个数据点
    inputData: '', // 用户输入的十六进制数据
    result:null,
    x_data:[],
    y_data:[],
    x_value: [],
    EEGdata: [],
    timer :""
  },
  onLoad: function () {
    var that = this;
    var arr1 = new Array(250);
    for (var i = 0; i < 250; i++) {
      arr1[i] = i + 1;
    }
    that.setData({
      x_value: arr1,
    });
     this.OnWxChart(that.data.x_value, that.data.EEGdata, 'EEG信号');
     wx.onBLEConnectionStateChange(res => {
      console.log('连接状态变化:', res);
      if (!res.connected) {
        this.setData({ connected: false });
        wx.showToast({ title: '连接已断开', icon: 'none' });
        // 可选：尝试自动重连
      }
    });
  },
  onUnload: function () {
    if (this.data.timer) {
      clearInterval(this.data.timer);
    }
  },

  OnWxChart: function (x_data, y_data, name) {
      var windowWidth = '',
        windowHeight = ''; //定义宽高
      try {
        var res = wx.getSystemInfoSync(); //试图获取屏幕宽高数据
        windowWidth = res.windowWidth ; //以设计图750为主进行比例算换
        windowHeight = res.windowWidth  //以设计图750为主进行比例算换
      } catch (e) {
        console.error('getSystemInfoSync failed!'); //如果获取失败
      }

      lineChart = new wxCharts({
        canvasId: 'EEG', //输入wxml中canvas的id
        type: 'line',
        categories: x_data, //模拟的x轴横坐标参数
        animation: false, //是否开启动画
  
        series: [{
          name: name,
          data: y_data,
          format: function (val, name) {
            return val;
          }
        }],
        xAxis: { //是否隐藏x轴分割线
          disableGrid: true,
        },
        yAxis: { //y轴数据
          title: '电压(V)', //标题
          format: function (val) { //返回数值
            return val.toFixed(2);
          },
          min: -10, //最小值
          max: 10, // 最大值
          gridColor: '#D8D8D8',
        },
        width: windowWidth * 1.1, //图表展示内容宽度
        height: windowHeight, //图表展示内容高度
        dataLabel: false, //是否在图表上直接显示数据
        dataPointShape: false, //是否在图标上显示数据点标志
        extra: {
          lineStyle: 'Broken' //曲线
        },
      });
    },

    send: function() {
      var that = this;
      // 清除已有的定时器
      if (that.data.timer) {
        clearInterval(that.data.timer);
      }
      // 启动新的定时器并保存到 data 中
      that.setData({
        timer: setInterval(function () {
          var qwe = wx.getStorageSync('EEGdata');
          that.OnWxChart(that.data.x_value, qwe);
        }, 100)
      });
    },

  onShow() {
    var that = this;
    // 检查是否已连接设备
    if (app.globalData.connectedDevice) {
      that.send();
      this.setData({
        connected: true,
        deviceName: app.globalData.connectedDevice.name
      });
      this.startListenData();
    }
  },
  // 跳转到扫描页面
  navigateToScan() {
    wx.navigateTo({ url: '/pages/scan/scan' });
  },
  enableBLEData: function (data) {
    var hex = data
    var typedArray = new Uint8Array(hex.match(/[\da-f]{2}/gi).map(function (h) {
      return parseInt(h, 16)
    }))
    console.log("转换为Uint8Array", typedArray);
    var buffer1 = typedArray.buffer
    console.log("对应的buffer值，typedArray.buffer", buffer1)
    /**
     * 向蓝牙低功耗设备特征值中写入二进制数据。
     */
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
    const that = this; // 确保正确的作用域指向
    const deviceId = app.globalData.connectedDevice.deviceId;
    const serviceId = app.globalData.connectedDevice.advertisServiceUUIDs[0];
    const targetCharacteristicId = app.globalData.RecvCharacteristicId; // 确保全局ID已正确定义
  
    // 1. 获取设备特征值列表
    wx.getBLEDeviceCharacteristics({
      deviceId: deviceId,
      serviceId: serviceId,
      success: function (res) {
        // console.log('特征列表:', app.globalData.connectedDevice);
  
        // 2. 查找匹配的特征ID
        const targetChar = res.characteristics.find(c => 
          c.uuid.toUpperCase() === targetCharacteristicId.toUpperCase()
        );
        // console.log(targetChar);

        if (!targetChar) {
          console.error('未找到匹配的特征ID');
          return;
        }
  
        // 3. 检查特征是否支持通知/指示属性
        if (!(targetChar.properties.notify || targetChar.properties.indicate)) {
          console.error('特征不支持NOTIFY/INDICATE属性');
          return;
        }

        if (!deviceId || !serviceId || !targetCharacteristicId) {
          console.error('缺失必要参数，请检查设备连接状态');
          return;
        }

        that.enableBLEData("1919"); 

        let buf = '';  // 缓存接收到的数据
        var lengthBuf = buf.length;// 缓存接收到的数据长度
        // 4. 启用特征值变化通知
        wx.notifyBLECharacteristicValueChange({
          deviceId: deviceId,
          serviceId: serviceId,
          type: targetChar.properties.indicate ? 'indicate' : 'notification', // 动态设置 type
          //type: 'notification',
          characteristicId: targetChar.uuid,
          state: true,
          //type,
          success: function (res) {
            console.log('Notify功能启用成功', res);
            console.log('Notify功能启用成功后的charaid是', targetChar.uuid);
            // 5. 设置特征值变化监听（建议放在页面onLoad中，确保只设置一次）
            wx.onBLECharacteristicValueChange(function (characteristic) {
                const result = characteristic.value;
                const hex = that.buf2hex(result);
                buf = hex;
                lengthBuf = buf.length;

                while (lengthBuf >= 10) {
                  if (buf[0] == 1 && buf[1] == 1 && buf[8] == 0 && buf[9] == 1) {
                     
                     var str1 = buf.substring(2,8);
                     var value1 = parseInt(str1, 16);
                     if (value1 >= 8388608) {
                      value1 = value1 - 16777216;
                    }
                    value1 = value1 * 2.24 * 1000 / 8388608;
                    
                    var y_data = that.data.EEGdata;
                    for (var i = 0; i < 249; i++) {
                      y_data[i] = y_data[i + 1];
                    }
                    y_data[249] = value1;
                    wx.setStorageSync('EEGdata', y_data)

                    buf = buf.substring(10);
                    lengthBuf = buf.length;
                  } else {
                    buf = buf.substring(1);
                    lengthBuf = buf.length;
                  }
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

  // 处理用户输入
  handleInput(e) {
    this.setData({
      inputData: e.detail.value
    });
  },
  buf2hex: function (buffer) { // buffer is an ArrayBuffer
    return Array.prototype.map.call(new Uint8Array(buffer), x => ('00' + x.toString(16)).slice(-2)).join('');
  },
  // 将十六进制字符串转换为 ArrayBuffer
  hexStringToArrayBuffer(hexString) {
    var hex = hexString
    var typedArray = new Uint8Array(hex.match(/[\da-f]{2}/gi).map(function (h) {
      return parseInt(h, 16)
    }))
    console.log("原始", hexString);
    console.log("转换为Uint8Array", typedArray);
    console.log("对应的buffer值，typedArray.buffer", typedArray.buffer)
    return typedArray.buffer
  },


  // 发送数据到设备
  sendData() {
    if (!this.data.connected) {
      wx.showToast({
        title: '未连接设备',
        icon: 'none'
      });
      return;
    }

    if (!this.data.inputData) {
      wx.showToast({
        title: '请输入数据',
        icon: 'none'
      });
      return;
    }
    this.enableBLEData(this.data.inputData)
   
  }
});