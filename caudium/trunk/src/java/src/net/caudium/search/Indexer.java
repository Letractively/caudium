package net.caudium.search;

import org.apache.lucene.analysis.standard.StandardAnalyzer;
import org.apache.lucene.index.IndexWriter;
import org.apache.lucene.document.Document;
import org.apache.lucene.document.Field;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Enumeration;
import java.io.File;
import java.io.FileNotFoundException;

public class Indexer {

    private String indexDir;

    private IndexWriter index;

    private int bytes;

    public Indexer(String indexDir, boolean incremental)
      throws java.io.IOException
    {

        index = new IndexWriter(new File(indexDir), new StandardAnalyzer(),
                                !incremental);
    }

   public void close()
      throws java.io.IOException
   {
        index.optimize();
        index.close();
   }


   public void add(URLSummary summary)
     throws java.io.IOException
   {
            Document doc = new Document();
            doc.add(Field.UnIndexed("url", summary.url));
            doc.add(Field.UnIndexed("title", summary.title));
            doc.add(Field.UnIndexed("type", summary.type));
            doc.add(Field.UnIndexed("date", summary.date));
            doc.add(Field.UnIndexed("desc", summary.desc));
            doc.add(Field.Text("body", summary.body));
            synchronized(this) {
                bytes += summary.body.length();
                index.addDocument(doc);
            }
    }
            
}

class URLSummary {

    String url;
    String body;
    String desc = "";
    String title = "Untitled";
    String type = "text/html";
    String date = "";

}
