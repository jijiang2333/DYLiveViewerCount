# DYLiveViewerCount

抖音**推荐页**直播实时在线人数插件。刷到直播卡片时，直接在卡片外显示当前直播间的实时在线人数，无需进入直播间。

## 功能

- **关闭**：不显示人数。
- **精准**：显示完整人数，例如 `12345`。
- **模糊**：使用更紧凑的单位显示，例如 `1.2万`。
- **显示设置**：使用原生三段选择器，支持点击与拖动切换关闭、精准、模糊。
- **刷新间隔**：独立卡片与显示设置间隔 12pt；原生滑块可设置 2–10 秒，默认 3 秒。拖动时显示整数秒数，松手保存；关闭模式禁用滑块，保留已选间隔。
- **前后台处理**：切换应用或离开推荐页后暂停请求，回到前台时自动恢复。

## 使用

打开抖音设置，进入 **直播观众数**，选择显示模式并按需调整刷新间隔。插件只处理**推荐页**中的直播预览卡片。

## 构建

项目使用 Theos 构建，支持 rootless、rootful 和 roothide 方案：

```sh
make package SCHEME=rootless
make package SCHEME=rootful
make package SCHEME=roothide
```

构建完成后，安装生成的 deb 包并重启抖音即可生效。
当前仅在抖音版本 **39.9.0** 上完成测试。其他版本请自行测试；
不同抖音版本的内部界面可能变化，如遇兼容性问题需要针对对应版本适配。


## 开源协议

[MIT License](LICENSE)

项目仓库：[github.com/jijiang2333/DYLiveViewerCount](https://github.com/jijiang2333/DYLiveViewerCount)
