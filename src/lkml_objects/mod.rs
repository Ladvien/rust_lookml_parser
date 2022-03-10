#[derive(Debug)]
pub struct LKMLFile {
    pub includes: Vec<Include>,
    pub views: Vec<View>,
}

impl LKMLFile {
    pub fn new() -> Self {
        Self {
            includes: Vec::new(),
            views: Vec::new(),
        }
    }
}
#[derive(Debug)]
pub struct Include {
    pub path: String,
}
#[derive(Debug)]
pub struct View {
    pub measures: Vec<Measure>,
    pub dimensions: Vec<Dimension>,
}
#[derive(Debug)]
pub struct Dimension {
    pub sql: String,
}
#[derive(Debug)]
pub struct Measure {
    sql: String,
}
