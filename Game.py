import math

import numpy as np
from psychopy import visual, core, event
import random
import time
import sys
import pygame

# --- 新增: 窗口保证函数，确保 win 可用 ---
try:
    win
except NameError:
    win = None

def ensure_window():
    global win
    try:
        if win is None or getattr(win, 'winHandle', None) is None:
            win = visual.Window(fullscr=True, color=(-0.8, -0.8, -0.8), screen=0, waitBlanking=True, units='norm')
    except Exception as e:
        print(f"创建/恢复 PsychoPy 窗口失败: {e}")
        raise

# 1. 初始化设置 (浓缩后保留)
# ==============================================================================
# 创建一个全屏窗口，深灰色背景
ensure_window()

# --- 1. 参数设置 (方便在此处统一修改) ---
DURATION = 60  # 任务持续时间 (秒)
NUM_RACERS = 5  # "赛车"(形状)的数量
RACER_SIZE = 0.1  # 形状的尺寸 (单位: norm)
BASE_SPEED = 0.3  # 形状的基础移动速度 (单位: norm/秒)
BOUNDING_RADIUS = 0.5  # 运动区域的半径 (0.5 表示占屏幕高度的一半)
SHOW_BOUNDARY = True  # 是否显示运动区域的边界 (实验时建议设为False)

# 形状列表和颜色
SHAPES = ['圆形', '矩形', '三角形', '菱形', '十字形']
RACER_COLOR = 'white'

def create_shape(win, shape_type, size, color):
    """
    根据给定的类型创建并返回一个PsychoPy形状对象。
    """
    racer = None
    if shape_type == '圆形':
        racer = visual.Circle(win, radius=size / 2, fillColor=color, lineColor=color)
    elif shape_type == '矩形':
        racer = visual.Rect(win, width=size, height=size, fillColor=color, lineColor=color)
    elif shape_type == '三角形':
        # PsychoPy的Polygon默认是等边的
        racer = visual.Polygon(win, edges=3, radius=size / 2, fillColor=color, lineColor=color)
    elif shape_type == '菱形':
        racer = visual.Rect(win, width=size, height=size, ori=45, fillColor=color, lineColor=color)
    elif shape_type == '十字形':
        # 使用ShapeStim自定义十字形, 顶点坐标相对于中心
        cross_vertices = [
            (-size / 10, -size / 2), (size / 10, -size / 2), (size / 10, -size / 10), (size / 2, -size / 10),
            (size / 2, size / 10), (size / 10, size / 10), (size / 10, size / 2), (-size / 10, size / 2),
            (-size / 10, size / 10), (-size / 2, size / 10), (-size / 2, -size / 10), (-size / 10, -size / 10)
        ]
        racer = visual.ShapeStim(win, vertices=cross_vertices, fillColor=color, lineColor=color)
    return racer


