import os

import numpy as np
from psychopy import visual, core, event, sound
import random
import time


"""
   该代码用于设计实验范式给，采集脑电信号
"""

# 创建窗口（更高的刷新率设置）
win = visual.Window(fullscr=True, color=(-0.8, -0.8, -0.8),
                    screen=0, waitBlanking=True)


# 准备期（不变）
def preparation_phase(duration=5):
    text = visual.TextStim(win, text="准备开始实验\n请保持放松", height=0.1)
    text.draw()
    win.flip()
    core.wait(duration)


# 静息阶段（不变）
def resting_phase1(duration=60):
    images = ["mountain.jpg", "clouds.jpg"]
    image_stims = [visual.ImageStim(win, image=img, size=3.0) for img in images]
    start_time = time.time()
    current_img = 0

    while time.time() - start_time < duration:
        image_stims[current_img].draw()
        win.flip()
        core.wait(10)
        current_img = 1 - current_img
        if event.getKeys(keyList=['escape']):
            win.close()
            core.quit()
#
def resting_phase2(duration=60):

    images = ["mountain.jpg", "clouds.jpg"] if os.path.exists("mountain.jpg") else []
    if images:
        image_stims = [visual.ImageStim(win, image=img, size=3.0) for img in images]

    # 注意力干扰元素
    flicker_circle = visual.Circle(win, radius=0.2, fillColor='red', opacity=0)
    moving_text = visual.TextStim(win, text="", height=0.1, color='white')

    # 随机形状参数
    shapes = {
        'circle': lambda: visual.Circle(win, radius=0.2, edges=32),
        'square': lambda: visual.Rect(win, width=0.4, height=0.4),
        'triangle': lambda: visual.ShapeStim(
            win,
            vertices=[[0, 0.3], [-0.26, -0.15], [0.26, -0.15]],  # 等边三角形
            closeShape=True
        )
    }

    # 颜色库 (RGB值)
    colors = [
        (1, -1, -1),  # 红
        (-1, 1, -1),  # 绿
        (-1, -1, 1),  # 蓝
        (1, 1, -1),  # 黄
        (1, -1, 1),  # 紫
        (-1, 1, 1),  # 青
        (1, 0.5, -1),  # 橙
    ]

    # 干扰参数
    flicker_freq = 10  # 闪烁频率(Hz)
    current_shape = None
    current_color = None

    # 计时器
    global_clock = core.Clock()
    flicker_clock = core.Clock()

    while global_clock.getTime() < duration:
        # 基础静息背景
        if images:
            current_img = int(global_clock.getTime()) % 2
            image_stims[current_img].draw()

        # 随机闪烁图形
        if flicker_clock.getTime() > 1 / flicker_freq:
            # 随机选择形状和颜色
            shape_type = random.choice(list(shapes.keys()))
            current_shape = shapes[shape_type]()  # 创建新形状实例
            current_color = random.choice(colors)

            # 设置属性
            current_shape.fillColor = current_color
            current_shape.pos = (random.uniform(-0.8, 0.8), random.uniform(-0.5, 0.5))
            current_shape.opacity = random.uniform(0.3, 1)  # 随机透明度

            flicker_clock.reset()

        # 绘制当前形状（如果存在）
        if current_shape:
            current_shape.draw()

        # 其他干扰保持不变（移动文字/声音等）
        moving_text.text = random.choice(["*", "#", "?", "!", "~"])
        moving_text.pos = (np.sin(global_clock.getTime()), np.cos(global_clock.getTime()) * 0.5)
        moving_text.draw()

        win.flip()

        if event.getKeys(keyList=['escape']):
            win.close()
            core.quit()


