use crate::lkml_objects::{Dimension, DimensionGroup, Include, LKMLFile, View};

extern crate phf;

#[derive(PartialEq, Debug, Clone)]
pub enum Token {
    ILLEGAL(String),
    BOF,
    EOF,
    EQL,
    DOT,
    SEMI,
    LCURLY,
    RCURLY,
    LBRACK,
    RBRACK,
    COMMA,
    LKMLCOM,
    NEWL,
    VIEW(View),
    INCLUDE(Include),
    DIM(Dimension),
    DIMGRP(DimensionGroup),
    MEAS(Vec<char>),
    FILT(Vec<char>),
    FILTS(Vec<char>),
    ACCFILT(Vec<char>),
    BFILTS(Vec<char>),
    MLAYER(Vec<char>),
    PARAMTR(Vec<char>),
    SET(Vec<char>),
    COLUMN(Vec<char>),
    DERIVCOL(Vec<char>),
    EXPLORE(Vec<char>),
    LINK(Vec<char>),
    WHEN(Vec<char>),
    ALLWVAL(Vec<char>),
    NAMEVALFRMT(Vec<char>),
    JOIN(Vec<char>),
    DATGRP(Vec<char>),
    ACCGRNT(Vec<char>),
    SQLSTEP(Vec<char>),
    ACTION(Vec<char>),
    PARAM(Vec<char>),
    FPARAM(Vec<char>),
    OPTION(Vec<char>),
    USRATTRPARAM(Vec<char>),
    ASSERT(Vec<char>),
    TEST(Vec<char>),
    QUERY(Vec<char>),
    EXTNDS(Vec<char>),
    AGGTABLE(Vec<char>),
    CONST(Vec<char>),
    SYMB(Vec<char>),
    IDENT(Vec<char>),
}

pub fn get_keyword_token(ident: &Vec<char>) -> Result<Token, String> {
    let identifier: String = ident.into_iter().collect();
    match &identifier[..] {
        _ => Err(String::from("Not valid token.")),
    }
}
