use core::fmt;
use std::{marker::PhantomData, ops::Range, ptr::NonNull};

const MIN_DEGREE: usize = 40;

#[derive(Debug, Clone)]
struct Node<T: Clone + fmt::Debug> {
    keys: Vec<T>, // In leaf: actual data, in internal: routing keys
    children: Vec<Option<Box<Node<T>>>>,
    leaf: bool,
    next: Option<NonNull<Node<T>>>,
}

impl<T: Clone + fmt::Debug> Node<T> {
    fn new(leaf: bool) -> Self {
        Self {
            keys: Vec::new(),
            children: Vec::new(),
            leaf,
            next: None,
        }
    }
}

#[derive(Debug)]
pub struct IndexableSet<T: Ord + Clone + fmt::Debug> {
    root: Option<Box<Node<T>>>,
    first_leaf: Option<NonNull<Node<T>>>,
}

unsafe impl<T: Send + Ord + Clone + fmt::Debug> Send for IndexableSet<T> {}
unsafe impl<T: Send + Ord + Clone + fmt::Debug> Sync for IndexableSet<T> {}

impl<T: Ord + Clone + fmt::Debug> IndexableSet<T> {
    #[allow(clippy::new_without_default)]
    pub fn new() -> Self {
        Self {
            root: Some(Box::new(Node::new(true))),
            first_leaf: None,
        }
    }

    pub fn insert(&mut self, val: T) {
        let mut root = self.root.take().unwrap();
        if root.keys.len() == 2 * MIN_DEGREE - 1 {
            let mut s = Box::new(Node::new(false));
            s.children.push(Some(root));
            self.split_child(&mut s, 0);
            self.insert_non_full(&mut s, val);
            self.root = Some(s);
        } else {
            self.insert_non_full(&mut root, val);
            self.root = Some(root);
        }
        if self.first_leaf.is_none() {
            self.first_leaf = Self::find_first_leaf(self.root.as_ref());
        }
    }

    fn insert_non_full(&mut self, node: &mut Box<Node<T>>, val: T) {
        if node.leaf {
            match node.keys.binary_search(&val) {
                Ok(_) => {} // duplicate
                Err(i) => node.keys.insert(i, val),
            }
        } else {
            let mut i = match node.keys.binary_search(&val) {
                Ok(i) => i + 1,
                Err(i) => i,
            };

            let child = node.children[i].as_mut().unwrap();
            if child.keys.len() == 2 * MIN_DEGREE - 1 {
                self.split_child(node, i);
                if val > node.keys[i] {
                    i += 1;
                }
            }
            self.insert_non_full(node.children[i].as_mut().unwrap(), val);
        }
    }

    fn split_child(&mut self, parent: &mut Box<Node<T>>, i: usize) {
        let mut y = parent.children[i].take().unwrap();
        let mut z = Box::new(Node::new(y.leaf));
        let mid = MIN_DEGREE;

        // 키 분할
        z.keys.extend(y.keys.drain(mid..));

        if y.leaf {
            // ✅ leaf chaining 유지
            z.next = y.next;
            let z_ptr = NonNull::from(&*z);
            y.next = Some(z_ptr);

            // ✅ B+Tree에서는 leaf split 시 promote하지 않고 key만 복사
            let separator = z.keys[0].clone();
            parent.keys.insert(i, separator);
        } else {
            // ✅ internal node는 key를 하나 promote (중간 key)
            let promoted = y.keys.pop().unwrap(); // mid번째 key
            z.children.extend(y.children.drain(mid..));

            parent.keys.insert(i, promoted);
        }

        parent.children.insert(i + 1, Some(z));
        parent.children[i] = Some(y);
    }

    #[allow(clippy::borrowed_box)]
    fn find_first_leaf(node: Option<&Box<Node<T>>>) -> Option<NonNull<Node<T>>> {
        let mut curr = node;
        while let Some(n) = curr {
            if n.leaf {
                return Some(NonNull::from(&**n));
            }
            curr = n.children.first()?.as_ref();
        }
        None
    }

    pub fn range_iter(&self, range: Range<usize>) -> impl Iterator<Item = &T> {
        struct LeafIter<'a, T: Clone + fmt::Debug> {
            current: Option<NonNull<Node<T>>>,
            global_index: usize,
            range: Range<usize>,
            index_in_node: usize,
            _marker: PhantomData<&'a T>,
        }