def arithmetic_phase(duration=60):
    # 创建紧凑的文本刺激（所有内容集中在视野中心区域）
    problem_text = visual.TextStim(win,
                                   text="",
                                   height=0.10,  # 题目字号
                                   color='white',
                                   pos=(0, 0.05))  # 题目稍微上移

    instruction_text = visual.TextStim(win,
                                       text="请心算以下题目",
                                       height=0.05,  # 说明文字字号
                                       color='white',
                                       pos=(0, -0.15))  # 说明文字稍微下移

    # 计时器
    start_time = time.time()
    problem_duration = 3  # 每3秒更换一题

    while time.time() - start_time < duration:
        # 生成两位数加法题目
        num1 = random.randint(10, 99)
        num2 = random.randint(10, 99)

        # 显示题目（紧凑布局）
        problem_text.text = f"{num1} + {num2} = ?"

        # 绘制所有元素
        problem_text.draw()
        instruction_text.draw()
        win.flip()

        # 等待题目持续时间或直到按下退出键
        timer = core.CountdownTimer(problem_duration)
        while timer.getTime() > 0:
            if event.getKeys(keyList=['escape']):
                win.close()
                core.quit()
            core.wait(0.1)  # 减少CPU占用

    # 显示结束信息
    end_text = visual.TextStim(win, text="心算任务结束", height=0.1, color='white')
    end_text.draw()
    win.flip()
    core.wait(2)


def resting_phase3(duration=60):
    # 加载静态背景图（自然场景）
    images = ["mountain.jpg"] if os.path.exists("mountain.jpg") else []
    if images:
        image_stims = [visual.ImageStim(win, image=img, size=3.0, opacity=0.7) for img in images]  # 进一步降低背景图透明度

    # 干扰元素参数调整
    max_opacity = 0.4  # 略微提高最大透明度到40%
    min_size = 0.15  # 增大最小尺寸
    max_size = 0.25  # 增大最大尺寸
    drift_speed = 0.8  # 提高漂移速度（°/秒）
    color_intensity = 0.1  # 颜色变化强度参数

    # 创建干扰元素（增加到2个）
    distractors = []
    # for _ in range(2):
    #     distractor = visual.ShapeStim(
    #         win,
    #         vertices='circle',
    #         size=random.uniform(min_size, max_size),
    #         fillColor=(0.95, 0.95, 0.95),  # 提高基础亮度
    #         opacity=random.uniform(0.2, max_opacity),  # 初始不透明
    #         pos=(random.uniform(-0.8, 0.8), random.uniform(-0.5, 0.5))
    #     )
    #     distractors.append(distractor)

    # 颜色库（略微提高饱和度）
    pastel_colors = [
        (0.95, 0.8, 0.8),  # 粉
        (0.8, 0.95, 0.8),  # 绿
        (0.8, 0.8, 0.95),  # 蓝
        (0.95, 0.95, 0.7),  # 黄
    ]

    # 状态变量
    drift_directions = [(random.uniform(-1, 1) * drift_speed,
                         random.uniform(-1, 1) * drift_speed)
                        for _ in range(2)]
    change_interval = random.uniform(2, 4)  # 缩短变化间隔到2-4秒
    last_change = 0

    # 主循环
    global_clock = core.Clock()
    while global_clock.getTime() < duration:
        # 绘制背景
        if images:
            current_img = int(global_clock.getTime() / 8) % len(images)  # 加快背景切换频率到8秒
            image_stims[current_img].draw()

        # 更新干扰元素参数（更频繁的变化）
        if global_clock.getTime() - last_change > change_interval:
            for i, distractor in enumerate(distractors):
                # 更明显的颜色变化
                base_color = list(random.choice(pastel_colors))
                distractor.fillColor = [min(c + random.uniform(-color_intensity, color_intensity), 1)
                                        for c in base_color]
                distractor.opacity = random.uniform(0.25, max_opacity)
                distractor.size = random.uniform(min_size, max_size)
                drift_directions[i] = (random.uniform(-1, 1) * drift_speed,
                                       random.uniform(-1, 1) * drift_speed)
            change_interval = random.uniform(2, 4)
            last_change = global_clock.getTime()

        # 更新并绘制干扰元素
        for i, distractor in enumerate(distractors):
            # 更活跃的运动轨迹
            new_x = distractor.pos[0] + drift_directions[i][0] * 0.016
            new_y = distractor.pos[1] + drift_directions[i][1] * 0.016

            # 边界反弹（增加运动变化）
            if abs(new_x) > 0.9:
                drift_directions[i] = (-drift_directions[i][0] * 1.2,
                                       drift_directions[i][1] * random.uniform(0.8, 1.2))
            if abs(new_y) > 0.7:
                drift_directions[i] = (drift_directions[i][0] * random.uniform(0.8, 1.2),
                                       -drift_directions[i][1] * 1.2)

            distractor.pos = (new_x, new_y)
            distractor.draw()

        # 增加文字干扰频率和可见性
        if random.random() < 0.03:  # 提高到3%概率出现
            symbols = ["✦", "•", "○", "⌂"]  # 使用更显眼的符号
            txt = visual.TextStim(win,
                                  text=random.choice(symbols),
                                  height=0.08,  # 增大尺寸
                                  color=(0.8, 0.8, 0.8),  # 提高对比度
                                  opacity=random.uniform(0.3, 0.6),
                                  pos=(random.uniform(-0.9, 0.9), random.uniform(-0.6, 0.6)))
            txt.draw()

        win.flip()

        if event.getKeys(keyList=['escape']):
            win.close()
            core.quit()

