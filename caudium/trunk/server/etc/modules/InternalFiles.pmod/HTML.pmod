/* I'm -*-Pike-*-, dude */

static constant mime_type = "text/html";

static mapping empty_file = ([
    "data":#string "nofile.html",
    "type":mime_type]);

static string
replace_vars(string file, mapping(string:string) vars)
{
    if (!vars || !sizeof(vars))
        return file;

    array(string) from = ({}), to = ({});

    foreach(indices(vars), string var) {
        from += ({"$" + var});
        to += ({vars[var]});
    }

    return replace(file, from, to);
}

mapping(string:string) handle(object id,
                              string file,
			      mapping(string:mixed) query,
                              mapping(string:string) vars,
                              string basedir) 
{
    if (!basedir)
        throw(({"Must have a base directory!", backtrace()}));

    if (!query)
        throw(({"Query absent!", backtrace()}));
    
    if (basedir[-1] != '/')
        basedir += "/";

    while(sizeof(query) && query[0] == '/')
        query = query[1..];
    
    string fpath = basedir + query;

    if (!file_stat(fpath)) {
        empty_file->file = replace_vars(empty_file->file,
                                        (["fpath":fpath]));
        return empty_file;
    }
    
    return ([
        "data":replace_vars(Stdio.read_file(fpath), vars),
        "type":mime_type
    ]);
}
