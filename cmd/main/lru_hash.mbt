///|
pub struct KHashLruCache[K, V] {
  shards : Array[LruCache[K, V]]
  num_shards : Int
}

///|
/// 创建一个带分片的 LRU-K 缓存
/// capacity 为每个分片的容量
pub fn[K : Eq + Hash, V] KHashLruCache::new(
  total_capacity : Int,
  num_shards : Int,
) -> KHashLruCache[K, V] {
  let per_shard_capacity = total_capacity / num_shards
  let shards = Array::new(capacity=num_shards)
  for i = 0; i < num_shards; i = i + 1 {
    let node : LruCache[K, V] = LruCache::new(
      per_shard_capacity.reinterpret_as_uint(),
    )
    shards[i] = node
  }
  KHashLruCache::{ shards, num_shards }
}

///|
/// 内部辅助函数：根据 key 计算所在分片
fn[K, V] KHashLruCache::get_shard_index(
  self : KHashLruCache[K, V],
  key : Int,
) -> Int {
  key % self.num_shards
}

///|
/// 获取 key 对应的值
pub fn[K : Eq + Hash, V] KHashLruCache::get(
  self : KHashLruCache[K, V],
  key : K,
  capacity : Int,
) -> V? {
  let idx = self.get_shard_index(capacity)
  let shard = self.shards[idx]
  shard.get(key)
}

///|
/// 插入或更新一个键值对
pub fn[K : Eq + Hash, V] KHashLruCache::put(
  self : KHashLruCache[K, V],
  key : K,
  value : V,
  capacity : Int,
) -> Unit {
  let idx = self.get_shard_index(capacity)
  let shard = self.shards[idx]
  shard.put(key, value)
}
