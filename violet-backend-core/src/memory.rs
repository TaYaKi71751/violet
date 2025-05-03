use serde::{Deserialize, Serialize};
use std::cmp::Ordering;
use std::collections::{BTreeSet, BinaryHeap, HashMap};
use std::fs;
use std::path::Path;
use std::sync::{Arc, Mutex, RwLock};
use std::time::{SystemTime, UNIX_EPOCH};

const PAGE_SIZE: usize = 5_000_00;
const MAX_MEMORY_ENTRIES: usize = 3_000_00; // 약 2GB 제한

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

#[derive(Debug, Serialize, Deserialize)]
struct Page {
    entries: Vec<RankedEntry>,
    min_value: i64,
    max_value: i64,
}

impl Page {
    fn new() -> Self {
        Page {
            entries: Vec::with_capacity(PAGE_SIZE),
            min_value: i64::MAX,
            max_value: i64::MIN,
        }
    }

    fn add_entry(&mut self, entry: RankedEntry) {
        self.min_value = self.min_value.min(entry.value);
        self.max_value = self.max_value.max(entry.value);
        self.entries.push(entry);
    }

    fn save_to_file(&self, path: &Path) -> std::io::Result<()> {
        let entries: Vec<_> = self
            .entries
            .iter()
            .map(|entry| {
                let member = entry.member.as_ref().clone();
                (entry.value, member, entry.expire)
            })
            .collect();
        let json = serde_json::to_string(&entries)?;
        fs::write(path, json)?;
        Ok(())
    }

    fn load_from_file(path: &Path) -> std::io::Result<Self> {
        let json = fs::read_to_string(path)?;
        let entries: Vec<(i64, String, Option<u64>)> = serde_json::from_str(&json)?;

        let mut page = Page::new();
        for (value, member, expire) in entries {
            page.add_entry(RankedEntry {
                value,
                member: Arc::new(member),
                expire,
            });
        }
        Ok(page)
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
    tables: RwLock<HashMap<String, BTreeSet<RankedEntry>>>,
    expire_queue: Mutex<BinaryHeap<ExpireEntry>>,
    table_lookup: RwLock<Vec<String>>,
    table_indices: RwLock<HashMap<String, usize>>,
    page_dir: String,
    current_page: RwLock<HashMap<String, usize>>,
}

impl RankedState {
    pub fn new(page_dir: String) -> Self {
        // 페이지 디렉토리 생성
        fs::create_dir_all(&page_dir).unwrap();

        RankedState {
            tables: RwLock::new(HashMap::new()),
            expire_queue: Mutex::new(BinaryHeap::new()),
            table_lookup: RwLock::new(Vec::new()),
            table_indices: RwLock::new(HashMap::new()),
            page_dir,
            current_page: RwLock::new(HashMap::new()),
        }
    }

    fn get_page_path(&self, table: &str, page_num: usize) -> String {
        format!("{}/{}_{}.json", self.page_dir, table, page_num)
    }

    fn save_current_page(&self, table: &str) -> std::io::Result<()> {
        let tables = self.tables.read().unwrap();
        if let Some(entries) = tables.get(table) {
            let mut page = Page::new();
            for entry in entries.iter() {
                page.add_entry(entry.clone());
            }

            let page_num = *self.current_page.read().unwrap().get(table).unwrap_or(&0);
            let path = self.get_page_path(table, page_num);
            page.save_to_file(Path::new(&path))?;
        }
        Ok(())
    }

    fn load_page(&self, table: &str, page_num: usize) -> std::io::Result<()> {
        let path = self.get_page_path(table, page_num);
        let page = Page::load_from_file(Path::new(&path))?;

        let mut tables = self.tables.write().unwrap();
        let sorted_entries = tables
            .entry(table.to_string())
            .or_insert_with(BTreeSet::new);
        sorted_entries.clear();

        for entry in page.entries {
            sorted_entries.insert(entry);
        }

        Ok(())
    }

