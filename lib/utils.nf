// some small helper functions used throughout the workflow.

// Turns a true/false parameter into a real boolean (command-line values arrive as text, "false" would otherwise count as true).
def paramBoolean(value) {
    if ( value instanceof Boolean ) return value
    if ( value instanceof String ) {
        if ( !(value.toLowerCase() in ['true', 'false']) ) {
            error "expected true or false, got '${value}'."
        }
        return value.toLowerCase() == 'true'
    }
    error "expected a boolean, got '${value}' (${value.getClass()})."
}

// wraps a list so combine() keeps it as one item instead of flattening it.
def wrapList(value) {
    return [ value instanceof List ? value : [ value ] ]
}

// Staging location of file for a notebook: inputs/input_<n>/<filename>
// the numbered folder keeps files with the same name from clashing.
def inputName(files, f) { "input_${files.indexOf(f) + 1}/${f.name}" }
def inputRef(files, f)  { "inputs/${inputName(files, f)}" }

// Cohort columns as a list. On the command line --cohort_columns "a,b" arrives as one comma-separated string.
def cohortColumns(value) {
    if ( value instanceof List ) return value
    return value.toString().split(',').collect { it.trim() }.findAll { it }
}
