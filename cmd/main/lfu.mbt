///|
pub struct LfuNode[Key, Value] {
  key : Key?
  mut value : Value?
  mut freq : UInt
  mut prev : Ref[LfuNode[Key, Value]]?
  mut next : Ref[LfuNode[Key, Value]]?
}

///|
pub fn[Key, Value] LfuNode::new(
  key : Key,
  value : Value,
) -> LfuNode[Key, Value] {
  let freq = 1U
  let key = Some(key)
  let value = Some(value)
  LfuNode::{ key, value, freq, prev: None, next: None }
}

///|
pub struct LfuNodeList[Key, Value] {
  head : Ref[LfuNode[Key, Value]]
  tail : Ref[LfuNode[Key, Value]]
  mut size : UInt
}

///|
pub fn[Key, Value] LfuNodeList::new() -> LfuNodeList[Key, Value] {
  let freq = 1U
  let head = Ref::new(LfuNode::{
    key: None,
    value: None,
    freq,
    prev: None,
    next: None,
  })
  let tail = Ref::new(LfuNode::{
    key: None,
    value: None,
    freq,
    prev: None,
    next: None,
  })
  head.val.next = Some(tail)
  tail.val.prev = Some(head)
  LfuNodeList::{ head, tail, size: 0 }
}

///|
pub fn[Key, Value] LfuNodeList::isEmpty(self : LfuNodeList[Key, Value]) -> Bool {
  self.size == 0
}

///|
pub fn[K, V] LfuNodeList::insertNode(
  self : LfuNodeList[K, V],
  node : Ref[LfuNode[K, V]],
) -> Unit { //尾部插入节点
  // 取 dummyTail 之前的节点
  let prevNode = self.tail.val.prev.unwrap()

  // 调整指针关系：prevNode <-> node <-> dummyTail
  prevNode.val.next = Some(node)
  node.val.prev = Some(prevNode)
  node.val.next = Some(self.tail)
  self.tail.val.prev = Some(node)
  self.size += 1
}

///|
pub fn[K, V] LfuNodeList::removeNode(
  self : LfuNodeList[K, V],
  node : Ref[LfuNode[K, V]],
) -> Unit {
  let prevNode = node.val.prev.unwrap()
  let nextNode = node.val.next.unwrap()

  // 把前后节点连起来
  prevNode.val.next = Some(nextNode)
  nextNode.val.prev = Some(prevNode)

  // 断开自身链接
  node.val.prev = None
  node.val.next = None
  self.size -= 1
}

///|
pub fn[K, V] LfuNodeList::getFirstNode(
  self : LfuNodeList[K, V],
) -> LfuNode[K, V] {
  let a = self.head.val
  a.next.unwrap().val
}

///|
pub struct LfuCache[K, V] {
  nodeMap : Map[K, LfuNode[K, V]]
  capacity : UInt
  lruNodeLink : LfuNodeList[K, V]
  freqToFreqList : Map[UInt, LfuNodeList[K, V]]
  mut minFreq : UInt
  maxAverageNum : UInt
  mut curAverageNum : UInt
  mut curTotalNum : UInt
}

///|
pub fn[K, V] LfuCache::new(
  capacity : UInt,
  maxAverageNum : UInt,
) -> LfuCache[K, V] {
  let nodeMap : Map[K, LfuNode[K, V]] = Map::new()
  let lruNodeLink = LfuNodeList::new()
  let freqToFreqList : Map[UInt, LfuNodeList[K, V]] = Map::new()
  let minFreq = maxAverageNum
  LfuCache::{
    nodeMap,
    capacity,
    lruNodeLink,
    freqToFreqList,
    minFreq,
    maxAverageNum,
    curAverageNum: 0U,
    curTotalNum: 0U,
  }
}