    fn check_and_save_page(&self, table: &str) -> std::io::Result<()> {
        // 1. 현재 메모리 상태 확인
        let (should_save, entries_to_save) = {
            let tables = self.tables.read().unwrap();
            if let Some(entries) = tables.get(table) {
                if entries.len() >= MAX_MEMORY_ENTRIES {
                    (true, entries.iter().cloned().collect::<Vec<_>>())
                } else {
                    (false, Vec::new())
                }
            } else {
                (false, Vec::new())
            }
        };

        if should_save {
            // 2. 페이지 저장
            let mut page = Page::new();
            for entry in entries_to_save {
                page.add_entry(entry);
            }

            let page_num = {
                let current_page = self.current_page.read().unwrap();
                *current_page.get(table).unwrap_or(&0)
            };

            let path = self.get_page_path(table, page_num);
            page.save_to_file(Path::new(&path))?;

            // 3. 페이지 번호 증가 및 메모리 클리어
            {
                let mut current_page = self.current_page.write().unwrap();
                let page_num = current_page.entry(table.to_string()).or_insert(0);
                *page_num += 1;
            }

            let mut tables = self.tables.write().unwrap();
            if let Some(entries) = tables.get_mut(table) {
                entries.clear();
            }
        }

        Ok(())
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

        // 1. 만료된 항목 수집
        let expired_entries = {
            let mut expire_queue = self.expire_queue.lock().unwrap();
            let mut expired = Vec::new();
            while let Some(entry) = expire_queue.peek() {
                if entry.expire_time > now {
                    break;
                }
                expired.push(expire_queue.pop().unwrap());
            }
            expired
        };

        // 2. 만료된 항목 처리
        if !expired_entries.is_empty() {
            let mut tables = self.tables.write().unwrap();
            for entry in expired_entries {
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
    }

    pub fn zadd(&self, table: String, request: ZAddRequest) -> String {
        self.process_expired_entries();

        let member = Arc::new(request.member);
        let mut tables = self.tables.write().unwrap();
        let sorted_entries = tables.entry(table.clone()).or_insert_with(BTreeSet::new);

        let entry = RankedEntry {
            value: request.value,
            member: member,
            expire: None,
        };

        sorted_entries.replace(entry);

        // 페이지 저장 체크
        drop(tables);
        self.check_and_save_page(&table).unwrap();

        "OK".to_string()
    }

    pub fn zincrby(&self, table: String, request: ZIncrByRequest) -> String {
        self.process_expired_entries();

        let member = Arc::new(request.member);
        {
            let mut tables = self.tables.write().unwrap();
            let sorted_entries = tables.entry(table.clone()).or_insert_with(BTreeSet::new);

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

            // 페이지 저장 체크
            drop(tables);
        }
        self.check_and_save_page(&table).unwrap();

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

        // 1. 데이터 업데이트
        {
            let mut tables = self.tables.write().unwrap();
            let sorted_entries = tables.entry(table.clone()).or_insert_with(BTreeSet::new);

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
        }

        // 2. 만료 큐 업데이트
        {
            let mut expire_queue = self.expire_queue.lock().unwrap();
            expire_queue.push(ExpireEntry {
                expire_time: now + request.expire,
                table_id: table_id,
                member: member,
                value: request.increment,
            });
        }

        // 3. 페이지 저장 체크
        self.check_and_save_page(&table).unwrap();

        "OK".to_string()
    }

    pub fn zrange(&self, table: String, request: ZRangeRequest) -> String {
        self.process_expired_entries();

        let mut result = Vec::new();
        let mut remaining = request.count;
        let mut offset = request.offset;

        // 1. 메모리에 있는 데이터 처리
        {
            let tables = self.tables.read().unwrap();
            if let Some(sorted_entries) = tables.get(&table) {
                // 메모리에 있는 데이터의 범위 확인
                let memory_min = sorted_entries.first().map(|e| e.value).unwrap_or(i64::MAX);
                let memory_max = sorted_entries.last().map(|e| e.value).unwrap_or(i64::MIN);

                // 현재 페이지 번호 확인
                let current_page = self.current_page.read().unwrap();
                let page_num = *current_page.get(&table).unwrap_or(&0);

                // 디스크의 페이지들을 확인하여 정렬 순서 결정
                let mut disk_pages = Vec::new();
                for i in 0..page_num {
                    if let Ok(page) =
                        Page::load_from_file(Path::new(&self.get_page_path(&table, i)))
                    {
                        disk_pages.push((i, page.min_value, page.max_value));
                    }
                }

                // 메모리 데이터가 처리될 위치 계산
                let mut memory_start = 0;
                let mut memory_end = sorted_entries.len();

                // 디스크 페이지 중 메모리 데이터보다 작은 값이 있는지 확인
                for (_, min, max) in &disk_pages {
                    if *max < memory_min {
                        memory_start += PAGE_SIZE;
                        memory_end += PAGE_SIZE;
                    } else if *min > memory_max {
                        break;
                    }
                }

                // 메모리 데이터 처리
                let start = offset.saturating_sub(memory_start);
                let end = (start + remaining).min(memory_end - memory_start);

                if start < sorted_entries.len() {
                    result = sorted_entries
                        .iter()
                        .skip(start)
                        .take(end - start)
                        .map(|entry| {
                            if request.withscores {
                                format!("{}:{}", entry.member, entry.value)
                            } else {
                                entry.member.to_string()
                            }
                        })
                        .collect();

                    remaining -= end - start;
                    offset = offset.saturating_sub(memory_end);
                }
            }
        }

        // 2. 디스크의 페이지 처리
        if remaining > 0 {
            let current_page = self.current_page.read().unwrap();
            let mut page_num = *current_page.get(&table).unwrap_or(&0);

            while remaining > 0 && page_num > 0 {
                page_num -= 1;
                if let Ok(page) =
                    Page::load_from_file(Path::new(&self.get_page_path(&table, page_num)))
                {
                    let start = offset.min(page.entries.len());
                    let end = (start + remaining).min(page.entries.len());

                    result.extend(
                        page.entries
                            .iter()
                            .skip(start)
                            .take(end - start)
                            .map(|entry| {
                                if request.withscores {
                                    format!("{}:{}", entry.member, entry.value)
                                } else {
                                    entry.member.to_string()
                                }
                            }),
                    );

                    remaining -= end - start;
                    offset = offset.saturating_sub(page.entries.len());
                }
            }
        }

        serde_json::to_string(&result).unwrap()
    }

    pub fn zrevrange(&self, table: String, request: ZRangeRequest) -> String {
        self.process_expired_entries();

        let mut result = Vec::new();
        let mut remaining = request.count;
        let mut offset = request.offset;

        // 1. 메모리에 있는 데이터 처리
        {
            let tables = self.tables.read().unwrap();
            if let Some(sorted_entries) = tables.get(&table) {
                // 메모리에 있는 데이터의 범위 확인
                let memory_min = sorted_entries.first().map(|e| e.value).unwrap_or(i64::MAX);
                let memory_max = sorted_entries.last().map(|e| e.value).unwrap_or(i64::MIN);

                // 현재 페이지 번호 확인
                let current_page = self.current_page.read().unwrap();
                let page_num = *current_page.get(&table).unwrap_or(&0);

                // 디스크의 페이지들을 확인하여 정렬 순서 결정
                let mut disk_pages = Vec::new();
                for i in 0..page_num {
                    if let Ok(page) =
                        Page::load_from_file(Path::new(&self.get_page_path(&table, i)))
                    {
                        disk_pages.push((i, page.min_value, page.max_value));
                    }
                }

                // 메모리 데이터가 처리될 위치 계산 (역순)
                let mut memory_start = 0;
                let mut memory_end = sorted_entries.len();

                // 디스크 페이지 중 메모리 데이터보다 큰 값이 있는지 확인
                for (_, min, max) in disk_pages.iter().rev() {
                    if *min > memory_max {
                        memory_start += PAGE_SIZE;
                        memory_end += PAGE_SIZE;
                    } else if *max < memory_min {
                        break;
                    }
                }

                // 메모리 데이터 처리 (역순)
                let start = offset.saturating_sub(memory_start);
                let end = (start + remaining).min(memory_end - memory_start);

                if start < sorted_entries.len() {
                    result = sorted_entries
                        .iter()
                        .rev()
                        .skip(start)
                        .take(end - start)
                        .map(|entry| {
                            if request.withscores {
                                format!("{}:{}", entry.member, entry.value)
                            } else {
                                entry.member.to_string()
                            }
                        })
                        .collect();

                    remaining -= end - start;
                    offset = offset.saturating_sub(memory_end);
                }
            }
        }

        // 2. 디스크의 페이지 처리 (역순)
        if remaining > 0 {
            let current_page = self.current_page.read().unwrap();
            let mut page_num = *current_page.get(&table).unwrap_or(&0);

            while remaining > 0 && page_num > 0 {
                page_num -= 1;
                if let Ok(page) =
                    Page::load_from_file(Path::new(&self.get_page_path(&table, page_num)))
                {
                    let start = offset.min(page.entries.len());
                    let end = (start + remaining).min(page.entries.len());

                    result.extend(page.entries.iter().rev().skip(start).take(end - start).map(
                        |entry| {
                            if request.withscores {
                                format!("{}:{}", entry.member, entry.value)
                            } else {
                                entry.member.to_string()
                            }
                        },
                    ));

                    remaining -= end - start;
                    offset = offset.saturating_sub(page.entries.len());
                }
            }
        }

        serde_json::to_string(&result).unwrap()
    }

    pub fn flushall(&self) -> String {
        let mut tables = self.tables.write().unwrap();
        let mut expire_queue = self.expire_queue.lock().unwrap();
        let mut table_indices = self.table_indices.write().unwrap();
        let mut table_lookup = self.table_lookup.write().unwrap();
        let mut current_page = self.current_page.write().unwrap();

        tables.clear();
        expire_queue.clear();
        table_indices.clear();
        table_lookup.clear();
        current_page.clear();

        // 페이지 파일 삭제
        if let Ok(entries) = fs::read_dir(&self.page_dir) {
            for entry in entries {
                if let Ok(entry) = entry {
                    let _ = fs::remove_file(entry.path());
                }
            }
        }

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
        let state = RankedState::new("test".to_string());
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
        let state = RankedState::new("test".to_string());
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
        let state = RankedState::new("test".to_string());
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
        let state = RankedState::new("test".to_string());

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
        let state = RankedState::new("test".to_string());

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
        let state = RankedState::new("test".to_string());

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
        let state = Arc::new(RankedState::new("test".to_string()));
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

        let state = RankedState::new("test".to_string());

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

        let state = RankedState::new("test".to_string());

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

        let state = RankedState::new("test".to_string());

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

        let state = RankedState::new("test".to_string());

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
    fn test_page_stress() {
        let state = Arc::new(RankedState::new("./page".to_string()));
        let num_entries = 50_000_00;
        let num_threads = 8;
        let entries_per_thread = num_entries / num_threads;

        println!("Starting page stress test with {} entries...", num_entries);

        // 데이터 삽입 테스트
        let insert_start = std::time::Instant::now();
        let mut handles = vec![];

        for thread_id in 0..num_threads {
            let state = Arc::clone(&state);
            let handle = thread::spawn(move || {
                let start = thread_id * entries_per_thread;
                let end = start + entries_per_thread;
                for i in start..end {
                    let request = ZIncrByRequest {
                        increment: (i % 1000) as i64 + 1,
                        member: format!("user{}", i),
                    };
                    let result = state.zincrby("test".to_string(), request);
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

        // 페이지 수 확인
        let current_page = state.current_page.read().unwrap();
        let page_count = current_page.get("test").unwrap_or(&0);
        println!("Total pages created: {}", page_count);

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
            let _result = state.zrange("test".to_string(), range_request);
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
        println!("Current entries in memory: {}", sorted_entries.len());
        println!(
            "Memory usage per entry: ~{} bytes",
            std::mem::size_of::<RankedEntry>()
        );

        // 페이지 파일 크기 확인
        let mut total_page_size = 0;
        for i in 0..=*page_count {
            if let Ok(metadata) = fs::metadata(state.get_page_path("test", i)) {
                total_page_size += metadata.len();
            }
        }
        println!(
            "Total page file size: {} MB",
            total_page_size / (1024 * 1024)
        );
    }
}
