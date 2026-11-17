//! Finds a prefix that SPARQL text uses without declaring it.
//!
//! Upstream reports an undeclared prefix as a general syntax error whose
//! message lists the characters it expected and never names the prefix. This
//! looks for the name itself, and only runs on text upstream has refused. Its
//! tokens follow the terminals of upstream's grammar, but it does not parse,
//! so it can take text inside a string or a comment for a name. What it finds
//! is a candidate, which the caller checks against the parser.

/// A prefixed name whose prefix nothing declared, and where it starts, with
/// the line and column counted from one in characters.
pub struct Undeclared {
    pub prefix: String,
    pub line: usize,
    pub column: usize,
}

/// Returns the first prefixed name in `text` whose prefix is neither one of
/// `declared` nor declared by a `PREFIX` before it. Comments, strings, IRIs,
/// variables, language tags, and blank node labels are skipped. The scan
/// ends, naming nothing, at a string that never closes and at a `<` that
/// does not open an IRI: a prefix is named only when it comes before the
/// first comparison or embedded triple.
pub fn first_undeclared(text: &str, declared: &[String]) -> Option<Undeclared> {
    let characters: Vec<char> = text.chars().collect();
    let mut declared: Vec<String> = declared.to_vec();
    let mut index = 0;
    while let Some(&character) = characters.get(index) {
        let next = characters.get(index + 1).copied();
        index = match character {
            '#' => after_comment(&characters, index),
            '<' => after_iri(&characters, index)?,
            '"' | '\'' => after_string(&characters, index)?,
            '?' | '$' => after_while(&characters, index + 1, is_variable_character),
            '@' => after_while(&characters, index + 1, is_language_tag_character),
            '_' if next == Some(':') => after_name(&characters, index + 2),
            ':' => {
                if !declared.iter().any(String::is_empty) {
                    return Some(undeclared(&characters, index, String::new()));
                }
                after_local_name(&characters, index + 1)
            }
            _ if is_name_start(character) => {
                let end = after_name(&characters, index);
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
/// White space and comments may come between the two.
fn after_declaration(characters: &[char], index: usize, declared: &mut Vec<String>) -> usize {
    let mut start = index;
    loop {
        start = after_while(characters, start, char::is_whitespace);
        if characters.get(start) == Some(&'#') {
            start = after_comment(characters, start);
        } else {
            break;
        }
    }
    let end = match characters.get(start) {
        Some(&character) if is_name_start(character) => after_name(characters, start),
        _ => start,
    };
    if characters.get(end) == Some(&':') {
        declared.push(characters[start..end].iter().collect());
        end + 1
    } else {
        start
    }
}

/// The index after the comment that opens at `start`. A comment runs to the
/// end of its line, which a carriage return ends as well as a line feed.
fn after_comment(characters: &[char], start: usize) -> usize {
    after_while(characters, start, |character| {
        !matches!(character, '\n' | '\r')
    })
}

/// The index after the run of name characters that starts at `start`, for a
/// prefix or a blank node label. Either may contain dots and may not end with
/// one.
fn after_name(characters: &[char], start: usize) -> usize {
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

/// The index after the IRI that opens at `start`, or nothing when the `<`
/// there opens no IRI that closes. Such a `<` is a comparison, the start of
/// an embedded triple, or an IRI cut short, and only a parse can tell which,
/// so what follows it cannot be read for prefixed names.
fn after_iri(characters: &[char], start: usize) -> Option<usize> {
    let end = after_while(characters, start + 1, |character| {
        !character.is_whitespace()
            && !matches!(character, '<' | '>' | '"' | '{' | '}' | '|' | '^' | '`')
    });
    (characters.get(end) == Some(&'>')).then_some(end + 1)
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
        } else if matches!(character, '\n' | '\r') {
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

/// The grammar's `PN_CHARS_BASE`: what a prefix may start with.
fn is_name_start(character: char) -> bool {
    matches!(character,
        'A'..='Z'
        | 'a'..='z'
        | '\u{00C0}'..='\u{00D6}'
        | '\u{00D8}'..='\u{00F6}'
        | '\u{00F8}'..='\u{02FF}'
        | '\u{0370}'..='\u{037D}'
        | '\u{037F}'..='\u{1FFF}'
        | '\u{200C}'..='\u{200D}'
        | '\u{2070}'..='\u{218F}'
        | '\u{2C00}'..='\u{2FEF}'
        | '\u{3001}'..='\u{D7FF}'
        | '\u{F900}'..='\u{FDCF}'
        | '\u{FDF0}'..='\u{FFFD}')
}

/// The grammar's `VARNAME` characters: what a variable name may contain.
fn is_variable_character(character: char) -> bool {
    is_name_start(character)
        || matches!(character,
            '_' | '0'..='9' | '\u{00B7}' | '\u{0300}'..='\u{036F}' | '\u{203F}'..='\u{2040}')
}

/// The grammar's `PN_CHARS`: a variable name's characters and the hyphen.
fn is_name_character(character: char) -> bool {
    character == '-' || is_variable_character(character)
}

fn is_language_tag_character(character: char) -> bool {
    character == '-' || character.is_ascii_alphanumeric()
}
