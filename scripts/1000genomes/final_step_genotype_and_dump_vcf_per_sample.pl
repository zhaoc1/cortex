#!/usr/bin/perl -w
use strict;
use File::Basename;

use Getopt::Long;

## annoyingly, there are a couple of variable you need to pass in, even though you dont need them for this
my $hash = "/path/to/stampy/hash/of/human/genone";
my $stampy = "/path/to/stampy.py";
my $vcftoolsdir = "/path/to/vcftools_dir";
my $ref_fasta = "/path/to/human_g1k_v37.fasta.proper_chroms_only";
my $invcf = "cortex_phase3_biallelic_sitelist.vcf";

my $cortex_dir = "/home/zam/CORTEX_release_v1.0.5.21";
my $analyse_variants_dir = $cortex_dir."scripts/analyse_variants/";
my $sample_cleaned_graph="";
my $ref_overlap_bubble_graph="human_g1k_v37.proper_chroms.k31.ctx.list_intersect_bubbles.ctx";
my $bubble_callfile = "cortex_phase3_biallelic_pseudo_callfile";
my $mem_height = 24;
my $mem_width = 73;
my $kmer= 31;
my $sample="";
my $sample_graph="";
my $bubble_graph="";



&GetOptions(
    'invcf:s'                             =>\$invcf,
    'sample:s'                            =>\$sample,
    'sample_graph:s'                      =>\$sample_graph,##whole genome graph of sample
    'bubble_graph:s'                         => \$bubble_graph,
    'bubble_callfile:s'                   => \$bubble_callfile,#should be as above but with path in front
    'ref_overlap_bubble_graph:s'              => \$ref_overlap_bubble_graph,#should be as above, but with path on front
    'mem_height:i'                          =>\$mem_height,
    'mem_width:i'                           =>\$mem_width,
    );




check_args($bubble_graph, $mem_height, $mem_width, $sample);

if ($cortex_dir !~ /\/$/)
{
    $cortex_dir=$cortex_dir.'/';
}


## Now intersect your sample
my $ctx_binary = check_cortex_compiled_2colours($cortex_dir, $kmer);
my $suffix = "intersect_sites";
my ($colour_list, $filename_of_sample_overlap_bubble_binary) = make_colourlist($sample_graph, $sample, $suffix);


my $cmd = $ctx_binary." --kmer_size $kmer --mem_height $mem_height --mem_width $mem_width --multicolour_bin $bubble_graph --colour_list $colour_list --load_colours_only_where_overlap_clean_colour 0 --successively_dump_cleaned_colours $suffix";
print "$cmd\n";
my $ret = qx{$cmd};
print "$ret\n";
print "Finished intersecting sample $sample with the bubble graph $bubble_graph\n";

print "Now, genotype:\n";
my $gt_output = $bubble_callfile.".".$sample.".genotyped";
my $gt_log = $sample."_gt.log ";
my $g_colour_list = make_2colourlist($filename_of_sample_overlap_bubble_binary, $ref_overlap_bubble_graph, $sample);
my $gt_cmd = $ctx_binary." --kmer_size $kmer --mem_height $mem_height --mem_width $mem_width --colour_list $g_colour_list --max_read_len 15000 --gt ".$bubble_callfile.",".$gt_output.",BC –genome_size 3000000000 –experiment_type EachColourADiploidSampleExceptTheRefColour –print_median_covg_only  –estimated_error_rate 0.01 –ref_colour 0  >& $gt_log";
print "$gt_cmd\n";
my $gt_ret = qx{$gt_cmd};
print "$gt_ret\n";
print "Genotyping done\n\nNow dump a VCF\n";

my $vcf_cmd = "perl $analyse_variants_dir"."process_calls.pl --callfile $gt_ret --callfile_log $gt_log --out_vcf $sample".".vcf --outdir $outdir --samplename_list REF_AND_SAMPLE --num_cols 2 --stampy_hash $hash --vcftools_dir $vcftoolsdir --caller BC --kmer 31 --stampy_bin $stampy --refcol 0 --ploidy 2 --ref_fasta $ref_fasta --vcf_which_generated_calls $invcf";
print $vcf_cmd;
my $vcfret = qx{$vcf_cmd};
print $vcfret;

print "Finished! Sample $sample is genotyped and a VCF has been dumped\n";




sub check_args
{
    my ($bub_g, $h, $w, $sam) = @_;
    
    if ($bub_g eq "")
    {
	die("You must specify the bubble graph, using --bubble_graph");
    }
    if (!(-e $bub_g))
    {
	die("You have specified a non existent file $bub_g");
    }
    if ($sam eq "")
    {
	die("You must specify sample id with --sample");
    }
    if ($sample_graph eq "")
    {
	die("You must specify the cleaned sample graph with --sample_cleaned_graph");
    }

}


sub check_cortex_compiled_2colours
{
    my ($dir, $k) = @_;

    my $maxk=31;
    if (($k>32) && ($k<64) )
    {
	$maxk=63;
    }
    elsif ($k<32)
    {
	#maxk is already 31
    }
    else
    {
	die("This script expects you to use a k<64");
    }
	
    if (-e $dir."bin/cortex_var_".$maxk."_c2")
    {
	return $dir."bin/cortex_var_".$maxk."_c2";
    }
    else
    {
	die("Please go and compile Cortex in $cortex_dir for k=$kmer with 2 colours");
    }
}


sub make_colourlist
{
    my ($graph, $id, $suffix) = @_;

    my $bname = basename($graph);
    my $dir = dirname($graph);

    if ($dir !~ /\/$/)
    {
	$dir = $dir.'/';
    }
    my $col_list = $dir.$id."_colourlist_for_intersection";
    my $list_this_binary=$graph.".filelist";
    my $list_this_binary_nodir = basename($list_this_binary); 
    open(COL, ">".$col_list)||die("Cannot open $col_list");
    open(FLIST, ">".$list_this_binary)||die("Cannot open $list_this_binary");

    print FLIST "$bname\n";
    close(FLIST);
    print COL "$list_this_binary_nodir\n";
    close(FLIST);
    close(COL);

    return ($col_list, $list_this_binary.$suffix.".ctx");
}


##ref and sample
#we just want a file that says "REF\nSAMPLE_ID\n";
#where 
#  >cat REF
#  /path/to/reference_overlap_bubbles_binary
#  >cat SAMPLE_ID
#  /path/to/sample_ontersect_bubbles_binary
sub make_2colourlist
{
    my ($graph, $ref_binary, $id) = @_;

    my $bname = basename($graph);
    my $ref_bname = basename($ref_binary);
    my $dir = dirname($graph);

    if ($dir !~ /\/$/)
    {
	$dir = $dir.'/';
    }
    my $col_list = $dir.$id."_colourlist_for_genotyping";
    my $list_this_binary=$graph.".filelist";
    my $list_ref_binary =$ref_binary.".filelist";

    my $list_this_binary_nodir = basename($list_this_binary); 
    my $list_ref_binary_nodir = basename($list_ref_binary); 
    open(COL, ">".$col_list)||die("Cannot open $col_list");
    open(FLIST, ">".$list_this_binary)||die("Cannot open $list_this_binary");
    open(RLIST, ">".$list_ref_binary)||die("Cannot open $list_ref_binary");

    print FLIST "$bname\n";
    close(FLIST);
    print RLIST "$ref_bname\n";
    close(RLIST);
    print COL "$list_ref_binary_nodir\n$list_this_binary_nodir\n";
    close(COL);

    return $col_list;
}