///|
pub fn[K : Eq + Hash, V] LfuCache::getInternal(
  self : LfuCache[K, V],
  node : LfuNode[K, V],
) -> Unit {
  self.removeFromFreqList(node)
  node.freq += 1
  self.addToFreqList(node)
  if node.freq - 1 == self.minFreq &&
    self.freqToFreqList.get(node.freq - 1).is_empty() {
    self.minFreq += 1
  }
  self.addFreqNum()
}

///|
pub fn[K : Eq + Hash, V] LfuCache::putInternal(
  self : LfuCache[K, V],
  key : K,
  value : V,
) -> Unit {
  if self.nodeMap.size() == self.capacity.reinterpret_as_int() {
    self.kickOut()
  }
  let node = LfuNode::new(key, value)
  self.nodeMap.set(key, node)
  self.addToFreqList(node)
  self.addFreqNum()
  if self.minFreq > 1 {
    self.minFreq = 1
  }
}

///|
pub fn[K : Eq + Hash, V] LfuCache::kickOut(self : LfuCache[K, V]) -> Unit {
  let freqList = self.freqToFreqList.get(self.minFreq)
  let firstNode = freqList.unwrap().getFirstNode()
  self.nodeMap.remove(firstNode.key.unwrap())
  self.decreaseFreqNum(firstNode.freq)
}

///|
pub fn[K : Eq + Hash, V] LfuCache::removeFromFreqList(
  self : LfuCache[K, V],
  node : LfuNode[K, V],
) -> Unit {
  if node.key is None {
    return
  }
  let freq = node.freq
  let freqList = self.freqToFreqList.get(freq).unwrap()
  freqList.removeNode(Ref::new(node))
}

///|

///|
/// 将节点加入对应频率的链表（若不存在则创建）
pub fn[K : Eq + Hash, V] LfuCache::addToFreqList(
  self : LfuCache[K, V],
  node : LfuNode[K, V],
) -> Unit {
  if node.key is None {
    return
  }
  let freq = node.freq
  let freqListOpt = self.freqToFreqList.get(freq)

  // 若不存在该频率的链表，创建一个新的
  match freqListOpt {
    None => {
      let newList = LfuNodeList::new()
      newList.insertNode(Ref::new(node))
      self.freqToFreqList.set(freq, newList)
    }
    Some(existingList) => existingList.insertNode(Ref::new(node))
  }
}

///|
pub fn[K : Eq + Hash, V] LfuCache::addFreqNum(self : LfuCache[K, V]) -> Unit {
  self.curTotalNum += 1
  if self.nodeMap.is_empty() {
    self.curAverageNum = 0
  } else {
    self.curAverageNum = self.curTotalNum /
      self.nodeMap.size().reinterpret_as_uint()
  }
  if self.curAverageNum > self.maxAverageNum {
    self.handleOverMaxAverageNum()
  }
}

///|
pub fn[K, V] LfuCache::decreaseFreqNum(
  self : LfuCache[K, V],
  num : UInt,
) -> Unit {
  self.curTotalNum -= num
  if self.nodeMap.is_empty() {
    self.curAverageNum = 0
  } else {
    self.curAverageNum = self.curTotalNum /
      self.nodeMap.size().reinterpret_as_uint()
  }
}

///|
pub fn[K : Eq + Hash, V] LfuCache::handleOverMaxAverageNum(
  self : LfuCache[K, V],
) -> Unit {
  if self.nodeMap.is_empty() {
    return
  }
  self.nodeMap.eachi((_, _, node) => {
    self.removeFromFreqList(node)
    node.freq -= self.maxAverageNum / 2
    if node.freq < 1 {
      node.freq = 1
    }
    self.addToFreqList(node)
  })

  // 更新最小频率
  self.updateMinFreq()
}

///|
pub fn[K, V] LfuCache::updateMinFreq(self : LfuCache[K, V]) -> Unit {
  self.minFreq = self.maxAverageNum
  self.freqToFreqList.eachi((_, k, _) => if self.minFreq > k {
    self.minFreq = k
  })

  // 更新最小频率
  if self.minFreq == self.maxAverageNum {
    self.minFreq = 1
  }
}

