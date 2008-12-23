#include <binary_kmer.h>
#include <stdlib.h>
#include <stdio.h>
#include <dB_graph.h>
#include <seq.h>

int load_fasta_data_from_filename_into_graph(char* filename, dBGraph* db_graph)
{
  FILE* fp = fopen(filename, "r");
  if (fp == NULL){
    printf("cannot open file:%s\n",filename);
    exit(1); //TODO - prfer to print warning and skip file and reutnr an error code?
  }

  return load_fasta_data_into_graph(fp, db_graph);
}


//returns length of sequence loaded
int load_fasta_data_into_graph(FILE* fp, dBGraph * db_graph)
{
  Sequence* seq;
  int seq_length=0;
  int count_bad_reads=0;

  while ((seq = read_sequence_from_fasta(fp)))
    {
      if (DEBUG)
	{
	  printf ("\nsequence %s\n",seq->seq);
	}

      KmerArray *kmers;
      int i;
      seq_length += seq->length;

      kmers = get_binary_kmers_from_sequence(seq->seq,seq->length,db_graph->kmer_size);
      free_sequence(&seq);

      if (kmers == NULL)
	{
	  count_bad_reads++;
	}

      else
	{
	  Element * current_node  = NULL;
	  Element * previous_node = NULL;
 	
	  Orientation current_orientation,previous_orientation;
	
	  for(i=0;i<kmers->nkmers;i++){	   
     	    current_node = hash_table_find_or_insert(element_get_key(kmers->bin_kmers[i],db_graph->kmer_size),db_graph);	  	  
	    current_orientation = db_node_get_orientation(kmers->bin_kmers[i],current_node, db_graph->kmer_size);
	    
	    if (DEBUG)
	      {
		printf("kmer %i:  %s\n",i,binary_kmer_to_seq(kmers->bin_kmers[i],db_graph->kmer_size));
	      }
	  
	    if (i>0){
	      //never assume that previous pointer stays as we do reallocation !!!!!!
	      previous_node = hash_table_find(element_get_key(kmers->bin_kmers[i-1],db_graph->kmer_size),db_graph);
	      
	      if (previous_node == NULL){
		puts("file_reader: problem - kmer not found\n");
		exit(1);
	      }
	      previous_orientation = db_node_get_orientation(kmers->bin_kmers[i-1],previous_node, db_graph->kmer_size); 	      
	      db_node_add_edge(previous_node,current_node,previous_orientation,current_orientation, db_graph->kmer_size);	  	      
	    }
	  
	  }
	  binary_kmer_free_kmers(&kmers);
	}
    }
  
  fprintf(stderr, "Found this many bad reads:%d\n", count_bad_reads);

  return seq_length;
}


