use crate::lexer::token::Token;
use crate::lexer::token::Token::*;
pub struct Parser {
    tokens: Vec<Token>,
    active_node: Token,
}

impl Parser {
    pub fn new(tokens: Vec<Token>) -> Self {
        Self {
            tokens: tokens,
            active_node: ILLEGAL('%'),
        }
    }

    fn process_node(&mut self, token: &Token) -> () {
        match self.active_node {
            VIEW => match token {
                IDENT(_) => println!("{:?}, {:?}", self.active_node, token),
                LCURLY => println!("\t\tVIEW: {:?}", token),
                _ => self.active_node = ILLEGAL('%'),
            },
            LKMLCOM => match token {
                NEWL => self.active_node = ILLEGAL('%'),
                _ => println!("\t\tCOMMENT: {:?}", token),
            },
            _ => self.active_node = ILLEGAL('%'),
        }
    }

    pub fn parse(&mut self) -> () {
        let mut i = 0;
        while i < self.tokens.len() {
            let token = self.tokens.remove(i);
            self.process_node(&token);

            match token {
                ILLEGAL(_) => (),
                BOF => (),
                EOF => (),
                VIEW => self.active_node = VIEW,
                INCLUDE => (),
                DIM => (),
                DIMGRP => (),
                MEAS => (),
                FILT => (),
                FILTS => (),
                ACCFILT => (),
                BFILTS => (),
                MLAYER => (),
                PARAMTR => (),
                SET => (),
                COLUMN => (),
                DERIVCOL => (),
                EXPLORE => (),
                LINK => (),
                WHEN => (),
                ALLWVAL => (),
                NAMEVALFRMT => (),
                JOIN => (),
                DATGRP => (),
                ACCGRNT => (),
                SQLSTEP => (),
                ACTION => (),
                PARAM => (),
                FPARAM => (),
                OPTION => (),
                USRATTRPARAM => (),
                ASSERT => (),
                TEST => (),
                QUERY => (),
                EXTNDS => (),
                AGGTABLE => (),
                EQL => (),
                DBLQ => (),
                CONST => (),
                SYMB => (),
                COLON => (),
                DOT => (),
                SEMI => (),
                LCURLY => (),
                RCURLY => (),
                LBRACK => (),
                RBRACK => (),
                COMMA => (),
                LKMLCOM => self.active_node = LKMLCOM,
                IDENT(_) => (),
                NEWL => (),
            }
            i += 1;
        }
    }
}
