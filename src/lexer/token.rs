extern crate phf;

#[derive(PartialEq, Debug)]
pub enum Token {
    ILLEGAL(char),
    BOF,
    EOF,
    VIEW,
    INCLUDE,
    EQL(char),
    DBLQ(char),
    CONST(char),
    SYMB(char),
    COLON(char),
    DOT(char),
    SEMI(char),
    LCURLY(char),
    RCURLY(char),
    LBRACK(char),
    RBRACK(char),
    IDENT(Vec<char>),
}

pub fn get_keyword_token(ident: &Vec<char>) -> Result<Token, String> {
    let identifier: String = ident.into_iter().collect();
    match &identifier[..] {
        "view" => Ok(Token::VIEW),
        "include" => Ok(Token::INCLUDE),
        _ => Err(String::from("Not valid token.")),
    }
}
