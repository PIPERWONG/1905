# 1905 ARCADE — 复古街机作品集

一个网页融合三件小组作品，主题：**80s 复古街机 / CRT / 霓虹 / 合成波 / 35mm 胶片**。

| 作品 | 作者 | 原参考 |
|---|---|---|
| 01 跑路之后变安详（Mario World 1-1 改编） | [@youge96youge-boop](https://github.com/youge96youge-boop) | [Shadertoy XtlSD7 · knarkowicz](https://www.shadertoy.com/view/XtlSD7) |
| 02 Serene Escape Unlimited（安详逃亡） | [@manyuju](https://github.com/manyuju) | [Shadertoy wtS3W3 · spolsh](https://www.shadertoy.com/view/wtS3W3) |
| 03 tm gyroid 2 · 驾驶版 | [@PIPERWONG](https://github.com/PIPERWONG) | [Shadertoy tXtyW8 · tubeman](https://www.shadertoy.com/view/tXtyW8) |

三件原作许可均为 **CC BY-NC-SA 3.0**，页脚已标注原网页，仅作课程学习展示。

## 页面结构

1. **Hero · 复古街机**：机台居中（灯牌 / 双侧霓虹灯带 / 屏幕边框 / 摇杆 / 四颗按钮 / 投币口 /
   网格地面反光），屏幕里**实时运行**三件作品，每 2.8s 故障转场切换（编号/名称/年份/标签 OSD）。
   按钮可手动切作品，投币口触发故障彩蛋。顶部 `[1905] CREATIVE_PORTFOLIO`。
2. **钻屏滚动**：滚动进度驱动镜头推进——先靠近、再对准屏幕中心加速、最后屏幕撑满视口
   （机壳在穿过瞬间融化消失）。反向滚动可完整倒带回街机。街机离屏自动暂停省性能。
3. **1905 WORKS · 胶片轮播**：35mm 胶片卡片（上下齿孔、左右帧号、年份/角色/标签/简介），
   支持鼠标拖拽（带限幅惯性）、滚轮横滚、← → 方向键、低速自动循环；悬停暂停自动滚动，
   中央卡片微微放大发光，边缘渐隐。卡片 ▶ PLAY 回到街机切到该作品，FULLSCREEN 新标签页全屏试玩。
4. **EMOTION ARC**：小组情绪目标（允许自己先逃 → 在逃跑的路上抵达安详）。
5. **REFERENCES**：原作致谢与许可、小组成员。

## 运行

```bash
cd showcase && python3 -m http.server 8060
# 打开 http://localhost:8060/
```

## 目录

```
showcase/
├── index.html        复古街机展示主页（本页）
├── previous.html     上一版三联屏页面（备份）
├── embed-bridge.js   iframe 内嵌桥：父页可暂停/恢复街机屏里的作品
├── fonts/            Press Start 2P（本地像素字体，约 5KB）
├── covers/           三件作品的封面截图（胶片卡用）
├── mario/ drive/ gyroid/   三件作品（可独立运行、可被街机屏幕与 FULLSCREEN 调用）
└── README.md
```

## 交互备忘

- 街机屏幕内作品默认不可点（滚动优先），试玩走卡片 ▶ PLAY / FULLSCREEN。
- 方向键同时驱动胶片轮播；当焦点在街机屏内作品时按键归该作品。
- `?zen=1` 等各作品自带参数在 FULLSCREEN 新标签页中照常可用。
