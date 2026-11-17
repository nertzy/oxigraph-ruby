//! Finds a prefix that SPARQL text uses without declaring it.
//!
//! Upstream reports an undeclared prefix as a general syntax error whose
//! message lists the characters it expected and never names the prefix. This
//! looks for the name itself, and only runs on text upstream has refused.

/// A prefixed name whose prefix nothing declared, and where it starts, with
/// the line and column counted from one in characters.
pub struct Undeclared {
    pub prefix: String,
    pub line: usize,
    pub column: usize,
}

/// Returns the first prefixed name in `text` whose prefix is neither one of
/// `declared` nor declared by a `PREFIX` before it. Comments, strings, IRIs,
/// variables, and blank node labels are skipped. Text this cannot follow, such
/// as an unclosed string, yields nothing.
pub fn first_undeclared(text: &str, declared: &[String]) -> Option<Undeclared> {
    let characters: Vec<char> = text.chars().collect();
    let mut declared: Vec<String> = declared.to_vec();
    let mut index = 0;
    while let Some(&character) = characters.get(index) {
        let next = characters.get(index + 1).copied();
        index = match character {
            '#' => after_while(&characters, index, |character| character != '\n'),
            '<' => after_iri(&characters, index),
            '"' | '\'' => after_string(&characters, index)?,
            '?' | '$' | '@' => after_while(&characters, index + 1, is_name_character),
            '_' if next == Some(':') => after_while(&characters, index + 2, is_name_character),
            ':' => {
                if !declared.iter().any(String::is_empty) {
                    return Some(undeclared(&characters, index, String::new()));
                }
                after_local_name(&characters, index + 1)
            }
            _ if character.is_alphabetic() => {
                let end = after_prefix(&characters, index);
                let word: String = characters[index..end].iter().collect();
                if characters.get(end) == Some(&':') {
                    if !declared.contains(&word) {
                        return Some(undeclared(&characters, index, word));
                    }
                    after_local_name(&characters, end + 1)
                } else if word.eq_ignore_ascii_case("PREFIX") {
                    after_declaration(&characters, end, &mut declared)
                } else {
                    end
                }
            }
            _ => index + 1,
        };
    }
    None
}

fn undeclared(characters: &[char], start: usize, prefix: String) -> Undeclared {
    let before = &characters[..start];
    let line_start = before
        .iter()
        .rposition(|&character| character == '\n')
        .map_or(0, |newline| newline + 1);
    Undeclared {
        prefix,
        line: before
            .iter()
            .filter(|&&character| character == '\n')
            .count()
            + 1,
        column: start - line_start + 1,
    }
}

/// Records the prefix that follows a `PREFIX` keyword ending at `index`.
fn after_declaration(characters: &[char], index: usize, declared: &mut Vec<String>) -> usize {
    let start = after_while(characters, index, char::is_whitespace);
    let end = after_prefix(characters, start);
    if characters.get(end) == Some(&':') {
        declared.push(characters[start..end].iter().collect());
        end + 1
    } else {
        start
    }
}

/// The index after the prefix that starts at `start`. A prefix may contain a
/// dot and may not end with one.
fn after_prefix(characters: &[char], start: usize) -> usize {
    let mut end = after_while(characters, start, |character| {
        is_name_character(character) || character == '.'
    });
    while end > start && characters[end - 1] == '.' {
        end -= 1;
    }
    end
}

fn after_local_name(characters: &[char], start: usize) -> usize {
    let mut index = start;
    while let Some(&character) = characters.get(index) {
        if character == '\\' {
            index += 2;
        } else if is_name_character(character) || matches!(character, '.' | ':' | '%') {
            index += 1;
        } else {
            break;
        }
    }
    index
}

/// The index after the IRI that opens at `start`, or after the `<` alone when
/// it is a comparison and not the start of an IRI.
fn after_iri(characters: &[char], start: usize) -> usize {
    for (offset, &character) in characters[start + 1..].iter().enumerate() {
        if character == '>' {
            return start + offset + 2;
        }
        if character.is_whitespace() || matches!(character, '<' | '"' | '{' | '}' | '|' | '^' | '`')
        {
            break;
        }
    }
    start + 1
}

/// The index after the string that opens at `start`, or nothing when the
/// string never closes.
fn after_string(characters: &[char], start: usize) -> Option<usize> {
    let quote = characters[start];
    let long =
        characters.get(start + 1) == Some(&quote) && characters.get(start + 2) == Some(&quote);
    let mut index = start + if long { 3 } else { 1 };
    while let Some(&character) = characters.get(index) {
        if character == '\\' {
            index += 2;
        } else if long {
            if characters[index..].starts_with(&[quote, quote, quote]) {
                return Some(index + 3);
            }
            index += 1;
        } else if character == quote {
            return Some(index + 1);
        } else if character == '\n' {
            return None;
        } else {
            index += 1;
        }
    }
    None
}

fn after_while(characters: &[char], start: usize, keep: impl Fn(char) -> bool) -> usize {
    let start = start.min(characters.len());
    characters[start..]
        .iter()
        .position(|&character| !keep(character))
        .map_or(characters.len(), |offset| start + offset)
}

fn is_name_character(character: char) -> bool {
    character.is_alphanumeric() || matches!(character, '_' | '-')
}
