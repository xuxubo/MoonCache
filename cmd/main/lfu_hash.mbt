///|
pub struct HashLfuCache[Key, Value] {
  sliceNum : UInt
  capacity : UInt
  shards : Array[LfuCache[Key, Value]]
}

///|
pub fn[Key : Eq + Hash, Value] HashLfuCache::new(
  sliceNum : UInt,
  capacity : UInt,
  maxAverageNum : UInt,
) -> HashLfuCache[Key, Value] {
  let sliceSize = capacity / sliceNum
  let shards = Array::new(capacity=sliceNum.reinterpret_as_int())
  for i = 0; i < sliceSize.reinterpret_as_int(); i = i + 1 {
    let node : LfuCache[Key, Value] = LfuCache::new(sliceSize, maxAverageNum)
    shards.push(node)
  }
  HashLfuCache::{ sliceNum, capacity, shards }
}

///|
/// 内部辅助函数：根据 key 计算所在分片
fn[Key, Value] HashLfuCache::get_shard_index(
  self : HashLfuCache[Key, Value],
  key : UInt,
) -> UInt {
  key % self.sliceNum
}

///|
/// 获取 key 对应的值
pub fn[Key : Eq + Hash, Value] HashLfuCache::get(
  self : HashLfuCache[Key, Value],
  key : Key,
  capacity : Int,
) -> Value? {
  let idx = self.get_shard_index(capacity.reinterpret_as_uint())
  let shard = self.shards[idx.reinterpret_as_int()]
  shard.get(key)
}

///|
pub fn[Key : Eq + Hash, Value] HashLfuCache::put(
  self : HashLfuCache[Key, Value],
  key : Key,
  value : Value,
  capacity : Int,
) -> Unit {
  let idx = self.get_shard_index(capacity.reinterpret_as_uint())
  let shard = self.shards[idx.reinterpret_as_int()]
  shard.put(key, value)
}

///|
pub fn[Key : Eq + Hash, Value] HashLfuCache::purge(
  self : HashLfuCache[Key, Value],
) -> Unit {
  for nodeList in self.shards {
    nodeList.purge()
  }
}
