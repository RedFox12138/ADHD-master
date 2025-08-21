import numpy as np
from psychopy import visual, core, event
import random
import time

# 1. 初始化设置 (浓缩后保留)
# ==============================================================================
# 创建一个全屏窗口，深灰色背景
win = visual.Window(fullscr=True, color=(-0.8, -0.8, -0.8), screen=0, waitBlanking=True, units='norm')

# 2. 实验阶段函数 (只保留需要的，并新增第三阶段)
# ==============================================================================

def preparation_phase(duration=5):
    """准备阶段：显示提示文字"""
    text = visual.TextStim(win, text="准备开始实验\n请保持放松", height=0.1)
    text.draw()
    win.flip()
    core.wait(duration)

def resting_phase1(duration=60):
    """静息阶段1：风景画轮播"""
    try:
        images = ["mountain.jpg", "clouds.jpg", "forest.jpg"]
        image_stims = [visual.ImageStim(win, image=img, size=(2, 2)) for img in images] # size=(2,2) 适应 norm单位
    except Exception as e:
        print(f"警告：无法加载图片，将显示空白背景。错误：{e}")
        image_stims = [] # 如果图片不存在，则列表为空

    main_clock = core.Clock()
    image_switch_timer = core.Clock()
    current_img_index = 0
    IMAGE_INTERVAL = 10

    while main_clock.getTime() < duration:
        if image_stims: # 仅在图片加载成功时绘制
            image_stims[current_img_index].draw()
        win.flip()

        if event.getKeys(keyList=['escape']):
            win.close()
            core.quit()

        if image_switch_timer.getTime() > IMAGE_INTERVAL:
            if image_stims:
                current_img_index = (current_img_index + 1) % len(image_stims)
            image_switch_timer.reset()

def break_phase(duration=10):
    """休息阶段：为下一节做准备"""
    text = visual.TextStim(win, text="休息一下\n即将开始心算任务", height=0.1)
    text.draw()
    win.flip()
    core.wait(duration)

def arithmetic_phase(duration=60):
    """心算任务阶段"""
    problem_text = visual.TextStim(win, text="", height=0.15, pos=(0, 0.1))
    instruction_text = visual.TextStim(win, text="请心算以下题目", height=0.08, pos=(0, -0.2))
    main_clock = core.Clock()
    problem_timer = core.Clock()
    PROBLEM_INTERVAL = 5 # 每5秒换一题

    while main_clock.getTime() < duration:
        # 每隔5秒生成新题目
        if problem_timer.getTime() > PROBLEM_INTERVAL or main_clock.getTime() < 0.1:
            num1 = random.randint(100, 999)
            num2 = random.randint(100, 999)
            problem_text.text = f"{num1} + {num2} = ?"
            problem_timer.reset()

        problem_text.draw()
        instruction_text.draw()
        win.flip()

        if event.getKeys(keyList=['escape']):
            win.close()
            core.quit()
        core.wait(0.01) # 稍微等待，防止CPU过载


def generate_figure8_track(num_points=100, scale_x=0.9, scale_y=0.7, frequency_x=1, frequency_y=2,
                           phase_shift=np.pi / 2):
    waypoints = [];
    t = np.linspace(0, 2 * np.pi, num_points)
    x = scale_x * np.sin(frequency_x * t + phase_shift) + np.random.normal(0, 0.05, num_points)
    y = scale_y * np.sin(frequency_y * t) + np.random.normal(0, 0.05, num_points)
    for i in range(num_points): waypoints.append((x[i], y[i]))
    waypoints.append(waypoints[0]);
    return waypoints


