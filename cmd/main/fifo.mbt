///|
pub enum List[A] {
  Empty
  More(A, List[A])
}

///|
pub fn[A] List::new() -> List[A] {
  Empty
}

///|
pub fn[A] List::prepend(self : List[A], head : A) -> List[A] {
  More(head, self)
}

///|
pub fn[A] List::rev(self : List[A]) -> List[A] {
  loop (self, Empty) {
    (Empty, acc) => acc
    (More(h, t), acc) => continue (t, More(h, acc))
  }
}

///|
pub fn[A] List::is_empty(self : List[A]) -> Bool {
  self is Empty
}

///|
pub fn[A] List::length(self : List[A]) -> Int {
  loop (self, 0) {
    (Empty, len) => len
    (More(_, tail), acc) => continue (tail, acc + 1)
  }
}

///|
/// 一个基于两个不可变列表的高效 FIFO 队列。
/// `inbox` 用于 O(1) 的入队操作。
/// `outbox` 用于 O(1) 的出队操作。
pub struct FifoQueue[A] {
  inbox : List[A]
  outbox : List[A]
}

///|
/// 创建一个空队列。
pub fn[A] FifoQueue::new() -> FifoQueue[A] {
  FifoQueue::{ inbox: List::new(), outbox: List::new() }
}

///|
/// 将一个新元素入队
pub fn[A] FifoQueue::enqueue(self : FifoQueue[A], value : A) -> FifoQueue[A] {
  // 总是将新元素添加到 inbox 的头部
  FifoQueue::{ inbox: self.inbox.prepend(value), outbox: self.outbox }
}

///|
/// 从队列头部出队一个元素。这是一个 O(1) 操作。
pub fn[A] FifoQueue::dequeue(self : FifoQueue[A]) -> (A?, FifoQueue[A]) {
  match self.outbox {
    More(head, tail) =>
      // Outbox 不为空，直接从 outbox 头部取元素。
      (Some(head), FifoQueue::{ inbox: self.inbox, outbox: tail })
    Empty => {
      // Outbox 为空，将 inbox 逆序后移动到 outbox。
      let new_outbox = self.inbox.rev()
      match new_outbox {
        More(head, tail) =>
          // 新的 outbox 有元素，从中取，并清空 inbox。
          (Some(head), FifoQueue::{ inbox: List::new(), outbox: tail })
        Empty =>
          // Inbox 和 Outbox 都为空，整个队列是空的。
          (None, self)
      }
    }
  }
}

///|
/// 返回队列中的元素数量。
pub fn[A] FifoQueue::size(self : FifoQueue[A]) -> Int {
  self.inbox.length() + self.outbox.length()
}

///|
/// 先进先出 (FIFO) 缓存。
/// 当缓存达到容量上限时，会淘汰最早插入的条目。
pub struct FifoCache[K, V] {
  // 用于 O(1) 查找
  data : Map[K, V]
  // 用于记录插入顺序
  mut order : FifoQueue[K]
  // 缓存的最大容量
  capacity : UInt
}

///|
/// 创建一个新的 FIFO 缓存。
pub fn[K, V] FifoCache::new(capacity : UInt) -> FifoCache[K, V] {
  if capacity == 0 {
    abort("FifoCache capacity must be greater than 0")
  }
  FifoCache::{ data: Map::new(), order: FifoQueue::new(), capacity }
}

///|
/// 向缓存中插入或更新一个键值对。
pub fn[K : Eq + Hash, V] FifoCache::put(
  self : FifoCache[K, V],
  key : K,
  value : V,
) -> Unit {
  // 检查键是否已经存在
  if self.data.contains(key) {
    // 键已存在，仅更新值。遵循 FIFO 原则，不改变其淘汰顺序。
    self.data.set(key, value)
    return
  }

  // 键不存在，是新插入
  // 检查是否需要淘汰
  if self.order.size() >= self.capacity.to_int() {
    // 队列已满，淘汰最老的元素
    let (oldestKeyOpt, new_order) = self.order.dequeue()
    self.order = new_order // 更新队列状态
    if oldestKeyOpt is Some(oldestKey) {
      self.data.remove(oldestKey)
    }
  }

  // 将新条目加入哈希表和队列
  self.data.set(key, value)
  self.order = self.order.enqueue(key) // 更新队列状态
}

///|
/// 根据键从缓存中获取值。此操作不影响淘汰顺序。
pub fn[K : Eq + Hash, V] FifoCache::get(self : FifoCache[K, V], key : K) -> V? {
  self.data.get(key)
}

///|
/// 返回缓存中当前的元素数量。
pub fn[K, V] FifoCache::size(self : FifoCache[K, V]) -> Int {
  self.order.size()
}

///|
test "fifo_cache_built_with_list_workflow" {
  let cache : FifoCache[String, Int] = FifoCache::new(3)

  // 1. 插入三个元素，填满缓存
  cache.put("A", 1)
  cache.put("B", 2)
  cache.put("C", 3)
  assert_eq(cache.size(), 3)
  assert_eq(cache.get("A"), Some(1))
  // 内部队列逻辑: 最老 -> A, B, C <- 最新

  // 2. 访问 "A"，在 FIFO 中，这不应该影响其顺序
  let _ = cache.get("A")
  assert_eq(cache.get("A"), Some(1))

  // 3. 插入新元素 "D"，触发淘汰
  // "A" 是最早插入的 (First-In)，所以 "A" 被淘汰 (First-Out)
  cache.put("D", 4)
  assert_eq(cache.size(), 3)
  assert_eq(cache.get("A"), None) // 验证 A 已被淘汰
  assert_eq(cache.get("B"), Some(2))
  assert_eq(cache.get("C"), Some(3))
  assert_eq(cache.get("D"), Some(4))
  // 内部队列逻辑: 最老 -> B, C, D <- 最新

  // 4. 更新已存在元素 "B" 的值
  // 这不应该改变 "B" 的位置，它仍然是当前最老的元素
  cache.put("B", 22)
  assert_eq(cache.size(), 3)
  assert_eq(cache.get("B"), Some(22))

  // 5. 再插入 "E"，此时 "B" 是最老的，应该被淘汰
  cache.put("E", 5)
  assert_eq(cache.size(), 3)
  assert_eq(cache.get("B"), None) // 验证 B 已被淘汰
  assert_eq(cache.get("C"), Some(3))
  assert_eq(cache.get("D"), Some(4))
  assert_eq(cache.get("E"), Some(5))
  // 内部队列逻辑: 最老 -> C, D, E <- 最新
}
