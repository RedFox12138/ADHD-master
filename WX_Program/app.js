App({
  globalData: {
    connectedDevice: null,    // 已连接设备
    characteristic: null,    // 特征值
    serviceId: "",     // 根据实际设备修改
    SendCharacteristicId: "6e400002-b5a3-f393-e0a9-e50e24dcca9e",
    RecvCharacteristicId: "6e400003-b5a3-f393-e0a9-e50e24dcca9e",
    userId: null,  // 用户 openid
    HTTP_URL: 'https://xxyeeg.zicp.fun'  // 服务器地址
  },

  /**
   * 全局统一的 getUserId 方法
   * 所有页面都应该使用这个方法获取 userId
   */
  getUserId() {
    return new Promise((resolve, reject) => {
      // 1. 先检查全局变量
      if (this.globalData.userId) {
        resolve(this.globalData.userId);
        return;
      }

      // 2. 检查本地存储
      const cachedUserId = wx.getStorageSync('user_id');
      if (cachedUserId) {
        this.globalData.userId = cachedUserId;
        resolve(cachedUserId);
        return;
      }

      // 3. 调用微信登录获取 openid
      wx.login({
        success: (res) => {
          if (res.code) {
            wx.request({
              url: `${this.globalData.HTTP_URL}/getOpenId`,
              method: 'POST',
              data: { code: res.code },
              success: (res) => {
                if (res.data && res.data.openid) {
                  const userId = res.data.openid;
                  // 保存到全局变量和本地存储
                  this.globalData.userId = userId;
                  wx.setStorageSync('user_id', userId);
                  console.log('[全局] 获取 userId 成功:', userId);
                  resolve(userId);
                } else {
                  reject('服务器未返回 openid');
                }
              },
              fail: (err) => {
                console.error('[全局] 获取 openid 失败:', err);
                reject('获取 openid 失败');
              }
            });
          } else {
            reject('wx.login 失败');
          }
        },
        fail: (err) => {
          console.error('[全局] wx.login 调用失败:', err);
          reject('wx.login 调用失败');
        }
      });
    });
  },

  onLaunch() {
    // 应用启动时预加载 userId
    this.getUserId().then(userId => {
      console.log('[应用启动] userId 已加载:', userId);
    }).catch(err => {
      console.error('[应用启动] 获取 userId 失败:', err);
    });
  }
})