# Transmission 4.0.5 一键安装脚本

> 适用于 Debian 11 / 12 系统的 Transmission 自动化编译安装脚本

## 📋 功能特性

### ✨ 核心功能
- ✅ **源码编译安装** - 安装最新版 Transmission 4.0.5
- ✅ **交互式配置** - 支持自定义密码、下载目录、Web 端口
- ✅ **智能默认值** - 所有配置项都有合理的默认值，可直接回车跳过
- ✅ **第三方 Web 界面** - 可选安装 TrguiNG 或 Transmission Web Control
- ✅ **完整的系统集成** - 自动创建 systemd 服务，开机自启
- ✅ **安全加固** - systemd 服务沙箱化，最小权限运行
- ✅ **详细日志** - 完整的安装信息保存到文件

### 🎯 高级特性
- 🔐 随机密码生成（可自定义）
- 📁 自定义下载目录（支持路径验证）
- 🌐 自定义 Web 端口（支持端口占用检测）
- 🎨 多种 Web 界面可选
- 📝 配置文件自动生成
- 🔄 完善的错误处理和重试机制
- 🧹 自动清理临时文件

## 🚀 快速开始

### 系统要求
- **操作系统**: Debian 11 或 Debian 12
- **权限**: Root 用户
- **网络**: 可访问 GitHub 和软件源
- **磁盘**: 至少 500MB 可用空间

### 一键安装

```bash
# 下载脚本
wget https://raw.githubusercontent.com/你的仓库/transmission.sh

# 添加执行权限
chmod +x transmission.sh

# 运行脚本
./transmission.sh
```

### 安装过程

脚本会依次提示以下配置项（均可直接回车使用默认值）：

1. **设置密码**
   ```
   :: 随机生成密码: abc12345
   :: 请输入自定义密码(按回车使用随机密码): 
   ```
   - 留空：使用随机密码
   - 输入：使用自定义密码

2. **设置下载目录**
   ```
   :: 默认下载目录: /var/transmission/downloads
   :: 请输入自定义下载目录(按回车使用默认):
   ```
   - 留空：使用默认目录 `/var/transmission/downloads`
   - 输入：使用自定义目录，如 `/mnt/storage/downloads`

3. **设置 Web 端口**
   ```
   :: 默认 Web 端口: 9091
   :: 请输入自定义端口(按回车使用默认):
   ```
   - 留空：使用默认端口 `9091`
   - 输入：使用自定义端口（1024-65535）

4. **确认配置**
   ```
   配置摘要
   用户名:     admin
   密码:       abc12345
   Web 端口:   9091
   Peer 端口:  51413
   下载目录:   /var/transmission/downloads
   
   确认以上配置开始安装？(y/n):
   ```

5. **选择 Web 界面**
   ```
   Web 界面模板选择
   1) 使用官方默认 Web 界面
   2) 安装 TrguiNG 第三方 Web 界面 (推荐)
   请选择 (1/2, 默认 2):
   ```

## 📦 安装内容

### 安装路径
| 项目 | 路径 | 说明 |
|------|------|------|
| 程序目录 | `/usr/local/bin` | transmission-daemon 等可执行文件 |
| 配置文件 | `/etc/transmission-daemon/settings.json` | 主配置文件 |
| Web 界面 | `/usr/local/share/transmission/web` | Web 管理界面文件 |
| 下载目录 | `/var/transmission/downloads` | BT 文件下载保存位置（可自定义） |
| 未完成目录 | `/var/transmission/downloads/incomplete` | 下载中的文件临时存放 |

### 系统服务
- **服务名称**: `transmission-daemon.service`
- **运行用户**: `debian-transmission`
- **启动方式**: systemd 管理
- **开机自启**: 已启用

## 🎮 使用指南

### Web 管理界面

安装完成后，通过浏览器访问：

```
http://你的服务器IP:9091
```

默认账户：
- 用户名: `admin`
- 密码: 安装时显示的密码（已保存到 `/root/transmission_info.txt`）

### 常用命令

```bash
# 启动服务
systemctl start transmission-daemon

# 停止服务
systemctl stop transmission-daemon

# 重启服务
systemctl restart transmission-daemon

# 查看运行状态
systemctl status transmission-daemon

# 查看实时日志
journalctl -u transmission-daemon -f

# 查看最近日志
journalctl -u transmission-daemon -n 50
```

### 修改配置

#### 修改下载目录

```bash
# 1. 停止服务
systemctl stop transmission-daemon

# 2. 编辑配置文件
nano /etc/transmission-daemon/settings.json

# 修改以下两行：
# "download-dir": "/新的下载路径",
# "incomplete-dir": "/新的下载路径/incomplete",

# 3. 创建新目录并设置权限
mkdir -p /新的下载路径/incomplete
chown -R debian-transmission:debian-transmission /新的下载路径

# 4. 启动服务
systemctl start transmission-daemon
```

#### 修改密码

```bash
# 1. 停止服务
systemctl stop transmission-daemon

# 2. 编辑配置文件
nano /etc/transmission-daemon/settings.json

# 修改这一行（输入明文密码，重启后会自动加密）：
# "rpc-password": "新密码",

# 3. 启动服务
systemctl start transmission-daemon
```

#### 修改 Web 端口

