use colored::Colorize;

pub struct LookMLObject {
    pub name: String,
    pub index: usize,
    pub length: usize,
    pub chars: Vec<char>,
}

impl LookMLObject {
    fn match_check(&mut self) -> bool {
        if self.index == self.length {
            // println!("Found {} key.", self.name.red());
            self.index = 0;
            true
        } else {
            false
        }
    }

    pub fn match_character(&mut self, character: char) -> bool {
        if character == self.chars[self.index] {
            self.index += 1;
            return self.match_check();
        } else {
            self.index = 0;
            return false;
        }
    }
}
