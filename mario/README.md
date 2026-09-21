# 跑路之后变安详 · Mario World 1-1 Shader 改编版

基于 knarkowicz 的 [Shadertoy "Mario World 1-1"](https://www.shadertoy.com/view/XtlSD7)(单片段着色器复刻 NES 超级马里奥 1-1 关卡)的二次创作,主题:**"逃跑"之后变得"安详"**。

## 效果

- 全程纯片段着色器程序化渲染,保持 NES 像素风格与 2D 横版平台跳跃
- 开局天空中大量彩色像素耀西(红/绿/蓝/黄),随关卡推进逐渐消失;音乐进入慢板时天空完全清空,只剩蓝天
- 结局:城堡换成木床,马里奥碰旗杆后走到床边躺下盖被睡觉,一只鸽子飞落到他肚子上,然后循环
- 背景音乐:8-bit 方波/三角波版小星星变奏曲(Var.2 快板琶音 → Var.11 柔板)
- 整个画面与音乐 50 秒循环播放,空格键暂停/继续

## 自定义功能(页面左上角面板)

- 上传图片替换天空背景(自动像素化)
- 上传图片分别替换耀西 / 马里奥 / 蘑菇兵(16×16 像素化,保留原动画帧轮廓)
- 耀西数量滑块(10%–225%)
- 一键恢复默认

## 文件

| 文件 | 说明 |
|---|---|
| `index.html` | WebGL 运行器 + Web Audio 音乐 + 上传 UI + 暂停 |
| `mario.frag` | 原版 shader(未改动) |
| `mario_sleep.frag` | 改编版 shader(由脚本生成) |
| `make_mod.py` | 改编脚本:像素画转 base-4 编码并打补丁,`python3 make_mod.py` 重新生成 |
| `server.py` | 多线程 no-cache 本地静态服务器 |

## 运行

```bash
python3 server.py
# 打开 http://localhost:8000,点击画面开始(含音乐)
# 调试:index.html#t=秒 可冻结在指定时间
```

## 许可

原 shader 为 CC BY-NC-SA 3.0(TDM / knarkowicz),本改编版同样仅限非商业使用。任天堂角色版权归任天堂所有,本项目仅供学习研究。