def attention_cloud_phase(win, duration):
    """
    【粒子云版】在中央圆形区域内进行注意力追踪，旨在减少眼动。
    """
    # --- 2. 提示用户 ---
    shapes_text = ", ".join(SHAPES)
    instruction = visual.TextStim(
        win,
        text=f"所有形状将在屏幕中央移动。\n\n可选形状: {shapes_text}\n\n请选择一个【形状】并持续用注意力追踪它！",
        height=0.05,
        wrapWidth=1.5,
        pos=(0, 0.7)  # <-- 【关键修改】在这里设置文本的位置，(0, 0.4) 表示水平居中、垂直靠上
    )

    # --- 3. 初始化刺激物 ---
    bounding_circle = visual.Circle(
        win,
        radius=BOUNDING_RADIUS,
        edges=128,
        lineColor='gray',
        lineWidth=1,
        opacity=0.5
    )

    racers = []
    racer_velocities = []

    for i in range(NUM_RACERS):
        shape_type = SHAPES[i % len(SHAPES)]
        racer = create_shape(win, shape_type, RACER_SIZE, RACER_COLOR)

        angle = random.uniform(0, 2 * np.pi)
        radius = random.uniform(0, BOUNDING_RADIUS - 0.01)
        racer.pos = (np.cos(angle) * radius, np.sin(angle) * radius)

        speed_angle = random.uniform(0, 2 * np.pi)
        speed = random.uniform(BASE_SPEED * 0.8, BASE_SPEED * 1.2)
        velocity_vector = np.array([np.cos(speed_angle), np.sin(speed_angle)]) * speed
        racer_velocities.append(velocity_vector)
        racers.append(racer)

    # --- 准备阶段循环 (10秒) ---
    prep_clock = core.Clock()
    while prep_clock.getTime() < 10:
        if event.getKeys(keyList=['escape', 'q']):
            win.close()
            core.quit()

        instruction.draw()
        if SHOW_BOUNDARY:
            bounding_circle.draw()
        for racer in racers:
            racer.draw()
        win.flip()

    # --- 4. 动画主循环 ---
    main_clock = core.Clock()
    dt_clock = core.Clock()

    while main_clock.getTime() < duration:
        if event.getKeys(keyList=['escape', 'q']):
            win.close()
            core.quit()

        dt = dt_clock.getTime()
        dt_clock.reset()
        if dt == 0:
            continue

        if SHOW_BOUNDARY:
            bounding_circle.draw()

        for i in range(NUM_RACERS):
            racers[i].pos += racer_velocities[i] * dt
            pos_vec = racers[i].pos
            dist_from_center = np.linalg.norm(pos_vec)

            if dist_from_center > BOUNDING_RADIUS:
                racers[i].pos = (pos_vec / dist_from_center) * BOUNDING_RADIUS
                normal_vec = pos_vec / dist_from_center
                velocity_vec = racer_velocities[i]
                racer_velocities[i] = velocity_vec - 2 * np.dot(velocity_vec, normal_vec) * normal_vec

            racers[i].draw()

        win.flip()

    # --- 5. 任务结束 ---
    end_text = visual.TextStim(win, text="任务结束，谢谢！", height=0.1)
    end_text.draw()
    win.flip()
    core.wait(3)


def resting_phase2(duration=60):
    """静息阶段1：显示绿色十字标志"""
    # 创建顶部提示文字
    tip_text = visual.TextStim(win, text="请尽可能少眨眼！", height=0.07, pos=(0, 0.85))
    # 创建绿色十字标志
    cross_color = (0, 1, 0)  # 绿色 (RGB值，范围0-1)
    line_width = 1  # 十字线条宽度
    line_length = 0.2  # 十字线条长度

    # 创建两条线组成十字
    horizontal_line = visual.Line(
        win=win,
        start=(-line_length / 2, 0),
        end=(line_length / 2, 0),
        lineWidth=line_width,
        lineColor=cross_color
    )

    vertical_line = visual.Line(
        win=win,
        start=(0, -line_length / 2),
        end=(0, line_length / 2),
        lineWidth=line_width,
        lineColor=cross_color
    )

    main_clock = core.Clock()

    while main_clock.getTime() < duration:
        # 绘制顶部提示文字
        tip_text.draw()
        # 绘制十字标志
        horizontal_line.draw()
        vertical_line.draw()
        win.flip()

        if event.getKeys(keyList=['escape']):
            win.close()
            core.quit()

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
    shapes_text = "圆形, 方形, 三角形, 菱形, 十字形"
    instruction = visual.TextStim(win,
                                  text=f"赛车将以不同形状出现：\n{shapes_text}\n\n请选择一个【形状】并持续追踪它！",
                                  height=0.08)
    instruction.draw();
    win.flip();
    core.wait(10)

    # --- 2. 生成赛道 (缩小赛道尺寸) ---
    waypoints = generate_figure8_track(num_points=200, scale_x=0.5, scale_y=0.4, frequency_x=2, frequency_y=3)  # 从0.9缩小到0.5和0.4
    track = visual.ShapeStim(win, vertices=waypoints, closeShape=False, lineWidth=6, lineColor='gray', opacity=0.8)  # 线条也稍微细一点

    # --- 3. 初始化赛车 (核心修改处) ---
    NUM_RACERS = 5
    RACER_SIZE = 0.08  # 稍微减小尺寸，从0.1改为0.08
    BASE_SPEED = 0.4   # 大幅降低速度，从0.8改为0.4

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
            # 使用ShapeStim自定义十字形 (调整尺寸)
            cross_vertices = [(-0.015, -RACER_SIZE / 2), (0.015, -RACER_SIZE / 2), (0.015, -0.015), (RACER_SIZE / 2, -0.015),
                              (RACER_SIZE / 2, 0.015), (0.015, 0.015), (0.015, RACER_SIZE / 2), (-0.015, RACER_SIZE / 2),
                              (-0.015, 0.015), (-RACER_SIZE / 2, 0.015), (-RACER_SIZE / 2, -0.015), (-0.015, -0.015)]
            racer = visual.ShapeStim(win, vertices=cross_vertices, fillColor=RACER_COLOR, lineColor=RACER_COLOR)

        # 设置通用属性并添加到列表
        racer.pos = (waypoints[0][0] + random.uniform(-0.03, 0.03), waypoints[0][1] + random.uniform(-0.03, 0.03))  # 减小初始位置偏移
        racers.append(racer)

        # 初始化速度和状态（降低速度变化范围）
        racer_speeds.append(random.uniform(BASE_SPEED * 0.9, BASE_SPEED * 1.1))  # 从0.95-1.05改为0.9-1.1，但基础速度更低
        racer_target_waypoints.append(1)
        racer_states.append('normal')
        racer_state_timers.append(random.uniform(3, 6))  # 增加状态变化间隔，从2-5改为3-6

    # --- 4. 动画主循环 (调整速度倍数) ---
    # 动画逻辑本身不关心刺激是什么形状，只关心它的 .pos 属性，所以这部分完全兼容
    main_clock = core.Clock();
    dt_clock = core.Clock()
    SPEED_MULTIPLIERS = {'boost': 1.3, 'normal': 1.0, 'lag': 0.7}  # 降低boost倍数，从1.5改为1.3
    STATE_CHANGE_INTERVAL = (3, 6);  # 增加状态变化间隔
    BOOST_CHANCE = 0.2;  # 降低boost概率，从0.25改为0.2
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
            if distance_to_target < 0.08:  # 减小到达判定距离，从0.1改为0.08
                racer_target_waypoints[i] = (target_waypoint_index + 1) % (len(waypoints) - 1);
                target_pos = waypoints[racer_target_waypoints[i]]
            direction = np.array(target_pos) - np.array(racers[i].pos);
            norm_direction = direction / np.linalg.norm(direction)
            perp_direction = np.array([-norm_direction[1], norm_direction[0]]);
            wobble = np.sin(main_clock.getTime() * 3 + i * np.pi) * 0.15  # 降低摆动幅度和频率，从5改为3，0.2改为0.15
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


