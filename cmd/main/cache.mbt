// =================================================================
// =               1. 统一接口和工厂 (核心代码)                    =
// =================================================================

///|
/// 定义支持的缓存策略。
pub enum CachePolicy {
  FIFO
  LRU
  LFU
  ARC
}

///|
/// 一个统一的缓存包装器，可以持有任何一种具体的缓存实现。
pub enum Cache[K, V] {
  Fifo(FifoCache[K, V])
  Lru(LruCache[K, V])
  Lfu(LfuCache[K, V])
  Arc(ArcCache[K, V])
}

///|
/// 为统一的 Cache 包装器实现 'get' 方法。
/// 它会根据内部持有的具体缓存类型，调用相应的 'get' 方法。
pub fn[K : Eq + Hash, V] Cache::get(self : Cache[K, V], key : K) -> V? {
  match self {
    Fifo(cache) => cache.get(key)
    Lru(cache) => cache.get(key)
    Lfu(cache) => cache.get(key)
    Arc(cache) => cache.get(key)
  }
}

///|
/// 为统一的 Cache 包装器实现 'put' 方法。
pub fn[K : Eq + Hash, V] Cache::put(
  self : Cache[K, V],
  key : K,
  value : V,
) -> Unit {
  match self {
    Fifo(cache) => cache.put(key, value)
    Lru(cache) => cache.put(key, value)
    Lfu(cache) => cache.put(key, value)
    Arc(cache) => cache.put(key, value)
  }
}

///|
/// 返回缓存中的当前元素数量。
pub fn[K : Eq + Hash, V] Cache::size(self : Cache[K, V]) -> Int {
  match self {
    Fifo(cache) => cache.size()
    Lru(cache) => cache.lruNodeLink.size.reinterpret_as_int()
    Lfu(cache) => cache.nodeMap.size()
    Arc(cache) => cache.size()
  }
}

///|
/// **缓存工厂函数**
/// 根据指定的策略和容量创建一个新的缓存实例。
pub fn[K : Eq + Hash, V] new_cache(
  policy : CachePolicy,
  capacity : UInt,
) -> Cache[K, V] {
  match policy {
    CachePolicy::FIFO => Cache::Fifo(FifoCache::new(capacity))
    CachePolicy::LRU => Cache::Lru(LruCache::new(capacity))
    CachePolicy::LFU => {
      // LFU 需要一个额外的参数 `maxAverageNum`，我们这里提供一个合理的默认值。
      let max_average_num = capacity * 2
      Cache::Lfu(LfuCache::new(capacity, max_average_num))
    }
    CachePolicy::ARC => {
      // ARC 也需要额外的参数，我们提供合理的默认值。
      let transform_threshold = capacity / 4 // 例如，当ghost cache达到1/4时转换
      let max_average_num = capacity * 2
      Cache::Arc(ArcCache::new(capacity, transform_threshold, max_average_num))
    }
  }
}

///|
test "cache_factory_fifo_test" {
  // 使用工厂创建一个容量为 2 的 FIFO 缓存
  let cache = new_cache(CachePolicy::FIFO, 2)
  cache.put("x", 100)
  cache.put("y", 200)
  // 此时缓存已满: ["x", "y"]

  // 插入 "z"，"x" 是最早插入的，应该被淘汰
  cache.put("z", 300)
  assert_eq(cache.get("x"), None)
  assert_eq(cache.get("y"), Some(200))
  assert_eq(cache.get("z"), Some(300))
}

///|
test "cache_factory_lru_test" {
  // 使用工厂创建一个容量为 2 的 LRU 缓存
  let cache = new_cache(CachePolicy::LRU, 2)
  cache.put("x", 100)
  cache.put("y", 200)
  // 此时缓存: ["x", "y"] (y是最近使用的)

  // 访问 "x"，使其变为最近使用的
  let _ = cache.get("x")
  // 此时缓存: ["y", "x"] (x是最近使用的)

  // 插入 "z"，此时 "y" 是最久未使用的，应该被淘汰
  cache.put("z", 300)
  assert_eq(cache.get("y"), None)
  assert_eq(cache.get("x"), Some(100))
  assert_eq(cache.get("z"), Some(300))
}

///|
test "cache_factory_lfu_test" {
  // 使用工厂创建一个容量为 3 的 LFU 缓存
  let cache = new_cache(CachePolicy::LFU, 3)

  // 1. 插入三个元素，填满缓存
  cache.put("a", 1)
  cache.put("b", 2)
  cache.put("c", 3)
  // 当前频率: a=1, b=1, c=1

  // 2. 增加 a 和 b 的访问频率
  let _ = cache.get("a") // a=2, b=1, c=1
  let _ = cache.get("a") // a=3, b=1, c=1
  let _ = cache.get("b") // a=3, b=2, c=1
  // 此时，"c" 是访问频率最低的元素

  // 3. 插入新元素 "d"，这将触发淘汰
  // 因为 "c" 的频率最低，所以它应该被淘汰
  cache.put("d", 4)

  // 4. 验证结果
  assert_eq(cache.get("c"), None) // c 被淘汰
  assert_eq(cache.get("a"), Some(1)) // a 还在
  assert_eq(cache.get("b"), Some(2)) // b 还在
  assert_eq(cache.get("d"), Some(4)) // d 成功插入
}

///|
test "cache_factory_arc_test" {
  // 使用工厂创建一个容量为 3 的 ARC 缓存
  let cache = new_cache(CachePolicy::ARC, 3)

  // 1. 插入三个元素，它们最初都在 LRU 分区 (T1)
  cache.put("a", 1)
  cache.put("b", 2)
  cache.put("c", 3)
  // T1 内部顺序 (最老 -> 最新): a, b, c

  // 2. 访问 "b"。这是一个 T1 命中，"b" 会被晋升到 LFU 分区 (T2)
  let _ = cache.get("b")
  // 此时状态: T1 = {"a", "c"}, T2 = {"b"}
  // 在 T1 中，"a" 是最久未被使用的

  // 3. 插入新元素 "d"，这将触发淘汰
  // ARC 优先淘汰 LRU 分区(T1)的元素，因此 "a" 会被淘汰
  cache.put("d", 4)

  // 4. 验证结果
  assert_eq(cache.get("a"), None) // a 被淘汰
  assert_eq(cache.get("b"), Some(2)) // b (在T2中) 被保留
  assert_eq(cache.get("c"), Some(3)) // c (在T1中) 被保留
  assert_eq(cache.get("d"), Some(4)) // d 成功插入 T1
}
