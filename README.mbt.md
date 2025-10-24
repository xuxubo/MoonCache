# 🌙 MoonCache

**MoonCache** 是一个用 [MoonBit](https://www.moonbitlang.com/) 编写的高性能本地缓存库，  
支持多种缓存淘汰算法（FIFO、LRU、LFU、LRU-K、HashLRU、ARC 等），  
旨在为 MoonBit 提供统一、可扩展且轻量的缓存基础设施。

---

## 🚀 特性

- 🧩 **多策略支持**：FIFO / LRU / LFU / LRU-K / HashLRU / ARC  
- ⚙️ **统一接口设计**：基于 `Cache` trait 的多态策略切换  
- 🕒 **可选过期时间 (TTL)** 支持  
- 📊 **缓存统计**：命中率、淘汰次数、容量使用情况  
- 🧵 **并发安全（规划中）**  
- 💾 **轻量持久化（规划中）**  

---

## 📦 安装

假设你的项目结构如下：

```
my_project/
 ├── src/
 ├── moon.mod
 └── deps/
     └── mooncache/
```

将 `MoonCache` 克隆到 `deps/` 下：

```bash
git clone https://github.com/yourname/mooncache.git deps/mooncache
```

然后在你的 `moon.mod` 中添加依赖：

```toml
[dependencies]
mooncache = "./deps/mooncache"
```

---

## 🧠 快速开始

```moonbit
import mooncache.cache
import mooncache.fifo
import mooncache.lru

fn main() {
    // 使用 LRU 策略创建缓存
    let mut cache = LRUCache::new(3)
    cache.put("a", 1)
    cache.put("b", 2)
    cache.put("c", 3)

    print(cache.get("a"))  // Some(1)
    cache.put("d", 4)      // 淘汰最早未使用的 key
    print(cache.get("b"))  // None (被淘汰)
}
```

或使用统一工厂接口：

```moonbit
import mooncache.factory

let mut cache = new_cache(CachePolicy::FIFO, 2)
cache.put("x", 100)
cache.put("y", 200)
cache.put("z", 300)

assert_eq!(cache.get("x"), None)
```

---

## 🧩 模块结构

```
mooncache/
├── src/
│   ├── cache.mbt       # Trait & CachePolicy 定义
│   ├── fifo.mbt        # FIFO 策略
│   ├── lru.mbt         # LRU 策略
│   ├── lfu.mbt         # LFU 策略
│   ├── arc.mbt         # ARC 策略
│   └── factory.mbt     # 工厂模式创建器
└── test/
    └── cache_test.mbt
```

---

## 🧪 测试

使用 MoonBit 自带测试框架运行：

```bash
moon test
```

示例：

```moonbit
test "FIFO eviction" {
    let mut cache = FIFOCache::new(2)
    cache.put("a", 1)
    cache.put("b", 2)
    cache.put("c", 3)

    assert_eq!(cache.get("a"), None)
    assert_eq!(cache.get("b"), Some(2))
}
```

---

## 🔭 开发路线图

| 阶段   | 功能                        | 状态     |
| ------ | --------------------------- | -------- |
| ✅ v0.1 | 实现 FIFO / LRU             | ✔️ 完成   |
| ✅ v0.2 | 增加 LFU / LRU-K 支持       | ⏳ 进行中 |
| 🔜 v0.3 | 支持 ARC / HashLRU          | 🔜 计划中 |
| 🔜 v0.4 | 添加 TTL / Metrics / 并发锁 | 🔜 计划中 |
| 🔜 v0.5 | 发布 MoonPkg 包             | 🔜 计划中 |

---

## 🤝 贡献指南

欢迎提交 PR 或 issue！  
请确保你的代码通过 `moon test` 并遵循项目代码风格。

---

## 📄 许可证

本项目基于 [Apache License 2.0](LICENSE) 开源。

---

## 💬 作者

**MoonCache** 由 MoonBit 爱好者社区开发维护。  
欢迎加入我们，一起完善 MoonBit 生态系统！🌕

---

> “A cache beneath the moonlight — fast, simple, and adaptive.” 🌙
