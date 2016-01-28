#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use File::ReadBackwards;
use IO::Socket;


##### Conf to modify ############
my $log = "/var/log/jboss7/front/server.log";
my $search = "OutOfMemory";
## False-positive : Strings appearing during jboss start
my $exclu = "HeapDumpOnOutOfMemoryError";
my $TEST = "java_oom";
my $COLOR="green";
if (!defined($ENV{BBDISP})) { $ENV{BBDISP} = "1.2.3.4"; }
if (!defined($ENV{MACHINE})) { $ENV{MACHINE} = "device_name"; }
#######  End COnf ##############


#use constant ONE_HOUR =>  1 * 60 * 60;
#use constant ONE_HOUR =>  0 ;
#use constant TWO_HOUR =>  2 * 60 * 60;
use constant ONE_HOUR =>  60 * 60;
use constant TWO_HOUR =>  2 * 60 * 60;
use POSIX qw/strftime/;
my $date =  strftime("%H:", localtime(time - ONE_HOUR));
my $date_end =  strftime("%H:", localtime(time - TWO_HOUR));
my $now =  strftime("%d/%b/%Y:%H:%M:%S", localtime(time));

my %total;
my %counts;
my $count=0;
my @html;

push @html, "Watching $search in log $log <br>";
=for MyAss
push @html, "<style type=\"text/css\">";
push @html, "\n
\#top {
        margin: 1 auto;
        padding-right:5px;
        border-width:1px 2px 3px 2px;
        padding:0 10px;
        float:left;
        clear:both;
}";
push @html, "
td {
        padding-right:15px;
}
.type {
        border:1px solid white;
        padding:3px;
 }
</style>";
=cut



my @lines;
my @raw;
my $fh = File::ReadBackwards->new($log) or die "can't read file: $!\n";
while ( defined(my $line = $fh->readline) ) {
        next if $line !~ /^$date/;
        push @raw, $line;
        my @data = split (' ',$line);
        my $type = $data[1];
        #print "type:$type\n";
        if ( $line =~ /$search/ && $line !~ /$exclu/ ) {
                $counts{'oom'}++;
        }
        $counts{$type}++;
        $count++;
        print "line:$line\n";
        last if $line =~ /^$date_end/;
}

print "Error total: $count\n";

push @html, "<div id=top>";
push @html, "<h3><span class=type>Log Type</span></h3>";
push @html, "<table id=type border=1>";
#for my $type ( reverse sort keys %counts ) {
for my $type ( reverse sort { $counts{$a} <=> $counts{$b} } keys %counts ) {
        my $color = "green";
        my $max=10;
        use integer;
        my $perc = ( 100 * $counts{$type} / $count );
        if ( $type eq 'oom' ) {
                $color = 'red';
        }
        push @html, "<tr><td>&$color</td><td>$type</td><td>$counts{$type}</td><td>$perc%</td></tr>\n";
        print "Type:$type:$counts{$type}\n";
}
push @html, "</table></div>";

push @html, "<div id=bottom>";
push @html, "<BR><HR>RAW LOG:\n";
push @html, "<pre style=\"width: 80%; overflow: none\">@raw</pre>";
push @html, "<BR><HR>\n";
push @html, "</div>";

if (grep /&yellow/, @html) { $COLOR="yellow"; }
if (grep /&red/, @html) { $COLOR="red"; }


my $sock = new IO::Socket::INET (
         PeerAddr => $ENV{BBDISP},
         PeerPort => '1984',
         Proto => 'tcp',
);
die "Could not create socket: $!\n" unless $sock;

my $line="status+2d $ENV{MACHINE}.$TEST $COLOR $now - $TEST looks $COLOR
</pre><!-- FUCK We 1 -->
This led shows the error in log.
<br>

Analyzing Logs Date : $date
<br>

@html
<pre><!-- tatadammm -->
";

print $sock $line;
close $sock;

##############################
# RRD
#############################

for my $type ( reverse sort keys %counts ) {

my $rrd="data $ENV{MACHINE}.trends
[$TEST.$type.rrd]
DS:last_hour:GAUGE:600:U:U $counts{$type}";

print "rrd:$rrd\n";

my $sock = new IO::Socket::INET (
         PeerAddr => $ENV{BBDISP},
         PeerPort => '1984',
         Proto => 'tcp',
);
die "Could not create socket: $!\n" unless $sock;
print $sock $rrd;
close $sock;
}
############################

exit 0;
