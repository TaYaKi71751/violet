// 고성능 IndexableSet: BTreeSet의 캐시 친화적 레이아웃을 반영하여 성능 극대화
use std::{cmp::Ordering, ops::Range};

const MIN_DEGREE: usize = 4; // B-Tree 최소 차수

#[derive(Debug, Clone)]
struct Node<T: Clone> {
    keys: Vec<T>,
    children: Vec<Option<Box<Node<T>>>>,
    size: usize,
    leaf: bool,
}

impl<T: Ord + Clone> Node<T> {
    fn new(leaf: bool) -> Self {
        Node {
            keys: Vec::new(),
            children: Vec::new(),
            size: 0,
            leaf,
        }
    }
}

#[derive(Debug)]
pub struct IndexableSet<T: Ord + Clone> {
    root: Option<Box<Node<T>>>,
}

impl<T: Ord + Clone> IndexableSet<T> {
    pub fn new() -> Self {
        Self {
            root: Some(Box::new(Node::new(true))),
        }
    }

    pub fn insert(&mut self, val: T) {
        let mut root = self.root.take().unwrap();
        if root.keys.len() == 2 * MIN_DEGREE - 1 {
            let mut s = Box::new(Node::new(false));
            s.children.push(Some(root));
            Self::split_child(&mut s, 0);
            Self::insert_non_full(&mut s, val);
            self.root = Some(s);
        } else {
            Self::insert_non_full(&mut root, val);
            self.root = Some(root);
        }
    }

    fn split_child(parent: &mut Box<Node<T>>, i: usize) {
        let y = parent.children[i].take().unwrap();
        let mut z = Box::new(Node::new(y.leaf));

        z.keys.extend_from_slice(&y.keys[MIN_DEGREE..]);
        let mid = y.keys[MIN_DEGREE - 1].clone();

        if !y.leaf {
            z.children.extend_from_slice(&y.children[MIN_DEGREE..]);
        }

        parent.keys.insert(i, mid);
        parent.children.insert(i + 1, Some(z));

        let mut y = *y;
        y.keys.truncate(MIN_DEGREE - 1);
        if !y.leaf {
            y.children.truncate(MIN_DEGREE);
        }

        parent.children[i] = Some(Box::new(y));
    }

    fn insert_non_full(node: &mut Box<Node<T>>, val: T) {
        let mut i = node.keys.len();

        while i > 0 && val < node.keys[i - 1] {
            i -= 1;
        }

        if node.leaf {
            if node.keys.get(i).map_or(true, |k| k != &val) {
                node.keys.insert(i, val);
                node.size += 1;
            }
        } else {
            if let Some(ref mut child) = node.children[i] {
                if child.keys.len() == 2 * MIN_DEGREE - 1 {
                    Self::split_child(node, i);
                    if val > node.keys[i] {
                        i += 1;
                    }
                }
                Self::insert_non_full(node.children[i].as_mut().unwrap(), val);
            }
            node.size = node
                .children
                .iter()
                .map(|c| c.as_ref().map_or(0, |n| n.size))
                .sum::<usize>()
                + node.keys.len();
        }
    }

    pub fn get(&self, mut index: usize) -> Option<&T> {
        let mut node = self.root.as_ref()?;
        loop {
            let mut total = 0;
            for (i, key) in node.keys.iter().enumerate() {
                let left_size = if node.leaf {
                    i
                } else {
                    node.children[i].as_ref().map_or(0, |c| c.size)
                };
                if index < left_size {
                    node = node.children[i].as_ref()?;
                    break;
                } else if index == left_size {
                    return Some(key);
                } else {
                    index -= left_size + 1;
                    total += left_size + 1;
                }
            }
            if node.leaf {
                return None;
            }
        }
    }

    pub fn range(&self, range: Range<usize>) -> Vec<&T> {
        let mut res = Vec::with_capacity(range.end - range.start);
        Self::range_inner(
            self.root.as_ref().unwrap(),
            range.start,
            range.end,
            0,
            &mut res,
        );
        res
    }

    fn range_inner<'a>(
        node: &'a Box<Node<T>>,
        start: usize,
        end: usize,
        mut index: usize,
        res: &mut Vec<&'a T>,
    ) -> usize {
        for i in 0..node.keys.len() {
            if !node.leaf {
                if let Some(ref child) = node.children[i] {
                    index = Self::range_inner(child, start, end, index, res);
                }
            }
            if index >= start && index < end {
                res.push(&node.keys[i]);
            }
            index += 1;
        }
        if !node.leaf {
            if let Some(ref child) = node.children.last().unwrap() {
                index = Self::range_inner(child, start, end, index, res);
            }
        }
        index
    }

    pub fn take(&mut self, val: &T) -> Option<T> {
        Self::take_inner(&mut self.root, val)
    }

    fn take_inner(node: &mut Option<Box<Node<T>>>, val: &T) -> Option<T> {
        let node_ref = node.as_mut()?;
        match node_ref.keys.binary_search(val) {
            Ok(i) => {
                if node_ref.leaf {
                    Some(node_ref.keys.remove(i))
                } else {
                    // Non-leaf node: more complex (not fully implemented here)
                    // Could replace with predecessor/successor and recurse
                    None
                }
            }
            Err(i) => {
                if node_ref.leaf {
                    None
                } else {
                    Self::take_inner(&mut node_ref.children[i], val)
                }
            }
        }
    }
}
