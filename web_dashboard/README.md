# DeepSell Web Dashboard

`web_dashboard` 是 `deepsell.wiki` 的网页端经营后台，使用静态文件实现：

- `index.html`
- `styles.css`
- `app.js`

网页端覆盖总览、库存、订单、经营分析、运营工具和双端同步状态。界面不提供邮箱、密码、token、WebDAV 账号或“账号云同步”填写入口。

## 数据接口

网页端默认使用：

- `GET /api/data` 读取业务数据
- `POST /api/data` 写回网页端改价、上架状态和订单状态

安卓 App 负责后台同步完整业务数据到服务器。网页端只调用服务器接口；如果接口返回 `Not logged in` 或 `401`，应在 `deepsell.wiki` 后端用服务器账号/内置凭据做代理，不要把账号信息放进前端代码。

## 本地预览

在 `http://127.0.0.1`、`localhost` 或 `file://` 下打开时，页面默认使用本地预览数据。本地预览下的改价和状态修改会保存到浏览器 `localStorage`，方便检查交互。

需要在本地强制测试线上接口时，可以打开：

```text
http://127.0.0.1:4173/?live=1#overview
```