def resting_phase_corss(duration=60):
    # 创建绿色十字准心（固定注视点）
    fixation = visual.TextStim(
        win,
        text="+",          # 十字符号
        color=(0, 1, 0),   # 纯绿色 (RGB)
        height=0.15,       # 适当大小（可根据需要调整）
        pos=(0, 0)         # 屏幕正中央
    )

    # 主循环（仅显示十字）
    global_clock = core.Clock()
    while global_clock.getTime() < duration:
        fixation.draw()  # 绘制十字
        win.flip()       # 刷新屏幕

        # 允许按ESC键退出
        if event.getKeys(keyList=['escape']):
            win.close()
            core.quit()

# 休息阶段（不变）
def break_phase(duration=5):
    text = visual.TextStim(win, text="休息一下", height=0.1)
    text.draw()
    win.flip()
    core.wait(duration)


def attention_phase(duration=60):
    # 极限参数设置
    trial_duration = 0.5  # 500ms反应窗口
    target_prob = 0.3  # 目标概率
    blank_duration = 0.1  # 刺激间隔100ms

    # 精确计时器
    global_clock = core.Clock()
    rt_clock = core.Clock()

    colors = {
        'target': (0.9, -1, -1),  # 高饱和度红色（Target）
        'distractor1': (0.7, -0.8, -0.8),  # 低饱和度红
        'distractor2': (0.9, -0.5, -0.5),  # 粉红
        'distractor3': (0.9, -0.3, -1),  # 橙红
        'distractor_blue': (-1, -1, 0.7),  # 低饱和度蓝
        'distractor_green': (-1, 0.6, -1),  # 低饱和度绿
        'distractor_yellow': (0.8, 0.8, -1),  # 低饱和度黄
    }

    # 优化刺激呈现
    stim = visual.Circle(win, radius=0.15, edges=64)
    mask = visual.Rect(win, width=0.4, height=0.4, fillColor=(-0.8, -0.8, -0.8))  # 灰色掩蔽

    # 创建鼠标对象
    mouse = event.Mouse(win=win)

    # 性能计数器
    correct = 0
    false_alarms = 0
    misses = 0
    total_trials = 0

    # 主循环
    while global_clock.getTime() < duration:
        # 生成刺激
        is_target = random.random() < target_prob

        # 显示掩蔽（100ms）
        mask.draw()
        # fixation.draw()
        win.flip()
        core.wait(blank_duration)

        # 显示刺激
        if is_target:
            stim.fillColor = colors['target']
        else:
            stim.fillColor = random.choice(list(colors.values())[1:])

        stim.draw()
        # fixation.draw()
        win.flip()

        # 重置鼠标状态
        mouse.clickReset()

        # 反应检测（改为检测鼠标左键）
        response = False
        rt_clock.reset()
        while rt_clock.getTime() < trial_duration:
            if mouse.getPressed()[0]:  # 检测鼠标左键点击
                response = True
                rt = rt_clock.getTime() * 1000  # 毫秒
                break

        # 性能记录
        if is_target:
            if response:
                correct += 1
            else:
                misses += 1
        else:
            if response:
                false_alarms += 1

        total_trials += 1

        # 极短间隔（100ms）
        mask.draw()
        # fixation.draw()
        win.flip()
        core.wait(blank_duration)

    # 结果分析
    hit_rate = correct / (correct + misses) if (correct + misses) > 0 else 0
    false_alarm_rate = false_alarms / (total_trials - correct - misses) if (total_trials - correct - misses) > 0 else 0

    # 显示极简结果
    results = visual.TextStim(win,
                              text=f"命中率: {hit_rate * 100:.1f}%\n虚报率: {false_alarm_rate * 100:.1f}%",
                              color='white',
                              height=0.08
                              )
    results.draw()
    win.flip()
    core.wait(3)


