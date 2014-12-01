#/usr/bin/perl 
# set the above the path of your perl interpreter on Linux or Unix systems
#
# By Keith Wright
# 11/30/1994
#
# dedup.pl <directory>...
# Program will walk all subdirectories of starting directories provided as the first argument
# A md5_hex digest of the first $LENGTH bytes of each mov, jpg or nef file (or the files that match $reg)
# will be stored as the key in the %digests hash
# and the value of the %digests hash will be the path to the file.
# If the digest already exists, then the files will be reported as duplicates, and written to duplist.txt
# If the user confirms, then the duplicate files will be deleted

use warnings;
use strict;
use File::Find qw(find);
use Data::Dumper;
use Digest::MD5 'md5_hex';

die "Usage: $0 directory... \n" unless @ARGV; # do not start without at least one directory listed

my %digests; # unique set of keys for each digested file with the file as the value 
my @dups; # the array of duplicate file names
my $total_files; # used to count how many files are processed

# Variables to set to configure the script
my $LENGTH=1200; # the number of bytes to process in each file to determine if it is unique (default 1200)
# Given that I had over 10,000 files to process I limited this to 1200 bytes which was sufficient for photos
# In subsequent tests 500 is too low for small images
my $VERBOSE = 1; # whether to print more or less output
my $reg = qr/(jpg$)|(nef$)|(mov$)/i; # the regular expression to use to match the wanted files

&main; 

sub main {
	find(\&find_dups, @ARGV);
	&de_dup_files(@dups);
	my $secs = &get_secs;
	print "Total time to execute script was $secs seconds\n"; # if $VERBOSE; might speed things up a tiny bit
}

sub get_secs {
	return time - $^T;
}

sub find_dups {
	if ($_ =~ $reg) { # match all cases of jpg or nef
		my $file = $File::Find::name;  # store the full path for later
		my $fh;
		unless (open $fh, $_) { # $_ set by File::Find for the current path
			warn "$0 open $file: $!" if $VERBOSE;
			next;
		}
		print "$file " if $VERBOSE;
		my $digest = get_digest($fh);
		if (exists $digests{$digest}) {
			push @dups, $file;
		} else {
			$digests{$digest} = $file;
		}
	}	
	$total_files++;
}

sub get_digest { 
	my $fh = shift;
	binmode $fh;
	my $data;
	read $fh, $data, $LENGTH;
	#return md5_hex($data);
    my $digest = md5_hex($data); 
	print "$digest\n" if $VERBOSE;
	return $digest;
}

sub de_dup_files {
	print 'Duplicate files:'  if $VERBOSE;
	print Dumper(\@_) if $VERBOSE;
	my $dupfiles = scalar @_;
	print "$dupfiles duplicates found\n" if $VERBOSE;
	if ($dupfiles) {
		open(my $fh, ">", "duplist.txt") or die "cannot open > duplist.txt: $!";
		foreach my $file (@_) {
			print $fh "$file\n" if $VERBOSE;
		}
		close $fh;
	}
	my $secs = &get_secs;
	print "$secs seconds processing $total_files files and finding $dupfiles duplicates\n" if $VERBOSE;
	del_dups(@_);
}

sub del_dups {
	my $dupfiles = scalar @_;
	if ($dupfiles) {
		print 'Do you want to remove the duplicates? (y/n) ';
		chomp(my $answer=<STDIN>); 
		if ($answer eq 'y') {
			print "Removing $dupfiles duplicate files...\n" if $VERBOSE;
			foreach my $file (@_) {
				unlink $file or warn "Could not unlink $file: $!" if $VERBOSE;
			}
		}
	}
}
