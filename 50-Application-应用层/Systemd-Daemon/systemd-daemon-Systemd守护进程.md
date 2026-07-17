---
type: concept
tags: [systemd, 守护进程, Linux服务, 服务管理, 日志]
aliases: [Systemd, 守护进程, systemd服务, 服务管理]
---

# Systemd 守护进程

## 一句话结论

systemd 是 Linux 的"大管家"——PID 1，负责启动所有系统服务、管理服务依赖、收集日志、监控服务状态。你写的守护进程通过一个 `.service` 文件注册到 systemd，它就能自动启动、崩溃重启、日志收集。V881 上所有系统服务（摄像头、WiFi、音频、OTA）都由 systemd 管理。

## 30秒先看懂

1. systemd 是 Linux 的 init 系统（PID 1），负责启动和管理所有系统服务，并行启动比旧式 SysV init 快得多。
2. 守护进程通过 `.service` 文件注册到 systemd，配置启动命令、依赖关系、重启策略和资源限制。
3. 核心命令：`systemctl start/stop/restart/status` 管理服务，`journalctl -u xxx` 查看日志。
4. 崩溃自动重启：`Restart=on-failure` + `RestartSec=5` 让服务崩溃后自动恢复。
5. V881 上所有系统服务（摄像头、WiFi、音频、OTA）都由 systemd 管理，保证服务依赖和启动顺序正确。

## 学完以后应该能做什么

### 第一遍
- 写一个 `.service` 文件注册自己的守护进程到 systemd
- 使用 `systemctl` 命令管理服务（启动、停止、重启、查看状态）
- 用 `journalctl` 查看和管理日志
- 配置服务的崩溃重启策略

### 进阶
- 使用 `Type=notify` 实现服务就绪通知
- 配置 systemd watchdog 监控服务健康状态
- 使用 cgroup 资源限制（CPU、内存、IO）
- 编写 systemd timer 替代 cron 定时任务

## 前置知识

- Linux 进程概念（PID、父进程、孤儿进程）
- 基本的命令行操作
- 信号处理（SIGTERM、SIGHUP）

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 守护进程 | Daemon | 后台长期运行的服务进程，没有控制终端 |
| 服务单元 | Service Unit | systemd 中描述一个服务的配置文件（.service） |
| 目标 | Target | systemd 中的同步点，用于分组服务（类似 SysV 的运行级别） |
| 日志 | Journal | systemd 的二进制日志系统，通过 `journalctl` 查看 |
| 看门狗 | Watchdog | systemd 监控服务健康状况的机制，超时未应答则重启 |
| 套接字激活 | Socket Activation | 由 systemd 监听端口，连接到达时启动服务（按需启动） |
| 控制组 | Cgroup | Linux 内核的资源管理机制，systemd 用它限制服务资源使用 |

## 第一层：费曼心智模型

### 类比：大楼的物业管理系统

systemd = 整个大楼的物业管理系统：
- 每天早晨巡查所有房间，按顺序开门（启动服务，按依赖顺序）
- 定期巡检（健康检查，watchdog）
- 坏了自动修（`Restart=on-failure`，崩溃重启）
- 记录出入日志（journalctl，所有服务的日志统一管理）
- 控制访问权限（cgroup 限制 CPU/内存使用）

没有 systemd：每个服务你得手动启动、手动监控、手动重启、手动管理日志——运维噩梦。

### 边界

- systemd 是 Linux 特有的，嵌入式 RTOS（如 FreeRTOS）没有 systemd 概念
- 不是所有 Linux 发行版都用 systemd（如 Alpine 用 OpenRC，但主流的 Ubuntu/Debian/CentOS 都用）
- systemd 功能强大但也复杂，嵌入式系统可能只需要最小功能（如 `Type=simple` + `Restart=on-failure`）

### 场景推演：V881 启动时服务启动顺序

V881 上电后，systemd 作为 PID 1 启动，然后按依赖顺序启动服务：
1. `basic.target` → 挂载文件系统、设置网络
2. `dbus.service` → 启动 D-Bus 守护进程（其他服务依赖它）
3. `wifi-service.service` → 启动 WiFi 连接（`After=network.target`）
4. `cam-service.service` → 启动摄像头服务（`After=dbus.service`）
5. `audio-service.service` → 启动音频服务（`After=dbus.service`）

