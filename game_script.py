import pygame
import random
import sys
import time

def run_dodge_game_phase(duration=60):
    """
    运行"飞机躲子弹"游戏阶段。
    此版本为横向移动的 "垂直弹幕雨" 玩法。
    使用鼠标左右键控制飞机移动。
    【策略】使用全屏黑边模式，游戏内容居中。
    """
    print("正在启动 Pygame 游戏阶段 (鼠标控制模式)...")

    pygame.init()

    # --- 窗口设置 (全屏黑背景 + 居中游戏区域) ---
    screen_info = pygame.display.Info()
    FULLSCREEN_WIDTH = screen_info.current_w
    FULLSCREEN_HEIGHT = screen_info.current_h

    GAME_WIDTH = 500
    GAME_HEIGHT = 400

    GAME_OFFSET_X = (FULLSCREEN_WIDTH - GAME_WIDTH) // 2
    GAME_OFFSET_Y = (FULLSCREEN_HEIGHT - GAME_HEIGHT) // 2

    screen = pygame.display.set_mode((FULLSCREEN_WIDTH, FULLSCREEN_HEIGHT), pygame.FULLSCREEN)
    game_surface = pygame.Surface((GAME_WIDTH, GAME_HEIGHT))

    if sys.platform == 'win32':
        try:
            import ctypes
            pygame_window_info = pygame.display.get_wm_info()
            hwnd = pygame_window_info['window']
            ctypes.windll.user32.SetForegroundWindow(hwnd)
        except (ImportError, KeyError) as e:
            print(f"无法将窗口置顶，错误: {e}")

    # --- 玩法设置 ---
    PLAYER_HP = 50
    WAVE_SPAWN_RATE = 400
    BULLETS_PER_WAVE_MIN = 3
    BULLETS_PER_WAVE_MAX = 6
    BULLET_MIN_SPEED = 2
    BULLET_MAX_SPEED = 5

    pygame.display.set_caption("飞机躲子弹 (鼠标控制)")
    clock = pygame.time.Clock()
    font = pygame.font.Font(None, 28)

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
            self.image = pygame.Surface([28, 20])
            self.image.fill(BLUE)
            self.rect = self.image.get_rect()
            self.rect.centerx = GAME_WIDTH // 2
            self.rect.bottom = GAME_HEIGHT - 20
            self.speed = 8
            self.hp = PLAYER_HP
            self.invincible = False
            self.invincible_timer = 0
            self.invincible_duration = 1000

        def update(self):
            if self.invincible and pygame.time.get_ticks() - self.invincible_timer > self.invincible_duration:
                self.invincible = False
                self.image.set_alpha(255)

            mouse_buttons = pygame.mouse.get_pressed()
            if mouse_buttons[0]:
                self.rect.x -= self.speed
            if mouse_buttons[2]:
                self.rect.x += self.speed

            if self.rect.left < 0: self.rect.left = 0
            if self.rect.right > GAME_WIDTH: self.rect.right = GAME_WIDTH

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
            self.image = pygame.Surface([3, 12])
            self.image.fill(RED)
            self.rect = self.image.get_rect()
            self.rect.x = random.randrange(GAME_WIDTH)
            self.rect.y = random.randrange(-60, -self.rect.height)
            self.vel_y = random.uniform(BULLET_MIN_SPEED, BULLET_MAX_SPEED)

        def update(self):
            self.rect.y += self.vel_y
            if self.rect.top > GAME_HEIGHT:
                self.kill()

    all_sprites = pygame.sprite.Group()
    bullets = pygame.sprite.Group()
    player = Player()
    all_sprites.add(player)

    ADD_WAVE = pygame.USEREVENT + 1
    pygame.time.set_timer(ADD_WAVE, WAVE_SPAWN_RATE)

    start_time = pygame.time.get_ticks()
    running = True
    game_over = False
    player_won = False

    # 显示初始提示
    instruction_surface = pygame.Surface((GAME_WIDTH, GAME_HEIGHT))
    instruction_surface.fill(BLACK)
    instruction_font = pygame.font.Font(None, 24)
    instruction_text1 = instruction_font.render("鼠标左键: 向左移动", True, WHITE)
    instruction_text2 = instruction_font.render("鼠标右键: 向右移动", True, WHITE)
    instruction_text3 = instruction_font.render("ESC键: 退出游戏", True, WHITE)
    instruction_surface.blit(instruction_text1, (GAME_WIDTH//2 - instruction_text1.get_width()//2, GAME_HEIGHT//2 - 40))
    instruction_surface.blit(instruction_text2, (GAME_WIDTH//2 - instruction_text2.get_width()//2, GAME_HEIGHT//2 - 10))
    instruction_surface.blit(instruction_text3, (GAME_WIDTH//2 - instruction_text3.get_width()//2, GAME_HEIGHT//2 + 20))
    screen.fill(BLACK)
    screen.blit(instruction_surface, (GAME_OFFSET_X, GAME_OFFSET_Y))
    pygame.display.flip()
    pygame.time.wait(3000)

    while running:
        clock.tick(60)
        for event in pygame.event.get():
            if event.type == pygame.QUIT or (event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE):
                running = False
            elif event.type == ADD_WAVE and not game_over:
                num_to_spawn = random.randint(BULLETS_PER_WAVE_MIN, BULLETS_PER_WAVE_MAX)
                for _ in range(num_to_spawn):
                    new_bullet = Bullet()
                    all_sprites.add(new_bullet)
                    bullets.add(new_bullet)

        if not game_over:
            all_sprites.update()
            if pygame.sprite.spritecollide(player, bullets, True):
                player.get_hit()
                if player.hp <= 0:
                    game_over = True

            elapsed_seconds = (pygame.time.get_ticks() - start_time) / 1000
            if elapsed_seconds >= duration:
                game_over = True
                player_won = True

        screen.fill(BLACK)
        game_surface.fill(BLACK)
        all_sprites.draw(game_surface)

        remaining_time = max(0, duration - int(elapsed_seconds))
        timer_text = font.render(f"Time: {remaining_time}", True, WHITE)
        game_surface.blit(timer_text, (8, 8))
        hp_text = font.render(f"HP: {player.hp}", True, GREEN)
        game_surface.blit(hp_text, (8, 35))
        control_text = font.render("Left Click: ←  Right Click: →", True, WHITE)
        game_surface.blit(control_text, (8, GAME_HEIGHT - 25))

        if game_over:
            end_text_str = "You Win!" if player_won else "Game Over"
            end_color = GREEN if player_won else RED
            end_text = font.render(end_text_str, True, end_color)
            text_rect = end_text.get_rect(center=(GAME_WIDTH / 2, GAME_HEIGHT / 2))
            game_surface.blit(end_text, text_rect)
            screen.blit(game_surface, (GAME_OFFSET_X, GAME_OFFSET_Y))
            pygame.display.flip()
            pygame.time.wait(3000)
            running = False

        if not game_over:
            screen.blit(game_surface, (GAME_OFFSET_X, GAME_OFFSET_Y))

        pygame.display.flip()

    pygame.quit()
    print("Pygame 游戏阶段结束。")

if __name__ == '__main__':
    # 允许从命令行接收一个持续时间的参数
    game_duration = 60
    if len(sys.argv) > 1:
        try:
            game_duration = int(sys.argv[1])
        except ValueError:
            print(f"无法将 '{sys.argv[1]}' 解析为整数，使用默认时长 60 秒。")

    run_dodge_game_phase(duration=game_duration)

