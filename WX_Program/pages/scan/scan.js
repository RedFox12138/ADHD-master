const app = getApp()

Page({
  data: {
    devices: [], // 存储发现的设备
    discovering: false, // 是否正在搜索
    connectedId: null, // 当前连接的设备ID
    existing: new Map() // 将 existing 存储为页面数据
  },

  onShow() {
    this.startDiscovery()
  },

  onUnload() {
    this.stopDiscovery() // 页面卸载时停止搜索
    this.setData({ existing: new Map() });
  },

  // 开始搜索蓝牙设备
  startDiscovery() {
    this.setData({ discovering: true }) // 不清空设备列表
    wx.openBluetoothAdapter({
      success: () => {
        console.log('蓝牙适配器初始化成功')
        wx.startBluetoothDevicesDiscovery({
          allowDuplicatesKey: false, // 不重复上报同一设备
          success: () => {
            console.log('开始搜索蓝牙设备')
            wx.onBluetoothDeviceFound(this.handleFoundDevice)
            // 30秒后自动停止搜索
            setTimeout(() => this.stopDiscovery(), 30000)
          },
          fail: (err) => {
            console.error('开始搜索蓝牙设备失败', err)
            this.setData({ discovering: false })
          }
        })
      },
      fail: (err) => {
        console.error('蓝牙适配器初始化失败', err)
        this.setData({ discovering: false })
      }
    })
  },

  // 停止搜索蓝牙设备
  stopDiscovery() {
    if (!this.data.discovering) return
    wx.stopBluetoothDevicesDiscovery({
      complete: () => this.setData({ discovering: false })
    })
  },

  // 处理发现的设备
  handleFoundDevice(devices) {
    if (!devices.devices.length) return

    // 合并设备列表并去重
    //const newDevices = devices.devices.filter(d => d.name || d.localName) // 过滤掉没有名称的设备
    const newDevices = devices.devices
    this.data.existing = new Map(this.data.devices.map(d => [d.deviceId, d]))
    newDevices.forEach(device => {
      this.data.existing.set(device.deviceId, device)
      // if (!existing.has(device.deviceId)) {
        
      // }
    })

    this.setData({
      devices: Array.from(this.data.existing.values())
    })
  },

  // 连接设备
  async connectDevice(e) {
    const device = e.currentTarget.dataset.device
    if (this.data.connectedId === device.deviceId) {
      return wx.showToast({ title: '已连接该设备', icon: 'none' })
    }

    wx.showLoading({ title: '连接中...', mask: true })
    this.stopDiscovery() // 停止搜索

    try {
      await this.createConnection(device)
      this.setData({ connectedId: device.deviceId })
      wx.showToast({ title: '连接成功', icon: 'success' })
    } catch (err) {
      console.error('连接失败:', err)
      wx.showToast({ title: '连接失败', icon: 'error' })
    }
    wx.hideLoading()
  },

  // 创建蓝牙连接
  createConnection(device) {
    return new Promise((resolve, reject) => {
      // 增加超时处理
      const timeout = setTimeout(() => {
        reject(new Error('连接超时'))
        wx.closeBLEConnection({ deviceId: device.deviceId })
      }, 5000)

      wx.createBLEConnection({
        deviceId: device.deviceId,
        success: () => {
          clearTimeout(timeout)
          app.globalData.connectedDevice = device
          resolve()
        },
        fail: (err) => {
          clearTimeout(timeout)
          reject(err)
        }
      })
    })
  }
})