如果某个服务崩溃，systemd 自动重启（`Restart=on-failure`），但如果 30 秒内重启超过 3 次，systemd 放弃并标记为 failed。

## 第二层：原理/时序/约束

### 一个完整的 Service 文件

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

### Service 类型详解

| Type | 含义 | 什么时候用 |
|------|------|-----------|
| **simple** | 默认。ExecStart 启动后 systemd 认为服务已就绪 | 大多数守护进程 |
| **forking** | 服务 fork 到后台，父进程退出 | 旧式守护进程（如 nginx） |
| **oneshot** | 执行一次就退出，systemd 等它退出 | 初始化脚本 |
| **notify** | 服务主动通知 systemd 自己已就绪 | 支持 sd_notify 的服务 |
| **dbus** | 服务在 D-Bus 上注册后 systemd 认为就绪 | D-Bus 服务 |

### 常用管理命令

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

### 在 C 代码中与 systemd 交互

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

### systemd 的单元关系

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

## 第三层：真实SDK代码

### V881 上的 systemd 服务配置

在 `/home/ys/aiglass/reglasses/services/` 中，各服务都有对应的 systemd service 文件：

```ini
# 文件路径: reglasses/services/camera/cam-service.service
[Unit]
Description=ReGlasses Camera Service
After=network.target dbus.service
Requires=dbus.service

[Service]
Type=simple
ExecStart=/usr/bin/cam_service --config /etc/reglasses/cam.conf
ExecStop=/bin/kill -TERM $MAINPID
Restart=on-failure
RestartSec=5
User=reglasses
Group=reglasses
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### 守护进程的信号处理

在 `/home/ys/aiglass/reglasses/services/camera/cam_service.c` 中，守护进程实现了标准的信号处理以配合 systemd：

```c
// 伪代码——V881 摄像头守护进程的信号处理
// 文件路径: reglasses/services/camera/cam_service.c

static volatile sig_atomic_t running = 1;

static void sig_handler(int signo) {
    if (signo == SIGTERM) {
        running = 0;  // systemd 发 SIGTERM 要求优雅退出
    }
}

int main(int argc, char *argv[]) {
    // 注册信号处理
    signal(SIGTERM, sig_handler);
    signal(SIGINT, sig_handler);
    signal(SIGPIPE, SIG_IGN);  // 忽略管道破裂

    // 如果使用 Type=notify，通知 systemd 已就绪
    sd_notify(0, "READY=1");

    while (running) {
        // 主循环：处理摄像头帧
        int ret = process_frame();
        if (ret < 0) {
            syslog(LOG_ERR, "Frame processing failed");
        }
    }

    // 优雅退出
    cleanup();
    syslog(LOG_INFO, "Camera service stopped");
    return 0;
}
```

## 第四层：正常/异常路径

### 正常路径

```
systemctl start cam-service
  → systemd 读取 service 文件
  → 检查依赖（After/Requires）
  → fork + exec ExecStart 指定的程序
  → 如果是 Type=simple，立即标记为 active
  → 如果是 Type=notify，等待 sd_notify("READY=1")
  → 服务进入 running 状态

systemctl stop cam-service
  → systemd 发送 SIGTERM 到主进程
  → 主进程处理信号，清理资源
  → 进程退出，systemd 标记为 inactive
```

### 异常路径

| 异常 | 现象 | 触发条件 | 恢复方式 |
|------|------|---------|---------|
| 启动失败 | `systemctl start` 报错，status 显示 failed | ExecStart 路径错误、权限不足 | 检查路径和权限，用 `systemctl status` 看详细错误 |
| 配置未生效 | 修改 service 文件后行为不变 | 忘了 `systemctl daemon-reload` | systemd 缓存了旧配置，必须 reload |
| 崩溃重启循环 | 服务反复重启 | 服务启动后立即崩溃，超过 StartLimitBurst | 用 `systemctl status` 看启动次数，排查崩溃原因 |
| 日志爆满 | 磁盘空间满 | 未设置 `SystemMaxUse` 限制 | 设置 `journalctl --vacuum-size=500M` 清理 |
| Watchdog 超时 | 服务被 systemd 杀死重启 | 服务未在 WatchdogSec 内发送心跳 | 检查服务是否卡死，或增加 WatchdogSec 时间 |
| 依赖服务未启动 | 服务启动失败，依赖错误 | RequiredBy 的服务未启动 | `systemctl start dbus.service` 先启动依赖 |

## 第五层：调试方法

### 服务状态排查

```bash
# 查看服务详细状态
systemctl status cam-service

