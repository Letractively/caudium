/* Standard includes */

#include <module.h>
inherit "module";
inherit "caudiumlib";

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_type = MODULE_LOCATION | MODULE_PARSER;
constant module_name = "Data Collector Module";
constant module_doc  = "Module serving the purpose of collecting, preliminary "
                       "processing and storing data from forms that use this "
                       "module as their action.<br>"
                       "The module recognizes the following 'files':<br>"
                       "<ul>"
                       "<li><strong>final</strong> - this "
                       "invocation is the final one. This means that the session will "
                       "be destroyed right after producing the final output and before "
                       "redirecting to the destination URL. The final URL will receive "
                       "all the processing results in defines which are created by the "
                       "associated <code>data_processor</code> provider module."
                       "<li><strong>process</strong> - normal form data processing."
                       "</ul>Each 'file' understands and processes the following parameters:<br>"
                       "<ul>"
                       "<li><strong>url</strong> - the URL where the module should "
                       "redirect the browser after processing the data</li>"
                       "<li><strong>error_url</strong> - location where the browser should "
                       "be redirected should an error happen. The URL will be reached with "
                       "the session destroyed and can expect two variables to be present:<br>"
                       "  <ul>"
                       "    <li><strong>error_code</strong> - the error code</li>"
                       "    <li><strong>error_text</strong> - the error message</li>"
                       "  </ul>"
                       "</ul>"
                       "All the other parameters are passed to the provider module verbatim.<br>"
                       "The provider modules are expected to export the following two functions:<br><blockquote>"
                       "<code>mapping|int final(object id, mapping data, mapping variables, "
                       "mapping tags, mapping containers);</code><br>"
                       "<code>mapping|int process(object id, mapping data, mapping variables, "
                       "mapping tags, mapping containers);</code></blockquote>"
                       "Those functions are used in different stages of the data collecting process. "
                       "The first one is called with the <code>data</code> mapping containing all the "
                       "data collected so far when the module is accessed via the <code>process</code> "
                       "file. The latter is called when the module is invoked via the <code>final</code> "
                       "file. Both functions can process the data the way they want and they can define "
                       "tags, variables and containers in the corresponding mappings passed to them. Those "
                       "elements can be made available to any subsequent pages (before the session is killed "
                       "by putting the &lt;dcenv&gt; tag somewhere at the top of the page that needs that "
                       "information. The tags, containers and variables will be available through the usual "
                       "RXML mechanisms after the tag is called.<br>"
                       "The tags defined by this module are:<br><ul>"
                       "<li>&lt;dcenv&gt; - construct the RXML environment as described above."
                       "<li>&lt;dcdump&gt; - debugging tag used to dump the collected data."
                       "<li>&lt;dckill&gt; - explicitly kills the session with the data."
                       "</ul>";

constant module_unique = 0;

private constant default_return =
"<html><head><title>Default Result Page</title><body>"
"<strong>Collected data for module <em>%s</em>:</strong><br><pre>%O</pre>"
"</body></html>";

private constant default_error_return =
"<html><head><title>Default Error Page</title><body>"
"<strong>Error in module <em>%s</em>:</strong><br><pre>%O</pre>"
"</body></html>";

#define SESSOBJ(__id) __id->conf->get_provider("123sessions")
#define PROCOBJ(__id) __id->conf->get_provider(QUERY(data_plugin))
#define SVARS(__id) __id->misc->session_variables
#define DATA(__id) SVARS(__id)->dcdata[QUERY(dc_name)]
#define DATAPART(__id, __part) DATA(__id)->parts[__part]
#define CURDATA(__id) DATA(__id)->parts[-1]
#define VARIABLES(__id) DATA(__id)->variables
#define TAGS(__id) DATA(__id)->tags
#define CONTAINERS(__id) DATA(__id)->containers

#define CALL_USER_TAG id->conf->parse_module->call_user_tag
#define CALL_USER_CONTAINER id->conf->parse_module->call_user_container

//
// Helper methods
//
private void notice(string msg, mixed ... args) 
{
    report_notice("DATA_COLLECTOR(notice): " + msg + "\n", @args);
}

private void error(string msg, mixed ... args) 
{
    report_error("DATA_COLLECTOR(error): " + msg + "\n", @args);
}

private void debug(string msg, mixed ... args) 
{
    if (QUERY(debug))
        report_debug("DATA_COLLECTOR(debug): " + msg + "\n", @args);
}

private void warning(string msg, mixed ... args) 
{
    report_warning("DATA_COLLECTOR(warning): " + msg + "\n", @args);
}

