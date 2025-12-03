# 音频文件说明（精简版）

请将音频文件放在此目录下。

## ⚡ 性能优化说明

**本系统已进行音频格式预指定优化**，避免运行时循环搜索，提升游戏流畅度。

## 🎵 需要的音频文件

### 音效文件 (4个必需)

| 文件名 | 格式要求 | 用途 | 说明 |
|--------|----------|------|------|
| `button_click.mp3` | **MP3** | 按钮点击音 | 所有按钮操作 |
| `turret_shoot.wav` | **WAV** | 炮台射击音 | 炮台发射子弹 |
| `explosion.wav` | **WAV** | 爆炸音效 | 怪物被消灭时 |
| `game_over.mp3` | **MP3** | 游戏结束音 | 小镇被摧毁时 |

### 背景音乐 (BGM)

**请您自己添加以下BGM文件：**

- `main_bgm.mp3` - 主界面背景音乐
  - 建议：轻松、舒缓的音乐
  - 用于游戏开始前的界面

- `game_bgm.mp3` - 游戏过程中的背景音乐
  - 建议：紧张、有节奏感的音乐
  - 用于游戏进行时（治疗阶段）

## 音频文件推荐来源

### 免费音效网站：
1. Freesound.org - https://freesound.org/
2. Zapsplat.com - https://www.zapsplat.com/
3. Mixkit.co - https://mixkit.co/free-sound-effects/

### 免费音乐网站：
1. Incompetech - https://incompetech.com/
2. FreePD - https://freepd.com/
3. Purple Planet - https://www.purple-planet.com/

## 音频规格建议

- **格式**: MP3 (推荐) 或 M4A
- **音效时长**: 0.5-3秒
- **BGM时长**: 2-5分钟（会自动循环）
- **比特率**: 128kbps 即可（小程序要控制包大小）
- **采样率**: 44.1kHz

## 注意事项

1. 音频文件不要太大（单个文件建议小于500KB）
2. 音效要简短，避免影响游戏流畅度
3. BGM需要能够循环播放
4. 确保音频文件有合法使用权限
