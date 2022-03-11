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
#[derive(Debug, PartialEq, Clone)]
pub struct Include {
    pub path: String,
}
#[derive(Debug, PartialEq, Clone)]
pub struct View {
    pub name: String,
    pub measures: Vec<Measure>,
    pub dimensions: Vec<Dimension>,
    pub dimension_groups: Vec<DimensionGroup>,
}
#[derive(Debug, PartialEq, Clone)]
pub struct Dimension {
    pub name: String,
    pub sql: String,
}
#[derive(Debug, PartialEq, Clone)]
pub struct Measure {
    pub name: String,
    pub sql: String,
}
#[derive(Debug, PartialEq, Clone)]
pub struct DimensionGroup {
    pub name: String,
    pub sql: String,
}
