# Systemd 守护进程

**一句话结论（20% 核心）**：systemd 是 Linux 的"大管家"——PID 1，负责启动所有系统服务、管理服务依赖、收集日志、监控服务状态。你写的守护进程通过一个 `.service` 文件注册到 systemd，它就能自动启动、崩溃重启、日志收集。V881 上所有系统服务（摄像头、WiFi、音频、OTA）都由 systemd 管理。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：大楼的物业管理系统

systemd = 整个大楼的物业管理系统：
- 每天早晨巡查所有房间，按顺序开门（启动服务，按依赖顺序）
- 定期巡检（健康检查，watchdog）
- 坏了自动修（`Restart=on-failure`，崩溃重启）
- 记录出入日志（journalctl，所有服务的日志统一管理）
- 控制访问权限（cgroup 限制 CPU/内存使用）

没有 systemd：每个服务你得手动启动、手动监控、手动重启、手动管理日志——运维噩梦。

### 1.2 一个完整的 Service 文件

```ini
# /etc/systemd/system/cam-service.service
[Unit]
Description=ReGlasses Camera Service
Documentation=https://wiki.reglasses.com/camera
After=network.target dbus.service          # 等网络和 D-Bus 就绪
Requires=dbus.service                       # 硬依赖（D-Bus 不启动我就不启动）
Wants=wifi.service                          # 软依赖（WiFi 最好有，但没也行）

[Service]
Type=simple                                  # 服务类型
ExecStart=/usr/bin/cam_service --config /etc/cam.conf
ExecStop=/usr/bin/kill -TERM $MAINPID       # 优雅停止
ExecReload=/usr/bin/kill -HUP $MAINPID      # 重载配置
Restart=on-failure                           # 崩溃后自动重启
RestartSec=5                                 # 等 5 秒再重启
StartLimitBurst=3                            # 最多连续重启 3 次
StartLimitIntervalSec=30                     # 在 30 秒内
User=camera                                  # 以 camera 用户运行
Group=camera
LimitNOFILE=65536                            # 最大文件描述符数
MemoryMax=256M                               # 内存限制
CPUQuota=50%                                 # CPU 限制
StandardOutput=journal                       # 标准输出 → journal
StandardError=journal                        # 标准错误 → journal

[Install]
WantedBy=multi-user.target                   # 在系统启动时自动启动
```

### 1.3 Service 类型详解

| Type | 含义 | 什么时候用 |
|------|------|-----------|
| **simple** | 默认。ExecStart 启动后 systemd 认为服务已就绪 | 大多数守护进程 |
| **forking** | 服务 fork 到后台，父进程退出 | 旧式守护进程（如 nginx） |
| **oneshot** | 执行一次就退出，systemd 等它退出 | 初始化脚本 |
| **notify** | 服务主动通知 systemd 自己已就绪 | 支持 sd_notify 的服务 |
| **dbus** | 服务在 D-Bus 上注册后 systemd 认为就绪 | D-Bus 服务 |

### 1.4 如果只记得一件事

> systemd = PID 1，服务管理器。写一个 `.service` 文件：`ExecStart` 启动命令，`Restart=on-failure` 崩溃重启，`WantedBy=multi-user.target` 开机自启。`journalctl -u xxx` 看日志，`systemctl daemon-reload` 重载配置。

---

## 第二层：实战理解

### 2.1 常用管理命令

```bash
# 启动/停止/重启
systemctl start cam-service
systemctl stop cam-service
systemctl restart cam-service
systemctl reload cam-service          # 重载配置（不重启）

# 状态查看
systemctl status cam-service          # 进程状态、最近日志
systemctl is-active cam-service       # 是否在运行
systemctl is-enabled cam-service      # 是否开机自启
systemctl list-units --state=failed   # 查看失败的服务

# 开机自启
systemctl enable cam-service          # 启用开机自启
systemctl disable cam-service         # 禁用
systemctl mask cam-service            # 完全屏蔽（不能被手动启动）

# 日志
journalctl -u cam-service             # 查看日志
journalctl -u cam-service -f          # 实时跟踪
journalctl -u cam-service --since today
journalctl -u cam-service -p err      # 只看错误

# 修改 service 文件后
systemctl daemon-reload               # 必须执行！否则不生效
```

### 2.2 在 C 代码中与 systemd 交互

```c
#include <systemd/sd-daemon.h>

int main() {
    // 初始化完成后通知 systemd（适用于 Type=notify）
    sd_notify(0, "READY=1");

    // 定期发送心跳（配合 WatchdogSec=）
    sd_notify(0, "WATCHDOG=1");

    while (running) {
        // 主循环
        sd_notify(0, "WATCHDOG=1");  // 每 30 秒心跳
        sleep(30);
    }

    // 退出前通知
    sd_notify(0, "STOPPING=1");
    return 0;
}
```

```ini
# 配合 watchdog
[Service]
Type=notify
WatchdogSec=60                         # 60 秒内没收心跳 → 杀进程
ExecStart=/usr/bin/my-service
```

### 2.3 常见坑

| 问题 | 现象 | 排查方法 | 根因 |
|------|------|---------|------|
| 服务启动失败 | `systemctl start` 报错 | `systemctl status xxx` 看错误信息 | ExecStart 路径错误或权限不足 |
| 改了 service 不生效 | 行为没变 | 必须 `systemctl daemon-reload` | systemd 缓存了旧配置 |
| 日志爆满 | `/var/log/journal/` 满 | `journalctl --disk-usage` 看大小 | 没设 `SystemMaxUse` 限制 |
| 服务频繁重启 | Restart 循环 | `systemctl status` 看启动次数 | StartLimitBurst 达到上限，systemd 停止重试 |

### 2.4 在 reGlasses 项目中怎么用

V881 上所有系统服务都由 systemd 管理：
- **cam-service**：摄像头采集+编码
- **wifi-service**：WiFi 连接管理
- **audio-service**：音频路由和 I2S 管理
- **ota-service**：OTA 固件下载和升级

WQ7036AX 跑 FreeRTOS，没有 systemd 概念。FreeRTOS 的任务由调度器管理，启动时在 `app_entry` 任务中创建所有子任务。

---

## 第三层：深入扩展

### 3.1 systemd 的单元关系

```
multi-user.target
    │
    ├── wifi-service.service (WantedBy)
    │       │
    │       └── network.target (After)
    │
    ├── dbus.service (RequiredBy)
    │       │
    │       └── cam-service.service (Requires + After)
    │
    └── basic.target (系统基础)
```

### 3.2 常见问题

- **systemd 和 SysV init 的区别？** systemd 并行启动服务（快），SysV init 串行启动（慢）。systemd 集成日志、cgroup 资源管理、socket 激活，SysV init 只是简单的启动脚本执行器。
- **systemd 的 journal 和 syslog 的区别？** journal 是二进制日志（更快、支持结构化查询），syslog 是文本日志。journal 可以转发到 syslog 兼容旧系统。
- **WantedBy 和 RequiredBy 的区别？** WantedBy 是软依赖（失败不影响目标），RequiredBy 是硬依赖（失败会导致目标失败）。

### 3.3 延伸阅读

- [[ipc-dbus-socket-IPC通信]] — systemd 和 D-Bus 配合管理服务
- [[rtos-freertos-RTOS原理与FreeRTOS]] — FreeRTOS 的任务管理（对比）
- [[file-io-文件IO]] — 守护进程的日志文件管理