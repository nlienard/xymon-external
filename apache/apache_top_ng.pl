#!/usr/bin/perl
########################################
# NLIENARD - 2015-02-23
# Analyze Apache log on the last Hour
# Show top 10 of most frequented IP
# NEED PERL MODULE File::ReadBackwards
# !! NG version !!
# Not using of system() anymore
########################################

use strict;
use warnings;
use Data::Dumper;
use File::ReadBackwards;
use IO::Socket;


##### Conf to modify ############
my $path = "/var/log/httpd/";
my @vhosts=('www.domain1.com', 'www.domain2.fr', 'www.domain3.fr', 'www.domain4.com') ;
my $warn = 4000;
my $crit = 5000;
#######  End COnf ##############

my $TEST="apache_top";
my $COLOR="green";

use constant ONE_HOUR =>  60 * 60;
use constant TWO_HOUR =>  2 * 60 * 60;
use POSIX qw/strftime/;
my $date =  strftime("%d/%b/%Y:%H", localtime(time - ONE_HOUR));
my $date_end =  strftime("%d/%b/%Y:%H", localtime(time - TWO_HOUR));

my $now =  strftime("%d/%b/%Y:%H:%M:%S", localtime(time));

my %total;
my %counts;
my $count=0;
my @html;

push @html, "WARN : $warn - CRIT : $crit<br>";

push @html, "<style type=\"text/css\">";
push @html, "\n
\#top {
        margin: 0 auto;
        padding-right:5px;
        border-width:1px 2px 3px 2px;
        padding:0 10px;
        float:left;
}";
push @html, "
td {
        padding-right:15px;
}

.vhost {
        border:1px solid white;
        padding:3px;
 }
</style>";

foreach my $vhost (@vhosts) {
        my @lines;
        my $log=$path . ${vhost} . "_access.log";
        my $fh = File::ReadBackwards->new($log) or die "can't read file: $!\n";
        while ( defined(my $line = $fh->readline) ) {
            next if $line !~ /$date/;
            my @data = split (' ',$line);
            my $ip = $data[0];
            $ip =~ s/,//;
            next if $ip =~ "-";
            $counts{$vhost}{$ip}++;
            $total{$vhost}++;
            $count++;
            last if $line =~ /$date_end/;
      }
}

for my $vhost ( reverse sort keys %counts ) {
        push @html, "<div id=top>";
        push @html, "<h3><span class=vhost>$vhost</span></h3>";
        push @html, "<table id=$vhost>";
        my $max=10;
        my $count=0;
        for my $ip ( reverse sort { $counts{$vhost}{$a} <=> $counts{$vhost}{$b} } keys %{ $counts{$vhost} }) {
                use integer;
                my $perc = ( 100 * $counts{$vhost}{$ip} / $total{$vhost} );
                my $color = 'green';
                if ($counts{$vhost}{$ip} >= $warn) {
                        $color = 'yellow';
                }
                if ($counts{$vhost}{$ip} >= $crit) {
                        $color = 'red';
                }
                my $dns=`host -W 5 $ip| awk '{print \$5}'`;
                chomp($dns);
                push @html,  "<tr><td>&$color</td><td>$ip / $dns</td><td>$counts{$vhost}{$ip}</td><td>$perc%</td></tr>\n";
                $count++;
                last if $count eq $max;

        }
        push @html,  "<tr><td>&green</td><td>Total</td><td>$total{$vhost}</td><td>100%</td></tr>\n";
        push @html, "</table></div>";
}

if (grep /&yellow/, @html) { $COLOR="yellow"; }
if (grep /&red/, @html) { $COLOR="red"; }


my $sock = new IO::Socket::INET (
         PeerAddr => $ENV{BBDISP},
         PeerPort => '1984',
         Proto => 'tcp',
);
die "Could not create socket: $!\n" unless $sock;


my $line="status+2d $ENV{MACHINE}.$TEST $COLOR $now - apache_top looks $COLOR
This led shows the top IP by vhost.

Analyzing Logs Date : $date

@html
";

print $sock $line;
close $sock;

##############################
# RRD
#############################
for my $vhost ( reverse sort keys %counts ) {
my $rrd="data $ENV{MACHINE}.trends
[$TEST.$vhost.rrd]
DS:last_hour:GAUGE:600:U:U $total{$vhost}";

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
