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

mod keys;
mod lookml_object;
use crate::keys::get_plural_keys;
use crate::lookml_object::LookMLObject;
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

    let lookml = validate_is_lookml(potential_lookml);
}

fn validate_is_lookml(potential_lookml: String) -> bool {
    let keys = get_plural_keys();

    let mut lookml_objects: Vec<LookMLObject> = keys
        .iter()
        .map(|k| LookMLObject {
            name: String::from(k.to_owned()),
            index: 0,
            length: k.len(),
            chars: k.chars().into_iter().collect::<Vec<char>>(),
        })
        .collect();

    let now = Instant::now();
    if potential_lookml.matches('{').count() != potential_lookml.matches('}').count() {
        panic!("{}", "Invalid LookML file. The number of opening brackets, \"{\" does not match the number of closing, \"}\"".red());
    }

    let mut line_index = 0;
    let mut bracket_index_level = 0;
    let mut curly_index_level = 0;

    for (i, character) in potential_lookml.chars().enumerate() {
        match character {
            '\n' => {
                line_index += 1;
                continue;
            }
            '{' => {
                curly_index_level += 1;
                continue;
            }
            '}' => {
                curly_index_level -= 1;
                continue;
            }
            '[' => {}
            ' ' => continue,
            '\t' => continue,
            _ => (),
        }

        // for j in 0..lookml_objects.len() {
        //     if lookml_objects[j].match_character(character) {
        //         break;
        //     };
        // }
    }

    let elapsed = now.elapsed();
    println!("Elapsed: {:.2?}", elapsed);
    true
}

// let characters = potential_lookml.replace(&['\n', '\t', ' '][..], "");
