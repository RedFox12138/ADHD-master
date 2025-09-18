import pygame
import random
import math

# --- 游戏设置 ---
SCREEN_WIDTH = 800
SCREEN_HEIGHT = 600
GAME_DURATION = 60  # 游戏总时长（秒）
FPS = 60  # 游戏帧率

# --- 颜色定义 ---
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
RED = (255, 0, 0)
BLUE = (100, 149, 237)  # 飞机的颜色 (Cornflower Blue)


# --- 玩家 (飞机) 类 ---
class Player(pygame.sprite.Sprite):
    def __init__(self):
        super().__init__()
        # 创建飞机的图像 (一个蓝色的小矩形)
        self.image = pygame.Surface([30, 40])
        self.image.fill(BLUE)
        self.rect = self.image.get_rect()

        # 将飞机初始位置设置在屏幕中央
        self.rect.centerx = SCREEN_WIDTH // 2
        self.rect.bottom = SCREEN_HEIGHT - 20

        self.speed = 5  # 飞机的移动速度

    def update(self):
        # 获取当前所有按键的状态
        keys = pygame.key.get_pressed()

        # 根据按键更新飞机的位置
        if keys[pygame.K_LEFT]:
            self.rect.x -= self.speed
        if keys[pygame.K_RIGHT]:
            self.rect.x += self.speed
        if keys[pygame.K_UP]:
            self.rect.y -= self.speed
        if keys[pygame.K_DOWN]:
            self.rect.y += self.speed

        # 限制飞机不能飞出屏幕
        if self.rect.left < 0:
            self.rect.left = 0
        if self.rect.right > SCREEN_WIDTH:
            self.rect.right = SCREEN_WIDTH
        if self.rect.top < 0:
            self.rect.top = 0
        if self.rect.bottom > SCREEN_HEIGHT:
            self.rect.bottom = SCREEN_HEIGHT


# --- 子弹类 ---
class Bullet(pygame.sprite.Sprite):
    def __init__(self):
        super().__init__()
        # 创建子弹的图像 (一个红色的小圆形)
        self.image = pygame.Surface([10, 10])
        self.image.fill(RED)
        pygame.draw.circle(self.image, RED, (5, 5), 5)  # 画成圆形
        self.image.set_colorkey(BLACK)  # 让黑色背景透明

        self.rect = self.image.get_rect()

        # --- 随机生成子弹的初始位置和方向 ---
        # 随机选择一个屏幕边缘作为出生点
        edge = random.choice(['top', 'bottom', 'left', 'right'])

        if edge == 'top':
            self.rect.x = random.randrange(SCREEN_WIDTH)
            self.rect.y = -self.rect.height
        elif edge == 'bottom':
            self.rect.x = random.randrange(SCREEN_WIDTH)
            self.rect.y = SCREEN_HEIGHT
        elif edge == 'left':
            self.rect.x = -self.rect.width
            self.rect.y = random.randrange(SCREEN_HEIGHT)
        elif edge == 'right':
            self.rect.x = SCREEN_WIDTH
            self.rect.y = random.randrange(SCREEN_HEIGHT)

        # 随机设定子弹的速度和方向
        # 目标点设在屏幕中心附近，增加游戏挑战性
        target_x = SCREEN_WIDTH / 2 + random.randrange(-100, 100)
        target_y = SCREEN_HEIGHT / 2 + random.randrange(-100, 100)

        angle = math.atan2(target_y - self.rect.y, target_x - self.rect.x)
        speed = random.uniform(2, 5)  # 子弹速度随机

        self.vel_x = math.cos(angle) * speed
        self.vel_y = math.sin(angle) * speed

    def update(self):
        # 更新子弹位置
        self.rect.x += self.vel_x
        self.rect.y += self.vel_y

        # 如果子弹飞出屏幕外太远，就将它销毁以节省资源
        if self.rect.y < -50 or self.rect.y > SCREEN_HEIGHT + 50 or \
                self.rect.x < -50 or self.rect.x > SCREEN_WIDTH + 50:
            self.kill()


# --- 游戏主函数 ---
def game_main():
    # 初始化Pygame
    pygame.init()

    # 创建游戏窗口和时钟
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    pygame.display.set_caption("飞机躲子弹 (Dodge Bullets)")
    clock = pygame.time.Clock()

    # 创建字体用于显示时间和消息
    font = pygame.font.Font(None, 50)

    # 创建精灵组
    all_sprites = pygame.sprite.Group()
    bullets = pygame.sprite.Group()

    # 创建玩家飞机
    player = Player()
    all_sprites.add(player)

    # 设置一个自定义事件，用于定时生成子弹
    ADD_BULLET = pygame.USEREVENT + 1
    pygame.time.set_timer(ADD_BULLET, 200)  # 每200毫秒（0.2秒）生成一颗子弹

    # 游戏开始时间
    start_time = pygame.time.get_ticks()

    # 游戏主循环
    running = True
    game_over = False

    while running:
        # 控制游戏刷新率
        clock.tick(FPS)

        # --- 事件处理 ---
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            # 如果是生成子弹的事件
            elif event.type == ADD_BULLET and not game_over:
                new_bullet = Bullet()
                all_sprites.add(new_bullet)
                bullets.add(new_bullet)

        # 如果游戏没有结束，则更新所有对象
        if not game_over:
            # 更新所有精灵的位置
            all_sprites.update()

            # --- 碰撞检测 ---
            # 检查飞机是否与任何子弹发生碰撞
            if pygame.sprite.spritecollide(player, bullets, False):
                game_over = True

            # --- 时间检测 ---
            elapsed_seconds = (pygame.time.get_ticks() - start_time) / 1000
            if elapsed_seconds >= GAME_DURATION:
                game_over = True  # 时间到，游戏胜利结束

        # --- 渲染/绘制 ---
        screen.fill(BLACK)  # 黑色背景
        all_sprites.draw(screen)  # 绘制所有精灵

        # 显示剩余时间
        remaining_time = max(0, GAME_DURATION - elapsed_seconds)
        timer_text = font.render(f"Time: {int(remaining_time)}", True, WHITE)
        screen.blit(timer_text, (10, 10))

        # --- 显示游戏结束/胜利信息 ---
        if game_over:
            if elapsed_seconds >= GAME_DURATION:
                # 胜利
                end_text = font.render("You Win!", True, (0, 255, 0))
            else:
                # 失败
                end_text = font.render("Game Over", True, RED)

            # 将结束文字显示在屏幕中央
            text_rect = end_text.get_rect(center=(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2))
            screen.blit(end_text, text_rect)

        # 刷新屏幕显示
        pygame.display.flip()

    pygame.quit()


# --- 程序入口 ---
if __name__ == "__main__":
    game_main()