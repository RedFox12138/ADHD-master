import math

import numpy as np
from psychopy import visual, core, event
import random
import time
import pygame
import sys

# 1. 初始化设置 (浓缩后保留)
# ==============================================================================
# 创建一个全屏窗口，深灰色背景
win = visual.Window(fullscr=True, color=(-0.8, -0.8, -0.8), screen=0, waitBlanking=True, units='norm')

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


# 2. 实验阶段函数 (只保留需要的，并新增第三阶段)
# ==============================================================================
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


# ==============================================================================
# SECTION 2: PYGAME 游戏阶段函数 (已更新HP系统)
# ==============================================================================
# ==============================================================================
# SECTION 2: PYGAME 游戏阶段函数 (固定窗口 + 高难度版)
# ==============================================================================
# ==============================================================================
# SECTION 2: PYGAME 游戏阶段函数 (横向移动 "弹幕雨" 版)
# ==============================================================================
def run_dodge_game_phase(duration=60):
    """
    运行“飞机躲子弹”游戏阶段。
    此版本为横向移动的 "垂直弹幕雨" 玩法。
    """
    print("正在启动 Pygame 游戏阶段 (横向移动模式)...")

    pygame.init()

    # --- 窗口设置 ---
    SCREEN_WIDTH = 1200
    SCREEN_HEIGHT = 800
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))

    # --- 难度与玩法设置 (为新模式调整) ---
    PLAYER_HP = 50  # 初始HP
    WAVE_SPAWN_RATE = 300  # 每隔多少毫秒生成一波子弹 (数值越小越难)
    BULLETS_PER_WAVE_MIN = 5  # 每波最少生成几颗子弹
    BULLETS_PER_WAVE_MAX = 10  # 每波最多生成几颗子弹
    BULLET_MIN_SPEED = 4  # 子弹最慢下落速度
    BULLET_MAX_SPEED = 8  # 子弹最快下落速度

    pygame.display.set_caption("飞机躲子弹 (横向移动)")
    clock = pygame.time.Clock()
    font = pygame.font.Font(None, 50)

    # --- 颜色定义 ---
    BLACK = (0, 0, 0)
    WHITE = (255, 255, 255)
    RED = (255, 0, 0)
    BLUE = (100, 149, 237)
    GREEN = (0, 255, 0)

    # --- 玩家 (飞机) 类 ---
    class Player(pygame.sprite.Sprite):
        def __init__(self):
            super().__init__()
            self.image = pygame.Surface([40, 30])  # 飞机可以改成横向的，更直观
            self.image.fill(BLUE)
            self.rect = self.image.get_rect()
            self.rect.centerx = SCREEN_WIDTH // 2
            self.rect.bottom = SCREEN_HEIGHT - 30  # 固定在底部
            self.speed = 8  # 提高横向移速
            self.hp = PLAYER_HP
            self.invincible = False
            self.invincible_timer = 0
            self.invincible_duration = 1000

        def update(self):
            if self.invincible and pygame.time.get_ticks() - self.invincible_timer > self.invincible_duration:
                self.invincible = False
                self.image.set_alpha(255)

            # --- 核心修改: 只响应左右移动 ---
            keys = pygame.key.get_pressed()
            if keys[pygame.K_LEFT]:
                self.rect.x -= self.speed
            if keys[pygame.K_RIGHT]:
                self.rect.x += self.speed
            # (上下移动的逻辑已被移除)

            # 限制飞机在屏幕左右边界内
            if self.rect.left < 0:
                self.rect.left = 0
            if self.rect.right > SCREEN_WIDTH:
                self.rect.right = SCREEN_WIDTH

        def get_hit(self):
            if not self.invincible:
                self.hp -= 1
                self.invincible = True
                self.invincible_timer = pygame.time.get_ticks()
                self.image.set_alpha(128)

    # --- 子弹类 ---
    class Bullet(pygame.sprite.Sprite):
        def __init__(self):
            super().__init__()
            self.image = pygame.Surface([5, 20])  # 子弹可以做成细长条，更像雨滴
            self.image.fill(RED)
            self.rect = self.image.get_rect()

            # --- 核心修改: 子弹只在顶部生成，并垂直下落 ---
            # 随机在屏幕顶部生成
            self.rect.x = random.randrange(SCREEN_WIDTH)
            self.rect.y = random.randrange(-100, -self.rect.height)  # 在屏幕外一点生成，避免突然出现

            # 速度只有垂直分量
            self.vel_x = 0
            self.vel_y = random.uniform(BULLET_MIN_SPEED, BULLET_MAX_SPEED)

        def update(self):
            self.rect.y += self.vel_y
            # 如果子弹落出屏幕底部，就销毁它
            if self.rect.top > SCREEN_HEIGHT:
                self.kill()

    # --- 游戏循环准备 ---
    all_sprites = pygame.sprite.Group()
    bullets = pygame.sprite.Group()
    player = Player()
    all_sprites.add(player)

    # --- 核心修改: 事件现在是生成一波 (Wave) 子弹 ---
    ADD_WAVE = pygame.USEREVENT + 1
    pygame.time.set_timer(ADD_WAVE, WAVE_SPAWN_RATE)

    start_time = pygame.time.get_ticks()
    running = True
    game_over = False
    player_won = False

    while running:
        clock.tick(60)
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            # --- 核心修改: 接收到事件后，生成一整波子弹 ---
            elif event.type == ADD_WAVE and not game_over:
                num_to_spawn = random.randint(BULLETS_PER_WAVE_MIN, BULLETS_PER_WAVE_MAX)
                for _ in range(num_to_spawn):
                    new_bullet = Bullet()
                    all_sprites.add(new_bullet)
                    bullets.add(new_bullet)

        if not game_over:
            all_sprites.update()
            collided_bullets = pygame.sprite.spritecollide(player, bullets, True)
            if collided_bullets:
                player.get_hit()
                if player.hp <= 0:
                    game_over = True
            elapsed_seconds = (pygame.time.get_ticks() - start_time) / 1000
            if elapsed_seconds >= duration:
                game_over = True
                player_won = True

        keys = pygame.key.get_pressed()
        if keys[pygame.K_ESCAPE]:
            running = False

        screen.fill(BLACK)
        all_sprites.draw(screen)
        remaining_time = max(0, duration - elapsed_seconds)
        timer_text = font.render(f"Time: {int(remaining_time)}", True, WHITE)
        screen.blit(timer_text, (10, 10))
        hp_text = font.render(f"HP: {player.hp}", True, GREEN)
        screen.blit(hp_text, (10, 50))

        if game_over:
            end_text_str = "You Win!" if player_won else "Game Over"
            end_color = GREEN if player_won else RED
            end_text = font.render(end_text_str, True, end_color)
            text_rect = end_text.get_rect(center=(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2))
            screen.blit(end_text, text_rect)
            pygame.display.flip()
            pygame.time.wait(3000)
            running = False

        pygame.display.flip()

    pygame.quit()
    print("Pygame 游戏阶段结束。")


