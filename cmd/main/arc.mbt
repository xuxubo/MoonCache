///|
pub struct ArcLruPart[Key, Value] {
  mut capacity : UInt
  ghostCapacity : UInt
  transformThreshold : UInt
  mainCache : LruCache[Key, Value]
  ghostCache : LruCache[Key, Value]
}

///|
pub fn[Key, Value] ArcLruPart::new(
  capacity : UInt,
  transformThreshold : UInt,
) -> ArcLruPart[Key, Value] {
  let mainCache = LruCache::new(capacity)
  let ghostCapacity = capacity
  let ghostCache = LruCache::new(ghostCapacity)
  ArcLruPart::{
    capacity,
    ghostCapacity,
    transformThreshold,
    mainCache,
    ghostCache,
  }
}

///|
pub fn[Key : Hash + Eq, Value] ArcLruPart::checkGhost(
  self : ArcLruPart[Key, Value],
  key : Key,
) -> Bool {
  let it = self.ghostCache.nodeMap.get(key)
  if it is Some(_) {
    self.ghostCache.removeNode(it.unwrap())
    self.ghostCache.nodeMap.remove(key)
    true
  } else {
    false
  }
}

///|
pub fn[Key, Value] ArcLruPart::increaseCapacity(
  self : ArcLruPart[Key, Value],
) -> Unit {
  self.capacity += 1
}

///|
pub fn[Key : Hash + Eq, Value] ArcLruPart::decreaseCapacity(
  self : ArcLruPart[Key, Value],
) -> Bool {
  if self.capacity == 0 {
    return false
  }
  if self.mainCache.nodeMap.size() == self.capacity.reinterpret_as_int() {
    let leastRecent = self.mainCache.popLeastRecent()
    if self.ghostCache.nodeMap.size() >=
      self.ghostCache.capacity.reinterpret_as_int() {
      self.ghostCache.evictLeastRecent()
    }
    self.ghostCache.addNewNode(leastRecent.unwrap())
  }
  self.capacity -= 1
  true
}

///|
pub struct ArcLfuPart[Key, Value] {
  mut capacity : UInt
  ghostCapacity : UInt
  transformThreshold : UInt
  mainCache : LfuCache[Key, Value]
  ghostCache : LfuCache[Key, Value]
}

///|
pub fn[Key, Value] ArcLfuPart::new(
  capacity : UInt,
  transformThreshold : UInt,
  maxAverageNum : UInt,
) -> ArcLfuPart[Key, Value] {
  let mainCache = LfuCache::new(capacity, maxAverageNum)
  let ghostCapacity = capacity
  let ghostCache = LfuCache::new(ghostCapacity, maxAverageNum)
  ArcLfuPart::{
    capacity,
    ghostCapacity,
    transformThreshold,
    mainCache,
    ghostCache,
  }
}

///|
pub fn[Key : Hash + Eq, Value] ArcLfuPart::checkGhost(
  self : ArcLfuPart[Key, Value],
  key : Key,
) -> Bool {
  let it = self.ghostCache.nodeMap.get(key)
  if it is Some(_) {
    self.ghostCache.removeFromFreqList(it.unwrap())
    self.ghostCache.nodeMap.remove(key)
    true
  } else {
    false
  }
}

///|
pub fn[Key, Value] ArcLfuPart::increaseCapacity(
  self : ArcLfuPart[Key, Value],
) -> Unit {
  self.capacity += 1
}

///|
pub fn[Key : Hash + Eq, Value] ArcLfuPart::decreaseCapacity(
  self : ArcLfuPart[Key, Value],
) -> Bool {
  if self.capacity == 0 {
    return false
  }
  if self.mainCache.nodeMap.size() == self.capacity.reinterpret_as_int() {
    let leastRecent = self.mainCache.popLeastFrequent()
    if self.ghostCache.nodeMap.size() >=
      self.ghostCache.capacity.reinterpret_as_int() {
      self.ghostCache.evictLeastFrequent()
    }
    self.ghostCache.addToFreqList(leastRecent.unwrap())
  }
  self.capacity -= 1
  true
}

///|
pub struct ArcCache[Key, Value] {
  capacity : UInt
  transformThreshold : UInt
  lruPart : ArcLruPart[Key, Value]
  lfuPart : ArcLfuPart[Key, Value]
}

///|
pub fn[Key, Value] ArcCache::new(
  capacity : UInt,
  transformThreshold : UInt,
  maxAverageNum : UInt,
) -> ArcCache[Key, Value] {
  let lruPart = ArcLruPart::new(capacity, transformThreshold)
  let lfuPart = ArcLfuPart::new(capacity, transformThreshold, maxAverageNum)
  ArcCache::{ capacity, transformThreshold, lruPart, lfuPart }
}

