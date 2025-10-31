///|
pub struct LruKCache[Key, Value] {
  lrucache : LruCache[Key, Value]
  history_value_map : Map[Key, Value]
  k : UInt
  history_capacity : UInt
  history_count : Map[Key, UInt]
}

///|
/// 创建新的 LRU-Key 缓存
pub fn[Key, Value] LruKCache::new(
  capacity : UInt,
  k : UInt,
  history_capacity : UInt,
) -> LruKCache[Key, Value] {
  let lrucache = LruCache::new(capacity)
  let history_value_map = Map::new()
  let history_count = Map::new()
  LruKCache::{ lrucache, history_value_map, k, history_capacity, history_count }
}

///|
/// 获取键对应的值
pub fn[Key : Eq + Hash, Value] LruKCache::get(
  self : LruKCache[Key, Value],
  key : Key,
) -> Value? {
  // 1️⃣ 尝试直接从主缓存获取
  match self.lrucache.get(key) {
    Some(value) => return Some(value)
    None => ()
  }

  // 2️⃣ 更新访问次数
  let count = match self.history_count.get(key) {
    Some(v) => v + 1
    None => 1
  }
  self.history_count.set(key, count)

  // 3️⃣ 如果未命中主缓存但访问次数达到 k 次，从历史中加载到主缓存
  if count >= self.k {
    match self.history_value_map.get(key) {
      Some(value) => {
        let val = value
        self.history_value_map.remove(key)
        self.history_count.remove(key)
        self.lrucache.put(key, val)
        return Some(val)
      }
      None => ()
    }
  }
  None
}

///|
/// 插入键值对
pub fn[Key : Eq + Hash, Value] LruKCache::put(
  self : LruKCache[Key, Value],
  key : Key,
  value : Value,
) -> Unit {
  // 1️⃣ 如果主缓存中已存在，则更新
  match self.lrucache.get(key) {
    Some(_) => {
      self.lrucache.put(key, value)
      return
    }
    None => ()
  }

  // 2️⃣ 更新访问次数
  let count = match self.history_count.get(key) {
    Some(v) => v + 1
    None => 1
  }
  self.history_count.set(key, count)
  self.history_value_map.set(key, value)

  // 3️⃣ 达到 k 次访问后进入主缓存
  if count >= self.k {
    self.history_count.remove(key)
    self.history_value_map.remove(key)
    self.lrucache.put(key, value)
  }
}

///|
test {
  println("==== LRU Cache 测试开始 ====")

  // 创建一个容量为 3 的 LRU 缓存
  let cache = LruKCache::new(3, 1, 3)

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

  // 再插入 E，检查淘汰逻辑（此时应淘汰 C）
  cache.put("E", 5)
  println("插入 E 后：")
  println(cache.get("A"))
  println(cache.get("C")) // 应为 None
  println(cache.get("D"))
  println(cache.get("E"))
  println("==== 测试结束 ====")
}