```bash
# 1. 停止服务
systemctl stop transmission-daemon

# 2. 编辑配置文件
nano /etc/transmission-daemon/settings.json

# 修改这一行：
# "rpc-port": 新端口号,

# 3. 启动服务
systemctl start transmission-daemon
```

### 查看安装信息

所有安装信息已保存到文件：

```bash
cat /root/transmission_info.txt
```

文件包含：
- 访问地址和密码
- 所有路径信息
- 常用命令
- 卸载方法

## 🔧 进阶配置

### 配置文件说明

主配置文件位于 `/etc/transmission-daemon/settings.json`

常用配置项：

```json
{
    "download-dir": "/var/transmission/downloads",     // 下载保存目录
    "incomplete-dir": "/var/transmission/downloads/incomplete",  // 未完成文件目录
    "rpc-port": 9091,                                  // Web 界面端口
    "rpc-username": "admin",                           // 登录用户名
    "rpc-password": "密码",                            // 登录密码
    "peer-port": 51413,                                // BT 监听端口
    "speed-limit-down": 100,                           // 下载限速 (KB/s)
    "speed-limit-down-enabled": false,                 // 是否启用下载限速
    "speed-limit-up": 100,                             // 上传限速 (KB/s)
    "speed-limit-up-enabled": false,                   // 是否启用上传限速
    "ratio-limit": 2,                                  // 分享率限制
    "ratio-limit-enabled": false                       // 是否启用分享率限制
}
```

⚠️ **注意**: 修改配置文件前务必停止服务，修改后再启动

### 防火墙配置

如果服务器启用了防火墙，需要开放端口：

```bash
# UFW 防火墙
ufw allow 9091/tcp      # Web 界面端口
ufw allow 51413/tcp     # BT 端口
ufw allow 51413/udp     # BT 端口

# iptables 防火墙
iptables -A INPUT -p tcp --dport 9091 -j ACCEPT
iptables -A INPUT -p tcp --dport 51413 -j ACCEPT
iptables -A INPUT -p udp --dport 51413 -j ACCEPT
```

### 性能优化

编辑 `/etc/transmission-daemon/settings.json`：

```json
{
    "cache-size-mb": 16,                    // 增加缓存到 16MB
    "peer-limit-global": 2000,              // 全局连接数
    "peer-limit-per-torrent": 200,          // 单任务连接数
    "upload-slots-per-torrent": 20          // 上传槽位
}
```

## 🗑️ 卸载方法

```bash
# 停止并禁用服务
systemctl stop transmission-daemon
systemctl disable transmission-daemon

# 删除程序文件
rm -rf /usr/local/bin/transmission-*
rm -rf /usr/local/share/transmission

# 删除配置文件
rm -rf /etc/transmission-daemon

# 删除下载目录（可选，如需保留下载文件请跳过）
rm -rf /var/transmission

# 删除服务文件
rm /etc/systemd/system/transmission-daemon.service
systemctl daemon-reload

# 删除系统用户（可选）
userdel debian-transmission

# 删除安装信息
rm /root/transmission_info.txt
```

## ❓ 常见问题

### 1. 无法访问 Web 界面

**问题**: 浏览器无法打开管理界面

**解决方案**:
```bash
# 检查服务是否运行
systemctl status transmission-daemon

# 检查端口是否监听
netstat -tuln | grep 9091

# 检查防火墙
ufw status
```

### 2. 下载速度慢

**解决方案**:
- 检查 tracker 服务器是否可用
- 增加连接数配置
- 检查网络带宽限制

### 3. 权限错误

**问题**: 无法写入下载目录

**解决方案**:
```bash
# 检查目录权限
ls -la /var/transmission/downloads

# 修复权限
chown -R debian-transmission:debian-transmission /var/transmission/downloads
chmod -R 755 /var/transmission/downloads
```

### 4. 服务启动失败

**解决方案**:
```bash
# 查看详细错误日志
journalctl -xeu transmission-daemon

# 检查配置文件语法
cat /etc/transmission-daemon/settings.json | python3 -m json.tool

# 检查端口占用
ss -tuln | grep 9091
```

### 5. 密码忘记

**解决方案**:
```bash
# 查看保存的信息
cat /root/transmission_info.txt

# 或重置密码
systemctl stop transmission-daemon
nano /etc/transmission-daemon/settings.json
# 修改 rpc-password 为新密码（明文）
systemctl start transmission-daemon
```

## 📚 相关资源

- [Transmission 官网](https://transmissionbt.com/)
- [Transmission GitHub](https://github.com/transmission/transmission)
- [Transmission 文档](https://github.com/transmission/transmission/wiki)
- [TrguiNG 项目](https://github.com/ManuZhu0728/TrguiNG)
- [Transmission Web Control](https://github.com/ronggang/transmission-web-control)

## 📝 更新日志

### v1.0.0 (2024-01-xx)
- ✅ 初始版本发布
- ✅ 支持 Transmission 4.0.5 编译安装
- ✅ 交互式配置向导
- ✅ 多种 Web 界面支持
- ✅ 完善的错误处理

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

## ⚠️ 免责声明

- 本脚本仅供学习交流使用
- 使用本脚本下载文件请遵守当地法律法规
- 作者不对使用本脚本造成的任何后果负责

## 💬 支持

如果这个项目对你有帮助，请给个 ⭐ Star！

---

**最后更新**: 2024-01-xx