# 查看服务最近的日志
journalctl -u cam-service -n 50

# 实时跟踪日志
journalctl -u cam-service -f

# 查看服务依赖关系
systemctl list-dependencies cam-service

# 查看所有失败的服务
systemctl list-units --state=failed

# 查看服务启动时间
systemd-analyze blame | grep cam-service
```

### 调试配置

```bash
# 测试 service 文件语法
systemd-analyze verify /etc/systemd/system/cam-service.service

# 查看服务启动耗时
systemd-analyze critical-chain cam-service.service

# 以调试模式启动服务（前台运行）
/usr/bin/cam_service --config /etc/cam.conf --foreground
```

### 日志管理

```bash
# 查看日志占用空间
journalctl --disk-usage

# 清理日志到指定大小
journalctl --vacuum-size=500M

# 清理指定天数前的日志
journalctl --vacuum-time=7d

# 只保留最近 100MB 日志
echo "SystemMaxUse=100M" >> /etc/systemd/journald.conf
systemctl restart systemd-journald
```

## 第六层：实战练习

### 练习1：编写一个守护进程的 service 文件

假设你写了一个名为 `audio-streamer` 的守护进程，安装在 `/usr/bin/audio-streamer`，配置文件在 `/etc/audio-streamer.conf`。它需要在网络就绪后启动，崩溃后自动重启，且日志写入 journal。请写出完整的 service 文件。

### 练习2：实现 watchdog 心跳

为 `audio-streamer` 添加 watchdog 支持：
1. 修改 service 文件，添加 `WatchdogSec=30`
2. 在 C 代码中调用 `sd_notify(0, "WATCHDOG=1")` 每 10 秒发送一次心跳
3. 测试：如果主循环卡死超过 30 秒，systemd 应该杀死进程

### 练习3：阅读真实源码——V881 服务的 systemd 配置

在 `/home/ys/aiglass/reglasses/services/` 目录下查找所有 `.service` 文件，分析：
1. 各服务的启动顺序依赖关系
2. 使用了哪些 Restart 策略
3. 哪些服务使用了 Type=notify 或 watchdog

## 自测与验收

1. systemd 在 Linux 系统中的角色是什么？为什么 PID 是 1？
2. `Type=simple` 和 `Type=notify` 的区别是什么？什么时候用 notify？
3. `Restart=on-failure` 和 `Restart=always` 的区别是什么？
4. 修改了 `/etc/systemd/system/xxx.service` 后需要执行什么命令？
5. 如何查看一个服务的日志？如何只看错误级别的日志？
6. `WantedBy` 和 `RequiredBy` 的区别？`After` 和 `Requires` 的区别？
7. 什么是 systemd watchdog？如何实现？

## 延伸阅读

- [[ipc-dbus-socket-IPC通信]] — systemd 和 D-Bus 配合管理服务
- [[rtos-freertos-RTOS原理与FreeRTOS]] — FreeRTOS 的任务管理（对比）
- [[file-io-文件IO]] — 守护进程的日志文件管理
- [[signal-handling-信号处理]] — 守护进程的信号处理

## #flashcard

Q: systemd 是什么？为什么 PID 是 1？
A: systemd 是 Linux 的 init 系统，PID 1 是内核启动的第一个用户态进程，所有其他进程都是它的子进程。

Q: Type=simple 和 Type=notify 的区别？
A: simple 在 ExecStart 启动后立即标记为 active，notify 等待服务调用 sd_notify("READY=1") 后才标记为 active。

Q: Restart=on-failure 和 Restart=always 的区别？
A: on-failure 只在非正常退出时重启（退出码非 0 或被信号杀死），always 无论什么退出原因都重启。

Q: 修改 service 文件后需要执行什么命令？
A: systemctl daemon-reload — 让 systemd 重新加载配置。

Q: systemd 的 watchdog 机制是什么？
A: 在 WatchdogSec 时间内，服务必须调用 sd_notify("WATCHDOG=1") 发送心跳，超时未发送则 systemd 杀死进程并重启。