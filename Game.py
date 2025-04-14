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
def resting_phase(duration=60):
    images = ["lake.jpg", "clouds.jpg"]
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
    print("准备阶段开始")
    preparation_phase(10)

    print("静息阶段开始")
    resting_phase(60)

    print("休息阶段开始")
    break_phase(10)

    print("注意力阶段开始")
    attention_phase(60)

    print("休息阶段开始")
    break_phase(10)

    print("舒尔特方格阶段开始")
    schulte_grid_phase(60)

    text = visual.TextStim(win, text="实验结束，谢谢参与！", height=0.1)
    text.draw()
    win.flip()
    core.wait(3)
    win.close()


if __name__ == "__main__":
    run_experiment()