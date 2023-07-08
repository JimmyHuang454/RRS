# RRS 一个基于 Trojan 协议的代理工具 （BETA）

JLS V3 可尝试 [sing-box](https://github.com/JimmyHuang454/sing-box)
---
# 快速上手 JLS V2
## Server
假设使用Ubuntu，确保有root权限，直接运行下面指令即可，
```bash
bash <(curl https://raw.githubusercontent.com/JimmyHuang454/RRS/master/tools/install.sh)
```

安装成功后，会得到一串密码和随机数，端口默认443。

类似这样，记得保存好。
```bash
....
password: 123124293489023745908237
random: 123124293489023745908237
.....
```

## Client

假设你本机使用的是Windows，去[下载页面](https://github.com/JimmyHuang454/RRS/releases)，选择最新版本的 RRS_Windows.zip，解压到本机。你会看到一个config.json文件，类似这样：
```json
{
  "outbounds": {
    "jls": {
      "protocol": "jls",
      "setting": {
        "address": "0.0.0.0", // 填写server的IP地址
        "port": 443,  // server 的端口
        "password": "123", // 复制粘贴Server的密码和随机数
        "random": "123"
      }
    }
  }
}
```

里面的 address，password 和random 要根据实际的server配置来填写（也就是生成的密码和随机数）。

最后，直接在运行 RRS_Windows.exe 即可。默认开放本机的 8183 端口作为 HTTP 代理入口，用户自行设置系统代理即可使用。

---
## [JLS](https://github.com/JimmyHuang454/JLS) 说明
目前 JLS的支持还在实验阶段，可能会随时改变或更新！

RRS 完整实现 JLS 协议，从网络协议栈看，JLS 应该是与 TLS 同层，但是 RRS 中的实现是基于 Trojan，去除了 Trojan 的前 58 个验证字节（其余逻辑与Trojan一样）。又因为 dart 编程语言的 Stream 特性，只要内存足够，就会不断接受输入（也就是不限制 buffer 大小），导致测速的时候会暴涨内存，待处理完所有流后自动恢复正常。

https://app.codecov.io/gh/JimmyHuang454/RRS
