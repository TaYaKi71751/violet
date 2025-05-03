use serde::{Deserialize, Serialize};
use std::cmp::Ordering;
use std::collections::{BinaryHeap, HashMap};
use std::sync::{Arc, Mutex, RwLock};
use std::time::{SystemTime, UNIX_EPOCH};

use crate::indexableset::IndexableSet;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RankedEntry {
    pub value: i64,
    #[serde(skip_serializing, skip_deserializing)]
    pub member: Arc<String>,
    pub expire: Option<u64>,
}

impl PartialEq for RankedEntry {
    fn eq(&self, other: &Self) -> bool {
        self.value == other.value && self.member == other.member
    }
}

impl Eq for RankedEntry {}

impl PartialOrd for RankedEntry {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for RankedEntry {
    fn cmp(&self, other: &Self) -> Ordering {
        match self.value.cmp(&other.value) {
            Ordering::Equal => self.member.cmp(&other.member),
            ordering => ordering,
        }
    }
}

#[derive(Debug, Clone, Eq, PartialEq)]
struct ExpireEntry {
    expire_time: u64,
    table_id: usize,
    member: Arc<String>,
    value: i64,
}

impl Ord for ExpireEntry {
    fn cmp(&self, other: &Self) -> Ordering {
        other.expire_time.cmp(&self.expire_time)
    }
}

impl PartialOrd for ExpireEntry {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

#[derive(Debug, Deserialize)]
pub struct ZAddRequest {
    pub value: i64,
    pub member: String,
}

#[derive(Debug, Deserialize)]
pub struct ZIncrByRequest {
    pub increment: i64,
    pub member: String,
}

#[derive(Debug, Deserialize)]
pub struct ZIncrByPeriodRequest {
    pub increment: i64,
    pub member: String,
    pub expire: u64,
}

#[derive(Debug, Deserialize, Clone)]
pub struct ZRangeRequest {
    pub offset: usize,
    pub count: usize,
    pub withscores: bool,
}

#[allow(clippy::type_complexity)]
pub struct RankedState {
    tables: RwLock<HashMap<String, IndexableSet<RankedEntry>>>,
    expire_queue: Mutex<BinaryHeap<ExpireEntry>>,
    table_lookup: RwLock<Vec<String>>,
    table_indices: RwLock<HashMap<String, usize>>,
}

impl RankedState {
    pub fn new() -> Self {
        RankedState {
            tables: RwLock::new(HashMap::new()),
            expire_queue: Mutex::new(BinaryHeap::new()),
            table_lookup: RwLock::new(Vec::new()),
            table_indices: RwLock::new(HashMap::new()),
        }
    }

    fn get_table_id(&self, table: &str) -> usize {
        let mut indices = self.table_indices.write().unwrap();
        let mut lookup = self.table_lookup.write().unwrap();

        if let Some(&index) = indices.get(table) {
            return index;
        }

        let new_index = lookup.len();
        lookup.push(table.to_string());
        indices.insert(table.to_string(), new_index);
        new_index
    }

    fn get_table_name(&self, id: usize) -> Option<String> {
        let lookup = self.table_lookup.read().unwrap();
        lookup.get(id).cloned()
    }

    fn process_expired_entries(&self) {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        let mut tables = self.tables.write().unwrap();
        let mut expire_queue = self.expire_queue.lock().unwrap();

        while let Some(entry) = expire_queue.peek() {
            if entry.expire_time > now {
                break;
            }

            let entry = expire_queue.pop().unwrap();
            let table_name = self.get_table_name(entry.table_id);

            if let Some(table_name) = table_name {
                if let Some(sorted_entries) = tables.get_mut(&table_name) {
                    if let Some(ranked_entry) = sorted_entries.take(&RankedEntry {
                        value: entry.value,
                        member: entry.member.clone(),
                        expire: None,
                    }) {
                        let new_value = ranked_entry.value - entry.value;
                        if new_value > 0 {
                            sorted_entries.insert(RankedEntry {
                                value: new_value,
                                member: ranked_entry.member,
                                expire: None,
                            });
                        }
                    }
                }
            }
        }
    }

    pub fn zadd(&self, table: String, request: ZAddRequest) -> String {
        self.process_expired_entries();

        let member = Arc::new(request.member);
        let mut tables = self.tables.write().unwrap();
        let sorted_entries = tables.entry(table).or_insert_with(IndexableSet::new);

        let entry = RankedEntry {
            value: request.value,
            member: member,
            expire: None,
        };

        sorted_entries.insert(entry);

        "OK".to_string()
    }

