---
type: moc
tags: [moc, application, posix, ipc, systemd, network]
---

# 50-Application: Linux 应用层

> Linux 用户空间程序开发——多线程、IPC、网络通信、系统服务。在 V881 上，这部分负责摄像头控制、视频流推送、WiFi 通信等。

---

## 待创建（按需补充）

| 主题 | 一句话 |
|------|--------|
| 多线程编程 | pthread_create、互斥量、条件变量、线程池 |
| IPC 通信 | 共享内存、消息队列、D-Bus、Unix Socket |
| 网络编程 | TCP/UDP Socket、MQTT、HTTP REST API |
| systemd 服务 | Unit 文件、守护进程、日志管理 |

## 核心问题

- pthread_mutex 和 pthread_cond 怎么配合使用？条件变量用于"等待某个条件成立"，必须配合互斥量。
- select/poll/epoll 的区别？select 有 fd 数量限制，poll 无限制但线性扫描，epoll 基于事件驱动效率最高。
- D-Bus 的 signal 和 method call 的区别？signal 是广播（一对多），method call 是 RPC（一对一，有返回值）。