//
// Server API methods
//
void create()
{
  defvar("mountpoint", "/dcoll", "Mount point", TYPE_LOCATION, 
         "This is where the module will be inserted in the "+
         "namespace of your virtual server.");
  defvar("data_plugin", "data_processor", "Data Processing Provider",
         TYPE_STRING,
         "Name of the provider module that exports APIs called by this "
         "module to process the collected data. The provider will be "
         "checked for the presence of all the required APIs and should they "
         "be missing, an error will be sent to the log.");
  defvar("dc_name", "dcoll", "Data collector name", TYPE_STRING,
         "This is the name used in the data part of the mapping built by this "
         "module to designate storage for this particular copy of the module. "
         "This allows for co-existence of several copies of this module which "
         "can store their data without disturbing other copies of the module.");
  defvar("debug", 0, "Debugging mode", TYPE_FLAG,
         "Output some debugging information into the server log");
}

void start(int num, object conf)
{
    module_dependencies(conf, ({ "123session" }));
}

string query_location()
{
  return QUERY(mountpoint);
}

private void next_part(object id)
{
    DATA(id)->counter++;
    DATA(id)->parts += ({([])});
    id->misc->is_dynamic = 1;
}

mixed find_file ( string path, object id )
{
    if (!SVARS(id))
        SVARS(id) = ([]);

    if (!SVARS(id)->dcdata)
        SVARS(id)->dcdata = ([]);

    if (!DATA(id)) {
        DATA(id) = ([]);
        DATA(id)->parts = ({});
        DATA(id)->counter = 0;
        VARIABLES(id) = ([]);
        TAGS(id) = ([]);
        CONTAINERS(id) = ([]);
    }
    
    collect_standard_params(id);
    switch(path) {
        case "/final":
            next_part(id);
            return do_final(id);

        case "/process":
            next_part(id);
            return do_process(id);
    }
    
    return 0;
}

void collect_standard_params(object id)
{
    if (!DATA(id)->std_params)
        DATA(id)->std_params = ([]);
    
    if (id->variables->url) {
        DATA(id)->std_params->url = id->variables->url;
        m_delete(id->variables, "url");
    }
    
    if (id->variables->error_url) {
        DATA(id)->std_params->error_url = id->variables->error_url;
        m_delete(id->variables, "error_url");
    }
}

private void collect_variables(object id, string prefix)
{
    if (id->variables && sizeof(id->variables)) {
        foreach(indices(id->variables), string idx)
            CURDATA(id)[idx] = id->variables[idx];
    } else {
        debug("%s - no variables passed from '%s'",
              prefix, id->referrer ? id->referrer : "typed URL");
    }
}

private mixed get_redirect(object id) 
{
    string url = 0;

    if (DATA(id)->std_params && DATA(id)->std_params->url) {
        url = DATA(id)->std_params->url;
        m_delete(DATA(id)->std_params, "url");
        m_delete(DATA(id)->std_params, "error_url");
    }
    
    return url ? http_redirect(url, id) :
        http_string_answer(sprintf(default_return,
                                   QUERY(dc_name),
                                   DATA(id)));
}

private mixed get_error_redirect(object id) 
{
    string error_url = 0;

    if (DATA(id)->std_params && DATA(id)->std_params->error_url) {
        error_url = DATA(id)->std_params->error_url;
        m_delete(DATA(id)->std_params, "url");
        m_delete(DATA(id)->std_params, "error_url");
    }
    
    return error_url ? http_redirect(error_url, id) :
        http_string_answer(sprintf(default_error_return,
                                   QUERY(dc_name),
                                   DATA(id)));
}

private void construct_defines(string which, object id,
                               mapping variables,
                               mapping tags,
                               mapping containers)
{
    if (variables && sizeof(variables)) {
        foreach(indices(variables), string idx) {
            if (VARIABLES(id)[idx])
                warning("%s - variable '%s' in module '%s' redefined",
                        which, idx, QUERY(dc_name));
            VARIABLES(id)[idx] = variables[idx];
        }
    }

    if (tags && sizeof(tags)) {
        foreach(indices(tags), string idx) {
            if (TAGS(id)[idx])
                warning("%s - tag '%s' in module '%s' redefined",
                        which, idx, QUERY(dc_name));
            TAGS(id)[idx] = tags[idx];
        }
    }

    if (containers && sizeof(containers)) {
        foreach(indices(containers), string idx) {
            if (CONTAINERS(id)[idx])
                warning("%s - container '%s' in module '%s' redefined",
                        which, idx, QUERY(dc_name));
            CONTAINERS(id)[idx] = containers[idx];
        }
    }
}

mixed provider_error(object id, mapping res)
{
    if (res->url)
        return http_redirect(res->url, id);
    else if (res->text) {
        string ret = sprintf("<html><head><title>%s</title></head>"
                             "<body>%s</body></html>",
                             res->title ? res->title : "Error",
                             res->text);
        
        return http_string_answer(ret);
    }

    return get_error_redirect(id);
}

