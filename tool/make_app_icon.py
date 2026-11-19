"""C 案「週の予定表」のアプリアイコン。紺の地に白い予定表、中に授業・シフト・締め切りなどの色の帯。
- 普通の版（iPhone・192/512）: 予定表の幅 72%
- maskable（Android のホーム画面などで円・しずく形に切り抜かれる）: 予定表を囲む長方形の対角線が直径 80% の円に収まる大きさ
- 小さい版（ファビコン 16〜48px）: 予定表を 90% に広げ、帯を太く 3 本に減らす。角を 20% 丸める"""
import io, math, subprocess, sys
from PIL import Image
out = sys.argv[1]
N, W = '10218B', 'FFFFFF'
SH, LE, DL, OT = 'CA5010', '4F6BED', 'C50F1F', '038387'

def table(w, small=False):
    """幅 w、中心 (256, 256+リングの分) の予定表。座標は 512 の枠"""
    h = w * 0.80
    ring = w * 0.10
    x, y = 256 - w / 2, 256 - (h - ring) / 2
    r = w * 0.10
    b = f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{r:.1f}" fill="#{W}"/>'
    head = h * 0.22
    b += f'<rect x="{x + w*0.09:.1f}" y="{y + head:.1f}" width="{w*0.82:.1f}" height="{w*0.035:.1f}" rx="{w*0.0175:.1f}" fill="#{N}"/>'
    rw = w * 0.075
    for cx in (x + w * 0.26, x + w * 0.74):
        b += f'<rect x="{cx - rw/2:.1f}" y="{y - ring:.1f}" width="{rw:.1f}" height="{ring*2:.1f}" rx="{rw/2:.1f}" fill="#{W}"/>'
    top = y + head + w * 0.09
    area = h - head - w * 0.09 - w * 0.08   # 帯を置く高さ
    if small:
        cols = [[(0.0, 0.55, LE)], [(0.30, 0.70, SH)], [(0.05, 0.45, OT)]]
    else:
        cols = [[(0.0, 0.45, LE)], [(0.25, 0.60, SH)], [(0.0, 0.30, LE), (0.50, 0.40, OT)],
                [(0.10, 0.80, SH)], [(0.80, 0.14, DL)]]
    n = len(cols)
    gap = w * (0.05 if small else 0.035)
    left = x + w * 0.09
    cw = (w * 0.82 - gap * (n - 1)) / n
    for i, blocks in enumerate(cols):
        for (t, hh, c) in blocks:
            b += (f'<rect x="{left + i*(cw+gap):.1f}" y="{top + t*area:.1f}" width="{cw:.1f}" '
                  f'height="{hh*area:.1f}" rx="{cw*0.18:.1f}" fill="#{c}"/>')
    return b, (w, h + ring)

def svg(body, size, r=0.0):
    rx = f' rx="{512*r:.1f}"' if r else ''
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 512 512">'
            f'<rect width="512" height="512"{rx} fill="#{N}"/>{body}</svg>')

def png(s, name, size, alpha=True):
    raw = subprocess.run(['rsvg-convert', '-w', str(size), '-h', str(size)], input=s.encode(), capture_output=True, check=True).stdout
    im = Image.open(io.BytesIO(raw)).convert('RGBA')
    if not alpha:
        im = im.convert('RGB')
    im.save(f'{out}/{name}')
    return im

big, _ = table(512 * 0.72)
# maskable: 対角線 ≤ 80%（410px）になる幅を探す
w = 512 * 0.72
while True:
    body, (bw, bh) = table(w)
    if math.hypot(bw, bh) <= 512 * 0.80:
        break
    w -= 2
mask = body
print('maskable width %.0f%%' % (w / 512 * 100))
small, _ = table(512 * 0.90, small=True)

png(svg(big, 1024), 'master-1024.png', 1024, alpha=False)
png(svg(big, 180), 'apple-touch-icon.png', 180, alpha=False)
png(svg(big, 192, 0.2), 'Icon-192.png', 192)
png(svg(big, 512, 0.2), 'Icon-512.png', 512)
png(svg(mask, 192), 'Icon-maskable-192.png', 192, alpha=False)
png(svg(mask, 512), 'Icon-maskable-512.png', 512, alpha=False)
fav = [png(svg(small, s, 0.2), f'favicon-{s}.png', s) for s in (16, 32, 48)]
fav[2].save(f'{out}/favicon.ico', sizes=[(16, 16), (32, 32), (48, 48)])
open(f'{out}/favicon.svg', 'w').write(svg(small, 32, 0.2))

# 見比べ用
from PIL import ImageDraw
sh = Image.new('RGB', (960, 300), (245, 245, 245))
im = Image.open(f'{out}/Icon-512.png').resize((240, 240), Image.LANCZOS); sh.paste(im, (20, 30), im)
m = Image.open(f'{out}/Icon-maskable-512.png').resize((240, 240), Image.LANCZOS)
mk = Image.new('L', (240, 240), 0); ImageDraw.Draw(mk).ellipse((0, 0, 239, 239), fill=255); sh.paste(m, (290, 30), mk)
a = Image.open(f'{out}/apple-touch-icon.png').resize((120, 120), Image.LANCZOS)
am = Image.new('L', (120, 120), 0); ImageDraw.Draw(am).rounded_rectangle((0, 0, 119, 119), 27, fill=255); sh.paste(a, (560, 90), am)
x = 720
for s in (48, 32, 16):
    f = Image.open(f'{out}/favicon-{s}.png'); sh.paste(f, (x, 130), f); x += s + 20
sh.save(f'{out}/preview.png')
print('ok')
