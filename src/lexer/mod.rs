use std::process::exit;

use self::token::Token;
use self::token::Token::*;

use crate::lkml_objects::*;

pub mod token;
pub struct Lexer {
    pub position: usize,
    pub read_position: usize,
    pub ch: char,
    pub file: LKMLFile,
    input: Vec<char>,
    input_length: usize,
}

pub fn is_letter(ch: char) -> bool {
    'a' <= ch && ch <= 'z' || 'A' <= ch && ch <= 'Z' || ch == '_'
}

pub fn is_digit(ch: char) -> bool {
    '0' <= ch && ch <= '9'
}

pub fn is_whitespace(ch: char) -> bool {
    ch == ' ' || ch == '\t'
    //  || ch == '\r' || ch == '\n'
}

impl Lexer {
    pub fn new(input: Vec<char>) -> Self {
        Self {
            input: input.clone(),
            position: 0,
            read_position: 0,
            ch: '~',
            input_length: input.len(),
            file: LKMLFile::new(),
        }
    }

    fn is_escaped_string(&mut self) -> bool {
        return self.ch == '\\' && self.peek(1) == '"';
    }

    fn is_lkml_param(&mut self) -> bool {
        self.peek(1) == ':'
    }

    fn text2token(&mut self, text: Vec<char>) -> Token {
        self.skip_whitespace();
        if self.is_lkml_param() {
            self.read_char();
            self.skip_whitespace();

            let argument = self.read_argument();

            match token::get_lookml_parameter(&text, argument) {
                Ok(parameter_token) => return parameter_token,
                Err(_) => return token::Token::IDENT(text),
            }
        } else {
            match token::get_keyword_token(&text) {
                Ok(keyword_token) => return keyword_token,
                Err(_) => return token::Token::IDENT(text),
            }
        }
    }

    fn skip_whitespace(&mut self) {
        while self.read_position <= self.input_length && is_whitespace(self.ch) {
            self.read_char()
        }
    }

    fn peek(&mut self, dist: usize) -> char {
        let mut peek_position = self.position;
        while peek_position <= self.input_length && is_whitespace(self.input[peek_position]) {
            peek_position += 1;
        }
        self.input[peek_position + dist - 1]
    }

    fn read_until(&mut self, ch: char) -> Vec<char> {
        let start_position = self.position;
        while self.ch != ch && !self.is_escaped_string() {
            self.skip_whitespace();
            self.read_char();
        }
        self.input[start_position..self.position].to_vec()
    }

    fn read_until_any(&mut self, chs: Vec<char>) -> Vec<char> {
        let start_position = self.position;
        while !chs.contains(&self.ch) && !self.is_escaped_string() {
            self.read_char();
        }
        self.input[start_position..self.position].to_vec()
    }

    fn read_identifier(&mut self) -> Vec<char> {
        let start_position = self.position;
        while self.position < self.input_length && is_letter(self.ch) || is_digit(self.ch) {
            self.read_char()
        }
        self.input[start_position..self.position].to_vec()
    }

    fn read_argument(&mut self) -> Vec<char> {
        if self.ch == '\"' {
            self.read_char();
            return self.read_until('\"');
        } else {
            return self.read_until_any(vec![' ', '{']);
        }
    }

    fn read_char(&mut self) {
        if self.read_position >= self.input_length {
            self.ch = '^';
        } else {
            self.ch = self.input[self.read_position]
        }
        self.position = self.read_position;
        self.read_position += 1;
    }

    pub fn next_token(&mut self) -> Token {
        let tok: Token;
        self.skip_whitespace();
        match self.ch {
            '~' => tok = token::Token::BOF,
            '^' => tok = token::Token::EOF,
            '=' => tok = token::Token::EQL,
            '#' => tok = token::Token::LKMLCOM,
            // '"' => {
            '.' => tok = token::Token::DOT,
            ';' => tok = token::Token::SEMI,
            // ':' => tok = token::Token::COLON,
            '{' => tok = token::Token::LCURLY,
            '}' => tok = token::Token::RCURLY,
            '[' => tok = token::Token::LBRACK,
            ']' => tok = token::Token::RBRACK,
            ',' => tok = token::Token::COMMA,
            '\n' => tok = token::Token::NEWL,
            '\r' => tok = token::Token::NEWL,
            _ => {
                if is_letter(self.ch) {
                    let text: Vec<char> = self.read_identifier();
                    tok = self.text2token(text);
                    // println!("here");
                    // let obj = self.read_until('\"').into_iter().collect::<String>();
                    // self.file.includes.push(Include { path: obj });
                    // return token::Token::ILLEGAL('I');
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
    fn peek_gives_next_none_whitespace_char() {
        let input = "\tdimension: test\n {";

        let mut lexer = Lexer::new(input.chars().collect());
        lexer = adv_lexer_to(lexer, 2);
        println!("{}", lexer.ch);
        // println!("{}", lexer.peek());
        // assert_eq!(':', lexer.peek());
    }

    fn parse(mut lexer: Lexer) -> Vec<Token> {
        let mut tokens: Vec<Token> = Vec::new();
        loop {
            let token = lexer.next_token();
            match token {
                Token::ILLEGAL(_) => assert!(false),
                Token::EOF => break,
                _ => tokens.push(token),
            }
        }
        tokens
    }

    fn adv_lexer_to(mut lexer: Lexer, stop_pos: usize) -> Lexer {
        let mut tokens: Vec<Token> = Vec::new();
        for _ in 0..stop_pos {
            let token = lexer.next_token();
            match token {
                Token::ILLEGAL(_) => assert!(false),
                Token::EOF => break,
                _ => tokens.push(token),
            }
        }
        lexer
    }

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
    fn whitespace_skips_whitespaces() {
        let input = "\tdimension: test\n {";
        let expected_output = vec![BOF, DIM, COLON, TEST, LCURLY];

        let lexer = Lexer::new(input.chars().collect());
        let tokens = parse(lexer);

        for i in 0..tokens.len() {
            assert!(tokens[i] == expected_output[i]);
        }
    }

    // #[test]
    // fn next_token_gets_view_token() {
    //     let input = r#"view: test {
    //      dimension: {}
    //     }"#;
    // }
}
