---
layout: post
title: "inotify实现nfs实时备份"
date: 2024-08-14
categories: [tutorials]
tags: [inotify, rsync, NFS, Ubuntu, 备份]
author: g66x
---

# inotify实现nfs实时备份

## 环境

| 主机    | Ip          | 角色/部署模块                       | 操作系统           |
| ------- | ----------- | ----------------------------------- | ------------------ |
| ebops9  | 10.1.62.208 | rsync(daemon)服务端、nfs备份服务器  | Ubuntu 20.04.6 LTS |
| ebops10 | 10.1.62.239 | nfs服务端、nfs客户端、inotify-tools | Ubuntu 20.04.6 LTS |

## 一、部署步骤

### 1.安装nfs-server

```shell
apt update
apt install nfs-kernel-server
# 创建共享目录
mkdir -p /data/media
# 共享目录赋权
chmod -R 777 /data/media
# 配置 NFS 导出
vi /etc/exports
# 在文件中添加以下行
/data/media *(rw,sync,no_subtree_check)
# 重新加载 NFS 配置
exportfs -a
# 启动 NFS 服务
systemctl restart nfs-kernel-server
systemctl enable nfs-kernel-server
systemctl status nfs-kernel-server
# 查看nfs服务器的共享目录
showmount -e localhost
```

### 2.安装nfs客户端

本机同时安装nfs客户端进行挂载测试

```shell
apt-get install nfs-common
mkdir /data/mnttest                                                                        
mount -t nfs -o nolock 10.1.62.239:/data/media /data/mnttest
```

验证挂载

```shell
root@ebops10:/data/media# touch a.txt
root@ebops10:/data/media# ll
total 8
drwxrwxrwx 2 root root 4096 Aug 14 08:29 ./
drwxr-xr-x 8 root root 4096 Aug 14 06:43 ../
-rw-r--r-- 1 root root    0 Aug 14 08:29 a.txt
root@ebops10:/data/media# ll /data/mnttest/
total 8
drwxrwxrwx 2 root root 4096 Aug 14 08:29 ./
drwxr-xr-x 8 root root 4096 Aug 14 06:43 ../
-rw-r--r-- 1 root root    0 Aug 14 08:29 a.txt
```

### 3.部署rsync服务

在ebops9主机部署rsync服务，异地实时同步需要在rsync以守护模式部署

```shell
vi /etc/rsyncd.conf 
#加入以下内容
log file = /var/log/rsyncd.log 
pidfile = /var/run/rsyncd.pid 
lock file = /var/run/rsync.lock

[nfsbackup]
path = /data/nfsbackup/
port = 873
uid = nfs_rsync
gid = nfs_rsync 
#ignore errors
read only = no
list = no
max connections = 200
timeout = 600
auth users = nfs_rsync
hosts allow = 10.1.62.239
hosts deny = 0.0.0.0 
secrets file = /etc/rsync.password
```

> **配置解释**
>
> log file = /var/log/rsyncd.log    # 日志文件位置，启动rsync后自动产生这个文件，无需提前创建
> pidfile = /var/run/rsyncd.pid     # pid文件的存放位置
> lock file = /var/run/rsync.lock   # 支持max connections参数的锁文件
>
> [nfsbackup]     # 自定义同步名称
> path = /data/nfsbackup         # rsync目标服务器数据存放路径，源服务器的数据将同步至此目录
> port = 873        # 默认端口
> #ignore errors     # 表示出现错误忽略错误
> read only = no    # 设置rsync源服务器为读写权限
> list = no     # 不显示rsync源服务器资源列表
> max connections = 200     # 最大连接数
> timeout = 600     # 设置超时时间
> auth users = nfs_rsync        # 执行数据同步的用户名，可以设置多个，用英文状态下逗号隔开
> hosts allow = 10.1.62.239   # 允许进行数据同步的源服务器IP地址，可以设置多个，用英文状态下逗号隔开
> hosts deny = 0.0.0.0      # 禁止数据同步的源服务器IP地址，可以设置多个，用英文状态下逗号隔开

根据配置文件中的`auth_users`创建用户

```shell
useradd nfs_rsync
passwd nfs_rsync 
#输入两次密码
```

根据配置中的`path`创建对应文件夹

```
mkdir /data/nfsbackup
chown nfs_rsync:nfs_rsync nfsbackup/
```

