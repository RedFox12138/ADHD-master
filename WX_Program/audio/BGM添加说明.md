# 游戏BGM添加说明

## 功能说明
现在游戏支持多个BGM随机播放。当一首BGM播放完成后，会自动随机选择下一首BGM播放（不会重复上一首）。

## 当前BGM列表
系统已配置以下BGM文件：
1. `game_bgm.mp3` - 原有BGM（已存在）
2. `game_bgm2.mp3` - 新增BGM2（需要添加）
3. `game_bgm3.mp3` - 新增BGM3（需要添加）
4. `game_bgm4.mp3` - 新增BGM4（需要添加）

## 如何添加新的BGM

### 步骤1：准备音频文件
1. 准备你想要添加的BGM音乐文件
2. 转换为 MP3 格式（推荐比特率：128kbps 或 192kbps）
3. 文件大小建议控制在 2MB 以内（微信小程序有包大小限制）
4. 建议音乐时长：30秒 - 2分钟

### 步骤2：重命名文件
将音频文件重命名为以下名称之一：
- `game_bgm2.mp3`
- `game_bgm3.mp3`
- `game_bgm4.mp3`

### 步骤3：放置文件
将重命名后的文件放入 `WX_Program/audio/` 文件夹中

### 步骤4：添加更多BGM（可选）
如果你想添加超过4首BGM，可以编辑 `WX_Program/utils/audioManager.js` 文件：

找到这段代码：
```javascript
this.gameBgmList = [
  'game_bgm',      // 原有BGM
  'game_bgm2',     // 新增BGM2
  'game_bgm3',     // 新增BGM3
  'game_bgm4'      // 新增BGM4
];
```

添加更多BGM名称，例如：
```javascript
this.gameBgmList = [
  'game_bgm',
  'game_bgm2',
  'game_bgm3',
  'game_bgm4',
  'game_bgm5',     // 新增BGM5
  'game_bgm6'      // 新增BGM6
];
```

然后将对应的 `game_bgm5.mp3` 和 `game_bgm6.mp3` 文件放入 audio 文件夹。

## 测试
1. 上传代码到微信开发者工具
2. 启动游戏
3. 游戏开始后会随机播放一首BGM
4. 当BGM播放完成后，会自动切换到另一首随机BGM
5. 确保BGM开关是开启状态

## 注意事项
- 如果某个BGM文件不存在或加载失败，系统会自动跳过并播放下一首
- BGM默认音量为30%（可以在 audioManager.js 中的 `this.bgmAudio.volume = 0.3` 处调整）
- 确保音频文件格式正确且没有损坏
- 建议使用版权允许的音乐或自己创作的音乐

## 推荐的免费音乐资源网站
- 爱给网（aigei.com）
- Freesound（freesound.org）
- Free Music Archive
- YouTube Audio Library

## 故障排除
**问题：BGM不播放**
- 检查文件名是否正确（区分大小写）
- 检查文件格式是否为 MP3
- 检查BGM开关是否开启
- 在微信开发者工具中查看控制台是否有错误信息

**问题：只播放一首BGM**
- 确认其他BGM文件已正确添加到 audio 文件夹
- 检查文件名拼写是否与代码中的配置一致