def attention_oddball_phase(duration=60):
    """【奇球范式版】中央呈现形状序列，检测目标，无眼动"""
    # --- 1. 设置与提示 ---
    instruction = visual.TextStim(win,
                                  text="一个形状会快速在中央闪烁。\n当【方形】出现时，请尽快按下空格键！\n其他形状出现时请不要按键。",
                                  height=0.08)
    instruction.draw()
    win.flip()
    core.wait(10)

    # 十字注视点
    fixation = visual.TextStim(win, text='+', height=0.1)

    # --- 2. 刺激物和试验序列设置 ---
    TARGET_SHAPE = 'square'  # 目标
    STANDARD_SHAPE = 'circle'  # 标准
    TARGET_PROB = 0.2  # 目标出现概率

    # 创建刺激物
    target_stim = visual.Rect(win, width=0.2, height=0.2, fillColor='white')
    standard_stim = visual.Circle(win, radius=0.1, fillColor='white')

    # 生成一个试验序列
    num_trials = int(duration / 0.7)  # 假设每个trial持续700ms (500ms呈现+200ms空屏)
    trial_list = [TARGET_SHAPE if random.random() < TARGET_PROB else STANDARD_SHAPE for _ in range(num_trials)]

    # --- 3. 实验主循环 ---
    for trial_shape in trial_list:
        # a. 呈现注视点 (空屏期)
        fixation.draw()
        win.flip()
        core.wait(0.2)  # 200ms

        # b. 呈现刺激物
        if trial_shape == TARGET_SHAPE:
            stim_to_draw = target_stim
        else:
            stim_to_draw = standard_stim

        stim_to_draw.draw()
        win.flip()
        core.wait(0.5)  # 500ms

        # c. 检查按键反应 (可以在呈现期间或之后检查)
        keys = event.getKeys(keyList=['space', 'escape'])
        if 'escape' in keys:
            win.close();
            core.quit()
        # (此处可以添加记录反应时间和正确率的逻辑)

    # --- 4. 结束提示 ---
    end_text = visual.TextStim(win, text="任务结束，谢谢！", height=0.1)
    end_text.draw();
    win.flip();
    core.wait(3)