根据配置中的`secrets file`创建rsync服务端配置密码文件

```
#ebops09
echo 'nfs_rsync:xxxxxx' >>/etc/rsync.password
```

启动rsync守护进程

```shell
pkill rsync
ps -ef|grep rsync
rsync --daemon
lsof -i tcp:873
```

### 4.rsync同步测试

在需要同步的nfs服务端手动同步测试

```shell
#创建密码文件,写入服务端同步账户的密码
echo 'xxxxxx' >> /etc/rsync.password
```

测试

```shell
root@ebops10:/data/media# ll
total 8
drwxrwxrwx 2 root root 4096 Aug 14 09:03 ./
drwxr-xr-x 8 root root 4096 Aug 14 06:43 ../
-rw-r--r-- 1 root root    0 Aug 14 09:03 a.txt
root@ebops10:/data/media# rsync -avH --port 873 --progress --delete ./ nfs_rsync@10.1.62.208::nfsbackup --password-file=/etc/rsync.password
sending incremental file list
./
a.txt
              0 100%    0.00kB/s    0:00:00 (xfr#1, to-chk=0/2)

sent 114 bytes  received 46 bytes  320.00 bytes/sec
total size is 0  speedup is 0.00
```

> 如有报错大概为目录权限、密码、服务器安全策略、selinux等问题,可自行查阅解决

### 5.安装inotify-tools 

在ebops10执行

查看是否支持,有以下内容则支持

```shell
root@ebops10:/data/media# ls -l /proc/sys/fs/inotify/
total 0
-rw-r--r-- 1 root root 0 Aug 14 08:51 max_queued_events
-rw-r--r-- 1 root root 0 Aug 14 08:51 max_user_instances
-rw-r--r-- 1 root root 0 Aug 14 08:51 max_user_watches
```

安装

```
apt install inotify-tools -y
```

测试

```shell
#执行以下命令，跟踪/data/media下的create事件
inotifywait -mrq --timefmt '%y/%m/%d %H:%M' --format '%T %w%f' -e create /data/media
#创建一个文件
root@ebops10:~# cd /data/media/
root@ebops10:/data/media# touch b.txt
#观察跟踪到文件创建
root@ebops10:/data/mnttest# inotifywait -mrq --timefmt '%y/%m/%d %H:%M' --format '%T %w%f' -e create /data/media/
24/08/14 07:15 /data/media/b.txt
```

### 6.编写脚本

vi inotify_backp.sh

```shell
#!/bin/bash  
  
# 定义变量  
Path=/data/media  
rsync_user=nfs_rsync  
backup_Server=10.1.62.208  
LogFile=/var/log/rsync_inotify.log  
  
touch $LogFile  
  
log_message() {  
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LogFile  
}  

# 使用inotifywait监控文件变化  
/usr/bin/inotifywait -mrq --format '%w%f' -e close_write,delete $Path | while read line  
do  
    log_message "Detected change in $line"  
  
    if [ -f "$line" ]; then  
        log_message "Starting rsync for file $line"  
        rsync -az "$line" --delete "$rsync_user@$backup_Server::nfsbackup" --password-file=/etc/rsync.password >> $LogFile 2>&1  
        if [ $? -eq 0 ]; then  
            log_message "File $line successfully synced."  
        else  
            log_message "Failed to sync file $line."  
        fi  
    else  
        log_message "Detected deletion or non-file change in $line, syncing entire directory."  
        cd "$Path" && \
        rsync -az ./ --delete "$rsync_user@$backup_Server::nfsbackup" --password-file=/etc/rsync.password >> $LogFile 2>&1  
        if [ $? -eq 0 ]; then  
            log_message "Entire directory successfully synced."  
        else  
            log_message "Failed to sync entire directory."  
        fi  
    fi  
done
```

```shell
nohup sh inotify_backp.sh &
```

## 二、测试效果

在nfs服务端启动脚本，在挂载目录进行文件增、删、改操作

