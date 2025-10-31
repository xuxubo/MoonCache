///|
pub struct KHashLruCache[Key, Value] {
  shards : Array[LruCache[Key, Value]]
  num_shards : Int
}

///|
/// 创建一个带分片的 LRU-Key 缓存
/// capacity 为每个分片的容量
pub fn[Key : Eq + Hash, Value] KHashLruCache::new(
  total_capacity : Int,
  num_shards : Int,
) -> KHashLruCache[Key, Value] {
  let per_shard_capacity = total_capacity / num_shards
  let shards = Array::new(capacity=num_shards)
  for i = 0; i < num_shards; i = i + 1 {
    let node : LruCache[Key, Value] = LruCache::new(
      per_shard_capacity.reinterpret_as_uint(),
    )
    shards.push(node)
  }
  KHashLruCache::{ shards, num_shards }
}

///|
/// 内部辅助函数：根据 key 计算所在分片
fn[Key, Value] KHashLruCache::get_shard_index(
  self : KHashLruCache[Key, Value],
  key : Int,
) -> Int {
  key % self.num_shards
}

///|
/// 获取 key 对应的值
pub fn[Key : Eq + Hash, Value] KHashLruCache::get(
  self : KHashLruCache[Key, Value],
  key : Key,
  capacity : Int,
) -> Value? {
  let idx = self.get_shard_index(capacity)
  let shard = self.shards[idx]
  shard.get(key)
}

///|
/// 插入或更新一个键值对
pub fn[Key : Eq + Hash, Value] KHashLruCache::put(
  self : KHashLruCache[Key, Value],
  key : Key,
  value : Value,
  capacity : Int,
) -> Unit {
  let idx = self.get_shard_index(capacity)
  let shard = self.shards[idx]
  shard.put(key, value)
}
