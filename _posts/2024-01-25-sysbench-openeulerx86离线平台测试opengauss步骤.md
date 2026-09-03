---
layout: post
title: "sysbench openeulerx86离线平台测试opengauss步骤"
date: 2024-01-25
categories: [tutorials]
tags: [sysbench, openEuler, openGauss, 性能测试, 离线安装]
author: g66x
---

# sysbench openeulerx86离线平台测试opengauss步骤

上传sysbench.zip到/root
```bash
[root@g66 ~]# ll sysbench
total 4304
-rw-r--r-- 1 root root  679013 Jan 24 14:39 autoconf-2.71-2.oe2203.noarch.rpm
-rw-r--r-- 1 root root  471253 Jan 24 14:37 automake-1.16.5-3.oe2203.noarch.rpm
-rw-r--r-- 1 root root    8097 Jan 24 14:39 emacs-filesystem-27.2-3.oe2203.noarch.rpm
-rw-r--r-- 1 root root   10337 Jun 17 17:51 libaio-devel-0.3.112-2.oe2203.x86_64.rpm
-rw-r--r-- 1 root root  181897 Jun 18 14:27 libpq-11.2-5.oe2203.x86_64.rpm
-rw-r--r-- 1 root root   90673 Jun 18 14:27 libpq-devel-11.2-5.oe2203.x86_64.rpm
-rw-r--r-- 1 root root  598201 Jun 18 14:29 libtool-2.4.6-34.oe2203.x86_64.rpm
-rw-r--r-- 1 root root   16212 Mar 29 13:50 oltp_common.lua
..........
..........


-rw-r--r-- 1 root root     939 Jun 28 15:04 prepare.sh
-rw-r--r-- 1 root root    5391 Jun 26 09:59 run.sh
-rw-r--r-- 1 root root 2298637 Jan 24 09:46 sysbench-1.0.20.zip
-rw-r--r-- 1 root root    1281 Jun 28 14:49 sysbench_install.sh
```

```shell
unzip sysbench.zip
sh /root/sysbench/sysbench_install.sh 
```


```bash
[root@g66 sysbench]# cat sysbench_install.sh 
#!/bin/bash
exec_dir='/root/sysbench'


rpm -ivh $exec_dir/autoconf-2.71-2.oe2203.noarch.rpm
rpm -ivh $exec_dir/automake-1.16.5-3.oe2203.noarch.rpm 
rpm -ivh $exec_dir/libpq-11.2-5.oe2203.x86_64.rpm 
rpm -ivh $exec_dir/libaio-devel-0.3.112-2.oe2203.x86_64.rpm 
rpm -ivh $exec_dir/libpq-devel-11.2-5.oe2203.x86_64.rpm 
rpm -ivh $exec_dir/libtool-2.4.6-34.oe2203.x86_64.rpm

unzip $exec_dir/sysbench-1.0.20.zip
cd $exec_dir/sysbench-1.0.20
./autogen.sh
./configure --prefix=/usr --with-pgsql --without-mysql
make && make install
```

### 测试opengauss

#### 创建数据库和用户

到db主库执行

```
sh /root/sysbench/prepare.sh create
```

```bash
[root@g66 sysbench]# cat prepare.sh 
#!/bin/bash

# 创建数据库和用户
_create(){
    gsql -d postgres -p 15400 -r <<EOF
create user sysbench identified by 'test1234';
create database sysbench owner sysbench;
grant all on database sysbench to sysbench;
grant all privileges to sysbench;
EOF
    echo "Database and user 'sysbench' created."
}

# 删除数据库和用户
_delete(){
    gsql -d postgres -p 15400 -r <<EOF
DROP DATABASE IF EXISTS sysbench;
DROP USER IF EXISTS sysbench;
EOF
    echo "Database and user 'sysbench' deleted."
}

# 检查输入参数
if [ -z "$1" ]; then
    echo "No arguments provided. Please use 'create' to create or 'delete' to delete the database and user."
else
    case "$1" in
        _create)
            create
            ;;
        _delete)
            delete
            ;;
        *)
            echo "Invalid argument. Please use 'create' to create or 'delete' to delete the database and user."
            ;;
    esac
fi
```

#### 运行测试

```
cd /root/sysbench/
sh run.sh
```