    pub fn zincrby(&self, table: String, request: ZIncrByRequest) -> String {
        self.process_expired_entries();

        let member = Arc::new(request.member);
        let mut tables = self.tables.write().unwrap();
        let sorted_entries = tables.entry(table).or_insert_with(IndexableSet::new);

        let mut entry = sorted_entries
            .take(&RankedEntry {
                value: 0,
                member: member.clone(),
                expire: None,
            })
            .unwrap_or_else(|| RankedEntry {
                value: 0,
                member: member,
                expire: None,
            });

        entry.value += request.increment;
        sorted_entries.insert(entry);

        "OK".to_string()
    }

    pub fn zincrbyp(&self, table: String, request: ZIncrByPeriodRequest) -> String {
        self.process_expired_entries();

        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        let member = Arc::new(request.member);
        let table_id = self.get_table_id(&table);

        let mut tables = self.tables.write().unwrap();
        let mut expire_queue = self.expire_queue.lock().unwrap();
        let sorted_entries = tables.entry(table).or_insert_with(IndexableSet::new);

        let mut entry = sorted_entries
            .take(&RankedEntry {
                value: 0,
                member: member.clone(),
                expire: None,
            })
            .unwrap_or_else(|| RankedEntry {
                value: 0,
                member: member.clone(),
                expire: None,
            });

        entry.value += request.increment;
        entry.expire = Some(now + request.expire);
        sorted_entries.insert(entry);

        expire_queue.push(ExpireEntry {
            expire_time: now + request.expire,
            table_id: table_id,
            member: member,
            value: request.increment,
        });

        "OK".to_string()
    }

    pub fn zrange(&self, table: String, request: ZRangeRequest) -> String {
        self.process_expired_entries();

        let tables = self.tables.read().unwrap();
        if let Some(sorted_entries) = tables.get(&table) {
            let result: Vec<_> = sorted_entries
                .range(request.offset..request.offset + request.count)
                .into_iter()
                .map(|entry| {
                    if request.withscores {
                        format!("{}:{}", entry.member, entry.value)
                    } else {
                        entry.member.to_string()
                    }
                })
                .collect();
            serde_json::to_string(&result).unwrap()
        } else {
            "[]".to_string()
        }
    }

    pub fn zrevrange(&self, table: String, request: ZRangeRequest) -> String {
        self.process_expired_entries();

        let tables = self.tables.read().unwrap();
        if let Some(sorted_entries) = tables.get(&table) {
            let result: Vec<_> = sorted_entries
                .range(request.offset..request.offset + request.count)
                .into_iter()
                .rev() // TODO: 수정
                .map(|entry| {
                    if request.withscores {
                        format!("{}:{}", entry.member, entry.value)
                    } else {
                        entry.member.to_string()
                    }
                })
                .collect();
            serde_json::to_string(&result).unwrap()
        } else {
            "[]".to_string()
        }
    }

    pub fn flushall(&self) -> String {
        let mut tables = self.tables.write().unwrap();
        let mut expire_queue = self.expire_queue.lock().unwrap();
        let mut table_indices = self.table_indices.write().unwrap();
        let mut table_lookup = self.table_lookup.write().unwrap();

        tables.clear();
        expire_queue.clear();
        table_indices.clear();
        table_lookup.clear();

        "OK".to_string()
    }
}

#[cfg(test)]
mod tests {
    use std::{sync::Arc, thread, time::Duration};

    use rand::Rng;

    use super::*;

    #[test]
    fn test_zadd() {
        let state = RankedState::new();
        let request = ZAddRequest {
            value: 100,
            member: "user1".to_string(),
        };

        assert_eq!(state.zadd("test".to_string(), request), "OK");

        // 같은 멤버에 대해 다른 값으로 업데이트
        let request = ZAddRequest {
            value: 200,
            member: "user1".to_string(),
        };
        assert_eq!(state.zadd("test".to_string(), request), "OK");
    }

    #[test]
    fn test_zincrby() {
        let state = RankedState::new();
        let request = ZIncrByRequest {
            increment: 10,
            member: "user1".to_string(),
        };

        assert_eq!(state.zincrby("test".to_string(), request), "OK");

        // 같은 멤버에 대해 다시 증가
        let request = ZIncrByRequest {
            increment: 20,
            member: "user1".to_string(),
        };
        assert_eq!(state.zincrby("test".to_string(), request), "OK");
    }

