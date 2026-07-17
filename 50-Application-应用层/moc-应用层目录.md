---
type: moc
tags: [moc, application, posix, ipc, systemd, network, multithread]
---

# 50-Application：Linux 应用层

> Linux 用户空间程序开发——多线程、IPC、网络通信、文件 IO、系统服务。在 V861 上，这部分负责摄像头控制、视频流推送、WiFi 通信等。

## 学习路线

文件 IO → 多线程 → IPC 通信 → 网络编程 → systemd 服务 → 信号处理

## 已有文档

| 文件 | 核心内容 |
|------|---------|
| [[file-io-文件IO.md|file-io-文件IO]] | open/read/write/close、标准 IO、文件描述符 |
| [[multithread-posix-多线程编程]] | pthread_create、互斥量、条件变量、线程池 |
| [[ipc-dbus-socket-IPC通信]] | 共享内存、消息队列、D-Bus、Unix Socket |
| [[network-mqtt-http-网络编程]] | TCP/UDP Socket、MQTT、HTTP REST API |
| [[systemd-daemon-Systemd守护进程]] | Unit 文件、守护进程、日志管理 |
| [[signal-handling-信号处理]] | Linux 信号机制、signal/sigaction |

## 核心问题

- `pthread_mutex` 和 `pthread_cond` 怎么配合？条件变量用于"等待某个条件成立"，必须配合互斥量使用。
- `select`/`poll`/`epoll` 的区别？select 有 fd 数量限制，poll 无限制但线性扫描，epoll 事件驱动效率最高。