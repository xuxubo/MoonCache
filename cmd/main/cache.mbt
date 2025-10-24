// src/cache.mbt
pub enum CachePolicy {
    FIFO;
    LRU;
    LFU;
    LRU_K;
    HashLRU;
    ARC
}

pub trait Cache{

}