    #[test]
    fn test_zincrbyp() {
        let state = RankedState::new();
        let request = ZIncrByPeriodRequest {
            increment: 10,
            member: "user1".to_string(),
            expire: 3600,
        };

        assert_eq!(state.zincrbyp("test".to_string(), request), "OK");

        // 같은 멤버에 대해 다시 증가
        let request = ZIncrByPeriodRequest {
            increment: 20,
            member: "user1".to_string(),
            expire: 3600,
        };
        assert_eq!(state.zincrbyp("test".to_string(), request), "OK");
    }

    #[test]
    fn test_zrange() {
        let state = RankedState::new();

        // 테스트 데이터 추가
        let requests = vec![
            ZAddRequest {
                value: 100,
                member: "user1".to_string(),
            },
            ZAddRequest {
                value: 200,
                member: "user2".to_string(),
            },
            ZAddRequest {
                value: 300,
                member: "user3".to_string(),
            },
        ];

        for request in requests {
            state.zadd("test".to_string(), request);
        }

        let range_request = ZRangeRequest {
            offset: 0,
            count: 2,
            withscores: true,
        };

        let result = state.zrange("test".to_string(), range_request);
        let expected = r#"["user1:100","user2:200"]"#;
        assert_eq!(result, expected);

        // withscores가 false인 경우
        let range_request = ZRangeRequest {
            offset: 0,
            count: 2,
            withscores: false,
        };

        let result = state.zrange("test".to_string(), range_request);
        let expected = r#"["user1","user2"]"#;
        assert_eq!(result, expected);
    }

    #[test]
    fn test_zrevrange() {
        let state = RankedState::new();

        // 테스트 데이터 추가
        let requests = vec![
            ZAddRequest {
                value: 100,
                member: "user1".to_string(),
            },
            ZAddRequest {
                value: 200,
                member: "user2".to_string(),
            },
            ZAddRequest {
                value: 300,
                member: "user3".to_string(),
            },
        ];

        for request in requests {
            state.zadd("test".to_string(), request);
        }

        let range_request = ZRangeRequest {
            offset: 0,
            count: 2,
            withscores: true,
        };

        let result = state.zrevrange("test".to_string(), range_request);
        let expected = r#"["user3:300","user2:200"]"#;
        assert_eq!(result, expected);

        // withscores가 false인 경우
        let range_request = ZRangeRequest {
            offset: 0,
            count: 2,
            withscores: false,
        };

        let result = state.zrevrange("test".to_string(), range_request);
        let expected = r#"["user3","user2"]"#;
        assert_eq!(result, expected);
    }

    #[test]
    fn test_flushall() {
        let state = RankedState::new();

        // 테스트 데이터 추가
        let request = ZAddRequest {
            value: 100,
            member: "user1".to_string(),
        };
        state.zadd("test".to_string(), request);

        assert_eq!(state.flushall(), "OK");

        // flushall 후 데이터가 비어있는지 확인
        let range_request = ZRangeRequest {
            offset: 0,
            count: 10,
            withscores: true,
        };
        let result = state.zrange("test".to_string(), range_request);
        assert_eq!(result, "[]");
    }

