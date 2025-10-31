# 🌙 MoonCache

**MoonCache** 是一个纯 [MoonBit](https://www.moonbitlang.com/) 实现的高性能内存缓存库。它支持多种主流的缓存淘汰策略，并提供了一套统一、灵活且易于扩展的 API，旨在成为 MoonBit 生态系统中的首选缓存解决方案。

---

## 🚀 特性

- 🧩 **丰富的策略支持**：内置多种缓存淘汰算法，包括 `FIFO`, `LRU`, `LFU`, `ARC`, `LRU-K`, `KHashLRU` 和 `HashLFU`。
- ⚙️ **灵活的 API 设计**：
    - **统一工厂模式**：通过 `new_cache` 函数和 `CachePolicy` 枚举，轻松创建和切换不同策略的缓存实例。
    - **独立实现**：每种缓存策略都可以独立导入和使用，提供了最大的灵活性。
- 🕒 **可选的过期时间 (TTL)**：为缓存条目设置生存时间。（规划中）
- 📊 **缓存指标统计**：获取命中率、淘汰次数等关键性能指标。（规划中）
- 🧵 **并发安全**：为多线程环境提供开箱即用的线程安全缓存。（规划中）

---

## 📦 安装

推荐使用 `moon` 命令行工具直接添加依赖(尚未发布)：

```bash
moon add github.com/yourname/mooncache 
```

或者，你也可以手动克隆本项目到你的 `deps` 目录下：
```bash
git clone https://github.com/yourname/mooncache.git deps/mooncache
```

---

## 💡 快速开始

有两种使用 MoonCache 的方式：

### 1. 使用统一工厂 (推荐)

这是最简单、最灵活的方式，推荐在大多数场景下使用。

```moonbit
test {
  // 使用工厂创建一个容量为 2 的 FIFO 缓存
  let cache = new_cache(CachePolicy::FIFO, 2)
  
  cache.put("x", 100)
  cache.put("y", 200)
  cache.put("z", 300) // "x" 是最早插入的，将被淘汰
  
  assert_eq(cache.get("x"), None)
  assert_eq(cache.get("y"), Some(200))
  assert_eq(cache.get("z"), Some(300))
}
```

### 2. 直接使用具体的缓存实现

如果你明确知道需要哪种策略，也可以直接导入并使用它。

```moonbit

test {
  
  // 创建一个容量为 3 的 LRU 缓存
  let cache : LruCache[String, Int] = LruCache::new(3)

  // 插入三个元素
  cache.put("A", 1)
  cache.put("B", 2)
  cache.put("C", 3)
  println("初始缓存状态：")
  println(cache.get("A"))
  println(cache.get("B"))
  println(cache.get("C"))

  // 访问 A，使其成为最近使用
  let a_val = cache.get("A")
  println(a_val)

  // 插入新元素 D，触发淘汰（应淘汰最久未访问的 B）
  cache.put("D", 4)
  println("插入 D 后：")
  println(cache.get("A"))
  println(cache.get("B")) // 应为 None
  println(cache.get("C"))
  println(cache.get("D"))

  // 更新 A 的值并再次访问
  cache.put("A", 10)
  println(cache.get("A"))
}
```

---

## 🗂️ 模块结构

```
mooncache/
├── moon.mod           # 项目配置文件
├── src/
│   ├── fifo.mbt       # FIFO (先进先出) 策略实现
│   ├── lru.mbt        # LRU (最近最少使用) 策略实现
│   ├── lfu.mbt        # LFU (最不经常使用) 策略实现
│   ├── arc.mbt        # ARC (自适应替换) 策略实现
│   ├── cache_hash.mbt    # HashLRU, HashLFU 等分片缓存实现
│   ├── lru_k.mbt      # LRU-K 策略实现
│   └── cache.mbt    # 统一缓存工厂和接口定义
    
```

---

## 🧪 测试

在项目根目录下运行 MoonBit 的测试命令：

```bash
moon test
```

我们为每种缓存策略和工厂模式都编写了详细的单元测试，以确保其行为的正确性。

---

## 🔭 开发路线图

| 版本   | 核心功能                       | 状态      |
| ------ | ------------------------------ | --------- |
| ✅ v0.1 | 实现 `FIFO`, `LRU`             | ✔️ 已完成 |
| ✅ v0.2 | 增加 `LFU`, `LRU-K` 支持       | ✔️ 已完成 |
| ✅ v0.3 | 实现 `ARC` 和分片缓存          | ✔️ 已完成 |
| ✅ v0.4 | **统一工厂模式**               | ✔️ 已完成 |
| ⏳ v0.5 | 添加 `TTL` (过期时间) 支持     | 🚧 进行中 |
| 
| 💡 v0.6 | 实现缓存指标统计 (`Metrics`)   | 💡 计划中 |
| 💡 v0.7 | 增加并发安全版本 (`sync.Cache`)| 💡 计划中 |
| 🚀 v1.0 | 发布到 MoonPkg 包管理器        | 🚀 计划中 |

---

## 🤝 贡献

我们非常欢迎任何形式的贡献！无论是提交 PR、报告 issue，还是改进文档，都是对项目的巨大帮助。

在提交代码前，请确保：
1.  代码遵循项目现有的风格。
2.  所有测试都通过 (`moon test`)。

---

## 📄 许可证

本项目基于 [Apache License 2.0](LICENSE) 开源。

---

> “A cache beneath the moonlight — fast, simple, and adaptive.” 🌙
