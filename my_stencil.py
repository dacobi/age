import os
import math

try:
    from PIL import Image, ImageDraw
except ImportError:
    import sys
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "Pillow"])
    from PIL import Image, ImageDraw

def generate_shape_points(shape_type, center_x=256, center_y=256):
    points = []
    
    if shape_type == "heart":
        for i in range(0, 360):
            t = math.radians(i)
            x = 16 * (math.sin(t) ** 3)
            y = 13 * math.cos(t) - 5 * math.cos(2*t) - 2 * math.cos(3*t) - math.cos(4*t)
            pixel_x = int(center_x + x * 13)
            pixel_y = int(center_y - y * 11)
            points.append((pixel_x, pixel_y))
            
    elif shape_type == "star":
        # 5-pointed star geometry
        outer_radius = 200
        inner_radius = 80
        for i in range(10):
            angle = math.radians(i * 36 - 90)
            r = outer_radius if i % 2 == 0 else inner_radius
            pixel_x = int(center_x + r * math.cos(angle))
            pixel_y = int(center_y + r * math.sin(angle))
            points.append((pixel_x, pixel_y))
            
    elif shape_type == "moon":
        outer_radius = 200
        for angle_deg in range(-110, 111, 2):
            angle = math.radians(angle_deg)
            pixel_x = int(center_x + outer_radius * math.cos(angle))
            pixel_y = int(center_y + outer_radius * math.sin(angle))
            points.append((pixel_x, pixel_y))
        
        inner_radius = 175
        offset_x = 90
        for angle_deg in range(85, -86, -2):
            angle = math.radians(angle_deg)
            pixel_x = int(center_x - offset_x + inner_radius * math.cos(angle))
            pixel_y = int(center_y + inner_radius * math.sin(angle))
            points.append((pixel_x, pixel_y))

    elif shape_type == "square":
        half_side = 170
        x_min, x_max = center_x - half_side, center_x + half_side
        y_min, y_max = center_y - half_side, center_y + half_side
        
        # Dense sample all 4 straight edges so distance fields map accurately
        for x in range(x_min, x_max): points.append((x, y_min))       # Top edge
        for y in range(y_min, y_max): points.append((x_max, y))       # Right edge
        for x in range(x_max, x_min, -1): points.append((x, y_max))   # Bottom edge
        for y in range(y_max, y_min, -1): points.append((x_min, y))   # Left edge

    elif shape_type == "capsule":
        radius = 110
        half_length = 100
        
        # 1. Right semi-circle cap
        for angle_deg in range(-90, 91, 2):
            angle = math.radians(angle_deg)
            pixel_x = int(center_x + half_length + radius * math.cos(angle))
            pixel_y = int(center_y + radius * math.sin(angle))
            points.append((pixel_x, pixel_y))
            
        # 2. Bottom straight flat edge
        for x in range(int(center_x + half_length), int(center_x - half_length), -2):
            points.append((x, int(center_y + radius)))
            
        # 3. Left semi-circle cap
        for angle_deg in range(90, 271, 2):
            angle = math.radians(angle_deg)
            pixel_x = int(center_x - half_length + radius * math.cos(angle))
            pixel_y = int(center_y + radius * math.sin(angle))
            points.append((pixel_x, pixel_y))
            
        # 4. Top straight flat edge
        for x in range(int(center_x - half_length), int(center_x + half_length), 2):
            points.append((x, int(center_y - radius)))
            
    return points

def create_faded_image(shape_name):
    width, height = 512, 512
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    pixels = img.load()
    
    shape_points = generate_shape_points(shape_name)
    
    mask_img = Image.new("L", (width, height), 0)
    draw = ImageDraw.Draw(mask_img)
    draw.polygon(shape_points, fill=255)
    
    FADE_RADIUS = 85
    
    for y in range(height):
        for x in range(width):
            if mask_img.getpixel((x, y)) == 255:
                pixels[x, y] = (255, 255, 255, 255)
            else:
                min_sq_dist = min((x - px)**2 + (y - py)**2 for px, py in shape_points)
                dist_to_edge = math.sqrt(min_sq_dist)
                
                if dist_to_edge >= FADE_RADIUS:
                    alpha = 0
                else:
                    alpha = int(255 * (1.0 - (dist_to_edge / FADE_RADIUS)))
                
                if alpha > 0:
                    pixels[x, y] = (255, 255, 255, alpha)
                    
    desktop = os.path.join(os.path.expanduser("~"), "Desktop")
    filename = f"fast_fade_white_{shape_name}.png"
    output_path = os.path.join(desktop, filename)
    img.save(output_path, "PNG")
    print(f"Generated: {output_path}")

shapes = ["heart", "star", "moon", "square", "capsule"]
for shape in shapes:
    create_faded_image(shape)
