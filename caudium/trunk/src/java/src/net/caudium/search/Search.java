package net.caudium.search;

import org.apache.lucene.analysis.standard.StandardAnalyzer;
import org.apache.lucene.search.Query;
import org.apache.lucene.search.Hits;
import org.apache.lucene.search.Searcher;
import org.apache.lucene.search.IndexSearcher;
import org.apache.lucene.queryParser.QueryParser;
import java.util.ArrayList;
import java.util.HashMap;

public class Search { 

    private static Searcher searcher; 

    /*
       create a new search engine
       @param dir directory the index is stored in
    */
    public void create(String dir)
      throws java.io.IOException
    {
      searcher = new IndexSearcher(dir);
    }

    private static final String attrib[] = 
       { "url", "title", "desc", "date", "type" };

    /**
     * Runs a query, returns a list of HashMap objects.  The objects have 
     * the following keys:
     * 'url', 'title', 'desc', 'score', 'date' and 'type'. 
     *
     * @param query Query to run against the index 
     */
    public static ArrayList search(String query) throws Exception {
        ArrayList list=search(query, 0, Integer.MAX_VALUE);
        return list;
    }

    /**
     * Runs a query, returns a list of HashMap objects.  The objects have 
     * the following keys:
     * 'url', 'title', 'desc', 'score'. 
     *
     * @param query Query to run against the index 
     * @param offset Position in the result set to start returning results
     * @param limit Max number of results to return
     */
    public static ArrayList search(String query, int offset, 
                                  int limit) throws Exception {

        Query q = QueryParser.parse(query, "body", new StandardAnalyzer());
                                    
        Hits h = searcher.search(q);
        ArrayList list = new ArrayList(h.length());
        for (int i = offset; list.size() < limit && i < h.length(); i++) {
            HashMap map = new HashMap();
            for (int x = 0; x < attrib.length; x++) {
                map.put(attrib[x], h.doc(i).get(attrib[x]));
            }
            map.put("score", new Float(h.score(i)));
            list.add(map);
        }
        searcher.close();

        return list;
    }

}
