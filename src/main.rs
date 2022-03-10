// https://github.com/joshtemple/lkml/blob/master/scripts/download_lookml.py
// https://mohitkarekar.com/posts/pl/lexer/
#[macro_use]
extern crate clap;

use clap::App;
use colored::Colorize;
use core::panic;
use std::time::Instant;

use std::env;
use std::fs;

mod lexer;
mod lkml_objects;

use crate::lexer::token::Token;
use crate::lexer::token::Token::*;
use crate::lexer::Lexer;

fn main() {
    let yaml = load_yaml!("cli.yml");
    let matches = App::from_yaml(yaml).get_matches();

    let current_dir = match env::current_dir() {
        Ok(exe_path) => exe_path,
        Err(_) => panic!("{}", "Cannot get current directory.".red()),
    };

    let mut file_path = current_dir.to_str().unwrap().to_owned();
    file_path.push_str("/");
    file_path.push_str(matches.value_of("file").unwrap());

    println!("Reading file: {}", file_path.green());
    let potential_lookml =
        fs::read_to_string(file_path).expect("Something went wrong reading the file");

    let mut lexer = Lexer::new(potential_lookml.chars().collect());
    let now = Instant::now();
    let mut tokens: Vec<Token> = Vec::new();
    loop {
        let token = lexer.next_token();
        if token == lexer::token::Token::EOF {
            break;
        } else {
            // println!("{:?}", token);
            tokens.push(token);
        }
    }
    println!("{:?}", lexer.file);
    let elapsed = now.elapsed();
    println!("Elapsed: {:.2?}", elapsed);
}