///|
pub fn[K : Eq + Hash, V] LfuCache::put(
  self : LfuCache[K, V],
  key : K,
  value : V,
) -> Unit {
  if self.capacity == 0 {
    return
  }
  let it = self.nodeMap.get(key)
  if it is Some(_) {
    it.unwrap().value = Some(value)
    self.getInternal(it.unwrap())
    return
  }
  self.putInternal(key, value)
}

///|
pub fn[K : Eq + Hash, V] LfuCache::get(self : LfuCache[K, V], key : K) -> V? {
  let nodeOpt = self.nodeMap.get(key)
  match nodeOpt {
    None => None
    Some(node) => {
      // ⚠️ 重要：更新该节点的频率统计
      self.getInternal(node)
      node.value
    }
  }
}

///|
pub fn[K : Eq + Hash, V] LfuCache::purge(self : LfuCache[K, V]) -> Unit {
  self.nodeMap.clear()
  self.freqToFreqList.clear()
}

///|
pub struct HashLfuCache[K, V] {
  sliceNum : UInt
  capacity : UInt
  shards : Array[LfuCache[K, V]]
}

///|
pub fn[K : Eq + Hash, V] HashLfuCache::new(
  sliceNum : UInt,
  capacity : UInt,
  maxAverageNum : UInt,
) -> HashLfuCache[K, V] {
  let sliceSize = capacity / sliceNum
  let shards = Array::new(capacity=sliceNum.reinterpret_as_int())
  for i = 0; i < sliceSize.reinterpret_as_int(); i = i + 1 {
    let node : LfuCache[K, V] = LfuCache::new(sliceSize, maxAverageNum)
    shards[i] = node
  }
  HashLfuCache::{ sliceNum, capacity, shards }
}

///|
/// 内部辅助函数：根据 key 计算所在分片
fn[K, V] HashLfuCache::get_shard_index(
  self : HashLfuCache[K, V],
  key : UInt,
) -> UInt {
  key % self.sliceNum
}

///|
/// 获取 key 对应的值
pub fn[K : Eq + Hash, V] HashLfuCache::get(
  self : HashLfuCache[K, V],
  key : K,
  capacity : Int,
) -> V? {
  let idx = self.get_shard_index(capacity.reinterpret_as_uint())
  let shard = self.shards[idx.reinterpret_as_int()]
  shard.get(key)
}

///|
pub fn[K : Eq + Hash, V] HashLfuCache::put(
  self : HashLfuCache[K, V],
  key : K,
  value : V,
  capacity : Int,
) -> Unit {
  let idx = self.get_shard_index(capacity.reinterpret_as_uint())
  let shard = self.shards[idx.reinterpret_as_int()]
  shard.put(key, value)
}

///|
pub fn[K : Eq + Hash, V] HashLfuCache::purge(self : HashLfuCache[K, V]) -> Unit {
  for nodeList in self.shards {
    nodeList.purge()
  }
}

///|
test {
  println("==== LRU Cache 测试开始 ====")

  // 创建一个容量为 3 的 LRU 缓存
  let cache = LfuCache::new(3, 3)

  // 插入三个元素
  cache.put("A", 1)
  cache.put("B", 2)
  cache.put("C", 3)
  println("初始缓存状态：")
  println(cache.get("A"))
  println(cache.get("A"))
  println(cache.get("B"))

  // 插入新元素 D，触发淘汰（应淘汰最久未访问的 B）
  cache.put("D", 4)
  println("插入 D 后：")
  println(cache.get("A"))
  println(cache.get("B"))
  println(cache.get("C"))
  println(cache.get("D"))

  // 更新 A 的值并再次访问
  cache.put("A", 10)
  println(cache.get("A"))

  // 再插入 E，检查淘汰逻辑（此时应淘汰 C）
  cache.put("E", 5)
  println("插入 E 后：")
  println(cache.get("A"))
  println(cache.get("C"))
  println(cache.get("D"))
  println(cache.get("E"))
  println("==== 测试结束 ====")
}