///|
/// 返回缓存中当前存储的键值对总数。
pub fn[Key, Value] ArcCache::size(self : ArcCache[Key, Value]) -> Int {
  self.lruPart.mainCache.nodeMap.size() + self.lfuPart.mainCache.nodeMap.size()
}

///|
pub fn[Key : Eq + Hash, Value] ArcCache::checkGhostCaches(
  self : ArcCache[Key, Value],
  key : Key,
) -> Bool {
  let mut inGhost = false
  if self.lruPart.checkGhost(key) {
    if self.lfuPart.decreaseCapacity() {
      self.lruPart.increaseCapacity()
    }
    inGhost = true
  } else if self.lfuPart.checkGhost(key) {
    if self.lruPart.decreaseCapacity() {
      self.lfuPart.increaseCapacity()
    }
    inGhost = true
  }
  inGhost
}

///|
pub fn[Key : Eq + Hash, Value] ArcCache::get(
  self : ArcCache[Key, Value],
  key : Key,
) -> Value? {
  let _ = self.checkGhostCaches(key)

  // 步骤 2: 尝试从 LRU 部分获取
  let lruNodeOpt = self.lruPart.mainCache.nodeMap.get(key)
  if lruNodeOpt is Some(lruNode) {
    // 在 LRU 部分命中 (T1 Hit) -> 提升到 LFU 部分 (T2)
    let value = lruNode.value.unwrap()

    // 从 LRU 中移除
    self.lruPart.mainCache.removeNode(lruNode)
    self.lruPart.mainCache.nodeMap.remove(key)

    // 添加到 LFU 中
    // `putInternal` 会处理 LFU 已满时的情况（淘汰 LFU 中频率最低的节点）
    self.lfuPart.mainCache.putInternal(key, value)
    return Some(value)
  }

  // 步骤 3: 如果 LRU 未命中，则尝试从 LFU 部分获取
  let lfuNodeOpt = self.lfuPart.mainCache.nodeMap.get(key)
  if lfuNodeOpt is Some(lfuNode) {
    // `getInternal` 负责更新频率和节点位置
    self.lfuPart.mainCache.getInternal(lfuNode)
    return lfuNode.value
  }

  // 步骤 4: LRU 和 LFU 都未命中
  return None
}

///|
pub fn[Key : Eq + Hash, Value] ArcCache::put(
  self : ArcCache[Key, Value],
  key : Key,
  value : Value,
) -> Unit {
  // 步骤 1: 检查幽灵缓存
  let _ = self.checkGhostCaches(key)
  // 步骤 2: 检查 key 是否已存在于 LFU 或 LRU 部分 (更新逻辑)
  let lfuNodeOpt = self.lfuPart.mainCache.nodeMap.get(key)
  if lfuNodeOpt is Some(lfuNode) {
    lfuNode.value = Some(value)
    self.lfuPart.mainCache.getInternal(lfuNode)
    return
  }
  let lruNodeOpt = self.lruPart.mainCache.nodeMap.get(key)
  if lruNodeOpt is Some(lruNode) {
    self.lruPart.mainCache.removeNode(lruNode)
    self.lruPart.mainCache.nodeMap.remove(key)
    self.lfuPart.mainCache.putInternal(key, value)
    return
  }
  // 步骤 3: Key 是全新的 (插入逻辑)
  let totalSize = self.lruPart.mainCache.nodeMap.size() +
    self.lfuPart.mainCache.nodeMap.size()
  // 检查是否需要淘汰
  if totalSize >= self.capacity.reinterpret_as_int() {
    // 如果 LRU part 不为空，则优先从中淘汰
    if self.lruPart.mainCache.lruNodeLink.size > 0 {
      let evictedNodeOpt = self.lruPart.mainCache.popLeastRecent()
      if evictedNodeOpt is Some(evictedNode) {
        if evictedNode.key is Some(k) && evictedNode.value is Some(v) {
          self.lruPart.ghostCache.put(k, v)
        }
      }
    } else {
      // 否则，从 LFU part 淘汰频率最低的
      let evictedNodeOpt = self.lfuPart.mainCache.popLeastFrequent()
      if evictedNodeOpt is Some(evictedNode) {
        if evictedNode.key is Some(k) && evictedNode.value is Some(v) {
          self.lfuPart.ghostCache.put(k, v)
        }
      }
    }
  }
  // 将新节点加入 LRU part (T1)
  self.lruPart.mainCache.put(key, value)
}

// =================================================================
// =                         测试用例                           =
// =================================================================