def schulte_grid_phase(duration=60):
    # 创建鼠标对象
    mouse = event.Mouse(win=win)

    # 设置网格参数
    grid_size = 7
    cell_size = 0.12
    grid_width = grid_size * cell_size
    grid_height = grid_size * cell_size

    # 创建网格单元格
    cells = []
    for i in range(grid_size):
        row = []
        for j in range(grid_size):
            x = (j - grid_size // 2) * cell_size + cell_size / 2
            y = (grid_size // 2 - i) * cell_size - cell_size / 2
            rect = visual.Rect(
                win,
                width=cell_size * 0.9,
                height=cell_size * 0.9,
                pos=(x, y),
                fillColor=(-0.5, -0.5, -0.5),
                lineColor='white'
            )
            row.append(rect)
        cells.append(row)

    # 创建文本刺激
    numbers = list(range(1, grid_size * grid_size + 1))
    random.shuffle(numbers)
    number_texts = []
    for i in range(grid_size):
        row = []
        for j in range(grid_size):
            x = (j - grid_size // 2) * cell_size + cell_size / 2
            y = (grid_size // 2 - i) * cell_size - cell_size / 2
            text = visual.TextStim(
                win,
                text=str(numbers[i * grid_size + j]),
                pos=(x, y),
                height=cell_size * 0.5,
                color='white'
            )
            row.append(text)
        number_texts.append(row)

    # 游戏状态
    current_number = 1
    start_time = time.time()
    correct_clicks = 0
    total_clicks = 0

    # 计时器文本
    timer_text = visual.TextStim(win, text="", pos=(0, 0.8), height=0.06, color='white')

    # 主游戏循环
    while time.time() - start_time < duration:
        # 更新计时器
        remaining_time = max(0, duration - (time.time() - start_time))
        timer_text.text = f"剩余时间: {int(remaining_time)}秒 | 当前目标: {current_number}"

        # 绘制网格和数字
        for row in cells:
            for cell in row:
                cell.draw()
        for row in number_texts:
            for text in row:
                text.draw()
        timer_text.draw()
        win.flip()

        # 检查鼠标点击
        if mouse.getPressed()[0]:  # 左键点击
            total_clicks += 1
            mouse.clickReset()
            mouse_pos = mouse.getPos()

            # 检查点击了哪个单元格
            for i in range(grid_size):
                for j in range(grid_size):
                    cell = cells[i][j]
                    if (abs(mouse_pos[0] - cell.pos[0]) < cell_size / 2 and
                            abs(mouse_pos[1] - cell.pos[1]) < cell_size / 2):

                        # 检查点击的数字是否正确
                        if number_texts[i][j].text == str(current_number):
                            correct_clicks += 1
                            current_number += 1

                            # 如果完成所有数字，重新开始
                            if current_number > grid_size * grid_size:
                                current_number = 1
                                # 重新打乱数字
                                numbers = list(range(1, grid_size * grid_size + 1))
                                random.shuffle(numbers)
                                for i in range(grid_size):
                                    for j in range(grid_size):
                                        number_texts[i][j].text = str(numbers[i * grid_size + j])

                        break

        # 检查退出键
        if event.getKeys(keyList=['escape']):
            win.close()
            core.quit()

    # 显示结果
    accuracy = correct_clicks / total_clicks if total_clicks > 0 else 0
    results = visual.TextStim(
        win,
        text=f"舒尔特方格完成\n正确点击: {correct_clicks}\n总点击: {total_clicks}\n准确率: {accuracy * 100:.1f}%",
        color='white',
        height=0.08
    )
    results.draw()
    win.flip()
    core.wait(3)


# 主实验流程（添加舒尔特方格阶段）
def run_experiment():
    preparation_phase(10)
    resting_phase_corss(60)
    break_phase(10)
    arithmetic_phase(60)

    # print("舒尔特方格阶段开始")
    # schulte_grid_phase(60)

    text = visual.TextStim(win, text="实验结束，谢谢参与！", height=0.1)
    text.draw()
    win.flip()
    core.wait(3)
    win.close()


if __name__ == "__main__":
    run_experiment()