# 3. 主实验流程 (更新后)
# ==============================================================================
def run_experiment():
    """定义整个实验的执行顺序"""

    # 第1阶段：静息
    # preparation_phase(10)
    # resting_phase2(60)
    #
    # attention_racetrack_phase(60)

    # attention_cloud_phase(win,60)

    transition_text = visual.TextStim(win, text="下一个任务：躲避游戏\n\n请你通过键盘上的\"左右按键\"躲避敌机", height=0.1)
    transition_text.draw()
    win.flip()
    core.wait(10)

    # --- 核心步骤: 关闭PsychoPy窗口 ---
    # 在启动Pygame之前，必须释放对屏幕的控制
    win.close()

    # --- 阶段 3: 运行Pygame游戏 ---
    run_dodge_game_phase(duration=60)  # 运行60秒的游戏

    # --- 阶段 4: 实验结束 ---
    # Pygame结束后，可以重新创建一个PsychoPy窗口来显示最终信息
    final_win = visual.Window(fullscr=True, color=(-0.8, -0.8, -0.8), screen=0, units='norm')
    end_text = visual.TextStim(final_win, text="实验结束，谢谢参与！", height=0.1)
    end_text.draw()
    final_win.flip()
    core.wait(5)

    # --- 清理 ---
    final_win.close()
    core.quit()


if __name__ == "__main__":
    run_experiment()
