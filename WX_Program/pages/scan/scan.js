const app = getApp()

Page({
  data: {
    devices: [], // 存储发现的设备
    allDevices: [], // 存储所有设备的完整列表
    displayDevices: [], // 当前显示的设备列表
    filteredDevices: [], // 搜索过滤后的设备列表
    discovering: false, // 是否正在搜索
    connectedId: null, // 当前连接的设备ID
    searchKeyword: '', // 搜索关键词
    showOnlyNamed: false, // 是否只显示有名称的设备
  },

  // 使用页面实例变量而不是data中的Map，避免序列化问题
  existingDevices: new Map(),

  onShow() {
    // 显示页面时，先显示已发现的设备
    this.updateDisplayDevices()
    this.startDiscovery()
  },

  onUnload() {
    this.stopDiscovery() // 页面卸载时停止搜索
  },

  // 搜索输入处理
  onSearchInput(e) {
    const keyword = e.detail.value
    this.setData({
      searchKeyword: keyword
    }, () => {
      this.filterDevices()
    })
  },

  // 搜索确认处理
  onSearchConfirm(e) {
    const keyword = e.detail.value.trim()
    this.setData({
      searchKeyword: keyword
    }, () => {
      this.filterDevices()
    })
  },

  // 清空搜索
  clearSearch() {
    this.setData({
      searchKeyword: ''
    }, () => {
      this.filterDevices()
    })
  },

  // 切换过滤模式
  toggleFilter() {
    this.setData({
      showOnlyNamed: !this.data.showOnlyNamed
    }, () => {
      this.filterDevices()
    })
  },

  // 过滤设备列表
  filterDevices() {
    const { searchKeyword, showOnlyNamed } = this.data
    let devices = Array.from(this.existingDevices.values())

    // 按名称过滤
    if (showOnlyNamed) {
      devices = devices.filter(device => device.name && device.name.trim() !== '')
    }

    // 按搜索关键词过滤
    let filteredDevices = devices
    if (searchKeyword.trim()) {
      const keyword = searchKeyword.toLowerCase()
      filteredDevices = devices.filter(device => {
        const deviceName = (device.name || '').toLowerCase()
        const deviceId = (device.deviceId || '').toLowerCase()
        return deviceName.includes(keyword) || deviceId.includes(keyword)
      })
    }

    // 按信号强度排序（信号强度越高越靠前）
    filteredDevices.sort((a, b) => (b.RSSI || -100) - (a.RSSI || -100))

    this.setData({
      allDevices: devices,
      filteredDevices: filteredDevices,
      displayDevices: filteredDevices,
      devices: filteredDevices // 保持兼容性
    })
  },

  // 更新显示的设备列表
  updateDisplayDevices() {
    this.filterDevices()
  },

  // 开始搜索蓝牙设备
  startDiscovery() {
    this.setData({ discovering: true })
    wx.openBluetoothAdapter({
      success: () => {
        console.log('蓝牙适配器初始化成功')
        wx.startBluetoothDevicesDiscovery({
          allowDuplicatesKey: false, // 不重复上报同一设备
          success: () => {
            console.log('开始搜索蓝牙设备')
            wx.onBluetoothDeviceFound(this.handleFoundDevice.bind(this))
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

    const newDevices = devices.devices
    let hasNewDevice = false
    
    newDevices.forEach(device => {
      if (!this.existingDevices.has(device.deviceId)) {
        // 为设备添加发现时间戳，用于排序
        device.discoveredAt = Date.now()
        this.existingDevices.set(device.deviceId, device)
        hasNewDevice = true
      } else {
        // 更新已存在设备的信号强度
        const existingDevice = this.existingDevices.get(device.deviceId)
        existingDevice.RSSI = device.RSSI
        this.existingDevices.set(device.deviceId, existingDevice)
      }
    })

    // 只有发现新设备或信号强度变化时才更新UI
    if (hasNewDevice || newDevices.length > 0) {
      this.updateDisplayDevices()
    }
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