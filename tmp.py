keys = [
    "dimension",
    "dimension_group",
    "filter",
    "filters",
    "access_filter",
    "bind_filters",
    "map_layer",
    "parameter",
    "set",
    "column",
    "derived_column",
    "explore",
    "link",
    "when",
    "allowed_value",
    "named_value_format",
    "join",
    "datagroup",
    "access_grant",
    "sql_step",
    "action",
    "param",
    "form_param",
    "option",
    "user_attribute_param",
    "assert",
    "test",
    "query",
    "extends",
    "aggregate_table",
]

tokens = [
    "dim",
    "dimgrp",
    "filt",
    "filts",
    "accfilt",
    "bfilts",
    "mlayer",
    "paramtr",
    "set",
    "column",
    "derivcol",
    "explore",
    "link",
    "when",
    "allwval",
    "namevalfrmt",
    "join",
    "datgrp",
    "accgrnt",
    "sqlstep",
    "action",
    "param",
    "fparam",
    "option",
    "usrattrparam",
    "assert",
    "test",
    "query",
    "extnds",
    "aggtable",
]

def prep_key(s: str):
    return s.upper()
print(len(keys))
print(len(tokens))
print(list(set(tokens) - set(keys)))
# assert(len(keys) == len(tokens))
for i in range(0, len(keys)):
    print(f""" "{keys[i]}" => Ok(Token::{prep_key(tokens[i])}),""")