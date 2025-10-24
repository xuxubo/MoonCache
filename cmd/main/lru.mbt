///|
pub struct LruNode[Key, Value] {
  key : Key?
  mut value : Value?
  mut accessCount : UInt
  mut prev : Ref[LruNode[Key, Value]]?
  mut next : Ref[LruNode[Key, Value]]?
}

///|
pub fn[Key, Value] LruNode::new(
  key : Key?,
  value : Value?,
) -> LruNode[Key, Value] {
  LruNode::{ key, value, accessCount: 1, prev: None, next: None }
}

///|
pub fn[K, V] LruNode::getKey(self : LruNode[K, V]) -> K {
  self.key.unwrap()
}

///|
pub fn[K, V] LruNode::getValue(self : LruNode[K, V]) -> V {
  self.value.unwrap()
}

///|
pub fn[K, V] LruNode::setValue(self : LruNode[K, V], value : V) -> Unit {
  self.value = Some(value)
}

///|
pub fn[K, V] LruNode::getAccessCount(self : LruNode[K, V]) -> UInt {
  self.accessCount
}

///|
pub fn[K, V] LruNode::incrementAccessCount(self : LruNode[K, V]) -> Unit {
  self.accessCount += 1
}

///|
pub struct LruNodeLink[Key, Value] {
  dummyTail : Ref[LruNode[Key, Value]]
  dummyHead : Ref[LruNode[Key, Value]]
  mut size : UInt
}

///|
pub fn[Key, Value] LruNodeLink::new(size : UInt) -> LruNodeLink[Key, Value] {
  let dummyHead : Ref[LruNode[Key, Value]] = Ref::new(LruNode::new(None, None))
  let dummyTail : Ref[LruNode[Key, Value]] = Ref::new(LruNode::new(None, None))

  // 建立双向连接：head <-> tail
  dummyHead.val.next = Some(dummyTail)
  dummyTail.val.prev = Some(dummyHead)
  // 初始化链表
  LruNodeLink::{ dummyTail, dummyHead, size }
}

///|
pub fn[K, V] LruNodeLink::insertNode(
  self : LruNodeLink[K, V],
  node : Ref[LruNode[K, V]],
) -> Unit { //尾部插入节点
  // 取 dummyTail 之前的节点
  let prevNode = self.dummyTail.val.prev.unwrap()

  // 调整指针关系：prevNode <-> node <-> dummyTail
  prevNode.val.next = Some(node)
  node.val.prev = Some(prevNode)
  node.val.next = Some(self.dummyTail)
  self.dummyTail.val.prev = Some(node)
  self.size += 1
}

///|
pub fn[K, V] LruNodeLink::removeNode(
  self : LruNodeLink[K, V],
  node : Ref[LruNode[K, V]],
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
pub struct LruCache[K, V] {
  nodeMap : Map[K, LruNode[K, V]]
  capacity : UInt
  lruNodeLink : LruNodeLink[K, V]
}

///|
pub fn[K, V] LruCache::new(capacity : UInt) -> LruCache[K, V] {
  let nodeMap : Map[K, LruNode[K, V]] = Map::new()
  let lruNodeLink = LruNodeLink::new(0)
  LruCache::{ nodeMap, capacity, lruNodeLink }
}

///|
pub fn[K, V] LruCache::updateExistingNode(
  self : LruCache[K, V],
  node : LruNode[K, V],
  value : V,
) -> Unit {
  node.value = Some(value)
  self.moveToMostRecent(node)
}

///|
pub fn[K, V] LruCache::removeNode(
  self : LruCache[K, V],
  node : LruNode[K, V],
) -> Unit {
  let lruNodeLink = self.lruNodeLink
  lruNodeLink.removeNode(@ref.new(node))
}

///|
pub fn[K, V] LruCache::insertNode(
  self : LruCache[K, V],
  node : LruNode[K, V],
) -> Unit {
  let lruNodeLink = self.lruNodeLink
  lruNodeLink.insertNode(@ref.new(node))
}

///|
pub fn[K, V] LruCache::moveToMostRecent(
  self : LruCache[K, V],
  node : LruNode[K, V],
) -> Unit {
  self.removeNode(node)
  self.insertNode(node)
}

///|
pub fn[K : Eq + Hash, V] addNewNode(
  self : LruCache[K, V],
  node : LruNode[K, V],
) -> Unit {
  if self.capacity <= self.lruNodeLink.size {
    self.evictLeastRecent()
  }
  self.insertNode(node)
  let key = node.getKey()
  self.nodeMap.set(key, node)
}

///|
pub fn[K : Eq + Hash, V] LruCache::evictLeastRecent(
  self : LruCache[K, V],
) -> Unit {
  let leastRecent = self.lruNodeLink.dummyHead.val.next.unwrap()
  self.removeNode(leastRecent.val)
  let key = leastRecent.val.getKey()
  self.nodeMap.remove(key)
}

///|
pub fn[K : Eq + Hash, V] LruCache::put(
  self : LruCache[K, V],
  key : K,
  value : V,
) -> Unit {
  if self.capacity <= 0 {
    return
  }
  let it = self.nodeMap.get(key)
  match it {
    None => self.addNewNode(LruNode::new(Some(key), Some(value)))
    Some(_) => self.updateExistingNode(it.unwrap(), value)
  }
}

///|
pub fn[K : Eq + Hash, V] LruCache::get(self : LruCache[K, V], key : K) -> V? {
  // 从哈希表中查找节点
  let nodeOpt = self.nodeMap.get(key)
  match nodeOpt {
    None => None // 没有命中缓存
    Some(node) => {
      // 命中缓存：将节点移动到最近使用位置
      self.moveToMostRecent(node)

      // 返回节点值的副本
      node.value
    }
  }
}

///|
pub fn[K : Eq + Hash, V] LruCache::remove(
  self : LruCache[K, V],
  key : K,
) -> Unit {
  // 从哈希表中查找节点
  let nodeOpt = self.nodeMap.get(key)
  match nodeOpt {
    None => ... // 没有命中缓存
    Some(node) => {
      // 命中缓存：将节点移动到最近使用位置
      self.removeNode(node)
      self.nodeMap.remove(node.getKey())
    }
  }
}

///|
test {
  println("==== LRU Cache 测试开始 ====")

  // 创建一个容量为 3 的 LRU 缓存
  let cache = LruCache::new(3)

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