///|
test "new_cache_is_empty" {
  let cache = ArcCache::new(10, 0, 10)
  assert_eq(cache.size(), 0)
  assert_eq(cache.get(1), None)
}

///|
test "put_and_get_single_item" {
  let cache = ArcCache::new(10, 0, 10)
  cache.put(1, "hello")
  assert_eq(cache.size(), 1)
  assert_eq(cache.get(1), Some("hello"))
}

///|
test "update_existing_item" {
  let cache = ArcCache::new(10, 0, 10)
  cache.put(1, "hello")
  cache.put(1, "world") // 更新值
  assert_eq(cache.size(), 1)
  assert_eq(cache.get(1), Some("world"))
}

///|
test "get_non_existent_key_returns_none" {
  let cache = ArcCache::new(2, 0, 10)
  cache.put(1, "a")
  assert_eq(cache.get(2), None)
}

///|
test "lru_eviction_on_capacity_breach" {
  // 创建一个容量为2的缓存
  let cache = ArcCache::new(2, 0, 10)

  // 1. 插入 "a" 和 "b"，此时它们都在 LRU part
  cache.put(1, "a")
  cache.put(2, "b")
  assert_eq(cache.size(), 2)
  assert_eq(cache.get(1), Some("a")) // 访问 "a"，使其移动到 LFU part

  // 2. 此时缓存状态: LFU={"a"}, LRU={"b"}
  cache.put(3, "c") // 插入 "c"

  // 3. 总容量超过2，需要淘汰。ARC 优先淘汰 LRU part 的内容
  //    因此 "b" 会被淘汰。
  assert_eq(cache.size(), 2)
  assert_eq(cache.get(1), Some("a")) // "a" 应该还在
  assert_eq(cache.get(2), None) // "b" 应该被淘汰了
  assert_eq(cache.get(3), Some("c")) // "c" 应该在 LRU part
}

///|
test "promotion_from_lru_to_lfu" {
  let cache = ArcCache::new(3, 0, 10)

  // 1. 插入三个元素，它们最初都在 LRU part
  cache.put(1, "a")
  cache.put(2, "b")
  cache.put(3, "c")

  // 2. 访问 "a"，这会把它从 LRU part 提升到 LFU part
  let val = cache.get(1)
  assert_eq(val, Some("a"))

  // 3. 插入一个新元素 "d"，这将导致淘汰
  //    因为 "a" 已经在 LFU part，它有更高的优先级被保留
  //    淘汰应该发生在 LRU part，最老的是 "b"
  cache.put(4, "d")

  // 4. 验证结果
  assert_eq(cache.size(), 3)
  assert_eq(cache.get(1), Some("a")) // "a" 依然存在
  assert_eq(cache.get(2), None) // "b" 被淘汰
  assert_eq(cache.get(3), Some("c")) // "c" 还在
  assert_eq(cache.get(4), Some("d")) // "d" 成功插入
}

///|
test "lfu_hit_increases_frequency_and_avoids_eviction" {
  let cache = ArcCache::new(3, 0, 10)

  // 1. 插入 "a", "b", "c"
  cache.put(1, "a")
  cache.put(2, "b")
  cache.put(3, "c")

  // 2. 将它们全部提升到 LFU part
  let _ = cache.get(1) // a -> LFU
  let _ = cache.get(2) // b -> LFU
  let _ = cache.get(3) // c -> LFU
  // 此时 LRU part 为空，所有元素都在 LFU part

  // 3. 大量访问 "a"，使其频率远高于 "b" 和 "c"
  let _ = cache.get(1)
  let _ = cache.get(1)
  let _ = cache.get(1)

  // 4. 插入一个新元素 "d"。由于 LRU part 为空，将从 LFU part 淘汰。
  //    LFU part 中频率最低的是 "b"（因为它在"c"之前被访问）
  cache.put(4, "d")

  // 5. 验证结果
  assert_eq(cache.size(), 3)
  assert_eq(cache.get(1), Some("a")) // "a" (最高频) 必须存在
  assert_eq(cache.get(2), None) // "b" (最低频) 应该被淘汰
  assert_eq(cache.get(3), Some("c")) // "c" 还在
  assert_eq(cache.get(4), Some("d")) // "d" 成功插入 LRU part
}

///|
test "update_value_in_lfu_part" {
  let cache = ArcCache::new(2, 0, 10)
  cache.put(1, "a")

  // 提升到 LFU
  let _ = cache.get(1)

  // 插入另一项
  cache.put(2, "b")

  // 更新在 LFU 中的 "a"
  cache.put(1, "a_updated")
  assert_eq(cache.size(), 2)
  assert_eq(cache.get(1), Some("a_updated"))
  assert_eq(cache.get(2), Some("b"))
}
