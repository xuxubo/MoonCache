// =================================================================
// =         1. 新的分片缓存工厂和统一接口 (核心代码)              =
// =================================================================

///|
/// 定义支持的分片缓存策略。
pub enum ShardedCachePolicy {
  KHashLRU
  HashLFU
}

///|
/// 统一的分片缓存包装器。
pub enum ShardedCache[K, V] {
  KHashLru(KHashLruCache[K, V])
  HashLfu(HashLfuCache[K, V])
}

///|
/// 统一的 'get' 方法，接收一个用于分片的整数键。
pub fn[K : Eq + Hash, V] ShardedCache::get(
  self : ShardedCache[K, V],
  key : K,
  shard_key : Int,
) -> V? {
  match self {
    KHashLru(cache) => cache.get(key, shard_key)
    HashLfu(cache) => cache.get(key, shard_key)
  }
}

///|
/// 统一的 'put' 方法，接收一个用于分片的整数键。
pub fn[K : Eq + Hash, V] ShardedCache::put(
  self : ShardedCache[K, V],
  key : K,
  value : V,
  shard_key : Int,
) -> Unit {
  match self {
    KHashLru(cache) => cache.put(key, value, shard_key)
    HashLfu(cache) => cache.put(key, value, shard_key)
  }
}

///|
/// **新的分片缓存工厂函数**
/// `num_shards`: 分片的数量。
/// `total_capacity`: 所有分片的总容量。
pub fn[K : Eq + Hash, V] new_sharded_cache(
  policy : ShardedCachePolicy,
  num_shards : Int,
  total_capacity : UInt,
) -> ShardedCache[K, V] {
  match policy {
    ShardedCachePolicy::KHashLRU =>
      ShardedCache::KHashLru(
        KHashLruCache::new(total_capacity.to_int(), num_shards),
      )
    ShardedCachePolicy::HashLFU => {
      // HashLFU 需要 maxAverageNum，我们提供一个默认值
      let max_average_num = total_capacity * 2
      ShardedCache::HashLfu(
        HashLfuCache::new(
          num_shards.reinterpret_as_uint(),
          total_capacity,
          max_average_num,
        ),
      )
    }
  }
}

///|
test "new_sharded_cache_factory_test" {
  // 创建一个4分片、总容量100的 KHashLruCache
  let cache = new_sharded_cache(ShardedCachePolicy::KHashLRU, 4, 100)

  // 假设我们有用户ID，我们用ID来决定分片
  let user_id_1 = 123
  let user_id_2 = 456

  // 将 "user1_data" 放入由 user_id_1 决定的分片中
  cache.put("user1_data", "some_value_1", user_id_1)

  // 将 "user2_data" 放入由 user_id_2 决定的分片中
  cache.put("user2_data", "some_value_2", user_id_2)

  // 从正确的分片获取数据
  assert_eq(cache.get("user1_data", user_id_1), Some("some_value_1"))
  assert_eq(cache.get("user2_data", user_id_2), Some("some_value_2"))

  // 如果用错误的分片键去获取，会找不到数据
  assert_eq(cache.get("user1_data", user_id_2), None)
}