def run_dodge_game_phase(duration=60):
    """
    使用 Pygame 实现的“飞机躲子弹”游戏阶段。
    - 全屏黑色背景
    - 中央 GAME_WIDTH x GAME_HEIGHT 的游戏区域
    - 鼠标左/右键或键盘 ←/→ / A/D 控制左右移动
    - ESC 退出
    """
    print("正在启动 Pygame 游戏阶段 (鼠标+键盘控制)...")

    pygame.init()

    # 屏幕尺寸与游戏区域
    screen_info = pygame.display.Info()
    FULL_W, FULL_H = screen_info.current_w, screen_info.current_h
    GAME_W, GAME_H = 500, 400
    OFF_X = (FULL_W - GAME_W) // 2  - 300
    OFF_Y = (FULL_H - GAME_H) // 2 -100

    # 全屏窗口
    screen = pygame.display.set_mode((FULL_W, FULL_H), pygame.FULLSCREEN)
    pygame.display.set_caption("飞机躲子弹 (Pygame)")
    clock = pygame.time.Clock()

    # 强制置前（Windows）
    if sys.platform == 'win32':
        try:
            import ctypes
            user32 = ctypes.windll.user32
            hwnd = pygame.display.get_wm_info()['window']
            SW_RESTORE = 9
            user32.ShowWindow(hwnd, SW_RESTORE)
            HWND_TOPMOST, HWND_NOTOPMOST = -1, -2
            SWP_NOMOVE, SWP_NOSIZE = 0x0002, 0x0001
            user32.SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE)
            user32.SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE)
            user32.SetForegroundWindow(hwnd)
        except Exception as e:
            print(f"置顶失败: {e}")

    # 颜色
    BLACK = (0, 0, 0)
    WHITE = (255, 255, 255)
    RED = (255, 0, 0)
    BLUE = (100, 149, 237)
    GREEN = (0, 255, 0)

    # 游戏区域画布
    game_surface = pygame.Surface((GAME_W, GAME_H))

    # 玩家
    class Player(pygame.sprite.Sprite):
        def __init__(self):
            super().__init__()
            self.image = pygame.Surface((28, 20))
            self.image.fill(BLUE)
            self.rect = self.image.get_rect()
            self.rect.centerx = GAME_W // 2
            self.rect.bottom = GAME_H - 20
            self.speed = 8
            self.hp = 50
            self.invincible = False
            self.inv_start = 0
            self.inv_ms = 1000

        def update(self):
            # 解除无敌
            if self.invincible and pygame.time.get_ticks() - self.inv_start > self.inv_ms:
                self.invincible = False
                self.image.set_alpha(255)

            # 输入
            mouse_buttons = pygame.mouse.get_pressed()
            keys = pygame.key.get_pressed()
            move = 0
            if mouse_buttons[0] or keys[pygame.K_LEFT] or keys[pygame.K_a]:
                move -= 1
            if mouse_buttons[2] or keys[pygame.K_RIGHT] or keys[pygame.K_d]:
                move += 1
            self.rect.x += move * self.speed

            # 边界
            if self.rect.left < 0:
                self.rect.left = 0
            if self.rect.right > GAME_W:
                self.rect.right = GAME_W

        def get_hit(self):
            if not self.invincible:
                self.hp -= 1
                self.invincible = True
                self.inv_start = pygame.time.get_ticks()
                self.image.set_alpha(128)

    # 子弹
    class Bullet(pygame.sprite.Sprite):
        def __init__(self):
            super().__init__()
            self.image = pygame.Surface((3, 12))
            self.image.fill(RED)
            self.rect = self.image.get_rect()
            self.rect.x = random.randrange(GAME_W)
            self.rect.y = random.randrange(-60, -self.rect.height)
            self.vy = random.uniform(2.0, 5.0)
        def update(self):
            self.rect.y += self.vy
            if self.rect.top > GAME_H:
                self.kill()

    # 组
    all_sprites = pygame.sprite.Group()
    bullets = pygame.sprite.Group()
    player = Player()
    all_sprites.add(player)

    ADD_WAVE = pygame.USEREVENT + 1
    pygame.time.set_timer(ADD_WAVE, 400)

    font = pygame.font.Font(None, 28)

    # 初始说明
    instruction_surface = pygame.Surface((GAME_W, GAME_H))
    instruction_surface.fill(BLACK)
    f24 = pygame.font.Font(None, 24)
    t1 = f24.render("鼠标左键/←/A: 向左", True, WHITE)
    t2 = f24.render("鼠标右键/→/D: 向右", True, WHITE)
    t3 = f24.render("ESC: 退出", True, WHITE)
    instruction_surface.blit(t1, (GAME_W//2 - t1.get_width()//2, GAME_H//2 - 40))
    instruction_surface.blit(t2, (GAME_W//2 - t2.get_width()//2, GAME_H//2 - 10))
    instruction_surface.blit(t3, (GAME_W//2 - t3.get_width()//2, GAME_H//2 + 20))

    screen.fill(BLACK)
    screen.blit(instruction_surface, (OFF_X, OFF_Y))
    pygame.display.flip()
    pygame.time.wait(2000)

    start_ms = pygame.time.get_ticks()
    running = True
    game_over = False
    player_won = False

    while running:
        clock.tick(60)
        for e in pygame.event.get():
            if e.type == pygame.QUIT:
                running = False
            elif e.type == pygame.KEYDOWN and e.key == pygame.K_ESCAPE:
                running = False
            elif e.type == ADD_WAVE and not game_over:
                n = random.randint(3, 6)
                for _ in range(n):
                    b = Bullet()
                    all_sprites.add(b)
                    bullets.add(b)

        if not game_over:
            all_sprites.update()
            # 碰撞
            for _ in pygame.sprite.spritecollide(player, bullets, True):
                player.get_hit()
                if player.hp <= 0:
                    game_over = True
                    break

            # 时间判定
            elapsed = (pygame.time.get_ticks() - start_ms) / 1000.0
            if elapsed >= duration:
                game_over = True
                player_won = True

        # 画面
        screen.fill(BLACK)
        game_surface.fill(BLACK)

        all_sprites.draw(game_surface)

        # UI
        remain = 0 if game_over else max(0, int(duration - elapsed))
        game_surface.blit(font.render(f"Time: {remain}", True, WHITE), (8, 8))
        game_surface.blit(font.render(f"HP: {player.hp}", True, GREEN), (8, 35))

        if game_over:
            msg = "You Win!" if player_won else "Game Over"
            color = GREEN if player_won else (255, 80, 80)
            end_text = font.render(msg, True, color)
            rect = end_text.get_rect(center=(GAME_W//2, GAME_H//2))
            game_surface.blit(end_text, rect)

        # 边框 & 合成
        pygame.draw.rect(screen, WHITE, (OFF_X-3, OFF_Y-3, GAME_W+6, GAME_H+6), 3)
        screen.blit(game_surface, (OFF_X, OFF_Y))
        pygame.display.flip()

        if game_over:
            pygame.time.wait(2000)
            running = False

    pygame.quit()
    print("Pygame 游戏阶段结束。")


# 3. 主实验流程 (更新后)
# ==============================================================================
def run_experiment():

    """定义整个实验的执行顺序"""
    ensure_window()

    # 第1阶段：静息/准备
    preparation_phase(10)
    resting_phase2(60)

    transition_text = visual.TextStim(win, text="下一个任务：躲避游戏\n\n请用鼠标或方向键左右移动", height=0.1)
    transition_text.draw()
    win.flip()
    core.wait(10)

    # arithmetic_phase(60)

    # 关闭 PsychoPy 窗口，释放显示控制权
    win.close()

    # 运行 Pygame 游戏
    run_dodge_game_phase(duration=60)

    # 重新创建窗口并结束提示
    # final_win = visual.Window(fullscr=True, color=(-0.8, -0.8, -0.8), screen=0, units='norm')
    # end_text = visual.TextStim(final_win, text="实验结束，谢谢参与！", height=0.1)
    # end_text.draw()
    # final_win.flip()
    # core.wait(3)

    # final_win.close()
    core.quit()


if __name__ == "__main__":
    run_experiment()
