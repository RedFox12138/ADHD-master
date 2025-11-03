// 音频管理器
class AudioManager {
  constructor() {
    // 音效实例池
    this.soundEffects = {};
    
    // BGM音频对象（使用InnerAudioContext，内置于游戏）
    this.bgmAudio = null;
    
    // 音效开关
    this.soundEnabled = true;
    this.bgmEnabled = true;
    
    // 当前播放的BGM
    this.currentBgm = null;
    
    // 初始化音效
    this.initSoundEffects();
  }
  
  // 初始化所有音效（预指定格式，避免运行时搜索）
  initSoundEffects() {
    // 预定义每个音效的文件格式（精简版）
    const effectsConfig = {
      'button_click': 'mp3',      // 按钮点击音
      'turret_shoot': 'wav',      // 炮台射击音
      'explosion': 'wav',         // 爆炸音
      'game_over': 'mp3'          // 游戏结束音
    };
    
    Object.keys(effectsConfig).forEach(effectName => {
      const audio = wx.createInnerAudioContext();
      const format = effectsConfig[effectName];
      
      // 直接指定格式，不再循环搜索
      audio.src = `/audio/${effectName}.${format}`;
      audio.volume = 0.5; // 默认音量50%
      
      // 错误处理（静默失败，不输出日志）
      audio.onError((err) => {
        // 静默处理，不输出日志
      });
      
      this.soundEffects[effectName] = audio;
    });
  }
  
  // 播放音效
  playSound(soundName) {
    if (!this.soundEnabled) return;
    
    const sound = this.soundEffects[soundName];
    if (sound) {
      try {
        // 停止当前播放，从头开始
        sound.stop();
        sound.play();
      } catch (err) {
        // 静默处理错误，不输出日志
      }
    }
  }
  
  // 播放背景音乐（内置于游戏，使用InnerAudioContext）
  playBGM(bgmName, title = '背景音乐') {
    if (!this.bgmEnabled) return;
    
    // 如果正在播放相同的BGM，不重复播放
    if (this.currentBgm === bgmName && this.bgmAudio) return;
    
    // 停止之前的BGM
    if (this.bgmAudio) {
      this.bgmAudio.stop();
      this.bgmAudio.destroy();
    }
    
    try {
      this.currentBgm = bgmName;
      
      // 创建内部音频对象
      this.bgmAudio = wx.createInnerAudioContext();
      this.bgmAudio.src = `/audio/${bgmName}.mp3`;
      this.bgmAudio.loop = true;  // 循环播放
      this.bgmAudio.volume = 0.3; // BGM音量稍低
      
      // 错误处理（静默）
      this.bgmAudio.onError(() => {
        // 静默失败，不输出日志
      });
      
      this.bgmAudio.play();
    } catch (err) {
      // 静默失败，不输出日志
    }
  }
  
  // 停止背景音乐
  stopBGM() {
    if (this.bgmAudio) {
      this.bgmAudio.stop();
      this.bgmAudio.destroy();
      this.bgmAudio = null;
    }
    this.currentBgm = null;
  }
  
  // 暂停背景音乐
  pauseBGM() {
    if (this.bgmAudio) {
      this.bgmAudio.pause();
    }
  }
  
  // 恢复背景音乐
  resumeBGM() {
    if (this.bgmEnabled && this.bgmAudio) {
      this.bgmAudio.play();
    }
  }
  
  // 切换音效开关
  toggleSound() {
    this.soundEnabled = !this.soundEnabled;
    return this.soundEnabled;
  }
  
  // 切换BGM开关
  toggleBGM() {
    this.bgmEnabled = !this.bgmEnabled;
    if (this.bgmEnabled) {
      this.resumeBGM();
    } else {
      this.pauseBGM();
    }
    return this.bgmEnabled;
  }
  
  // 设置音效音量 (0-1)
  setSoundVolume(volume) {
    Object.values(this.soundEffects).forEach(sound => {
      sound.volume = volume;
    });
  }
  
  // 设置BGM音量 (0-1)
  setBGMVolume(volume) {
    if (this.bgmAudio) {
      this.bgmAudio.volume = volume;
    }
  }
  
  // 销毁所有音频
  destroy() {
    Object.values(this.soundEffects).forEach(sound => {
      sound.destroy();
    });
    this.stopBGM();
  }
}

// 创建单例
const audioManager = new AudioManager();

module.exports = audioManager;