//
// File handlers
//
mixed do_final(object id)
{
    object procobj = PROCOBJ(id);

    collect_variables(id, "final");
    if (procobj) {
        mapping variables = ([]);
        mapping tags = ([]);
        mapping containers = ([]);
        mapping|int res;
        
        res = procobj->final(id, DATA(id), variables, tags, containers);
        if (!res) {
            construct_defines("final", id, variables, tags, containers);
        } else if (mappingp(res)) {
            return provider_error(id, res);
        }
    } else {
        warning("final - no '%s' provider found in the virtual server '%s'\n",
                QUERY(data_plugin), id->conf->name);
    }

    return get_redirect(id);
}

mixed do_process(object id)
{
    object procobj = PROCOBJ(id);

    collect_variables(id, "process");    
    if (procobj) {
        mapping variables = ([]);
        mapping tags = ([]);
        mapping containers = ([]);
        mapping|int res;
        
        res = procobj->process(id, DATA(id), variables, tags, containers);
        if (!res) {
            construct_defines("final", id, variables, tags, containers);
        } else if (mappingp(res)) {
            return provider_error(id, res);
        }
    } else {
        warning("process - no '%s' provider found in the virtual server '%s'\n",
                QUERY(data_plugin), id->conf->name);
    }
    
    return get_redirect(id);
}


//
// Tags
//
string tag_dcenv(string tag, mapping m, object id,
                 object file, mapping defines)
{
    debug("setting up the data collector environment");
    
    if (!SVARS(id)) {
        warning("no session present!");
        return "<!-- environment NOT set up correctly (no session) -->";
    }
    
    if (!SVARS(id)->dcdata) {
        warning("no data collector section in session variables");
        return "<!-- environment NOT set up correctly (no dc section) -->";
    }

    if (!DATA(id)) {
        warning("no data collector section for '%s' in session variables",
               QUERY(dc_name));
        return "<!-- environment NOT set up correctly (no dc named section) -->";
    }
    
        
    // Variables
    if (VARIABLES(id) && sizeof(VARIABLES(id))) {
        foreach(indices(VARIABLES(id)), string idx) {
            if (id->variables[idx])
                warning("variable '%s' redefined from session",
                        idx);
            id->variables[idx] = VARIABLES(id)[idx];
        }
    }
    
    // Tags
    if (TAGS(id) && sizeof(TAGS(id))) {
        if (!id->misc->tags)
            id->misc->tags = ([]);
        if (!id->misc->defaults)
            id->misc->defaults = ([]);
        foreach(indices(TAGS(id)), string idx) {
            string tmp = lower_case(idx);

            if (!id->misc->defaults[tmp])
                id->misc->defaults[tmp] = ([]);
            id->misc->tags[tmp] = TAGS(id)[idx];
            id->misc->_tags[tmp] = CALL_USER_TAG;
            if (id->misc->_xml_parser)
                id->misc->_xml_parser->add_tag(tmp, CALL_USER_TAG);
        }
    }
    
    // Containers
    if (CONTAINERS(id) && sizeof(CONTAINERS(id))) {
        if (!id->misc->containers)
            id->misc->containers = ([]);
        foreach(indices(CONTAINERS(id)), string idx) {
            string tmp = lower_case(idx);

            if (!id->misc->defaults[tmp])
                id->misc->defaults[tmp] = ([]);
            id->misc->containers[tmp] = CONTAINERS(id)[idx];
            id->misc->_containers[tmp] = CALL_USER_TAG;
            if (id->misc->_xml_parser)
                id->misc->_xml_parser->add_container(tmp, CALL_USER_CONTAINER);
        }
    }
    
    return "\n<!-- environment set up correctly -->\n";
}

string tag_dcdump(string tag, mapping m, object id,
                  object file, mapping defines)
{
    string ret = "<hr>";

    if (id->variables) {
        ret += "<strong>Collected variables:</strong><br><blockquote>";
        foreach(indices(id->variables), string idx)
            ret += sprintf("<code>%s</code><br>", idx);
        ret += "</blockquote><br>";
    }
    
    if (id->misc->tags) {
        ret += "<strong>Collected tags:</strong><br><blockquote>";
        foreach(indices(id->misc->tags), string idx)
            ret += sprintf("<code>%s</code><br>", idx);
        ret += "</blockquote><br>";
    }

    if (id->misc->containers) {
        ret += "<strong>Collected containers:</strong><br><blockquote>";
        foreach(indices(id->misc->containers), string idx)
            ret += sprintf("<code>%s</code><br>", idx);
        ret += "</blockquote><br>";
    }

    return ret;
}

string tag_dckill(string tag, mapping m, object id,
                 object file, mapping defines)
{
    object sessobj = SESSOBJ(id);

    if (sessobj) {
        debug("killing session '%s'", id->misc->session_id);
        sessobj->delete_session(id, id->misc->session_id, 1);
    }

    return "<!-- session killed -->";
}

mapping query_tag_callers()
{
    return ([
        "dcenv" : tag_dcenv,
        "dckill" : tag_dckill,
        "dcdump" : tag_dcdump
    ]);
}