def attention_racetrack_phase(duration=60):
    """【形状追踪版】使用8字形交叉赛道进行注意力追踪"""
    # --- 1. 提示用户（已更新为形状） ---
    shapes_text = "圆形, 方形, 三角形, 星形, 菱形, 十字形"
    instruction = visual.TextStim(win,
                                  text=f"赛车将以不同形状出现：\n{shapes_text}\n\n请选择一个【形状】并持续追踪它！",
                                  height=0.08)
    instruction.draw();
    win.flip();
    core.wait(8)

    # --- 2. 生成赛道 ---
    waypoints = generate_figure8_track(num_points=200, scale_x=0.9, scale_y=0.9, frequency_x=2, frequency_y=3)
    track = visual.ShapeStim(win, vertices=waypoints, closeShape=False, lineWidth=8, lineColor='gray', opacity=0.8)

    # --- 3. 初始化赛车 (核心修改处) ---
    NUM_RACERS = 5
    RACER_SIZE = 0.1  # 稍微增大尺寸以便看清形状
    BASE_SPEED = 0.8

    # 定义形状列表和统一的颜色
    SHAPES = ['circle', 'square', 'triangle', 'diamond', 'cross']
    RACER_COLOR = 'white'

    racers = []  # 现在将存储不同类型的形状对象
    racer_speeds, racer_target_waypoints = [], []
    racer_states, racer_state_timers = [], []

    for i in range(NUM_RACERS):
        shape_type = SHAPES[i]
        racer = None  # 先声明

        # 根据形状类型创建不同的PsychoPy对象
        if shape_type == 'circle':
            racer = visual.Circle(win, radius=RACER_SIZE / 2, fillColor=RACER_COLOR)
        elif shape_type == 'square':
            racer = visual.Rect(win, width=RACER_SIZE, height=RACER_SIZE, fillColor=RACER_COLOR)
        elif shape_type == 'triangle':
            racer = visual.Polygon(win, edges=3, radius=RACER_SIZE / 2, fillColor=RACER_COLOR)
        elif shape_type == 'star':
            racer = visual.Star(win, numVertices=5, innerRadius=RACER_SIZE / 4, outerRadius=RACER_SIZE / 2,
                                fillColor=RACER_COLOR)
        elif shape_type == 'diamond':
            racer = visual.Rect(win, width=RACER_SIZE, height=RACER_SIZE, ori=45, fillColor=RACER_COLOR)
        elif shape_type == 'cross':
            # 使用ShapeStim自定义十字形
            cross_vertices = [(-0.02, -RACER_SIZE / 2), (0.02, -RACER_SIZE / 2), (0.02, -0.02), (RACER_SIZE / 2, -0.02),
                              (RACER_SIZE / 2, 0.02), (0.02, 0.02), (0.02, RACER_SIZE / 2), (-0.02, RACER_SIZE / 2),
                              (-0.02, 0.02), (-RACER_SIZE / 2, 0.02), (-RACER_SIZE / 2, -0.02), (-0.02, -0.02)]
            racer = visual.ShapeStim(win, vertices=cross_vertices, fillColor=RACER_COLOR, lineColor=RACER_COLOR)

        # 设置通用属性并添加到列表
        racer.pos = (waypoints[0][0] + random.uniform(-0.05, 0.05), waypoints[0][1] + random.uniform(-0.05, 0.05))
        racers.append(racer)

        # 初始化速度和状态（与之前逻辑相同）
        racer_speeds.append(random.uniform(BASE_SPEED * 0.95, BASE_SPEED * 1.05))
        racer_target_waypoints.append(1)
        racer_states.append('normal')
        racer_state_timers.append(random.uniform(2, 5))

    # --- 4. 动画主循环 (无需改动) ---
    # 动画逻辑本身不关心刺激是什么形状，只关心它的 .pos 属性，所以这部分完全兼容
    main_clock = core.Clock();
    dt_clock = core.Clock()
    SPEED_MULTIPLIERS = {'boost': 1.5, 'normal': 1.0, 'lag': 0.6}
    STATE_CHANGE_INTERVAL = (2, 5);
    BOOST_CHANCE = 0.25;
    LAG_CHANCE = 0.15
    while main_clock.getTime() < duration:
        if event.getKeys(keyList=['escape']): win.close(); core.quit()
        dt = dt_clock.getTime();
        dt_clock.reset()
        if dt == 0: continue
        track.draw()
        for i in range(NUM_RACERS):
            # 状态更新
            racer_state_timers[i] -= dt
            if racer_state_timers[i] <= 0:
                rand_num = random.random()
                if rand_num < BOOST_CHANCE:
                    racer_states[i] = 'boost'
                elif rand_num < BOOST_CHANCE + LAG_CHANCE:
                    racer_states[i] = 'lag'
                else:
                    racer_states[i] = 'normal'
                racer_state_timers[i] = random.uniform(*STATE_CHANGE_INTERVAL)
            # 路径追踪与移动
            target_waypoint_index = racer_target_waypoints[i];
            target_pos = waypoints[target_waypoint_index]
            distance_to_target = np.linalg.norm(np.array(racers[i].pos) - np.array(target_pos))
            if distance_to_target < 0.1:
                racer_target_waypoints[i] = (target_waypoint_index + 1) % (len(waypoints) - 1);
                target_pos = waypoints[racer_target_waypoints[i]]
            direction = np.array(target_pos) - np.array(racers[i].pos);
            norm_direction = direction / np.linalg.norm(direction)
            perp_direction = np.array([-norm_direction[1], norm_direction[0]]);
            wobble = np.sin(main_clock.getTime() * 5 + i * np.pi) * 0.2
            final_direction = norm_direction + perp_direction * wobble
            state_multiplier = SPEED_MULTIPLIERS[racer_states[i]];
            current_speed = racer_speeds[i] * state_multiplier
            racers[i].pos += final_direction * current_speed * dt
            racers[i].draw()
        win.flip()

def third_phase(duration=10):
    text = visual.TextStim(win, text="休息一下，即将开始注意力追踪实验", height=0.1)
    text.draw()
    win.flip()
    core.wait(duration)

# 3. 主实验流程 (更新后)
# ==============================================================================
def run_experiment():
    """定义整个实验的执行顺序"""
    # 第1阶段：静息
    preparation_phase(10)
    resting_phase1(60)

    # 第2阶段：心算
    break_phase(10)
    arithmetic_phase(60)


    attention_racetrack_phase(60) # 调用新的注意力追踪阶段

    # 实验结束
    text = visual.TextStim(win, text="实验结束，谢谢参与！", height=0.1)
    text.draw()
    win.flip()
    core.wait(3)
    win.close()
    core.quit()

# 4. 运行实验
# ==============================================================================
if __name__ == "__main__":
    run_experiment()