```bash

[root@g66 sysbench]# cat run.sh 
#!/bin/bash

# 变量定义
PG_HOST="opengauss_primary_address"
PG_PORT=""
PG_USER="sysbench"
PG_PASSWORD="test1234"
PG_DB="sysbench"
RESULT_FILE="sysbench_test_results.log"
DELIMITER="=============================="

# opengauss测试参数
THREADS=64
TIME=180
TABLE_SIZE=1000000
TABLES=10

# 清空结果文件
> $RESULT_FILE

# 准备数据库测试数据
function prepare_database_test_data {
    sysbench --db-driver=pgsql \
        --pgsql-host=$PG_HOST \
        --pgsql-port=$PG_PORT \
        --pgsql-user=$PG_USER \
        --pgsql-db=$PG_USER \
        --pgsql-password=$PG_PASSWORD \
        --threads=$THREADS \
        --report-interval=1 \
        --rand-type=uniform \
        --time=$TIME \
        --events=0 \
        --percentile=99 \
        /usr/share/sysbench/oltp_common.lua \
        --tables=$TABLES \
        --table_size=$TABLE_SIZE \
        prepare
}

# 主键点查测试
function point_select_test {
    echo $DELIMITER >> $RESULT_FILE
    echo "主键点查测试" >> $RESULT_FILE
    echo $DELIMITER >> $RESULT_FILE
    echo "Threads: $THREADS, Time: $TIME, Tables: $TABLES, Table Size: $TABLE_SIZE" >> $RESULT_FILE
    sysbench --db-driver=pgsql \
        --pgsql-host=$PG_HOST \
        --pgsql-port=$PG_PORT \
        --pgsql-user=$PG_USER \
        --pgsql-password=$PG_PASSWORD \
        --pgsql-db=$PG_DB \
        --threads=$THREADS \
        --time=$TIME \
        --report-interval=1 \
        --tables=$TABLES \
        --table_size=$TABLE_SIZE \
        /usr/share/sysbench/oltp_point_select.lua run >> $RESULT_FILE
}

# 纯INSERT测试
function insert_test {
    echo $DELIMITER >> $RESULT_FILE
    echo "纯INSERT测试" >> $RESULT_FILE
    echo $DELIMITER >> $RESULT_FILE
    echo "Threads: $THREADS, Time: $TIME, Tables: $TABLES, Table Size: $TABLE_SIZE" >> $RESULT_FILE
    sysbench --db-driver=pgsql \
        --pgsql-host=$PG_HOST \
        --pgsql-port=$PG_PORT \
        --pgsql-user=$PG_USER \
        --pgsql-password=$PG_PASSWORD \
        --pgsql-db=$PG_DB \
        --threads=$THREADS \
        --time=$TIME \
        --report-interval=1 \
        --tables=$TABLES \
        --table_size=$TABLE_SIZE \
        /usr/share/sysbench/oltp_insert.lua run >> $RESULT_FILE
}




function cpu_test {
    #实际核心数/2
    CPU_CORES=$(nproc)
    THREADS=$((CPU_CORES / 2))
    CPU_MAX_PRIME=10000
    echo $DELIMITER >> $RESULT_FILE
    echo "CPU测试" >> $RESULT_FILE
    echo $DELIMITER >> $RESULT_FILE
    echo "Threads: $THREADS, Time: 60, CPU Max Prime: $CPU_MAX_PRIME" >> $RESULT_FILE
    sysbench --time=60 \
        --threads=$THREADS \
        --report-interval=3 \
        --test=cpu \
        --cpu-max-prime=$CPU_MAX_PRIME run >> $RESULT_FILE
}


# 内存测试
function memory_test {
    # 获取系统总内存大小（单位为KB）
    TOTAL_MEM=$(free -k | awk '/Mem:/ {print $2}')
    
    # 设定内存测试大小为系统总内存的50%
    MEMORY_TOTAL_SIZE=$((TOTAL_MEM / 2))K

    echo $DELIMITER >> $RESULT_FILE
    echo "内存测试" >> $RESULT_FILE
    echo $DELIMITER >> $RESULT_FILE
    echo "Threads: 4, Time: 60, Memory Total Size: $MEMORY_TOTAL_SIZE" >> $RESULT_FILE
    sysbench --threads=4 \
        --time=60 \
        --report-interval=1 \
        --test=memory \
        --memory-block-size=8K \
        --memory-total-size=$MEMORY_TOTAL_SIZE \
        --memory-access-mode=seq run >> $RESULT_FILE
}

function index_char_select(){

    echo $DELIMITER >> $RESULT_FILE
    echo "index_char_select" >> $RESULT_FILE
    echo $DELIMITER >> $RESULT_FILE
    echo "Threads: $THREADS, Time: $TIME, Tables: $TABLES, Table Size: $TABLE_SIZE" >> $RESULT_FILE
    sysbench --db-driver=pgsql \
        --pgsql-host=$PG_HOST \
        --pgsql-port=$PG_PORT \
        --pgsql-user=$PG_USER \
        --pgsql-password=$PG_PASSWORD \
        --pgsql-db=$PG_DB \
        --threads=$THREADS \
        --time=$TIME \
        --report-interval=1 \
        --tables=$TABLES \
        --table_size=$TABLE_SIZE \
        /usr/share/sysbench/oltp_index_char_select.lua run >> $RESULT_FILE

}

function index_int_select(){

    echo $DELIMITER >> $RESULT_FILE
    echo "index_int_select" >> $RESULT_FILE
    echo $DELIMITER >> $RESULT_FILE
    echo "Threads: $THREADS, Time: $TIME, Tables: $TABLES, Table Size: $TABLE_SIZE" >> $RESULT_FILE
    sysbench --db-driver=pgsql \
        --pgsql-host=$PG_HOST \
        --pgsql-port=$PG_PORT \
        --pgsql-user=$PG_USER \
        --pgsql-password=$PG_PASSWORD \
        --pgsql-db=$PG_DB \
        --threads=$THREADS \
        --time=$TIME \
        --report-interval=1 \
        --tables=$TABLES \
        --table_size=$TABLE_SIZE \
        /usr/share/sysbench/oltp_index_int_select.lua run >> $RESULT_FILE

}

# 清理数据
function sysbench_clear {
    sysbench --db-driver=pgsql \
        --pgsql-host=$PG_HOST \
        --pgsql-port=$PG_PORT \
        --pgsql-user=$PG_USER \
        --pgsql-password=$PG_PASSWORD \
        --pgsql-db=$PG_DB \
        --threads=$THREADS \
        --report-interval=10 \
        --rand-type=uniform \
        --time=120 \
        --events=0 \
        --percentile=99 \
        /usr/share/sysbench/oltp_common.lua \
        --tables=$TABLES \
        --table_size=$TABLE_SIZE \
        cleanup
}

# 调用函数
prepare_database_test_data
point_select_test
#index_char_select
#index_int_select
insert_test
cpu_test
memory_test
sysbench_clear
```

### 结果处理

获取/root/sysbench/sysbench_test_results.log
