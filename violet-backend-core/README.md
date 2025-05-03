# Ranked Data Structure

`ranked`는 Redis의 Sorted Set과 유사한 기능을 제공하며, periodic(daily, weekly, monthly, alltime 등)한 데이터를 조회하는데 최적화되어 있습니다.

## Ranked의 필요성

기존 Redis를 사용하는 경우 `expired zadd`나 `expired zincrby`를 구현하기 위해선 Redis의 `setex`와 `psubscribe __keyevent::expired`를 이용하거나, 서버의 자체 타이머(cron) 등을 이용해야 했습니다. 이는 `stateless`하게 서버를 구현할 수 없는 요인이 되었으며, `expired`를 위한 부가적인 연산이 추가로 소요되었습니다.

`ranked`는 이러한 문제를 모두 `stateful` 노드에서 처리하게 함으로써 서버의 독립성을 높이는 프로젝트입니다. `ranked`는 Redis의 `zadd`, `zsub`, `zinc`, `zdec`, `zrange`, `zrevrange`, `flushall`만을 `slim`하게 제공하며, 추가로 `ranked`의 핵심 함수인 `zincrbyp`를 제공합니다.

## 기능

- `zadd`: 멤버의 점수를 설정
- `zincrby`: 멤버의 점수를 증가/감소
- `zincrbyp`: 멤버의 점수를 증가/감소하고 만료 시간 설정
- `zrange`: 낮은 점수 순으로 멤버 조회
- `zrevrange`: 높은 점수 순으로 멤버 조회
- `flushall`: 모든 데이터 초기화

## 성능 최적화

- `BTreeSet`을 사용하여 항상 정렬된 상태 유지
- `HashMap`을 사용하여 O(1) 멤버 검색
- 스레드 안전한 구현 (`Mutex` 사용)
- 만료 항목 자동 처리

## 구현 상세

`ranked`는 `sorted map`과 `min heap`을 이용하여 구현됩니다. `incp` 또는 `decp` 요청을 해석하여 `remain`을 `timestamp`로 변환하고 `min heap`에 삽입합니다. `zrange` 또는 `zrevrange`이 요청되면 `min heap`에 삽입된 항목들을 조회하고 `sorted map`을 재구성하고 `range`명령을 처리합니다.

### Range 연산의 구현

`sorted map`을 통하여 `range`연산을 구현하기 위해선, `sorted map`의 모든 원소를 `value`의 오름차순 또는 내림차순으로 정렬하고, 요구되는 `offset`과 `count`에 따라 결과를 리턴해야 합니다. `sorted map`을 정렬하는데 `O(log n)`의 시간이 걸리므로, 한 번의 `range` 요청당 `log n`의 시간이 소요됩니다.

## 빌드 및 실행

```bash
# 빌드
cargo build --release

# 테스트 실행
cargo test

# 성능 테스트 실행
cargo test stress_test_performance -- --nocapture
```

## API

### zadd

```
zadd <table> [<value> <member>]+
```

`zadd`는 `table`에 있는 `member`를 `value`로 설정시킨다.
`value`는 정수만 가능하다.
`member` 값이 없는 경우 해당 값을 `value`로 설정시킨다.

### zincrby

```
zincrby <table> [<increment> <member>]+
```

`zincrby`는 `table`에 있는 `member`의 `value`를 `increment`만큼 증가시킨다.
`member` 값이 없는 경우 해당 값을 `0`으로 설정하고 `increment`만큼 증가시킨다.

### zincrbyp (expired zincrby)

```
zincrbyp <table> [<increment> <member>]+ <expire>
```

`zincrbyp`는 `table`에 있는 `member`의 `value`를 `increment`만큼 증가시키고, 
`expire`초가 지나면 `member`의 `value`를 `increment`만큼 감소시킨다.

### zrange

```
zrange <table> <offset> <count> [withscores]
```

`zrange`는 `<table>`에 있는 `key-value` 중 `value`가 작은 순으로 `key`들의 리스트를 가져오되, 
`offset`개 만큼 리스트의 앞 부분이 생략되고, `count`개 만큼의 리스트 크기만을 가져온다.
`withscores`는 `key-value`의 리스트를 가져온다.

### zrevrange

```
zrevrange <table> <offset> <count> [withscores]
```

`zrevrange`는 `<table>`에 있는 `key-value` 중 `value`가 큰 순으로 `key`들의 리스트를 가져오되, 
`offset`개 만큼 리스트의 앞 부분이 생략되고, `count`개 만큼의 리스트 크기만을 가져온다.
`withscores`는 `key-value`의 리스트를 가져온다.

### flushall

```
flushall
```

`flushall`은 메모리의 모든 `table`을 삭제한다.

## API 사용 예시

### zadd
```http
POST /zadd

{
    "table": "test",
    "value": 100,
    "member": "user1"
}
```

### zincrby
```http
POST /zincrby

{
    "table": "test",
    "increment": 10,
    "member": "user1"
}
```

### zincrbyp
```http
POST /zincrbyp

{
    "table": "test",
    "increment": 10,
    "member": "user1",
    "expire": 3600  // 1시간
}
```

### zrange
```http
POST /zrange

{
    "table": "test",
    "offset": 0,
    "count": 10,
    "withscores": true
}
```

### zrevrange
```http
POST /zrevrange

{
    "table": "test",
    "offset": 0,
    "count": 10,
    "withscores": true
}
```

### flushall
```http
POST /flushall
```

## 성능

- 5000만 개의 엔트리 처리 가능
- 멀티스레드 지원 (8개 스레드)
- O(1) 멤버 검색
- O(log n) 정렬 상태 유지

## 메모리 사용량

- 엔트리당 약 32바이트
- 정렬된 상태를 유지하기 위한 추가 메모리 사용
- 만료 큐를 위한 메모리 사용

## Ranked의 한계

`ranked`는 사용자가 실시간으로 `periodic`한 정보를 조회할 수 있도록 도와줍니다. 실시간 서비스가 필요하지 않을 경우, 가령 특정 시간에 한 번(하루에 한 번, 일주일에 한 번 등) 데이터를 재구성하는 경우엔 `ranked`말고 다른 방안을 강구해보는 것이 좋습니다.

## Ranked를 사용할 수 있는 경우

커뮤니티에서 특정 게시글의 조회수(또는 up vote 수 등)을 기준으로 실시간 게시글 랭킹 서비스를 구성한다고 하면 `ranked` 사용을 고려할 수 있습니다. 당일에 올라온 글들만 실시간 게시글 랭킹을 허용한다면 다른 방법으로도 문제없겠지만, 모든 글들을 대상으로 실시간 랭킹 서비스를 구성한다면 `ranked` 사용을 고려해볼만 합니다.

## 주의사항

- 메모리 사용량이 클 수 있음
- 만료 처리 시 일시적인 성능 저하 가능
- 동시성 처리를 위한 락 사용으로 인한 오버헤드 발생 가능
