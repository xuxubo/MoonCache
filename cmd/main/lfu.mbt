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
pub fn[Key, Value] LfuNodeList::insertNode(
  self : LfuNodeList[Key, Value],
  node : Ref[LfuNode[Key, Value]],
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
pub fn[Key, Value] LfuNodeList::removeNode(
  self : LfuNodeList[Key, Value],
  node : Ref[LfuNode[Key, Value]],
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
pub fn[Key, Value] LfuNodeList::getFirstNode(
  self : LfuNodeList[Key, Value],
) -> LfuNode[Key, Value] {
  let a = self.head.val
  a.next.unwrap().val
}

///|
pub struct LfuCache[Key, Value] {
  nodeMap : Map[Key, LfuNode[Key, Value]]
  capacity : UInt
  lruNodeLink : LfuNodeList[Key, Value]
  freqToFreqList : Map[UInt, LfuNodeList[Key, Value]]
  mut minFreq : UInt
  maxAverageNum : UInt
  mut curAverageNum : UInt
  mut curTotalNum : UInt
}

///|
pub fn[Key, Value] LfuCache::new(
  capacity : UInt,
  maxAverageNum : UInt,
) -> LfuCache[Key, Value] {
  let nodeMap : Map[Key, LfuNode[Key, Value]] = Map::new()
  let lruNodeLink = LfuNodeList::new()
  let freqToFreqList : Map[UInt, LfuNodeList[Key, Value]] = Map::new()
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
pub fn[Key : Eq + Hash, Value] LfuCache::getInternal(
  self : LfuCache[Key, Value],
  node : LfuNode[Key, Value],
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
pub fn[Key : Eq + Hash, Value] LfuCache::putInternal(
  self : LfuCache[Key, Value],
  key : Key,
  value : Value,
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
pub fn[Key : Eq + Hash, Value] LfuCache::kickOut(
  self : LfuCache[Key, Value],
) -> Unit {
  let freqList = self.freqToFreqList.get(self.minFreq)
  let firstNode = freqList.unwrap().getFirstNode()
  self.nodeMap.remove(firstNode.key.unwrap())
  self.decreaseFreqNum(firstNode.freq)
}

///|
pub fn[Key : Eq + Hash, Value] LfuCache::removeFromFreqList(
  self : LfuCache[Key, Value],
  node : LfuNode[Key, Value],
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
pub fn[Key : Eq + Hash, Value] LfuCache::addToFreqList(
  self : LfuCache[Key, Value],
  node : LfuNode[Key, Value],
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
pub fn[Key : Eq + Hash, Value] LfuCache::addFreqNum(
  self : LfuCache[Key, Value],
) -> Unit {
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
pub fn[Key, Value] LfuCache::decreaseFreqNum(
  self : LfuCache[Key, Value],
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
pub fn[Key : Eq + Hash, Value] LfuCache::handleOverMaxAverageNum(
  self : LfuCache[Key, Value],
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
pub fn[Key, Value] LfuCache::updateMinFreq(self : LfuCache[Key, Value]) -> Unit {
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
pub fn[Key : Eq + Hash, Value] LfuCache::evictLeastFrequent(
  self : LfuCache[Key, Value],
) -> Unit {
  let _ = self.popLeastFrequent()

}

///|
pub fn[Key : Eq + Hash, Value] LfuCache::popLeastFrequent(
  self : LfuCache[Key, Value],
) -> LfuNode[Key, Value]? {
  let leastFrequentListOpt = self.freqToFreqList.get(self.minFreq)
  if leastFrequentListOpt is None || leastFrequentListOpt.unwrap().isEmpty() {
    return None
  }
  let leastFrequentList = leastFrequentListOpt.unwrap()
  let nodeRefToPop = leastFrequentList.head.val.next.unwrap()
  let nodeToPop = nodeRefToPop.val
  leastFrequentList.removeNode(nodeRefToPop)
  self.nodeMap.remove(nodeToPop.key.unwrap())
  self.decreaseFreqNum(nodeToPop.freq)
  Some(nodeToPop)
}

///|
pub fn[Key : Eq + Hash, Value] LfuCache::put(
  self : LfuCache[Key, Value],
  key : Key,
  value : Value,
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
pub fn[Key : Eq + Hash, Value] LfuCache::get(
  self : LfuCache[Key, Value],
  key : Key,
) -> Value? {
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
pub fn[Key : Eq + Hash, Value] LfuCache::purge(
  self : LfuCache[Key, Value],
) -> Unit {
  self.nodeMap.clear()
  self.freqToFreqList.clear()
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
