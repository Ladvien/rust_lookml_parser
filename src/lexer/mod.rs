use self::token::Token;

pub mod token;
pub struct Lexer {
    input: Vec<char>,
    pub position: usize,
    pub read_position: usize,
    pub ch: char,
}

pub fn is_letter(ch: char) -> bool {
    'a' <= ch && ch <= 'z' || 'A' <= ch && ch <= 'Z' || ch == '_'
}

pub fn is_digit(ch: char) -> bool {
    '0' <= ch && ch <= '9'
}

pub fn is_whitespace(ch: char) -> bool {
    ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

impl Lexer {
    pub fn new(input: Vec<char>) -> Self {
        Self {
            input: input,
            position: 0,
            read_position: 0,
            ch: '~',
        }
    }

    pub fn read_char(&mut self) {
        if self.read_position >= self.input.len() {
            self.ch = '0';
        } else {
            self.ch = self.input[self.read_position]
        }
        self.position = self.read_position;
        self.read_position += 1;
    }

    pub fn skip_whitespace(&mut self) {
        while self.read_position <= self.input.len() && is_whitespace(self.ch) {
            self.read_char()
        }
    }

    pub fn next_token(&mut self) -> Token {
        let read_identifier = |l: &mut Lexer| -> Vec<char> {
            let start_position = l.position;
            while l.position < l.input.len() && is_letter(l.ch) || is_digit(l.ch) {
                l.read_char()
            }
            l.input[start_position..l.position].to_vec()
        };

        let tok: Token;
        self.skip_whitespace();
        match self.ch {
            '~' => tok = token::Token::BOF,
            '0' => tok = token::Token::EOF,
            '=' => tok = token::Token::EQL(self.ch),
            '"' => tok = token::Token::DBLQ(self.ch),
            '@' => tok = token::Token::CONST(self.ch),
            '$' => tok = token::Token::SYMB(self.ch),
            '.' => tok = token::Token::DOT(self.ch),
            ';' => tok = token::Token::SEMI(self.ch),
            ':' => tok = token::Token::COLON(self.ch),
            '{' => tok = token::Token::LCURLY(self.ch),
            '}' => tok = token::Token::RCURLY(self.ch),
            '[' => tok = token::Token::LBRACK(self.ch),
            ']' => tok = token::Token::RBRACK(self.ch),
            _ => {
                if is_letter(self.ch) {
                    let ident: Vec<char> = read_identifier(self);
                    match token::get_keyword_token(&ident) {
                        Ok(keyword_token) => return keyword_token,
                        Err(_) => return token::Token::IDENT(ident),
                    }
                } else {
                    tok = token::Token::ILLEGAL(self.ch);
                }
            }
        }
        self.read_char();
        tok
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn whitespace_skipped_catches_spaces() {
        let ch = ' ';
        assert!(is_whitespace(ch));
    }

    #[test]
    fn whitespace_skipped_catches_tabs() {
        let ch = '\t';
        assert!(is_whitespace(ch));
    }

    #[test]
    fn whitespace_skipped_catches_newline() {
        let ch = '\n';
        assert!(is_whitespace(ch));
    }

    #[test]
    fn whitespace_skipped_catches_carriage_return() {
        let ch = '\r';
        assert!(is_whitespace(ch));
    }

    #[test]
    fn whitespace_skipped() {
        let input = r#"dimension: test {
            
        "#;
        let mut lexer = Lexer::new(input.chars().collect());
        loop {
            let token = lexer.next_token();
            match token {
                Token::ILLEGAL(_) => debug_assert!(false),
                Token::EOF => break,
                _ => (),
            }
        }
    }
}
