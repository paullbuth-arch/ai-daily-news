# Systemd 守护进程

**一句话结论（20% 核心）**：systemd 是 Linux 的"大管家"——它负责启动所有系统服务、管理服务依赖、收集日志、监控服务状态。你写的守护进程通过一个 `.service` 文件注册到 systemd，它就能自动启动、崩溃重启、日志记录。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：大楼的物业管理系统

systemd = 物业管理系统：
- 开电闸（启动服务）
- 定期巡检（健康检查）
- 坏了自动修（`Restart=on-failure`）
- 记录出入日志（journalctl）

没有 systemd：每个服务你得手动启动、手动监控、手动重启。

### 1.2 一个最小的 Service 文件

```ini
# /etc/systemd/system/my-service.service
[Unit]
Description=My Camera Service
After=network.target              # 等网络就绪后再启动

[Service]
ExecStart=/usr/bin/cam_service    # 启动命令
Restart=on-failure                # 崩溃后自动重启
RestartSec=5                      # 等 5 秒再重启
User=root

[Install]
WantedBy=multi-user.target        # 在系统启动时自动启动
```

### 1.3 常用命令

```bash
systemctl start my-service       # 启动
systemctl stop my-service        # 停止
systemctl enable my-service      # 开机自启
systemctl status my-service      # 查看状态
journalctl -u my-service -f      # 查看日志
systemctl daemon-reload          # 修改 service 文件后重载
```

### 1.4 如果只记得一件事

> systemd = 服务管理器。写一个 `.service` 文件，`ExecStart` 指定启动命令，`Restart=on-failure` 实现崩溃重启。用 `journalctl -u xxx` 看日志。

---

## 第二层：实战理解

### 2.1 在 reGlasses 项目中怎么用

V881 上所有系统服务都由 systemd 管理：摄像头服务、WiFi 服务、音频服务、OTA 升级服务。WQ7036AX 跑 FreeRTOS，没有 systemd 概念，任务由 FreeRTOS 调度器管理。

### 2.2 常见坑

| 问题 | 现象 | 根因 |
|------|------|------|
| 服务启动失败 | systemctl start 报错 | ExecStart 路径错误或权限不足 |
| 改了 service 文件不生效 | 行为没变 | 需要先 `systemctl daemon-reload` |
| 日志爆满 | 磁盘满 | journald 没设日志大小上限 |

---

## 第三层：延伸阅读

- [[ipc-dbus-socket-IPC通信]] — systemd 和 D-Bus 配合使用
- [[rtos-freertos-RTOS原理与FreeRTOS]] — FreeRTOS 的任务管理（对比）