        impl<'a, T: Clone + fmt::Debug> Iterator for LeafIter<'a, T> {
            type Item = &'a T;

            fn next(&mut self) -> Option<Self::Item> {
                while let Some(ptr) = self.current {
                    let node = unsafe { ptr.as_ref() };
                    while self.index_in_node < node.keys.len() {
                        if self.range.contains(&self.global_index) {
                            let result = &node.keys[self.index_in_node];
                            self.index_in_node += 1;
                            self.global_index += 1;
                            return Some(result);
                        }
                        self.index_in_node += 1;
                        self.global_index += 1;
                    }
                    self.index_in_node = 0;
                    self.current = node.next;
                }
                None
            }
        }

        LeafIter {
            current: self.first_leaf,
            global_index: 0,
            range,
            index_in_node: 0,
            _marker: PhantomData,
        }
    }

    pub fn take(&mut self, val: &T) -> Option<T> {
        Self::take_inner(self.root.as_mut(), val)
    }

    fn take_inner(node: Option<&mut Box<Node<T>>>, val: &T) -> Option<T> {
        let node = node?;
        if node.leaf {
            if let Ok(i) = node.keys.binary_search(val) {
                Some(node.keys.remove(i))
            } else {
                None
            }
        } else {
            let i = match node.keys.binary_search(val) {
                Ok(i) => i + 1,
                Err(i) => i,
            };
            Self::take_inner(node.children[i].as_mut(), val)
        }
    }
}
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_split_child_leaf_correctness() {
        let mut set = IndexableSet::new();

        // leaf 하나에 가득 차도록 삽입 (2 * MIN_DEGREE)
        for i in 0..(2 * MIN_DEGREE) {
            set.insert(i as i32);
        }

        // 강제로 split 발생하도록 루트부터 다시 삽입
        set.insert((2 * MIN_DEGREE) as i32);

        let root = set.root.as_ref().unwrap();

        // 1. 루트는 내부 노드여야 함
        assert!(!root.leaf);

        // 2. 자식은 2개 있어야 하고, 모두 leaf
        assert_eq!(root.children.len(), 2);
        let left = root.children[0].as_ref().unwrap();
        let right = root.children[1].as_ref().unwrap();
        assert!(left.leaf && right.leaf);

        // 3. key가 잘 분할되어 있음
        assert_eq!(left.keys.len(), MIN_DEGREE); // 0..MIN_DEGREE
        assert_eq!(right.keys.len(), MIN_DEGREE + 1); // MIN_DEGREE..(2*MIN_DEGREE)

        // 4. 루트의 keys에는 오른쪽 leaf의 첫 키가 올라와 있어야 함 (B+Tree promote rule)
        assert_eq!(root.keys.len(), 1);
        assert_eq!(root.keys[0], right.keys[0]);

        // 5. leaf chaining 확인 (left.next -> right)
        let right_ptr = NonNull::from(&**right);
        assert_eq!(left.next, Some(right_ptr));
    }

    #[test]
    fn test_insert_and_range_iter_order() {
        let mut set = IndexableSet::new();
        for &val in &[10, 20, 5, 15, 25] {
            set.insert(val);
        }

        let collected: Vec<_> = set.range_iter(0..5).copied().collect();
        assert_eq!(collected, vec![5, 10, 15, 20, 25]);
    }

    fn print_leaf_chain_via_tree<T: std::fmt::Debug + Clone>(node: &Option<Box<Node<T>>>) {
        if let Some(n) = node {
            let this_ptr = n.as_ref() as *const Node<T>;
            println!("Leaf {} {:p} keys: {:?}", n.leaf, this_ptr, n.keys);
            if n.leaf {
                if let Some(next) = n.next {
                    let next_node = unsafe { next.as_ref() };
                    println!(
                        "   → next {:p} keys: {:?}",
                        next_node as *const Node<T>, next_node.keys
                    );
                } else {
                    println!("   → next: None");
                }
            } else {
                // 내부 노드: 자식들을 재귀적으로 검사
                for child in &n.children {
                    print_leaf_chain_via_tree(child);
                }
            }
        }
    }

    #[test]
    fn test_range_iter_correctness_small() {
        let mut set = IndexableSet::new();
        let max = 40;
        for i in 0..max {
            set.insert(i);
        }

        println!("== Leaf chain traversal via tree ==");
        print_leaf_chain_via_tree(&set.root);

        // 1. leaf chaining 검증
        let mut visited = vec![];
        let mut ptr = set.first_leaf;
        while let Some(p) = ptr {
            unsafe {
                let node = p.as_ref();
                visited.extend_from_slice(&node.keys);
                println!("node: {:?}", node.keys);
                println!("next: {:?}", node.next);
                ptr = node.next;
            }
        }

        // leaf chaining으로 순회한 결과도 정렬된 전체 key와 일치해야 함
        assert_eq!(visited, (0..max).collect::<Vec<_>>());

        // 2. range_iter로 정렬 순서 확인
        let collected: Vec<_> = set.range_iter(0..max).copied().collect();
        let expected: Vec<_> = (0..max).collect();

        assert_eq!(collected, expected);
    }

    #[test]
    fn test_insert_path_debug() {
        let mut set = IndexableSet::new();

        // 일부러 split 유도하는 값들 삽입
        for &v in &[10, 20, 30, 40, 50, 60, 70, 49] {
            println!("Inserting: {}", v);
            print_leaf_chain_via_tree(&set.root);
            set.insert(v);
        }

        // 트리 구조 출력
        fn print_tree<T: std::fmt::Debug + Clone>(node: &Option<Box<Node<T>>>, depth: usize) {
            if let Some(n) = node {
                let indent = "  ".repeat(depth);
                println!("{}Node (leaf={}): keys = {:?}", indent, n.leaf, n.keys);
                if !n.leaf {
                    for (i, c) in n.children.iter().enumerate() {
                        println!("{}  child[{}]:", indent, i);
                        print_tree(c, depth + 2);
                    }
                } else if let Some(next) = n.next {
                    let next_node = unsafe { next.as_ref() };
                    println!("{}  → next: keys = {:?}", indent, next_node.keys);
                }
            }
        }

        println!("===== Tree Structure =====");
        print_tree(&set.root, 0);

        // leaf chain도 직접 확인
        println!("===== Leaf chain via next pointers =====");
        let mut ptr = set.first_leaf;
        while let Some(p) = ptr {
            unsafe {
                let node = p.as_ref();
                println!("Leaf @{:p}: keys = {:?}", node as *const _, node.keys);
                ptr = node.next;
            }
        }

        // range_iter 결과 비교
        let collected: Vec<_> = set.range_iter(0..8).copied().collect();
        println!("Collected range_iter(0..8): {:?}", collected);
    }

    #[test]
    fn test_large_insert_and_range_iter_order() {
        use rand::{seq::SliceRandom, thread_rng};
        let mut set = IndexableSet::new();
        let max = 10_000_000usize;
        let mut data: Vec<usize> = (0..max).collect();
        data.shuffle(&mut thread_rng());

        for &val in &data {
            set.insert(val);
        }

        if max < 1000 {
            println!("== Leaf chain traversal via tree ==");
            print_leaf_chain_via_tree(&set.root);
        }

        // 결과가 정렬되어 있어야 한다
        let collected: Vec<_> = set.range_iter(0..max).copied().collect();
        assert_eq!(collected, (0..max).collect::<Vec<_>>());
    }

    #[test]
    fn test_duplicate_insert() {
        let mut set = IndexableSet::new();
        set.insert(10);
        set.insert(10);
        let collected: Vec<_> = set.range_iter(0..2).copied().collect();
        assert_eq!(collected, vec![10]);
    }

    #[test]
    fn test_take_existing() {
        let mut set = IndexableSet::new();
        for &val in &[1, 2, 3, 4] {
            set.insert(val);
        }
        assert_eq!(set.take(&3), Some(3));
        let collected: Vec<_> = set.range_iter(0..3).copied().collect();
        assert_eq!(collected, vec![1, 2, 4]);
    }

    #[test]
    fn test_take_nonexistent() {
        let mut set = IndexableSet::new();
        set.insert(42);
        assert_eq!(set.take(&100), None);
        let collected: Vec<_> = set.range_iter(0..1).copied().collect();
        assert_eq!(collected, vec![42]);
    }

    #[test]
    fn test_empty_range_iter() {
        let set: IndexableSet<i32> = IndexableSet::new();
        let collected: Vec<i32> = set.range_iter(0..10).copied().collect();
        assert_eq!(collected, vec![0; 0]);
    }
}