```shell
#启动脚本
root@ebops10:~# nohup sh inotifytest.sh &
[1] 1067461
root@ebops10:~# nohup: ignoring input and appending output to 'nohup.out'                 #进入挂载目录                  
root@ebops10:~# cd /data/mnttest/
root@ebops10:/data/mnttest# ll
total 8                                                                                   
drwxrwxrwx 2 root root 4096 Aug 14 09:03 ./                                               
drwxr-xr-x 8 root root 4096 Aug 14 06:43 ../                                               
-rw-r--r-- 1 root root    0 Aug 14 09:03 a.txt
#创建两个文件
root@ebops10:/data/mnttest# touch b.txt
root@ebops10:/data/mnttest# touch c.txt                                                   #删除一个文件                                         
root@ebops10:/data/mnttest# rm c.txt                                                       
root@ebops10:/data/mnttest# cd /data/media/
#修改一个文件
root@ebops10:/data/media# echo '1' >a.txt 
```

观察nfs备份端的文件,发现能够同步服务端的所有修改

```shell
root@ebops09:/data/nfsbackup# ll
total 8
drwxrwxrwx 2 nfs_rsync nfs_rsync 4096 Aug 14 08:29 ./
drwxr-xr-x 6 root      root      4096 Aug 14 07:04 ../
root@ebops09:/data/nfsbackup# ll
total 8
drwxrwxrwx 2 nfs_rsync nfs_rsync 4096 Aug 14 09:14 ./
drwxr-xr-x 6 root      root      4096 Aug 14 07:04 ../
-rw-r--r-- 1 nfs_rsync nfs_rsync    0 Aug 14 09:03 a.txt
-rw-r--r-- 1 nfs_rsync nfs_rsync    0 Aug 14 09:14 b.txt
root@ebops09:/data/nfsbackup# ll
total 8
drwxrwxrwx 2 nfs_rsync nfs_rsync 4096 Aug 14 09:14 ./
drwxr-xr-x 6 root      root      4096 Aug 14 07:04 ../
-rw-r--r-- 1 nfs_rsync nfs_rsync    0 Aug 14 09:03 a.txt
-rw-r--r-- 1 nfs_rsync nfs_rsync    0 Aug 14 09:14 b.txt
-rw-r--r-- 1 nfs_rsync nfs_rsync    0 Aug 14 09:14 c.txt
root@ebops09:/data/nfsbackup# ll
total 8
drwxrwxrwx 2 nfs_rsync nfs_rsync 4096 Aug 14 09:14 ./
drwxr-xr-x 6 root      root      4096 Aug 14 07:04 ../
-rw-r--r-- 1 nfs_rsync nfs_rsync    0 Aug 14 09:03 a.txt
-rw-r--r-- 1 nfs_rsync nfs_rsync    0 Aug 14 09:14 b.txt
root@ebops09:/data/nfsbackup# ll
total 12
drwxrwxrwx 2 nfs_rsync nfs_rsync 4096 Aug 14 09:15 ./
drwxr-xr-x 6 root      root      4096 Aug 14 07:04 ../
-rw-r--r-- 1 nfs_rsync nfs_rsync    2 Aug 14 09:15 a.txt
-rw-r--r-- 1 nfs_rsync nfs_rsync    0 Aug 14 09:14 b.txt
root@ebops09:/data/nfsbackup# cat a.txt 
1
```

创建100个文件

```
for i in {1..100};do touch "file${i}.txt";done
root@ebops10:/data/media# ls |wc -l
102
root@ebops09:/data/nfsbackup# ls |wc -l
102
root@ebops10:/data/media# tail /var/log/rsync_inotify.log 
2024-08-14 09:23:36 - File /data/media/file97.txt successfully synced.
2024-08-14 09:23:36 - Detected change in /data/media/file98.txt
2024-08-14 09:23:36 - Starting rsync for file /data/media/file98.txt
2024-08-14 09:23:36 - File /data/media/file98.txt successfully synced.
2024-08-14 09:23:36 - Detected change in /data/media/file99.txt
2024-08-14 09:23:36 - Starting rsync for file /data/media/file99.txt
2024-08-14 09:23:36 - File /data/media/file99.txt successfully synced.
2024-08-14 09:23:36 - Detected change in /data/media/file100.txt
2024-08-14 09:23:36 - Starting rsync for file /data/media/file100.txt
2024-08-14 09:23:36 - File /data/media/file100.txt successfully synced.
```

参考链接：https://www.cnblogs.com/leixixi/p/14751914.html
				https://www.cnblogs.com/zoe233/p/12028573.html