    #[test]
    fn test_concurrent_operations() {
        let state = Arc::new(RankedState::new());
        let handles: Vec<_> = (0..10)
            .map(|_| {
                let state = Arc::clone(&state);
                thread::spawn(move || {
                    let request = ZIncrByRequest {
                        increment: 1,
                        member: "user1".to_string(),
                    };
                    state.zincrby("test".to_string(), request)
                })
            })
            .collect();

        for handle in handles {
            assert_eq!(handle.join().unwrap(), "OK");
        }

        // 최종 값 확인
        let range_request = ZRangeRequest {
            offset: 0,
            count: 1,
            withscores: true,
        };
        let result = state.zrange("test".to_string(), range_request);
        assert_eq!(result, r#"["user1:10"]"#);
    }

    #[test]
    fn test_expire() {
        use std::thread;
        use std::time::Duration;

        let state = RankedState::new();

        // 만료 시간이 1초인 항목 추가
        let request = ZIncrByPeriodRequest {
            increment: 100,
            member: "user1".to_string(),
            expire: 1, // 1초 후 만료
        };
        assert_eq!(state.zincrbyp("test".to_string(), request), "OK");

        // 즉시 조회하면 값이 있어야 함
        let range_request = ZRangeRequest {
            offset: 0,
            count: 1,
            withscores: true,
        };
        let result = state.zrange("test".to_string(), range_request.clone());
        assert_eq!(result, r#"["user1:100"]"#);

        // 1.5초 대기
        thread::sleep(Duration::from_millis(1500));

        // 만료 후 조회하면 값이 감소해야 함
        let result = state.zrange("test".to_string(), range_request);
        assert_eq!(result, "[]");
    }

    #[test]
    fn test_multiple_expires() {
        use std::thread;
        use std::time::Duration;

        let state = RankedState::new();

        // 여러 항목 추가
        let requests = vec![
            ZIncrByPeriodRequest {
                increment: 100,
                member: "user1".to_string(),
                expire: 1, // 1초 후 만료
            },
            ZIncrByPeriodRequest {
                increment: 200,
                member: "user2".to_string(),
                expire: 2, // 2초 후 만료
            },
            ZIncrByPeriodRequest {
                increment: 300,
                member: "user3".to_string(),
                expire: 3, // 3초 후 만료
            },
        ];

        for request in requests {
            assert_eq!(state.zincrbyp("test".to_string(), request), "OK");
        }

        // 초기 상태 확인
        let range_request = || ZRangeRequest {
            offset: 0,
            count: 10,
            withscores: true,
        };
        let result = state.zrange("test".to_string(), range_request());
        assert_eq!(result, r#"["user1:100","user2:200","user3:300"]"#);

        // 1.5초 후 확인 (user1 만료)
        thread::sleep(Duration::from_millis(1500));
        let result = state.zrange("test".to_string(), range_request());
        assert_eq!(result, r#"["user2:200","user3:300"]"#);

        // 2.5초 후 확인 (user2 만료)
        thread::sleep(Duration::from_millis(1000));
        let result = state.zrange("test".to_string(), range_request());
        assert_eq!(result, r#"["user3:300"]"#);

        // 3.5초 후 확인 (user3 만료)
        thread::sleep(Duration::from_millis(1000));
        let result = state.zrange("test".to_string(), range_request());
        assert_eq!(result, "[]");
    }

    #[test]
    fn test_expire_with_multiple_increments() {
        use std::thread;
        use std::time::Duration;

        let state = RankedState::new();

        // 같은 멤버에 대해 여러 번 증가
        let requests = vec![
            ZIncrByPeriodRequest {
                increment: 100,
                member: "user1".to_string(),
                expire: 1,
            },
            ZIncrByPeriodRequest {
                increment: 200,
                member: "user1".to_string(),
                expire: 1,
            },
            ZIncrByPeriodRequest {
                increment: 300,
                member: "user1".to_string(),
                expire: 1,
            },
        ];

        for request in requests {
            assert_eq!(state.zincrbyp("test".to_string(), request), "OK");
        }

        // 초기 상태 확인
        let range_request = || ZRangeRequest {
            offset: 0,
            count: 1,
            withscores: true,
        };
        let result = state.zrange("test".to_string(), range_request());
        assert_eq!(result, r#"["user1:600"]"#);

        // 1.5초 후 확인 (모든 증가분 만료)
        thread::sleep(Duration::from_millis(1500));
        let result = state.zrange("test".to_string(), range_request());
        assert_eq!(result, "[]");
    }

    #[test]
    fn test_expire_with_different_tables() {
        use std::thread;
        use std::time::Duration;

        let state = RankedState::new();

        // 다른 테이블에 항목 추가
        let requests = vec![
            (
                "table1",
                ZIncrByPeriodRequest {
                    increment: 100,
                    member: "user1".to_string(),
                    expire: 1,
                },
            ),
            (
                "table2",
                ZIncrByPeriodRequest {
                    increment: 200,
                    member: "user1".to_string(),
                    expire: 2,
                },
            ),
        ];

        for (table, request) in requests {
            assert_eq!(state.zincrbyp(table.to_string(), request), "OK");
        }

        // 초기 상태 확인
        let range_request = || ZRangeRequest {
            offset: 0,
            count: 1,
            withscores: true,
        };
        let result1 = state.zrange("table1".to_string(), range_request());
        let result2 = state.zrange("table2".to_string(), range_request());
        assert_eq!(result1, r#"["user1:100"]"#);
        assert_eq!(result2, r#"["user1:200"]"#);

        // 1.5초 후 확인 (table1의 항목 만료)
        thread::sleep(Duration::from_millis(1500));
        let result1 = state.zrange("table1".to_string(), range_request());
        let result2 = state.zrange("table2".to_string(), range_request());
        assert_eq!(result1, "[]");
        assert_eq!(result2, r#"["user1:200"]"#);

        // 2.5초 후 확인 (table2의 항목 만료)
        thread::sleep(Duration::from_millis(1000));
        let result1 = state.zrange("table1".to_string(), range_request());
        let result2 = state.zrange("table2".to_string(), range_request());
        assert_eq!(result1, "[]");
        assert_eq!(result2, "[]");
    }

    #[test]
    fn stress_test_performance() {
        use std::sync::Arc;
        use std::thread;
        use std::time::Instant;

        let state = Arc::new(RankedState::new());
        let num_entries = 50_000_00;
        let num_threads = 8;
        let entries_per_thread = num_entries / num_threads;

        println!("Starting stress test with {} entries...", num_entries);

        // 데이터 삽입 테스트
        let insert_start = Instant::now();
        let mut handles = vec![];

        for thread_id in 0..num_threads {
            let state = Arc::clone(&state);
            let handle = thread::spawn(move || {
                let start = thread_id * entries_per_thread;
                let end = start + entries_per_thread;
                for i in start..end {
                    let request = ZIncrByPeriodRequest {
                        increment: (i % 1000) as i64 + 1,
                        member: format!("user{}", i),
                        expire: 3600, // 1시간
                    };
                    let result = state.zincrbyp("test".to_string(), request);
                    assert_eq!(result, "OK");
                }
            });
            handles.push(handle);
        }

        for handle in handles {
            handle.join().unwrap();
        }

        let insert_duration = insert_start.elapsed();
        println!("Insertion completed in {:?}", insert_duration);
        println!(
            "Insertion rate: {:.2} entries/sec",
            num_entries as f64 / insert_duration.as_secs_f64()
        );

        // 쿼리 테스트 - 랜덤 액세스
        let mut rng = rand::thread_rng();
        let mut total_query_duration = Duration::new(0, 0);

        // 100번 반복 테스트
        for _ in 0..10 {
            // 0부터 5000만까지 랜덤 오프셋 생성
            let random_offset = rng.gen_range(0..50_000_00);
            let range_request = ZRangeRequest {
                offset: random_offset,
                count: 100,
                withscores: true,
            };

            let query_start = std::time::Instant::now();
            let _result = state.zrevrange("test".to_string(), range_request);
            total_query_duration += query_start.elapsed();
        }

        let avg_query_duration = total_query_duration / 100;
        println!(
            "zrevrange query completed in {:?} (average over 100 iterations)",
            avg_query_duration
        );
        println!(
            "zrevrange query rate: {:.2} queries/sec",
            100.0 / total_query_duration.as_secs_f64()
        );

        // 메모리 사용량 확인
        let tables = state.tables.read().unwrap();
        let sorted_entries = tables.get("test").unwrap();
        // println!("Total entries in memory: {}", sorted_entries.len());

        let size_of_ranked_entry = std::mem::size_of::<RankedEntry>();
        let size_of_expire_entry = std::mem::size_of::<ExpireEntry>();

        println!(
            "Memory usage per RankedEntry: ~{} bytes",
            size_of_ranked_entry
        );
        println!(
            "Memory usage per ExpireEntry: ~{} bytes",
            size_of_expire_entry
        );

        // 메모리 최적화 수치 표시
        let original_exp_entry_size =
            std::mem::size_of::<String>() + std::mem::size_of::<Arc<String>>() + 16; // 16 = u64 + i64
        println!(
            "Memory optimization: Original ExpireEntry size: ~{} bytes",
            original_exp_entry_size
        );
        println!(
            "Memory optimization: Current ExpireEntry size: ~{} bytes",
            size_of_expire_entry
        );
        println!(
            "Memory optimization: Saving ~{} bytes per entry",
            original_exp_entry_size - size_of_expire_entry
        );
        // println!(
        //     "Total memory saved: ~{} MB",
        //     (original_exp_entry_size - size_of_expire_entry) * sorted_entries.len() / (1024 * 1024)
        // );

        // 만료 큐 크기 확인
        let expire_queue = state.expire_queue.lock().unwrap();
        println!("Total entries in expire queue: {}", expire_queue.len());

        // 테이블 관련 메모리 사용량
        let table_indices = state.table_indices.read().unwrap();
        let table_lookup = state.table_lookup.read().unwrap();
        println!("Number of unique tables: {}", table_lookup.len());
        println!(
            "Memory usage for table management: ~{} KB",
            (table_indices.len() * (std::mem::size_of::<String>() + std::mem::size_of::<usize>())
                + table_lookup.len() * std::mem::size_of::<String>())
                / 1024
        );
    }
}
