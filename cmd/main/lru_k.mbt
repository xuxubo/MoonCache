///|
pub struct LruKCache[K, V] {
  lrucache : LruCache[K, V]
  historyValueMap : Map[K, V]
  k : UInt
  historyList : LruCache[K, UInt]
}

///|
pub fn[K, V] LruKCache::new(
  capacity : UInt,
  historyCapacity : UInt,
  k : UInt,
) -> LruKCache[K, V] {
  let lrucache : LruCache[K, V] = LruCache::new(capacity)
  let historyValueMap : Map[K, V] = Map::new()
  let historyList : LruCache[K, UInt] = LruCache::new(historyCapacity)
  LruKCache::{ lrucache, historyValueMap, k, historyList }
}

///|
pub fn[K : Eq + Hash, V] LruKCache::get(self : LruKCache[K, V], key : K) -> V? {
  // 1. 尝试从主缓存获取
  let value = self.lrucache.get(key)

  // 2. 更新访问计数
  let mut historyCount = self.historyList.get(key).unwrap_or(0)
  historyCount += 1
  self.historyList.put(key, historyCount)

  // 3. 如果在主缓存中，直接返回
  if value is Some(_) {
    return value
  }

  // 4. 未命中主缓存，判断是否达到 K 次访问
  if historyCount >= self.k {
    match self.historyValueMap.get(key) {
      Some(node) => {
        let val = node
        self.historyList.remove(key)
        self.historyValueMap.remove(key)
        self.lrucache.put(key, val)
        return Some(val)
      }
      None => return None
    }
  }

  // 5. 未命中主缓存，访问次数未达 k
  return None
}

///|
pub fn[K : Eq + Hash, V] LruKCache::put(
  self : LruKCache[K, V],
  key : K,
  value : V,
) -> Unit {
  let existValue = self.lrucache.get(key)
  if existValue is Some(_) {
    self.lrucache.put(key, value)
    return
  }
  let mut historyCount = self.historyList.get(key).unwrap_or(0)
  historyCount += 1
  self.historyList.put(key, historyCount)
  self.historyValueMap.set(key, value)
  if historyCount >= self.k {
    self.historyList.remove(key)
    self.historyValueMap.remove(key)
    self.lrucache.put(key, value)
  }
}
