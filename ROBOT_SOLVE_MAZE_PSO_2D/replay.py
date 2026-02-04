import pygame
import numpy as np
import math

# ====== CONFIG ======
PATH_FILE = r"G:\ROBOT_29_04\robotdixa_y_max copy.npy"  # File đường đi đã lưu
MAP_PATH = r"G:\27_04_25\mapkhac\m10x10.jpg"  # File bản đồ
ROBOT_IMAGE = r"G:\27_04_25\robotfix\rb_3.png"  # File robot ảnh
ROBOT_SCALE = (15, 15)
DELAY_TIME = 30  # milliseconds mỗi frame
WINDOW_SIZE = (1000, 1059)

# ====== INIT ======
pygame.init()
screen = pygame.display.set_mode(WINDOW_SIZE)
pygame.display.set_caption("Replay Robot Path")
clock = pygame.time.Clock()

# Load map, robot image
my_map = pygame.image.load(MAP_PATH)
robot_img = pygame.image.load(ROBOT_IMAGE)
robot_img = pygame.transform.scale(robot_img, ROBOT_SCALE)
map_copy = my_map.copy()

# Load path
path = np.load(PATH_FILE)
if len(path.shape) == 3:
    path = path[0]  # Nếu bị bọc thêm 1 lớp

# ====== Hàm vẽ cảm biến ======
def draw_sensors(screen, pos, theta):
    angles = [theta + i * np.pi / 4 for i in range(8)]
    for angle in angles:
        distance = 0
        while True:
            edge_x = int(pos[0] + distance * np.cos(angle))
            edge_y = int(pos[1] + distance * np.sin(angle))
            if edge_x < 0 or edge_x >= map_copy.get_width() or edge_y < 0 or edge_y >= map_copy.get_height():
                break
            b, g, r, a = map_copy.get_at((edge_x, edge_y))
            if b < 100 and g < 100 and r < 100:
                break
            distance += 1
        pygame.draw.line(screen, (0, 255, 0), pos, (edge_x, edge_y), 1)
        pygame.draw.circle(screen, (0, 255, 0), (edge_x, edge_y), 3)

# ====== Hàm vẽ frame robot ======
def draw_robot_frame(screen, pos, theta):
    n = 40
    centerx, centery = pos
    x_axis = (centerx + n * math.cos(theta), centery + n * math.sin(theta))
    y_axis = (centerx + n * math.cos(theta + math.pi/2), centery + n * math.sin(theta + math.pi/2))
    pygame.draw.line(screen, (0, 0, 255), pos, x_axis, 3)
    pygame.draw.line(screen, (0, 255, 0), pos, y_axis, 3)

# ====== Main Replay ======
running = True
step = 0
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False

    if step >= len(path):
        pygame.time.wait(1000)
        break

    screen.blit(my_map, (0, 0))

    x, y, theta = path[step]

    # Vẽ robot
    rotated_img = pygame.transform.rotate(robot_img, -math.degrees(theta))
    rect = rotated_img.get_rect(center=(x, y))
    screen.blit(rotated_img, rect)

    # Vẽ cảm biến + robot frame
    draw_sensors(screen, (x, y), theta)
    draw_robot_frame(screen, (x, y), theta)

    pygame.display.update()
    clock.tick(1000 // DELAY_TIME)  # Điều chỉnh tốc độ
    step += 1

pygame.quit()
